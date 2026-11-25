package com.transita.bolivia

import android.app.Activity
import android.os.Build
import io.flutter.plugin.common.MethodChannel

/** Solo consulta metadatos de la app instalada. */
class AppInfo(activity: Activity, channel: MethodChannel) {
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "appVersion") {
                @Suppress("DEPRECATION")
                val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
                @Suppress("DEPRECATION")
                val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                result.success(mapOf("version" to (info.versionName ?: ""), "build" to code.toString()))
            } else {
                result.notImplemented()
            }
        }
    }
}
