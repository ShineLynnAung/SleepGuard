package com.sleepguard.app

import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.Image
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.util.Size

class CameraBrightnessAnalyzer(
    private val context: Context,
    private val onBrightnessResult: (Double) -> Unit
) {
    private var cameraDevice: CameraDevice? = null
    private var cameraSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private var isRunning = false

    fun start() {
        if (isRunning) return
        isRunning = true

        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)

        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        try {
            val cameraId = getFrontCameraId(cameraManager) ?: return
            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    createCaptureSession(camera)
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    cameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    cameraDevice = null
                }
            }, backgroundHandler)
        } catch (e: Exception) {
            isRunning = false
        }
    }

    private fun getFrontCameraId(cameraManager: CameraManager): String? {
        for (id in cameraManager.cameraIdList) {
            val characteristics = cameraManager.getCameraCharacteristics(id)
            val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
            if (facing == CameraCharacteristics.LENS_FACING_FRONT) return id
        }
        return null
    }

    private fun createCaptureSession(camera: CameraDevice) {
        val reader = ImageReader.newInstance(320, 240, ImageFormat.YUV_420_888, 2)
        imageReader = reader

        reader.setOnImageAvailableListener({ reader ->
            val image = reader.acquireLatestImage()
            if (image != null) {
                val brightness = analyzeBrightness(image)
                onBrightnessResult(brightness)
                image.close()
            }
        }, backgroundHandler)

        try {
            val surface = reader.surface
            camera.createCaptureSession(
                listOf(surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        cameraSession = session
                        startRepeatingCapture(session, surface)
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {}
                },
                backgroundHandler
            )
        } catch (e: Exception) {
            isRunning = false
        }
    }

    private fun startRepeatingCapture(session: CameraCaptureSession, surface: android.view.Surface) {
        try {
            val request = session.device.createCaptureRequest(
                CameraDevice.TEMPLATE_PREVIEW
            ).apply {
                addTarget(surface)
                set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
                set(CaptureRequest.SENSOR_EXPOSURE_TIME, 10000000L)
                set(CaptureRequest.SENSOR_SENSITIVITY, 800)
            }
            session.setRepeatingRequest(request.build(), null, backgroundHandler)
        } catch (e: Exception) {
            isRunning = false
        }
    }

    private fun analyzeBrightness(image: Image): Double {
        val planes = image.planes
        if (planes.isEmpty()) return 255.0

        val yPlane = planes[0]
        val buffer = yPlane.buffer
        val stride = yPlane.rowStride

        var sum = 0L
        var count = 0

        for (y in 0 until image.height step 4) {
            for (x in 0 until image.width step 4) {
                val index = y * stride + x
                if (index < buffer.capacity()) {
                    sum += buffer.get(index).toInt() and 0xFF
                    count++
                }
            }
        }

        return if (count > 0) sum.toDouble() / count else 255.0
    }

    fun stop() {
        isRunning = false
        try {
            cameraSession?.abortCaptures()
            cameraSession?.close()
        } catch (_: Exception) {}
        cameraSession = null
        cameraDevice?.close()
        cameraDevice = null
        imageReader?.close()
        imageReader = null
        backgroundThread?.quitSafely()
        backgroundThread = null
        backgroundHandler = null
    }
}
