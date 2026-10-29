package com.transita.bolivia

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private var tone: ToneGenerator? = null
    private var nfc: NfcTerminal? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nfc = NfcTerminal(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.transita.bolivia/nfc"))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.transita.bolivia/payment_alert").setMethodCallHandler { call, result ->
            if (call.method != "paymentReceived") {
                result.notImplemented()
            } else {
                try {
                    handler.removeCallbacksAndMessages(null)
                    tone?.release()
                    tone = ToneGenerator(AudioManager.STREAM_MUSIC, 90)
                    tone?.startTone(ToneGenerator.TONE_PROP_ACK, 180)
                    handler.postDelayed({ tone?.startTone(ToneGenerator.TONE_PROP_ACK, 180) }, 300)
                    handler.postDelayed({ tone?.release(); tone = null }, 650)
                    result.success(null)
                } catch (error: RuntimeException) {
                    result.error("AUDIO_UNAVAILABLE", "No se pudo reproducir el aviso", null)
                }
            }
        }
    }

    override fun onPause() {
        nfc?.cancel()
        super.onPause()
    }

    override fun onDestroy() {
        nfc?.cancel()
        handler.removeCallbacksAndMessages(null)
        tone?.release()
        tone = null
        super.onDestroy()
    }
}
