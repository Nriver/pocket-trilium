package nriver.pocket.trilium

import android.system.Os.setenv

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
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
        handleShareIntent(intent, true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent, false)
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

    private fun handleShareIntent(intent: Intent?, fromOnCreate: Boolean) {
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

        val uris = if (action == Intent.ACTION_VIEW) {
            emptyList()
        } else {
            getSharedUris(intent)
        }
        val sourceApp = resolveSourceAppLabel(intent, fromOnCreate, uris)

        if (uris.isNotEmpty()) {
            val hasNonImage = uris.any { !isImageUri(it, intent.type) }

            // Copying files may take a while, do it off the UI thread.
            thread {
                val copied = uris.mapIndexedNotNull { index, uri ->
                    copySharedFile(uri, index, intent.type)
                }
                runOnUiThread {
                    if (hasNonImage) {
                        deliverShare(
                            action, text, subject, viewUrl,
                            images = emptyList(), files = copied, sourceApp = sourceApp
                        )
                    } else {
                        deliverShare(
                            action, text, subject, viewUrl,
                            images = copied, files = emptyList(), sourceApp = sourceApp
                        )
                    }
                }
            }
            return
        }

        if (text.isNullOrBlank() && viewUrl.isNullOrBlank()) return
        deliverShare(
            action, text, subject, viewUrl,
            images = emptyList(), files = emptyList(), sourceApp = sourceApp
        )
    }

    private fun deliverShare(
        action: String,
        text: String?,
        subject: String?,
        viewUrl: String?,
        images: List<Map<String, Any?>>,
        files: List<Map<String, Any?>>,
        sourceApp: String?,
    ) {
        val share = mutableMapOf<String, Any?>(
            "text" to text,
            "subject" to subject,
            "url" to extractUrl(viewUrl ?: text),
            "action" to action,
            "sourceApp" to sourceApp,
            "timestamp" to System.currentTimeMillis()
        )
        if (images.isNotEmpty()) {
            share["images"] = images
        }
        if (files.isNotEmpty()) {
            share["files"] = files
        }
        pendingShare = share
        try {
            shareChannel?.invokeMethod("onShareReceived", share)
        } catch (_: Exception) {
            // Flutter side is not ready yet; it will pull pendingShare later.
        }
    }

    @Suppress("DEPRECATION")
    private fun resolveSourceAppLabel(
        intent: Intent,
        fromOnCreate: Boolean,
        uris: List<Uri>,
    ): String? {
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            return null
        }

        val intentReferrer: Uri? = intent.getParcelableExtra(Intent.EXTRA_REFERRER)
        appLabelFromReferrer(intentReferrer)?.let { return it }

        val referrerName = intent.getStringExtra(Intent.EXTRA_REFERRER_NAME)
        if (!referrerName.isNullOrBlank()) {
            appLabelFromReferrer(Uri.parse(referrerName))?.let { return it }
            appLabelForPackage(referrerName)?.let { return it }
        }

        // Content providers are often app-specific (FileProvider, gallery
        // providers, ...) and work for both cold and warm shares where the
        // system referrer is unavailable.
        sourceAppFromContentUris(uris)?.let { return it }

        // The launching package is only reliable for the initial share.
        if (fromOnCreate) {
            appLabelForPackage(getLaunchedFromPackage())?.let { return it }
            appLabelFromReferrer(referrer)?.let { return it }
        }

        return null
    }

    private fun sourceAppFromContentUris(uris: List<Uri>): String? {
        for (uri in uris) {
            if (uri.scheme != "content") continue
            val authority = uri.authority ?: continue
            if (isGenericFileAuthority(authority)) continue

            val providerPackage = try {
                packageManager.resolveContentProvider(authority, 0)?.packageName
            } catch (_: Exception) {
                null
            }
            appLabelForPackage(providerPackage)?.let { return it }

            appLabelForPackage(authority)?.let { return it }

            val parts = authority.split('.')
            for (i in parts.size downTo 2) {
                appLabelForPackage(parts.take(i).joinToString("."))?.let { return it }
            }
        }
        return null
    }

    private fun isGenericFileAuthority(authority: String): Boolean {
        val lower = authority.lowercase()
        return lower == "media" ||
            lower.contains("providers.media") ||
            lower.contains("externalstorage") ||
            lower.contains("documentsui") ||
            lower.contains("downloads")
    }

    private fun appLabelFromReferrer(uri: Uri?): String? {
        if (uri == null) return null
        return when (uri.scheme) {
            "android-app" -> appLabelForPackage(uri.host)
            null -> appLabelForPackage(uri.toString())
            else -> null
        }
    }

    private val homePackages: Set<String> by lazy {
        try {
            val homeIntent = Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
            packageManager.queryIntentActivities(homeIntent, 0)
                .mapNotNull { it.activityInfo?.packageName }
                .toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    private fun appLabelForPackage(packageName: String?): String? {
        if (packageName.isNullOrBlank() ||
            packageName == this.packageName ||
            homePackages.contains(packageName)
        ) {
            return null
        }
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString().trim().ifEmpty { null }
        } catch (_: Exception) {
            null
        }
    }

    @Suppress("DEPRECATION")
    private fun getSharedUris(intent: Intent): List<Uri> {
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

        return uris
    }

    private fun isImageUri(uri: Uri, fallbackMime: String?): Boolean {
        val mime = contentResolver.getType(uri)
            ?: fallbackMime?.takeIf { it.isNotBlank() && it != "*/*" }
            ?: guessMimeFromName(displayNameFor(uri))
        return mime?.startsWith("image/") == true
    }

    private fun copySharedFile(
        uri: Uri,
        index: Int,
        fallbackMime: String?,
    ): Map<String, Any?>? {
        return try {
            val displayName = displayNameFor(uri)
            val mime = contentResolver.getType(uri)
                ?: fallbackMime?.takeIf { it.isNotBlank() && it != "*/*" }
                ?: guessMimeFromName(displayName)
                ?: "application/octet-stream"

            val extension = MimeTypeMap.getSingleton()
                .getExtensionFromMimeType(mime)
                ?: displayName?.substringAfterLast('.', "")?.takeIf { it.isNotEmpty() }
                ?: "bin"

            val dir = File(cacheDir, "shared_files")
            if (!dir.exists() && !dir.mkdirs()) {
                return null
            }
            val file = File(dir, "shared_${System.currentTimeMillis()}_$index.$extension")
            contentResolver.openInputStream(uri)?.use { input ->
                file.outputStream().use { output ->
                    input.copyTo(output)
                }
            } ?: return null

            mapOf(
                "path" to file.absolutePath,
                "mime" to mime,
                "name" to (displayName ?: file.name),
                "size" to file.length(),
                "isImage" to mime.startsWith("image/")
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun displayNameFor(uri: Uri): String? {
        return queryDisplayName(uri) ?: uri.lastPathSegment
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) cursor.getString(index) else null
                } else {
                    null
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun guessMimeFromName(name: String?): String? {
        val extension = name?.substringAfterLast('.', "")?.lowercase() ?: return null
        if (extension.isEmpty()) return null
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
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
