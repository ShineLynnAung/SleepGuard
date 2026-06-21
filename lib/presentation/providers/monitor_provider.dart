import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/enums/monitor_state.dart';
import '../../domain/models/detection_config.dart';
import '../../data/services/monitor_service.dart';
import '../../data/services/platform_service.dart';
import '../providers/settings_provider.dart';

final platformServiceProvider = Provider<PlatformService>((ref) {
  return PlatformService();
});

final monitorServiceProvider = Provider<MonitorService>((ref) {
  final service = MonitorService();
  ref.onDispose(() => service.dispose());
  return service;
});

final monitorStateProvider = StreamProvider<MonitorState>((ref) {
  final service = ref.watch(monitorServiceProvider);
  return service.stateStream;
});

final warningCountdownProvider = StreamProvider<int>((ref) {
  final service = ref.watch(monitorServiceProvider);
  return service.warningCountdownStream;
});

final inactivityElapsedProvider = StreamProvider<int>((ref) {
  final service = ref.watch(monitorServiceProvider);
  return service.inactivityElapsedStream;
});

final cameraBlockedSecondsProvider = StreamProvider<int>((ref) {
  final service = ref.watch(monitorServiceProvider);
  return service.cameraBlockedSecondsStream;
});

final isMonitoringProvider = Provider<bool>((ref) {
  final state = ref.watch(monitorStateProvider);
  return state.valueOrNull == MonitorState.monitoring;
});

final isDeviceAdminProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(platformServiceProvider);
  return service.isDeviceAdmin();
});

final startMonitoringProvider = Provider<void Function()>((ref) {
  final service = ref.watch(monitorServiceProvider);
  return () {
    final config = ref.read(settingsProvider).valueOrNull ??
        const DetectionConfig();
    service.updateConfig(config);
    service.startMonitoring();
  };
});

final stopMonitoringProvider = Provider<void Function()>((ref) {
  final service = ref.watch(monitorServiceProvider);
  return () => service.stopMonitoring();
});

final resetInteractionProvider = Provider<void Function()>((ref) {
  final service = ref.watch(monitorServiceProvider);
  return () => service.resetInteraction();
});

final cancelWarningProvider = Provider<void Function()>((ref) {
  final service = ref.watch(monitorServiceProvider);
  return () => service.resetInteraction();
});
