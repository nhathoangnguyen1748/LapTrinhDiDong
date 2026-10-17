package com.example.apptracngiem

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class BleGattServerManager(
    private val context: Context,
    private val methodChannel: MethodChannel
) {
    companion object {
        private const val TAG = "BleGattServerManager"
        val SERVICE_UUID: UUID = UUID.fromString("0000fef0-0000-1000-8000-00805f9b34fb")
        val CHAR_EXAM_DATA_UUID: UUID = UUID.fromString("0000fef1-0000-1000-8000-00805f9b34fb")
        val CHAR_SUBMIT_RESULT_UUID: UUID = UUID.fromString("0000fef2-0000-1000-8000-00805f9b34fb")
        val CHAR_CANDIDATE_CONTROL_UUID: UUID = UUID.fromString("0000fef3-0000-1000-8000-00805f9b34fb")
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private var examChunks: List<ByteArray> = emptyList()
    private val connectedDevices = ConcurrentHashMap.newKeySet<BluetoothDevice>()
    private var charExamData: BluetoothGattCharacteristic? = null
    private var charCandidateControl: BluetoothGattCharacteristic? = null

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            Log.d(TAG, "BLE Advertising started successfully")
        }

        override fun onStartFailure(errorCode: Int) {
            Log.e(TAG, "BLE Advertising start failed with code: $errorCode")
        }
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            Log.d(TAG, "onConnectionStateChange: ${device.address}, status=$status, newState=$newState")
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                connectedDevices.add(device)
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                connectedDevices.remove(device)
            }
        }

        override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
            Log.d(TAG, "onMtuChanged: ${device.address}, mtu=$mtu")
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic
        ) {
            Log.d(TAG, "onCharacteristicReadRequest: ${characteristic.uuid}")
            val value = characteristic.value ?: ByteArray(0)
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
        }

        override fun onDescriptorReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            descriptor: BluetoothGattDescriptor
        ) {
            Log.d(TAG, "onDescriptorReadRequest: ${descriptor.uuid}")
            val value = descriptor.value ?: BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            Log.d(TAG, "onDescriptorWriteRequest: desc=${descriptor.uuid}")
            descriptor.value = value
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            }

            if (descriptor.uuid == CCCD_UUID && descriptor.characteristic?.uuid == CHAR_EXAM_DATA_UUID) {
                val isNotifyEnabled = value != null && value.isNotEmpty() && (value[0].toInt() and 0x01) != 0
                Log.d(TAG, "Client ${device.address} enabled notify for exam data: $isNotifyEnabled")
                if (isNotifyEnabled && examChunks.isNotEmpty()) {
                    streamExamChunksToDevice(device)
                }
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            Log.d(TAG, "onCharacteristicWriteRequest: char=${characteristic.uuid}, length=${value?.size}")
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            }

            val data = value ?: return
            when (characteristic.uuid) {
                CHAR_SUBMIT_RESULT_UUID -> {
                    mainHandler.post {
                        methodChannel.invokeMethod("onSubmissionReceived", data)
                    }
                }
                CHAR_CANDIDATE_CONTROL_UUID -> {
                    mainHandler.post {
                        methodChannel.invokeMethod("onCandidateControlReceived", data)
                    }
                }
            }
        }
    }

    private fun streamExamChunksToDevice(device: BluetoothDevice) {
        executor.execute {
            try {
                // Wait briefly for CCCD handshake to finalize on client
                Thread.sleep(150)
                val targetChar = charExamData ?: return@execute
                Log.d(TAG, "Streaming ${examChunks.size} chunks to ${device.address}...")

                for ((index, chunk) in examChunks.withIndex()) {
                    sendNotification(device, targetChar, chunk)
                    // 25ms delay prevents BLE queue saturation
                    Thread.sleep(25)
                }
                Log.d(TAG, "Completed streaming ${examChunks.size} chunks to ${device.address}")
            } catch (e: Exception) {
                Log.e(TAG, "Error streaming chunks: ${e.message}")
            }
        }
    }

    private fun sendNotification(
        device: BluetoothDevice,
        characteristic: BluetoothGattCharacteristic,
        data: ByteArray
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gattServer?.notifyCharacteristicChanged(device, characteristic, false, data)
            } else {
                @Suppress("DEPRECATION")
                characteristic.value = data
                @Suppress("DEPRECATION")
                gattServer?.notifyCharacteristicChanged(device, characteristic, false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "sendNotification error: ${e.message}")
        }
    }

    fun isSupported(): Boolean {
        val adapter = bluetoothManager?.adapter ?: return false
        return adapter.isMultipleAdvertisementSupported
    }

    fun startHosting(roomName: String, chunks: List<ByteArray>): Boolean {
        stopHosting()
        examChunks = chunks

        val adapter = bluetoothManager?.adapter ?: return false
        if (!adapter.isEnabled) {
            Log.e(TAG, "Bluetooth adapter is not enabled")
            return false
        }

        // 1. Open GATT Server
        val server = bluetoothManager.openGattServer(context, gattServerCallback)
        if (server == null) {
            Log.e(TAG, "openGattServer returned null")
            return false
        }
        gattServer = server

        // 2. Build Service & Characteristics
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        // Exam Data Characteristic (Read + Notify)
        val examChar = BluetoothGattCharacteristic(
            CHAR_EXAM_DATA_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        val cccdExam = BluetoothGattDescriptor(
            CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        examChar.addDescriptor(cccdExam)
        service.addCharacteristic(examChar)
        charExamData = examChar

        // Submit Result Characteristic (Write + Write_No_Response)
        val submitChar = BluetoothGattCharacteristic(
            CHAR_SUBMIT_RESULT_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        service.addCharacteristic(submitChar)

        // Candidate Control Characteristic (Write + Notify)
        val controlChar = BluetoothGattCharacteristic(
            CHAR_CANDIDATE_CONTROL_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        val cccdControl = BluetoothGattDescriptor(
            CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        controlChar.addDescriptor(cccdControl)
        service.addCharacteristic(controlChar)
        charCandidateControl = controlChar

        server.addService(service)

        // 3. Start Advertising
        val adv = adapter.bluetoothLeAdvertiser
        if (adv == null) {
            Log.e(TAG, "BluetoothLeAdvertiser is null")
            return false
        }
        advertiser = adv

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0)
            .build()

        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .setIncludeDeviceName(true)
            .build()

        adv.startAdvertising(settings, data, advertiseCallback)
        Log.d(TAG, "Started BLE Host: $roomName with ${chunks.size} chunks")
        return true
    }

    fun broadcastMasterStart() {
        val controlChar = charCandidateControl ?: return
        val startPayload = byteArrayOf(0x01)
        Log.d(TAG, "Broadcasting Master Start to ${connectedDevices.size} connected devices")
        for (device in connectedDevices) {
            sendNotification(device, controlChar, startPayload)
        }
    }

    fun stopHosting() {
        try {
            advertiser?.stopAdvertising(advertiseCallback)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping advertising: ${e.message}")
        }
        advertiser = null

        try {
            gattServer?.clearServices()
            gattServer?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing GATT server: ${e.message}")
        }
        gattServer = null
        connectedDevices.clear()
        charExamData = null
        charCandidateControl = null
        examChunks = emptyList()
    }
}
