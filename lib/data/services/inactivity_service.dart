import 'dart:async';
import 'package:flutter/material.dart';

class InactivityService {
  Timer? _inactivityTimer;
  bool _isRunning = false;
  bool _isInactive = false;

  bool get isInactive => _isInactive;
  int get elapsedSeconds => _elapsedSeconds;

  int _timeoutSeconds = 300;
  int _elapsedSeconds = 0;

  final StreamController<bool> _inactivityStateController =
      StreamController<bool>.broadcast();
  final StreamController<int> _elapsedController =
      StreamController<int>.broadcast();

  Stream<bool> get inactivityStateStream => _inactivityStateController.stream;
  Stream<int> get elapsedStream => _elapsedController.stream;

  void start({int timeoutMinutes = 5}) {
    if (_isRunning) return;
    _isRunning = true;
    _timeoutSeconds = timeoutMinutes * 60;
    _elapsedSeconds = 0;
    _isInactive = false;

    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      _elapsedController.add(_elapsedSeconds);

      final wasInactive = _isInactive;
      _isInactive = _elapsedSeconds >= _timeoutSeconds;

      if (wasInactive != _isInactive) {
        _inactivityStateController.add(_isInactive);
      }
    });
  }

  void resetInteraction() {
    _elapsedSeconds = 0;
    if (_isInactive) {
      _isInactive = false;
      _inactivityStateController.add(false);
    }
  }

  void updateTimeout(int timeoutMinutes) {
    _timeoutSeconds = timeoutMinutes * 60;
  }

  void stop() {
    _isRunning = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _elapsedSeconds = 0;
    _isInactive = false;
  }

  void dispose() {
    stop();
    _inactivityStateController.close();
    _elapsedController.close();
  }
}
