import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/detection_config.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, DetectionConfig>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<DetectionConfig> {
  @override
  Future<DetectionConfig> build() async {
    final repo = ref.read(settingsRepositoryProvider);
    return repo.loadConfig();
  }

  Future<void> updateConfig(DetectionConfig config) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveConfig(config);
    state = AsyncData(config);
  }

  Future<void> updateInactivityTimeout(int minutes) async {
    final current = state.valueOrNull ?? const DetectionConfig();
    await updateConfig(current.copyWith(inactivityTimeoutMinutes: minutes));
  }

  Future<void> updateCountdownDuration(int seconds) async {
    final current = state.valueOrNull ?? const DetectionConfig();
    await updateConfig(current.copyWith(warningCountdownSeconds: seconds));
  }

  Future<void> toggleCameraDetection(bool enabled) async {
    final current = state.valueOrNull ?? const DetectionConfig();
    await updateConfig(current.copyWith(cameraDetectionEnabled: enabled));
  }


}

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final repo = ref.read(settingsRepositoryProvider);
  return repo.getOnboardingComplete();
});
