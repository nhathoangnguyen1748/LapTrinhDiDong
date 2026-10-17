package com.example.apptracngiem

import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val KIOSK_CHANNEL = "com.example.apptracngiem/kiosk"
    private val BLE_HOST_CHANNEL = "com.example.apptracngiem/ble_host"
    private var bleHostManager: BleGattServerManager? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Kiosk Mode Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KIOSK_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "enableSecureMode") {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else if (call.method == "disableSecureMode") {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // BLE Host GATT Server Channel
        val hostChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLE_HOST_CHANNEL)
        bleHostManager = BleGattServerManager(this, hostChannel)

        hostChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> {
                    result.success(bleHostManager?.isSupported() ?: false)
                }
                "startHosting" -> {
                    val roomName = call.argument<String>("roomName") ?: "Phòng Thi BLE"
                    val chunksRaw = call.argument<List<ByteArray>>("chunks") ?: emptyList()
                    val success = bleHostManager?.startHosting(roomName, chunksRaw) ?: false
                    result.success(success)
                }
                "broadcastStart" -> {
                    bleHostManager?.broadcastMasterStart()
                    result.success(true)
                }
                "stopHosting" -> {
                    bleHostManager?.stopHosting()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        bleHostManager?.stopHosting()
        super.onDestroy()
    }
}
