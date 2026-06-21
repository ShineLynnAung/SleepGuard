import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/enums/monitor_state.dart';
import '../../domain/models/detection_config.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/platform_service.dart';
import '../providers/monitor_provider.dart';
import '../providers/settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  StreamSubscription<int>? _overlaySub;
  bool _wasMinimizedWithOverlay = false;

  String _formatRemaining(int totalSeconds, int elapsedSeconds) {
    final remaining = (totalSeconds - elapsedSeconds).clamp(0, totalSeconds);
    final m = remaining ~/ 60;
    final s = remaining % 60;
    if (totalSeconds >= 3600) {
      final h = m ~/ 60;
      final mins = m % 60;
      return '${h}h ${mins.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTimeoutLabel(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    if (minutes >= 60) {
      final hrs = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) return '$hrs hr of inactivity';
      return '${hrs} hr ${mins} min of inactivity';
    }
    return '$minutes min of inactivity';
  }

  DetectionConfig? _getConfig() {
    return ref.read(settingsProvider).valueOrNull;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDeviceAdmin();
    _startMonitoringIfNeeded();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _overlaySub = PlatformService.touchController.touchStream.listen((ts) {
      if (ts == -2 && mounted) {
        ref.read(resetInteractionProvider)();
        ref.read(platformServiceProvider).hideOverlay();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlaySub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _checkOverlayExitOnResume();
    }
  }

  Future<void> _onAppBackgrounded() async {
    final isMonitoring = ref.read(monitorStateProvider).valueOrNull == MonitorState.monitoring;
    if (!isMonitoring) return;

    try {
      final platform = ref.read(platformServiceProvider);
      if (!await platform.isOverlayPermissionGranted()) {
        await platform.requestOverlayPermission();
        if (!await platform.isOverlayPermissionGranted()) return;
      }
      _wasMinimizedWithOverlay = true;
    } catch (_) {}
  }

  Future<void> _checkOverlayExitOnResume() async {
    if (!_wasMinimizedWithOverlay) return;
    _wasMinimizedWithOverlay = false;

    try {
      final showing = await ref.read(platformServiceProvider).isOverlayShowing();
      if (showing) {
        ref.read(resetInteractionProvider)();
        await ref.read(platformServiceProvider).hideOverlay();
      }
    } catch (_) {}
  }

  Future<void> _checkDeviceAdmin() async {
    final isAdmin = await ref.read(isDeviceAdminProvider.future);
    if (!isAdmin && mounted) {
      context.go('/onboarding');
    }
  }

  Future<void> _startMonitoringIfNeeded() async {
    final onboardingRepo = SettingsRepository();
    final completed = await onboardingRepo.getOnboardingComplete();
    if (completed && mounted) {
      ref.read(startMonitoringProvider)();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(monitorStateProvider);
    final state = monitorState.valueOrNull ?? MonitorState.idle;

    if (state == MonitorState.warning) {
      return _buildWarningOverlay();
    }

    return Listener(
      onPointerDown: (_) => _resetInteraction(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SleepGuard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: () => context.push('/analytics'),
              tooltip: 'Analytics',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/settings'),
              tooltip: 'Settings',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => Future.delayed(const Duration(seconds: 1)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusCard(state),
              if (state == MonitorState.monitoring) ...[
                const SizedBox(height: 16),
                _buildCountdownCards(),
              ],
              const SizedBox(height: 24),
              _buildDetectionConfig(),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _toggleMonitoring,
          icon: Icon(
            state == MonitorState.monitoring ? Icons.stop : Icons.play_arrow,
          ),
          label: Text(
            state == MonitorState.monitoring
                ? 'Stop Monitoring'
                : 'Start Monitoring',
          ),
        ),
      ),
    );
  }

  Widget _buildWarningOverlay() {
    final countdown = ref.watch(warningCountdownProvider);

    return PopScope(
      canPop: false,
      child: GestureDetector(
        onTap: () => _cancelWarning(),
        onPanDown: (_) => _cancelWarning(),
        child: Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _pulseController,
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Are you still awake?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Locking in ${countdown.valueOrNull ?? 15} seconds...',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 64,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: () => _cancelWarning(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.nightlight_round, size: 28),
                  label: const Text(
                    "I'm Awake",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tap anywhere to dismiss',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownCards() {
    final inactivityElapsed = ref.watch(inactivityElapsedProvider);
    final cameraBlocked = ref.watch(cameraBlockedSecondsProvider);
    final config = _getConfig();
    final timeoutTotal = (config?.inactivityTimeoutMinutes ?? 5) * 60;

    final inactivitySecs = inactivityElapsed.valueOrNull ?? 0;

    final camSecs = cameraBlocked.valueOrNull ?? 0;
    final camRemaining = (30 - camSecs).clamp(0, 30);

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inactivity Lock',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimeoutLabel(timeoutTotal),
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatRemaining(timeoutTotal, inactivitySecs),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.camera_alt, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Camera Block Lock',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'if camera covered for 30s',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${camRemaining}s',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(MonitorState state) {
    final (icon, color, title, subtitle) = switch (state) {
      MonitorState.idle => (
        Icons.sensors_off,
        Colors.grey,
        'Monitoring Idle',
        'Tap start to begin sleep detection'
      ),
      MonitorState.monitoring => (
        Icons.monitor_heart,
        Colors.green,
        'Monitoring Active',
        'SleepGuard is monitoring for sleep signals'
      ),
      MonitorState.warning => (
        Icons.warning_amber_rounded,
        Colors.orange,
        'Warning!',
        'Sleep detected - countdown in progress'
      ),
      MonitorState.locking => (
        Icons.lock,
        Colors.red,
        'Locking Device',
        'Device is being locked'
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionConfig() {
    final settingsAsync = ref.watch(settingsProvider);
    final config = settingsAsync.valueOrNull;
    if (config == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _configRow(
              'Inactivity Timeout',
              _formatTimeoutLabel(config.inactivityTimeoutMinutes * 60),
              Icons.timer,
            ),
            _configRow(
              'Warning Countdown',
              '${config.warningCountdownSeconds} sec',
              Icons.hourglass_bottom,
            ),
            _configRow(
              'Camera Detection',
              config.cameraDetectionEnabled ? 'Enabled' : 'Disabled',
              Icons.camera_alt,
            ),
          ],
        ),
      ),
    );
  }

  Widget _configRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _resetInteraction() {
    ref.read(resetInteractionProvider)();
  }

  void _cancelWarning() {
    ref.read(cancelWarningProvider)();
  }

  Future<void> _toggleMonitoring() async {
    final state = ref.read(monitorStateProvider).valueOrNull;
    if (state == MonitorState.monitoring) {
      ref.read(stopMonitoringProvider)();
    } else {
      final platform = ref.read(platformServiceProvider);
      if (!await platform.isOverlayPermissionGranted()) {
        await platform.requestOverlayPermission();
        if (!await platform.isOverlayPermissionGranted()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Overlay permission required for background monitoring')),
            );
          }
          return;
        }
      }
      ref.read(startMonitoringProvider)();
    }
  }
}
