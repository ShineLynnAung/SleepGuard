import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/enums/monitor_state.dart';
import '../../domain/models/detection_config.dart';
import '../../domain/models/detection_event.dart';
import '../repositories/analytics_repository.dart';
import '../services/inactivity_service.dart';
import '../services/camera_service.dart';
import '../services/platform_service.dart';

class MonitorService {
  final InactivityService _inactivityService;
  final CameraService _cameraService;
  final PlatformService _platformService;
  final AnalyticsRepository _analyticsRepository;

  DetectionConfig _config = const DetectionConfig();
  MonitorState _state = MonitorState.idle;
  int _warningCountdown = 0;
  Timer? _warningTimer;

  final StreamController<MonitorState> _stateController =
      StreamController<MonitorState>.broadcast();
  final StreamController<int> _warningCountdownController =
      StreamController<int>.broadcast();

  StreamSubscription<bool>? _inactivitySub;
  StreamSubscription<bool>? _cameraSub;

  MonitorService({
    required AnalyticsRepository analyticsRepository,
    InactivityService? inactivityService,
    CameraService? cameraService,
    PlatformService? platformService,
  })  : _analyticsRepository = analyticsRepository,
        _inactivityService =
            inactivityService ?? InactivityService(),
        _cameraService = cameraService ?? CameraService(),
        _platformService = platformService ?? PlatformService();

  MonitorState get state => _state;
  int get warningCountdown => _warningCountdown;
  int get inactivityElapsed => _inactivityService.elapsedSeconds;

  Stream<MonitorState> get stateStream => _stateController.stream;
  Stream<int> get warningCountdownStream =>
      _warningCountdownController.stream;
  Stream<int> get inactivityElapsedStream => _inactivityService.elapsedStream;
  Stream<int> get cameraBlockedSecondsStream =>
      _cameraService.blockedSecondsStream;

  void updateConfig(DetectionConfig config) {
    _config = config;
    _inactivityService.updateTimeout(config.inactivityTimeoutMinutes);
    _platformService.setNativeInactivityTimeout(config.inactivityTimeoutMinutes * 60);
  }

  Future<void> startMonitoring() async {
    if (_state == MonitorState.monitoring) return;

    _state = MonitorState.monitoring;
    _stateController.add(_state);

    _inactivityService.start(timeoutMinutes: _config.inactivityTimeoutMinutes);

    if (_config.cameraDetectionEnabled) {
      await _cameraService.start();
    }

    await _platformService.startForegroundService();
    await _platformService.setNativeInactivityTimeout(
      _config.inactivityTimeoutMinutes * 60,
    );

    _inactivitySub = _inactivityService.inactivityStateStream.listen(
      _onInactivityChanged,
    );
    _cameraSub = _cameraService.blockedStateStream.listen(
      _onCameraBlockedChanged,
    );
  }

  void resetInteraction() {
    if (_state == MonitorState.warning) {
      _cancelWarning();
    }
    _inactivityService.resetInteraction();
    _cameraService.resetBlocked();
    _platformService.resetNativeInteraction();
  }

  void _onInactivityChanged(bool isInactive) {
    if (isInactive && _state == MonitorState.monitoring) {
      _triggerWarning();
    }
  }

  void _onCameraBlockedChanged(bool isBlocked) {
    if (isBlocked && _state == MonitorState.monitoring) {
      _triggerWarning();
    }
  }

  void _triggerWarning() {
    _state = MonitorState.warning;
    _warningCountdown = _config.warningCountdownSeconds;
    _stateController.add(_state);
    _warningCountdownController.add(_warningCountdown);

    _warningTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _warningCountdown--;
      _warningCountdownController.add(_warningCountdown);

      if (_warningCountdown <= 0) {
        _executeLock();
      }
    });

    _analyticsRepository.recordDetection(
      DetectionEvent(
        timestamp: DateTime.now(),
        totalScore: 0,
        triggeredLock: false,
      ),
    );
  }

  void _cancelWarning() {
    _warningTimer?.cancel();
    _warningTimer = null;
    _warningCountdown = _config.warningCountdownSeconds;
    _warningCountdownController.add(_warningCountdown);

    _state = MonitorState.monitoring;
    _stateController.add(_state);
    _inactivityService.resetInteraction();
    _cameraService.resetBlocked();
  }

  Future<void> _executeLock() async {
    _warningTimer?.cancel();
    _warningTimer = null;

    _state = MonitorState.locking;
    _stateController.add(_state);

    try {
      await _platformService.lockScreen();
    } catch (e) {
      debugPrint('Lock screen failed: $e');
    }

    _analyticsRepository.recordDetection(
      DetectionEvent(
        timestamp: DateTime.now(),
        totalScore: 0,
        triggeredLock: true,
      ),
    );

    _state = MonitorState.monitoring;
    _stateController.add(_state);
    _inactivityService.resetInteraction();
    _cameraService.resetBlocked();
  }

  Future<void> stopMonitoring() async {
    _warningTimer?.cancel();
    _warningTimer = null;

    _inactivitySub?.cancel();
    _cameraSub?.cancel();

    _inactivityService.stop();
    await _cameraService.stop();
    await _platformService.hideOverlay();
    await _platformService.stopForegroundService();

    _state = MonitorState.idle;
    _stateController.add(_state);
  }

  void dispose() {
    stopMonitoring();
    _stateController.close();
    _warningCountdownController.close();
  }
}
