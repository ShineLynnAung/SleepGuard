class AppConstants {
  AppConstants._();

  static const String appName = 'SleepGuard';
  static const String packageName = 'com.sleepguard.app';

  static const int defaultInactivityTimeoutMinutes = 5;
  static const int defaultWarningCountdownSeconds = 15;
  static const String prefInactivityTimeout = 'inactivity_timeout_minutes';
  static const String prefCountdownDuration = 'countdown_duration_seconds';
  static const String prefCameraDetectionEnabled = 'camera_detection_enabled';

  static const String prefTotalDetections = 'total_detections';
  static const String prefTotalLocks = 'total_locks';
  static const String prefLastDetectionTimestamp = 'last_detection_timestamp';

  static const String channelSleepGuard = 'com.sleepguard.app/channel';
  static const String methodLockScreen = 'lockScreen';
  static const String methodStartService = 'startForegroundService';
  static const String methodStopService = 'stopForegroundService';
  static const String methodIsDeviceAdmin = 'isDeviceAdmin';
  static const String methodRequestDeviceAdmin = 'requestDeviceAdmin';
  static const String methodRemoveDeviceAdmin = 'removeDeviceAdmin';

  static const String notificationChannelId = 'sleep_guard_monitor';
  static const int notificationId = 1001;
}
