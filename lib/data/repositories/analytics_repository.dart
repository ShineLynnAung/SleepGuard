import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../domain/models/detection_event.dart';

class AnalyticsRepository {
  SharedPreferences? _prefs;

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<int> getTotalDetections() async {
    await _ensureInitialized();
    return _prefs!.getInt(AppConstants.prefTotalDetections) ?? 0;
  }

  Future<int> getTotalLocks() async {
    await _ensureInitialized();
    return _prefs!.getInt(AppConstants.prefTotalLocks) ?? 0;
  }

  Future<DateTime?> getLastDetectionTimestamp() async {
    await _ensureInitialized();
    final millis = _prefs!.getInt(AppConstants.prefLastDetectionTimestamp);
    return millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
  }

  Future<double> getAverageDailyDetections() async {
    await _ensureInitialized();
    final total = await getTotalDetections();
    final firstTimestamp = _prefs!.getInt('first_detection_timestamp');
    if (firstTimestamp == null || total == 0) return 0;
    final firstDate = DateTime.fromMillisecondsSinceEpoch(firstTimestamp);
    final days = DateTime.now().difference(firstDate).inDays;
    if (days < 1) return total.toDouble();
    return total / days;
  }

  Future<void> recordDetection(DetectionEvent event) async {
    await _ensureInitialized();
    final total = (await getTotalDetections()) + 1;
    await _prefs!.setInt(AppConstants.prefTotalDetections, total);
    await _prefs!.setInt(
      AppConstants.prefLastDetectionTimestamp,
      event.timestamp.millisecondsSinceEpoch,
    );
    if (event.triggeredLock) {
      final locks = (await getTotalLocks()) + 1;
      await _prefs!.setInt(AppConstants.prefTotalLocks, locks);
    }
    final firstTs = _prefs!.getInt('first_detection_timestamp');
    if (firstTs == null) {
      await _prefs!.setInt(
        'first_detection_timestamp',
        event.timestamp.millisecondsSinceEpoch,
      );
    }
  }
}
