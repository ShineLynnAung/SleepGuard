import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/platform_service.dart';
import '../providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  bool _isDeviceAdmin = false;
  bool _isCameraPermissionGranted = false;
  bool _isLoading = true;

  final _pages = <Widget>[];

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final platformService = PlatformService();
    final isAdmin = await platformService.isDeviceAdmin();
    final isCameraGranted = await platformService.isCameraPermissionGranted();
    final repo = SettingsRepository();
    final completed = await repo.getOnboardingComplete();

    if (completed && isAdmin && isCameraGranted && mounted) {
      context.go('/home');
      return;
    }

    if (mounted) {
      setState(() {
        _isDeviceAdmin = isAdmin;
        _isCameraPermissionGranted = isCameraGranted;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: _buildStepContent(),
              ),
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildDeviceAdminStep();
      case 2:
        return _buildPermissionsStep();
      case 3:
        return _buildCompleteStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.nightlight_round,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Automatically detect when you fall asleep\n'
            'and lock your device to save battery.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),
          _buildFeatureRow(Icons.timer, 'Inactivity detection'),

          _buildFeatureRow(Icons.camera_alt, 'Camera visibility check'),
          const SizedBox(height: 8),
          _buildFeatureRow(Icons.lock, 'Automatic device lock'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  Widget _buildDeviceAdminStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: 80,
            color: _isDeviceAdmin ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 24),
          Text(
            'Device Admin Permission',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'SleepGuard needs Device Admin permission to\n'
            'lock your screen when sleep is detected.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),
          if (_isDeviceAdmin)
            const Chip(
              avatar: Icon(Icons.check_circle, color: Colors.green),
              label: Text('Permission Granted'),
            )
          else
            ElevatedButton.icon(
              onPressed: _requestDeviceAdmin,
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Grant Device Admin'),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionsStep() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Required Permissions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _permissionTile(
              Icons.camera_alt,
              'Camera',
              'Detect if camera view is blocked or dark',
            ),
            if (_isCameraPermissionGranted)
              const Chip(
                avatar: Icon(Icons.check_circle, color: Colors.green),
                label: Text('Camera Permission Granted'),
              )
            else
              ElevatedButton.icon(
                onPressed: _requestCameraPermission,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Grant Camera Permission'),
              ),
            const SizedBox(height: 16),
            _permissionTile(
              Icons.notifications_active,
              'Foreground Service',
              'Run monitoring in the background',
            ),
            _permissionTile(
              Icons.power_settings_new,
              'Wake Lock',
              'Prevent device from sleeping during monitoring',
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 100,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to Go!',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'SleepGuard is fully set up and ready to\n'
            'protect your device while you sleep.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Row(
      children: [
        if (_currentStep > 0)
          TextButton(
            onPressed: () => setState(() => _currentStep--),
            child: const Text('Back'),
          )
        else
          const SizedBox.shrink(),
        const Spacer(),
        if (_currentStep < 3)
          ElevatedButton(
            onPressed: _currentStep == 0
                ? () => setState(() => _currentStep++)
                : _canProceed() ? () => setState(() => _currentStep++) : null,
            child: Text(
              _currentStep == 0 ? 'Get Started' : 'Next',
            ),
          )
        else
          ElevatedButton(
            onPressed: _completeOnboarding,
            child: const Text('Start Monitoring'),
          ),
      ],
    );
  }

  bool _canProceed() {
    if (_currentStep == 1 && !_isDeviceAdmin) return false;
    if (_currentStep == 2 && !_isCameraPermissionGranted) return false;
    return true;
  }

  Future<void> _requestDeviceAdmin() async {
    try {
      final platformService = PlatformService();
      await platformService.requestDeviceAdmin();
      final isAdmin = await platformService.isDeviceAdmin();
      setState(() => _isDeviceAdmin = isAdmin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request device admin: $e')),
        );
      }
    }
  }

  Future<void> _requestCameraPermission() async {
    try {
      final platformService = PlatformService();
      final granted = await platformService.requestCameraPermission();
      setState(() => _isCameraPermissionGranted = granted);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request camera permission: $e')),
        );
      }
    }
  }

  Future<void> _completeOnboarding() async {
    final repo = SettingsRepository();
    await repo.setOnboardingComplete();
    if (mounted) context.go('/home');
  }
}
