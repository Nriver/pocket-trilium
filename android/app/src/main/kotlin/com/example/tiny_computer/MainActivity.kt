package nriver.pocket.trilium

import android.system.Os.setenv

import android.content.Intent
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

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "android").setMethodCallHandler {
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
                else -> {
                    // 不支持的方法名
                    result.notImplemented()
                }
            }
        }
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
