import 'dart:async';
import 'package:flutter/services.dart';
import 'platform_service.dart';

class CameraService {
  static const MethodChannel _channel = MethodChannel('com.sleepguard.app/channel');
  static const EventChannel _brightnessChannel =
      EventChannel('com.sleepguard.app/camera_brightness');

  bool _isRunning = false;
  bool _isBlocked = false;
  int _blockedSeconds = 0;
  StreamSubscription<dynamic>? _brightnessSub;
  Timer? _checkTimer;

  static const int _blockedTimeoutSeconds = 30;
  static const double _brightnessThreshold = 30.0;

  bool get isBlocked => _isBlocked;
  int get blockedSeconds => _blockedSeconds;

  final StreamController<bool> _blockedStateController =
      StreamController<bool>.broadcast();
  final StreamController<int> _blockedSecondsController =
      StreamController<int>.broadcast();

  Stream<bool> get blockedStateStream => _blockedStateController.stream;
  Stream<int> get blockedSecondsStream => _blockedSecondsController.stream;

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _blockedSeconds = 0;
    _isBlocked = false;

    try {
      final platformService = PlatformService();
      final granted = await platformService.isCameraPermissionGranted();
      if (!granted) {
        _isRunning = false;
        return;
      }
      await _channel.invokeMethod('startCameraMonitor');
    } catch (_) {}

    _brightnessSub = _brightnessChannel
        .receiveBroadcastStream()
        .listen(_onBrightness);

    _checkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _blockedSecondsController.add(_blockedSeconds);

      final wasBlocked = _isBlocked;
      _isBlocked = _blockedSeconds >= _blockedTimeoutSeconds;

      if (wasBlocked != _isBlocked) {
        _blockedStateController.add(_isBlocked);
      }
    });
  }

  void _onBrightness(dynamic brightnessValue) {
    final brightness = (brightnessValue as num).toDouble();
    final isDark = brightness < _brightnessThreshold;

    if (isDark) {
      _blockedSeconds++;
    } else {
      _blockedSeconds = 0;
    }
  }

  void resetBlocked() {
    _blockedSeconds = 0;
    _isBlocked = false;
    _blockedSecondsController.add(_blockedSeconds);
  }

  Future<void> stop() async {
    _isRunning = false;
    _isBlocked = false;
    _blockedSeconds = 0;

    _checkTimer?.cancel();
    _checkTimer = null;
    await _brightnessSub?.cancel();
    _brightnessSub = null;

    try {
      await _channel.invokeMethod('stopCameraMonitor');
    } catch (_) {}
  }

  void dispose() {
    stop();
    _blockedStateController.close();
    _blockedSecondsController.close();
  }
}
