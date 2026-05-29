package cn.studyassistant.app

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val ICON_CHANNEL = "app_icon"
    private val APK_CHANNEL = "apk_install"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        val alias = call.argument<String>("icon") ?: "Icon1"
                        setAppIcon(alias)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "install" -> installApk(call.argument("path"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("INVALID_PATH", "APK path is empty", null)
            return
        }
        val file = File(path)
        if (!file.exists()) {
            result.error("NOT_FOUND", "APK file not found", null)
            return
        }
        if (file.length() < 50L * 1024 * 1024) {
            result.error("INVALID_APK", "APK file is incomplete", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            result.error("NO_PERMISSION", "Install unknown apps not allowed", null)
            return
        }

        try {
            val uri: Uri = FileProvider.getUriForFile(
                this,
                "$packageName.apkInstallProvider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL_FAILED", e.message, null)
        }
    }

    private fun setAppIcon(alias: String) {
        val pm = packageManager
        val packageName = packageName

        listOf("Icon1", "Icon2", "Icon3").forEach { name ->
            pm.setComponentEnabledSetting(
                ComponentName(packageName, "$packageName.$name"),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }

        pm.setComponentEnabledSetting(
            ComponentName(packageName, "$packageName.$alias"),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
    }
}
