import 'dart:async';
import '../../domain/enums/monitor_state.dart';
import '../../domain/models/detection_config.dart';
import '../services/platform_service.dart';

class MonitorService {
  final PlatformService _platformService;

  DetectionConfig _config = const DetectionConfig();
  MonitorState _state = MonitorState.idle;
  int _warningCountdown = 0;
  StreamSubscription<Map<String, dynamic>>? _stateSub;

  final StreamController<MonitorState> _stateController =
      StreamController<MonitorState>.broadcast();
  final StreamController<int> _warningCountdownController =
      StreamController<int>.broadcast();
  final StreamController<int> _inactivityElapsedController =
      StreamController<int>.broadcast();
  final StreamController<int> _cameraBlockedController =
      StreamController<int>.broadcast();

  MonitorService({
    PlatformService? platformService,
  })  : _platformService = platformService ?? PlatformService();

  MonitorState get state => _state;
  int get warningCountdown => _warningCountdown;

  Stream<MonitorState> get stateStream => _stateController.stream;
  Stream<int> get warningCountdownStream =>
      _warningCountdownController.stream;
  Stream<int> get inactivityElapsedStream =>
      _inactivityElapsedController.stream;
  Stream<int> get cameraBlockedSecondsStream =>
      _cameraBlockedController.stream;

  void updateConfig(DetectionConfig config) {
    _config = config;
    _platformService.setNativeInactivityTimeout(config.inactivityTimeoutMinutes * 60);
    _platformService.setNativeAwakeCountdown(config.warningCountdownSeconds);
  }

  Future<void> startMonitoring() async {
    if (_state == MonitorState.monitoring) return;

    _state = MonitorState.monitoring;
    _stateController.add(_state);

    if (_config.cameraDetectionEnabled) {
      await _platformService.startCameraMonitor();
    }

    await _platformService.setNativeInactivityTimeout(
      _config.inactivityTimeoutMinutes * 60,
    );
    await _platformService.setNativeAwakeCountdown(
      _config.warningCountdownSeconds,
    );
    await _platformService.startForegroundService();

    _stateSub = PlatformService.monitorStateStream.listen(_onNativeState);
  }

  void _onNativeState(Map<String, dynamic> state) {
    final elapsed = state['elapsedSeconds'] as int? ?? 0;
    _inactivityElapsedController.add(elapsed);

    final camSecs = state['cameraBlockedSeconds'] as int? ?? 0;
    _cameraBlockedController.add(camSecs);

    final isWaiting = state['isWaitingForAwake'] as bool? ?? false;

    if (isWaiting) {
      if (_state != MonitorState.warning) {
        _state = MonitorState.warning;
        _stateController.add(_state);
      }
      _warningCountdown = state['awakeCountdown'] as int? ?? 0;
      _warningCountdownController.add(_warningCountdown);
    } else if (_state == MonitorState.warning) {
      _cancelWarning();
    }
  }

  void resetInteraction() {
    if (_state == MonitorState.warning) {
      _cancelWarning();
    }
    _platformService.resetNativeInteraction();
    _platformService.hideOverlay();
  }

  void _cancelWarning() {
    _state = MonitorState.monitoring;
    _stateController.add(_state);
    _warningCountdown = _config.warningCountdownSeconds;
    _warningCountdownController.add(_warningCountdown);
    _platformService.resetNativeInteraction();
    _platformService.hideOverlay();
  }

  Future<void> stopMonitoring() async {
    _stateSub?.cancel();
    _stateSub = null;

    await _platformService.hideOverlay();
    await _platformService.stopForegroundService();
    if (_config.cameraDetectionEnabled) {
      await _platformService.stopCameraMonitor();
    }

    _state = MonitorState.idle;
    _stateController.add(_state);
  }

  void dispose() {
    stopMonitoring();
    _stateController.close();
    _warningCountdownController.close();
    _inactivityElapsedController.close();
    _cameraBlockedController.close();
  }
}
