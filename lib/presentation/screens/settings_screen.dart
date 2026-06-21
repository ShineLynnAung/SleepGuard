import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/detection_config.dart';
import '../providers/settings_provider.dart';

String formatTimeout(int minutes) {
  if (minutes >= 60) {
    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hrs hr';
    return '${hrs} hr ${mins} min';
  }
  return '$minutes min';
}

const int _timeoutDivisions = 179;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        data: (config) => _SettingsForm(config: config, ref: ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SettingsForm extends StatelessWidget {
  final DetectionConfig config;
  final WidgetRef ref;

  const _SettingsForm({required this.config, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          'Detection Timing',
          [
            _buildSliderTile(
              'Inactivity Timeout',
              formatTimeout(config.inactivityTimeoutMinutes),
              config.inactivityTimeoutMinutes.toDouble(),
              1,
              180,
              (val) => ref
                  .read(settingsProvider.notifier)
                  .updateInactivityTimeout(val.round()),
            ),
            _buildSliderTile(
              'Warning Countdown',
              '${config.warningCountdownSeconds} seconds',
              config.warningCountdownSeconds.toDouble(),
              5,
              60,
              (val) => ref
                  .read(settingsProvider.notifier)
                  .updateCountdownDuration(val.round()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          'Detection Methods',
          [
            SwitchListTile(
              title: const Text('Camera Visibility Detection'),
              subtitle: const Text('Use front camera to detect if view is blocked'),
              value: config.cameraDetectionEnabled,
              onChanged: (val) => ref
                  .read(settingsProvider.notifier)
                  .toggleCameraDetection(val),
              secondary: const Icon(Icons.camera_alt),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(ref.context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSliderTile(
    String label,
    String value,
    double sliderValue,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final divisions = max == 180 ? _timeoutDivisions : ((max - min) / 5).round();

    return ListTile(
      title: Text(label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: sliderValue,
            min: min,
            max: max,
            divisions: divisions,
            label: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

}
