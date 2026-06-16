class DetectionConfig {
  final int inactivityTimeoutMinutes;
  final int warningCountdownSeconds;
  final bool cameraDetectionEnabled;

  const DetectionConfig({
    this.inactivityTimeoutMinutes = 5,
    this.warningCountdownSeconds = 15,
    this.cameraDetectionEnabled = true,
  });

  DetectionConfig copyWith({
    int? inactivityTimeoutMinutes,
    int? warningCountdownSeconds,
    bool? cameraDetectionEnabled,
  }) {
    return DetectionConfig(
      inactivityTimeoutMinutes:
          inactivityTimeoutMinutes ?? this.inactivityTimeoutMinutes,
      warningCountdownSeconds:
          warningCountdownSeconds ?? this.warningCountdownSeconds,
      cameraDetectionEnabled:
          cameraDetectionEnabled ?? this.cameraDetectionEnabled,
    );
  }
}
