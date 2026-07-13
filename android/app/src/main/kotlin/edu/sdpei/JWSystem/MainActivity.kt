package edu.sdpei.JWSystem

import android.Manifest
import android.app.AlarmManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "edu.sdpei.JWSystem/widget_permission",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWidgetPermissionStatus" -> result.success(readWidgetPermissionStatus())
                "openAutostartSettings" -> result.success(openAutostartSettings())
                else -> result.notImplemented()
            }
        }
    }

    private fun readWidgetPermissionStatus(): Map<String, Any> {
        val sdkInt = Build.VERSION.SDK_INT
        val exactAlarmRequired = sdkInt >= Build.VERSION_CODES.S
        val canScheduleExactAlarms = if (exactAlarmRequired) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }

        val notificationRequired = sdkInt >= Build.VERSION_CODES.TIRAMISU
        val notificationGranted = if (notificationRequired) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val isXiaomiFamily = manufacturer.contains("xiaomi") ||
            brand.contains("xiaomi") ||
            brand.contains("redmi") ||
            brand.contains("poco")

        return mapOf(
            "canScheduleExactAlarms" to canScheduleExactAlarms,
            "exactAlarmRequired" to exactAlarmRequired,
            "notificationGranted" to notificationGranted,
            "notificationRequired" to notificationRequired,
            "isXiaomiFamily" to isXiaomiFamily,
            "sdkInt" to sdkInt,
        )
    }

    private fun openAutostartSettings(): Boolean {
        val intents = listOf(
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.PermissionsEditorActivity",
                )
                putExtra("extra_pkgname", packageName)
            },
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.fromParts("package", packageName, null)
            },
        )

        for (intent in intents) {
            try {
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // Try next fallback.
            }
        }
        return false
    }
}
