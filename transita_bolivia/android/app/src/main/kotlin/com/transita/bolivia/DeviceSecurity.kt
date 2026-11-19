package com.transita.bolivia

import android.app.Activity
import android.content.Context
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.hardware.fingerprint.FingerprintManager
import android.os.Build
import android.os.CancellationSignal
import io.flutter.plugin.common.MethodChannel

/** El sistema verifica la biometría; no se leen ni almacenan plantillas. */
class DeviceSecurity(private val activity: Activity, channel: MethodChannel) {
    private var signal: CancellationSignal? = null
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "appVersion" -> {
                    @Suppress("DEPRECATION")
                    val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
                    @Suppress("DEPRECATION")
                    val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                    result.success(mapOf("version" to (info.versionName ?: ""), "build" to code.toString()))
                }
                "biometricAvailable" -> result.success(available())
                "authenticate" -> authenticate(result)
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun available(): Boolean {
        return try {
            when {
                Build.VERSION.SDK_INT >= 30 -> activity.getSystemService(BiometricManager::class.java)
                    ?.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
                Build.VERSION.SDK_INT >= 29 -> activity.getSystemService(BiometricManager::class.java)
                    ?.canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
                Build.VERSION.SDK_INT >= 28 -> {
                    val manager = activity.getSystemService(Context.FINGERPRINT_SERVICE) as? FingerprintManager
                    manager?.isHardwareDetected == true && manager.hasEnrolledFingerprints()
                }
                else -> false
            }
        } catch (_: RuntimeException) { false }
    }

    private fun authenticate(result: MethodChannel.Result) {
        if (pending != null || Build.VERSION.SDK_INT < 28 || !available()) {
            result.success(false)
            return
        }
        pending = result
        signal = CancellationSignal()
        try {
            val builder = BiometricPrompt.Builder(activity)
                .setTitle("Mi Pasaje")
                .setSubtitle("Confirma tu identidad para continuar")
                .setNegativeButton("Cancelar", activity.mainExecutor) { _, _ -> cancel() }
            if (Build.VERSION.SDK_INT >= 30) {
                builder.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            }
            builder.build().authenticate(signal!!, activity.mainExecutor, object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(value: BiometricPrompt.AuthenticationResult) { finish(true) }
                override fun onAuthenticationError(code: Int, text: CharSequence) { finish(false) }
            })
        } catch (_: RuntimeException) { cancel() }
    }

    private fun finish(ok: Boolean) {
        val result = pending
        pending = null
        signal = null
        result?.success(ok)
    }

    fun cancel() {
        val active = signal
        finish(false)
        active?.cancel()
    }
}
