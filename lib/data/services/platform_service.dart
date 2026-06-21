import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/constants.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel(
    AppConstants.channelSleepGuard,
  );

  static const EventChannel _monitorStateChannel = EventChannel(
    'com.sleepguard.app/monitor_state',
  );

  static final _touchController = _OverlayTouchController();
  static bool _initialized = false;

  static final StreamController<Map<String, dynamic>> _monitorStateController =
      StreamController<Map<String, dynamic>>.broadcast();

  static _OverlayTouchController get touchController => _touchController;
  static Stream<Map<String, dynamic>> get monitorStateStream =>
      _monitorStateController.stream;

  static void init() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
    _monitorStateChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        _monitorStateController.add(Map<String, dynamic>.from(event));
      }
    });
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onOverlayTouch':
        _touchController.emitTouch(
          DateTime.now().millisecondsSinceEpoch,
        );
        return null;
      case 'onOverlayExit':
        _touchController.emitTouch(-1);
        return null;
      case 'onOverlayAwake':
        _touchController.emitTouch(-2);
        return null;
      case 'onOverlayPermissionResult':
        return null;
      case 'onInactivityTimeoutReached':
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

  Future<void> lockFromTimeout() async {
    try {
      await _channel.invokeMethod('lockFromTimeout');
    } on PlatformException catch (e) {
      throw Exception('Failed to lock from timeout: ${e.message}');
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
      final result = await _channel.invokeMethod<bool>(
        'isCameraPermissionGranted',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestCameraPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestCameraPermission',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> showExitOverlay() async {
    try {
      await _channel.invokeMethod('showExitOverlay');
    } on PlatformException catch (e) {
      throw Exception('Failed to show exit overlay: ${e.message}');
    }
  }

  Future<void> showAwakeOverlay() async {
    try {
      await _channel.invokeMethod('showAwakeOverlay');
    } on PlatformException catch (e) {
      throw Exception('Failed to show awake overlay: ${e.message}');
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
      final result = await _channel.invokeMethod<int>(
        'getLastOverlayTouchTime',
      );
      return result ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  Future<bool> isOverlayPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isOverlayPermissionGranted',
      );
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

  Future<void> startCameraMonitor() async {
    try {
      await _channel.invokeMethod('startCameraMonitor');
    } on PlatformException {
      // ignore
    }
  }

  Future<void> stopCameraMonitor() async {
    try {
      await _channel.invokeMethod('stopCameraMonitor');
    } on PlatformException {
      // ignore
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
      await _channel.invokeMethod(
        'setNativeInactivityTimeout',
        seconds,
      );
    } on PlatformException {
      // ignore
    }
  }

  Future<void> setNativeAwakeCountdown(int seconds) async {
    try {
      await _channel.invokeMethod('setNativeAwakeCountdown', seconds);
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
