package nriver.pocket.trilium

import android.content.Context
import com.google.android.material.color.DynamicColors
import io.flutter.app.FlutterApplication

class MainApplication : FlutterApplication() {

    override fun onCreate() {
        super.onCreate()
        DynamicColors.applyToActivitiesIfAvailable(this@MainApplication)
    }

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
    }
}