import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/analytics_provider.dart';
import '../widgets/stat_card.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalDetections = ref.watch(totalDetectionsProvider);
    final totalLocks = ref.watch(totalLocksProvider);
    final lastTimestamp = ref.watch(lastDetectionTimestampProvider);
    final avgDaily = ref.watch(averageDailyDetectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(invalidateAnalyticsProvider)(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total Detections',
                  value: totalDetections.valueOrNull?.toString() ?? '--',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Total Locks',
                  value: totalLocks.valueOrNull?.toString() ?? '--',
                  icon: Icons.lock,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Avg Daily Detections',
                  value: avgDaily.valueOrNull != null
                      ? avgDaily.value!.toStringAsFixed(1)
                      : '--',
                  icon: Icons.trending_up,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Last Detection',
                  value: _formatTimestamp(lastTimestamp.valueOrNull),
                  icon: Icons.schedule,
                  color: Colors.purple,
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '--';
    return DateFormat('MMM d, HH:mm').format(timestamp);
  }
}
