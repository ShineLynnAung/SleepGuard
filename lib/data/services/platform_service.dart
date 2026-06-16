import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/constants.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel(
    AppConstants.channelSleepGuard,
  );

  static final _touchController = _OverlayTouchController();
  static bool _initialized = false;

  static _OverlayTouchController get touchController => _touchController;

  static void init() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onOverlayTouch':
        _touchController.emitTouch(DateTime.now().millisecondsSinceEpoch);
        return null;
      case 'onOverlayExit':
        _touchController.emitTouch(-1);
        return null;
      case 'onOverlayPermissionResult':
        return null;
      default:
        throw MissingPluginException();
    }
  }

  Future<void> lockScreen() async {
    try {
      await _channel.invokeMethod(AppConstants.methodLockScreen);
    } on PlatformException catch (e) {
      throw Exception('Failed to lock screen: ${e.message}');
    }
  }

  Future<void> startForegroundService() async {
    try {
      await _channel.invokeMethod(AppConstants.methodStartService);
    } on PlatformException catch (e) {
      throw Exception('Failed to start service: ${e.message}');
    }
  }

  Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod(AppConstants.methodStopService);
    } on PlatformException catch (e) {
      throw Exception('Failed to stop service: ${e.message}');
    }
  }

  Future<bool> isDeviceAdmin() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        AppConstants.methodIsDeviceAdmin,
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestDeviceAdmin() async {
    try {
      await _channel.invokeMethod(AppConstants.methodRequestDeviceAdmin);
    } on PlatformException catch (e) {
      throw Exception('Failed to request device admin: ${e.message}');
    }
  }

  Future<void> removeDeviceAdmin() async {
    try {
      await _channel.invokeMethod(AppConstants.methodRemoveDeviceAdmin);
    } on PlatformException catch (e) {
      throw Exception('Failed to request device admin: ${e.message}');
    }
  }

  Future<bool> isCameraPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isCameraPermissionGranted');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestCameraPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestCameraPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> showOverlay() async {
    try {
      await _channel.invokeMethod('showOverlay');
    } on PlatformException catch (e) {
      throw Exception('Failed to show overlay: ${e.message}');
    }
  }

  Future<void> hideOverlay() async {
    try {
      await _channel.invokeMethod('hideOverlay');
    } on PlatformException catch (e) {
      throw Exception('Failed to hide overlay: ${e.message}');
    }
  }

  Future<bool> isOverlayShowing() async {
    try {
      final result = await _channel.invokeMethod<bool>('isOverlayShowing');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<int> getLastOverlayTouchTime() async {
    try {
      final result = await _channel.invokeMethod<int>('getLastOverlayTouchTime');
      return result ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  Future<bool> isOverlayPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isOverlayPermissionGranted');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      throw Exception('Failed to request overlay permission: ${e.message}');
    }
  }

  Future<int> getNativeElapsedSeconds() async {
    try {
      final result = await _channel.invokeMethod<int>('getNativeElapsedSeconds');
      return result ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  Future<int> getNativeCameraBlockedSeconds() async {
    try {
      final result = await _channel.invokeMethod<int>('getNativeCameraBlockedSeconds');
      return result ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  Future<bool> getNativeIsCameraBlocked() async {
    try {
      final result = await _channel.invokeMethod<bool>('getNativeIsCameraBlocked');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> resetNativeInteraction() async {
    try {
      await _channel.invokeMethod('resetNativeInteraction');
    } on PlatformException {
      // ignore
    }
  }

  Future<void> setNativeInactivityTimeout(int seconds) async {
    try {
      await _channel.invokeMethod('setNativeInactivityTimeout', seconds);
    } on PlatformException {
      // ignore
    }
  }
}

class _OverlayTouchController {
  final _touchStreamController = StreamController<int>.broadcast();
  Stream<int> get touchStream => _touchStreamController.stream;

  void emitTouch(int timestamp) {
    _touchStreamController.add(timestamp);
  }

  void dispose() {
    _touchStreamController.close();
  }
}
