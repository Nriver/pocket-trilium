package nriver.pocket.trilium

import android.system.Os.setenv

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Patterns
import android.webkit.MimeTypeMap
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.NonNull
import androidx.annotation.Keep
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread


class MainActivity: FlutterFragmentActivity() {

    private var statusBarHidden: Boolean = false
    private var statusBarLightIcons: Boolean = false

    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingPickDestPath: String? = null

    private var shareChannel: MethodChannel? = null
    private var pendingShare: Map<String, Any?>? = null

    private val pickTriliumPackageLauncher =
        registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            val result = pendingPickResult
            val destPath = pendingPickDestPath
            pendingPickResult = null
            pendingPickDestPath = null

            if (result == null) {
                return@registerForActivityResult
            }
            if (uri == null || destPath == null) {
                result.success(null)
                return@registerForActivityResult
            }

            thread {
                try {
                    val destFile = File(destPath)
                    destFile.parentFile?.mkdirs()
                    contentResolver.openInputStream(uri)?.use { input ->
                        destFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    } ?: throw IllegalStateException("Cannot open selected file")
                    runOnUiThread { result.success(destPath) }
                } catch (e: Exception) {
                    runOnUiThread {
                        result.error("pick_file_failed", e.message, null)
                    }
                }
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "android")
        shareChannel?.setMethodCallHandler {
            // 注册通道并设置方法调用处理器
            call, result ->
            // 判断方法名
            when (call.method) {
                "launchSignal9Page" -> {
                    startActivity(Intent(this, Signal9Activity::class.java))
                    result.success(0)
                }
                "getNativeLibraryPath" -> {
                    result.success(getApplicationInfo().nativeLibraryDir)
                }
                "setStatusBarMode" -> {
                    statusBarHidden = call.argument<Boolean>("hidden") ?: false
                    statusBarLightIcons = call.argument<Boolean>("lightIcons") ?: false
                    applyStatusBarMode()
                    result.success(0)
                }
                "pickTriliumPackage" -> {
                    val destPath = call.argument<String>("destPath")
                    if (destPath.isNullOrEmpty()) {
                        result.error("invalid_args", "destPath is required", null)
                    } else if (pendingPickResult != null) {
                        result.error("busy", "A file picker is already open", null)
                    } else {
                        pendingPickResult = result
                        pendingPickDestPath = destPath
                        try {
                            pickTriliumPackageLauncher.launch(arrayOf("*/*"))
                        } catch (e: Exception) {
                            pendingPickResult = null
                            pendingPickDestPath = null
                            result.error("launch_failed", e.message, null)
                        }
                    }
                }
                "getPendingShare" -> {
                    result.success(pendingShare)
                }
                "consumePendingShare" -> {
                    pendingShare = null
                    result.success(0)
                }
                else -> {
                    // 不支持的方法名
                    result.notImplemented()
                }
            }
        }
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        if (action != Intent.ACTION_SEND &&
            action != Intent.ACTION_SEND_MULTIPLE &&
            action != Intent.ACTION_VIEW
        ) {
            return
        }

        val viewUrl = if (action == Intent.ACTION_VIEW) intent.data?.toString() else null
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            ?: intent.getCharSequenceExtra(Intent.EXTRA_HTML_TEXT)?.toString()

        val imageUris = if (action == Intent.ACTION_VIEW) {
            emptyList()
        } else {
            getSharedImageUris(intent)
        }

        if (imageUris.isNotEmpty()) {
            // Copying images may take a while, do it off the UI thread.
            thread {
                val images = imageUris.mapIndexedNotNull { index, uri ->
                    copySharedImage(uri, index, intent.type)
                }
                runOnUiThread {
                    deliverShare(action, text, subject, viewUrl, images)
                }
            }
            return
        }

        if (text.isNullOrBlank() && viewUrl.isNullOrBlank()) return
        deliverShare(action, text, subject, viewUrl, emptyList())
    }

    private fun deliverShare(
        action: String,
        text: String?,
        subject: String?,
        viewUrl: String?,
        images: List<Map<String, String>>,
    ) {
        val share = mutableMapOf<String, Any?>(
            "text" to text,
            "subject" to subject,
            "url" to extractUrl(viewUrl ?: text),
            "action" to action,
            "timestamp" to System.currentTimeMillis()
        )
        if (images.isNotEmpty()) {
            share["images"] = images
        }
        pendingShare = share
        try {
            shareChannel?.invokeMethod("onShareReceived", share)
        } catch (_: Exception) {
            // Flutter side is not ready yet; it will pull pendingShare later.
        }
    }

    @Suppress("DEPRECATION")
    private fun getSharedImageUris(intent: Intent): List<Uri> {
        val uris = mutableListOf<Uri>()

        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            val list: ArrayList<Uri>? =
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
            if (list != null) {
                uris.addAll(list)
            }
        }
        if (uris.isEmpty()) {
            val single: Uri? = intent.getParcelableExtra(Intent.EXTRA_STREAM)
            if (single != null) {
                uris.add(single)
            }
        }
        if (uris.isEmpty()) {
            val clip = intent.clipData
            if (clip != null) {
                for (i in 0 until clip.itemCount) {
                    clip.getItemAt(i)?.uri?.let { uris.add(it) }
                }
            }
        }

        val intentType = intent.type
        return uris.filter { uri ->
            val mime = contentResolver.getType(uri)
            mime?.startsWith("image/") == true ||
                (mime == null && intentType?.startsWith("image/") == true)
        }
    }

    private fun copySharedImage(
        uri: Uri,
        index: Int,
        fallbackMime: String?,
    ): Map<String, String>? {
        return try {
            val mime = contentResolver.getType(uri)
                ?: fallbackMime?.takeIf { it.startsWith("image/") }
                ?: guessImageMime(uri.lastPathSegment)
                ?: "image/jpeg"
            val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "jpg"
            val dir = File(cacheDir, "shared_images")
            if (!dir.exists() && !dir.mkdirs()) {
                return null
            }
            val file = File(dir, "shared_${System.currentTimeMillis()}_$index.$ext")
            contentResolver.openInputStream(uri)?.use { input ->
                file.outputStream().use { output ->
                    input.copyTo(output)
                }
            } ?: return null

            mapOf(
                "path" to file.absolutePath,
                "mime" to mime,
                "name" to (uri.lastPathSegment?.substringAfterLast('/') ?: file.name)
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun guessImageMime(name: String?): String? {
        val lower = name?.lowercase() ?: return null
        return when {
            lower.endsWith(".png") -> "image/png"
            lower.endsWith(".webp") -> "image/webp"
            lower.endsWith(".gif") -> "image/gif"
            lower.endsWith(".bmp") -> "image/bmp"
            lower.endsWith(".heic") || lower.endsWith(".heif") -> "image/heic"
            lower.endsWith(".jpg") || lower.endsWith(".jpeg") -> "image/jpeg"
            else -> null
        }
    }

    private fun extractUrl(text: String?): String? {
        if (text.isNullOrBlank()) return null

        val matcher = Patterns.WEB_URL.matcher(text)
        while (matcher.find()) {
            var candidate = matcher.group().trim()
            val matchEnd = matcher.end()

            // A trailing '?' can be part of the URL (empty query string).
            // Patterns.WEB_URL may stop before it, so append it when it is
            // the last character of the shared text.
            if (matchEnd < text.length &&
                text[matchEnd] == '?' &&
                text.substring(matchEnd + 1).isBlank()
            ) {
                candidate += "?"
            }

            candidate = candidate.trimEnd(
                '.', ',', ';', ':', '!', ')', ']', '}',
                '"', '\'', '，', '。', '！', '？', '）', '】', '》'
            )
            if (candidate.isBlank()) continue
            if (!candidate.startsWith("http://", ignoreCase = true) &&
                !candidate.startsWith("https://", ignoreCase = true)
            ) {
                candidate = "https://$candidate"
            }
            return candidate
        }

        val regex = Regex("""https?://[^\s<>"']+""", RegexOption.IGNORE_CASE)
        return regex.find(text)?.value?.trimEnd(
            '.', ',', ';', ':', '!', ')', ']', '}', '"', '\''
        )
    }

    private fun applyStatusBarMode() {
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        if (statusBarHidden) {
            controller.hide(WindowInsetsCompat.Type.statusBars())
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } else {
            controller.show(WindowInsetsCompat.Type.statusBars())
        }
        controller.isAppearanceLightStatusBars = !statusBarLightIcons
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            applyStatusBarMode()
        }
    }

}
