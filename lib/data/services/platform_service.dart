import 'package:flutter/services.dart';
import '../../core/constants.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel(
    AppConstants.channelSleepGuard,
  );

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
}
