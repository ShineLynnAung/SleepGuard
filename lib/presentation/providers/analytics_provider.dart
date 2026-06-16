import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/services/platform_service.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository();
});

final totalDetectionsProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(analyticsRepositoryProvider);
  return repo.getTotalDetections();
});

final totalLocksProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(analyticsRepositoryProvider);
  return repo.getTotalLocks();
});

final lastDetectionTimestampProvider = FutureProvider<DateTime?>((ref) async {
  final repo = ref.read(analyticsRepositoryProvider);
  return repo.getLastDetectionTimestamp();
});

final averageDailyDetectionsProvider = FutureProvider<double>((ref) async {
  final repo = ref.read(analyticsRepositoryProvider);
  return repo.getAverageDailyDetections();
});

final invalidateAnalyticsProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(totalDetectionsProvider);
    ref.invalidate(totalLocksProvider);
    ref.invalidate(lastDetectionTimestampProvider);
    ref.invalidate(averageDailyDetectionsProvider);
  };
});
