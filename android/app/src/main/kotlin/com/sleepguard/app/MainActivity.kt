package com.sleepguard.app

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat

import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.sleepguard.app/channel"
    private val cameraEventChannel = "com.sleepguard.app/camera_brightness"
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var componentName: ComponentName
    private var cameraAnalyzer: CameraBrightnessAnalyzer? = null
    private var cameraEventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val CAMERA_PERMISSION_REQUEST_CODE = 1001
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        devicePolicyManager =
            getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        componentName = ComponentName(this, DeviceAdminReceiver::class.java)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            cameraEventChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                cameraEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                cameraEventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "lockScreen" -> {
                    lockScreen()
                    result.success(true)
                }
                "startForegroundService" -> {
                    startForegroundService()
                    result.success(true)
                }
                "stopForegroundService" -> {
                    stopForegroundService()
                    result.success(true)
                }
                "isDeviceAdmin" -> {
                    result.success(isDeviceAdmin())
                }
                "requestDeviceAdmin" -> {
                    requestDeviceAdmin()
                    result.success(true)
                }
                "removeDeviceAdmin" -> {
                    removeDeviceAdmin()
                    result.success(true)
                }
                "isCameraPermissionGranted" -> {
                    result.success(isCameraPermissionGranted())
                }
                "requestCameraPermission" -> {
                    requestCameraPermission(result)
                }
                "startCameraMonitor" -> {
                    startCameraMonitor()
                    result.success(true)
                }
                "stopCameraMonitor" -> {
                    stopCameraMonitor()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startCameraMonitor() {
        stopCameraMonitor()
        cameraAnalyzer = CameraBrightnessAnalyzer(this) { brightness ->
            mainHandler.post {
                cameraEventSink?.success(brightness)
            }
        }
        cameraAnalyzer?.start()
    }

    private fun stopCameraMonitor() {
        cameraAnalyzer?.stop()
        cameraAnalyzer = null
    }

    private fun lockScreen() {
        if (devicePolicyManager.isAdminActive(componentName)) {
            devicePolicyManager.lockNow()
        }
    }

    private fun startForegroundService() {
        val intent = Intent(this, ForegroundMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopForegroundService() {
        val intent = Intent(this, ForegroundMonitorService::class.java)
        stopService(intent)
    }

    private fun isDeviceAdmin(): Boolean {
        return devicePolicyManager.isAdminActive(componentName)
    }

    private fun requestDeviceAdmin() {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
        intent.putExtra(
            DevicePolicyManager.EXTRA_DEVICE_ADMIN,
            componentName
        )
        intent.putExtra(
            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
            "SleepGuard needs device admin permission to lock your screen when sleep is detected."
        )
        startActivity(intent)
    }

    private fun removeDeviceAdmin() {
        if (devicePolicyManager.isAdminActive(componentName)) {
            devicePolicyManager.removeActiveAdmin(componentName)
        }
    }

    private fun isCameraPermissionGranted(): Boolean {
        return ContextCompat.checkSelfPermission(
            this, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestCameraPermission(result: MethodChannel.Result) {
        if (isCameraPermissionGranted()) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAMERA_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }
}
