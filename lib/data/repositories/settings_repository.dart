import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../domain/models/detection_config.dart';

class SettingsRepository {
  SharedPreferences? _prefs;

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<DetectionConfig> loadConfig() async {
    await _ensureInitialized();
    return DetectionConfig(
      inactivityTimeoutMinutes: _prefs!.getInt(
            AppConstants.prefInactivityTimeout,
          ) ??
          AppConstants.defaultInactivityTimeoutMinutes,
      warningCountdownSeconds: _prefs!.getInt(
            AppConstants.prefCountdownDuration,
          ) ??
          AppConstants.defaultWarningCountdownSeconds,
      cameraDetectionEnabled: _prefs!.getBool(
            AppConstants.prefCameraDetectionEnabled,
          ) ??
          true,
    );
  }

  Future<void> saveConfig(DetectionConfig config) async {
    await _ensureInitialized();
    await _prefs!.setInt(
      AppConstants.prefInactivityTimeout,
      config.inactivityTimeoutMinutes,
    );
    await _prefs!.setInt(
      AppConstants.prefCountdownDuration,
      config.warningCountdownSeconds,
    );
    await _prefs!.setBool(
      AppConstants.prefCameraDetectionEnabled,
      config.cameraDetectionEnabled,
    );
  }

  Future<bool> getOnboardingComplete() async {
    await _ensureInitialized();
    return _prefs!.getBool('onboarding_complete') ?? false;
  }

  Future<void> setOnboardingComplete() async {
    await _ensureInitialized();
    await _prefs!.setBool('onboarding_complete', true);
  }
}
