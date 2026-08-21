package com.lumina.lumina

import android.content.ComponentName
import android.content.pm.PackageManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val iconAliases = linkedMapOf(
        "default" to "LauncherDefault",
        "a1" to "LauncherA1",
        "a2" to "LauncherA2",
        "b1" to "LauncherB1",
        "b2" to "LauncherB2",
        "c1" to "LauncherC1",
        "c2" to "LauncherC2",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lumina/app_icon",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(true)
                "getIcon" -> result.success(currentIconId())
                "setIcon" -> {
                    val iconId = call.argument<String>("iconId")
                    if (iconId == null || !iconAliases.containsKey(iconId)) {
                        result.error("invalid_icon", "Unknown app icon: $iconId", null)
                        return@setMethodCallHandler
                    }
                    try {
                        setIcon(iconId)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("icon_change_failed", error.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun component(alias: String): ComponentName =
        ComponentName(this, "$packageName.$alias")

    private fun currentIconId(): String {
        for ((iconId, alias) in iconAliases) {
            val state = packageManager.getComponentEnabledSetting(component(alias))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return iconId
            if (
                iconId == "default" &&
                state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
            ) return iconId
        }
        return "default"
    }

    private fun setIcon(iconId: String) {
        val targetAlias = iconAliases.getValue(iconId)
        packageManager.setComponentEnabledSetting(
            component(targetAlias),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for ((_, alias) in iconAliases) {
            if (alias == targetAlias) continue
            packageManager.setComponentEnabledSetting(
                component(alias),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
