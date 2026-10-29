package com.transita.bolivia

import android.app.Activity
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/** Lee tarjetas Transita con SDM. El UID nunca autoriza un cobro por sí solo. */
class NfcTerminal(private val activity: Activity, channel: MethodChannel) {
    private val adapter = NfcAdapter.getDefaultAdapter(activity)
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private val mime = "application/vnd.transita.card"
    private val timeout = Runnable { finish(null, "TIMEOUT", "Se agotó el tiempo. Vuelve a acercar la tarjeta.") }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(if (adapter == null) "unavailable" else if (adapter.isEnabled) "ready" else "disabled")
                "cancel" -> { cancel(); result.success(null) }
                "read" -> {
                    if (adapter == null || !adapter.isEnabled) {
                        result.error("NFC_UNAVAILABLE", "Activa NFC o utiliza QR.", null)
                    } else if (pending != null) {
                        result.error("BUSY", "Ya hay una lectura NFC en curso.", null)
                    } else {
                        pending = result
                        try {
                            adapter.enableReaderMode(activity, { tag -> process(tag, result) },
                                NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
                                NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V or
                                NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS, null)
                            handler.postDelayed(timeout, 45000)
                        } catch (_: RuntimeException) {
                            finish(null, "NFC_UNAVAILABLE", "No se pudo iniciar el lector NFC.")
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun process(tag: Tag, request: MethodChannel.Result) {
        var content: String? = null
        var failure: String? = null
        try {
                val ndef = Ndef.get(tag) ?: throw IllegalArgumentException()
                ndef.use {
                    it.connect()
                    val messages = it.ndefMessage ?: throw IllegalArgumentException()
                    val record = messages.records.firstOrNull { record ->
                        record.tnf == NdefRecord.TNF_MIME_MEDIA && record.type.contentEquals(mime.toByteArray(Charsets.US_ASCII))
                    } ?: throw IllegalArgumentException()
                    require(record.payload.size <= 512)
                    content = String(record.payload, Charsets.UTF_8)
                }
        } catch (_: Exception) {
            failure = "No se pudo leer una tarjeta Transita compatible. Vuelve a acercarla o utiliza QR."
        }
        handler.post {
            if (pending === request) finish(content, if (failure == null) null else "TAG_ERROR", failure)
        }
    }

    private fun finish(value: String?, error: String?, message: String?) {
        val result = pending ?: return
        pending = null
        handler.removeCallbacks(timeout)
        try { adapter?.disableReaderMode(activity) } catch (_: RuntimeException) { }
        if (error == null) result.success(value) else result.error(error, message, null)
    }

    fun cancel() { finish(null, "CANCELLED", "Lectura cancelada.") }
}
