package com.example.apptracngiem

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.bluetooth.BluetoothManager
import android.location.LocationManager
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val KIOSK_CHANNEL = "com.example.apptracngiem/kiosk"
    private val BLE_HOST_CHANNEL = "com.example.apptracngiem/ble_host"
    private val DEVICE_CHECK_CHANNEL = "com.example.apptracngiem/device_check"
    private var bleHostManager: BleGattServerManager? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Device Hardware & Network Pre-check Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHECK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isWifiEnabled" -> {
                    val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                    val activeNetwork = cm?.activeNetwork
                    val caps = cm?.getNetworkCapabilities(activeNetwork)
                    val isWifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
                    result.success(isWifi)
                }
                "isBluetoothEnabled" -> {
                    val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                    val isBt = bm?.adapter?.isEnabled == true
                    result.success(isBt)
                }
                "isLocationEnabled" -> {
                    val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    val isLoc = lm?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true ||
                                lm?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true
                    result.success(isLoc)
                }
                else -> result.notImplemented()
            }
        }

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
                "broadcastForceSubmit" -> {
                    bleHostManager?.broadcastForceSubmit()
                    result.success(true)
                }
                "broadcastPolicy" -> {
                    val autoSubmit = call.argument<Boolean>("autoSubmit") ?: true
                    bleHostManager?.broadcastPolicy(autoSubmit)
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
