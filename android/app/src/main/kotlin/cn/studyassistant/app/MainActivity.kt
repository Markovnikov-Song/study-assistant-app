package cn.studyassistant.app

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setIcon" -> {
                    val alias = call.argument<String>("icon") ?: "Icon1"
                    setAppIcon(alias)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setAppIcon(alias: String) {
        val pm = packageManager
        val packageName = packageName

        // 先禁用所有 alias
        listOf("Icon1", "Icon2", "Icon3").forEach { name ->
            pm.setComponentEnabledSetting(
                ComponentName(packageName, "$packageName.$name"),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        // 启用目标 alias（保留主 activity）
        pm.setComponentEnabledSetting(
            ComponentName(packageName, "$packageName.$alias"),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
    }
}
