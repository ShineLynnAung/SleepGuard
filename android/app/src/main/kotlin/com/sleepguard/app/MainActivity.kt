package com.sleepguard.app

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.sleepguard.app/channel"
    private val cameraEventChannel = "com.sleepguard.app/camera_brightness"
    private val monitorEventChannel = "com.sleepguard.app/monitor_state"
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var componentName: ComponentName
    private var cameraAnalyzer: CameraBrightnessAnalyzer? = null
    private var cameraEventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var touchOverlayHelper: TouchOverlayHelper? = null
    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val CAMERA_PERMISSION_REQUEST_CODE = 1001
        private const val OVERLAY_PERMISSION_REQUEST_CODE = 1002
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

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            monitorEventChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                ForegroundMonitorService.monitorEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                ForegroundMonitorService.monitorEventSink = null
            }
        })

        ForegroundMonitorService.onAwakeTimeoutReached = {
            mainHandler.post {
                showAwakeOverlay()
                methodChannel?.invokeMethod("onInactivityTimeoutReached", null)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channel
        ).also { methodChannel = it }.setMethodCallHandler { call, result ->
            when (call.method) {
                "lockScreen" -> {
                    lockScreen()
                    result.success(true)
                }
                "lockFromTimeout" -> {
                    ForegroundMonitorService.serviceInstance?.executeLock()
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
                "showExitOverlay" -> {
                    showExitOverlay()
                    result.success(true)
                }
                "showAwakeOverlay" -> {
                    showAwakeOverlay()
                    result.success(true)
                }
                "hideAwakeOverlay" -> {
                    hideOverlay()
                    result.success(true)
                }
                "hideOverlay" -> {
                    hideOverlay()
                    result.success(true)
                }
                "isOverlayShowing" -> {
                    result.success(isOverlayShowing())
                }
                "getLastOverlayTouchTime" -> {
                    result.success(getLastOverlayTouchTime())
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(true)
                }
                "isOverlayPermissionGranted" -> {
                    result.success(isOverlayPermissionGranted())
                }
                "getNativeElapsedSeconds" -> {
                    result.success(ForegroundMonitorService.elapsedSeconds)
                }
                "getNativeCameraBlockedSeconds" -> {
                    result.success(ForegroundMonitorService.cameraBlockedSeconds)
                }
                "getNativeIsCameraBlocked" -> {
                    result.success(ForegroundMonitorService.isCameraBlocked)
                }
                "resetNativeInteraction" -> {
                    ForegroundMonitorService.resetInteraction()
                    result.success(true)
                }
                "setNativeInactivityTimeout" -> {
                    val seconds = call.arguments as? Int ?: 300
                    ForegroundMonitorService.inactivityTimeoutSeconds = seconds
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
                ForegroundMonitorService.reportBrightness(brightness)
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
        ForegroundMonitorService.resetInteraction()
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
        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
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

    private fun showExitOverlay() {
        if (touchOverlayHelper == null) {
            val mc = methodChannel ?: MethodChannel(
                flutterEngine?.dartExecutor?.binaryMessenger ?: return,
                channel
            )
            touchOverlayHelper = TouchOverlayHelper(this, mc)
        }
        touchOverlayHelper?.showExitBubble()
    }

    private fun showAwakeOverlay() {
        if (touchOverlayHelper == null) {
            val mc = methodChannel ?: MethodChannel(
                flutterEngine?.dartExecutor?.binaryMessenger ?: return,
                channel
            )
            touchOverlayHelper = TouchOverlayHelper(this, mc)
        }
        touchOverlayHelper?.showAwakeOverlay()
    }

    private fun hideOverlay() {
        touchOverlayHelper?.hide()
    }

    private fun isOverlayShowing(): Boolean {
        return touchOverlayHelper?.isShowing() ?: false
    }

    private fun getLastOverlayTouchTime(): Long {
        return TouchOverlayHelper.lastTouchTimeMs
    }

    private fun isOverlayPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (!isOverlayPermissionGranted()) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            methodChannel?.invokeMethod("onOverlayPermissionResult", isOverlayPermissionGranted())
        }
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
