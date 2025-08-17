import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/statistics.dart';

/// Global manager for tracking active practice sessions across the app
class PracticeSessionManager extends ChangeNotifier {
  static final PracticeSessionManager _instance = PracticeSessionManager._internal();
  factory PracticeSessionManager() => _instance;
  PracticeSessionManager._internal();

  PracticeItem? _activePracticeItem;
  int _targetSeconds = 60;
  int _elapsedSeconds = 0;
  bool _isTimerRunning = false;
  DateTime? _timerStartTime;
  Timer? _timer;

  // Getters
  PracticeItem? get activePracticeItem => _activePracticeItem;
  bool get hasActiveSession => _activePracticeItem != null;
  int get targetSeconds => _targetSeconds;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isTimerRunning => _isTimerRunning;
  double? get timerStartTime => _timerStartTime?.millisecondsSinceEpoch.toDouble() != null ? _timerStartTime!.millisecondsSinceEpoch.toDouble() / 1000.0 : null;
  
  int get remainingSeconds => _targetSeconds - _elapsedSeconds;
  double get progressPercentage {
    return _targetSeconds > 0 ? _elapsedSeconds / _targetSeconds : 0;
  }

  /// Start a new practice session
  void startSession({
    required PracticeItem item,
    int targetSeconds = 300,
  }) {
    _activePracticeItem = item;
    _targetSeconds = targetSeconds;
    _elapsedSeconds = 0;
    _isTimerRunning = false;
    _timerStartTime = null;
    notifyListeners();
  }


  /// Update timer
  void updateTimer(int elapsedSeconds, bool isRunning) {
    _elapsedSeconds = elapsedSeconds.clamp(0, _targetSeconds);
    _isTimerRunning = isRunning;
    notifyListeners();
  }

  /// Start timer
  void startTimer() {
    _isTimerRunning = true;
    _timerStartTime = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_elapsedSeconds < _targetSeconds) {
        _elapsedSeconds++;
        notifyListeners();
      } else {
        stopTimer();
      }
    });
    notifyListeners();
  }

  /// Stop timer
  void stopTimer() {
    _isTimerRunning = false;
    _timerStartTime = null;
    _timer?.cancel();
    notifyListeners();
  }

  /// Complete the session and save statistics
  Future<void> completeSession() async {
    _timer?.cancel();
    
    // Save statistics if there was an active session with time
    if (_activePracticeItem != null && _elapsedSeconds > 0) {
      try {
        await Statistics.addToStats(_activePracticeItem!, {
          'time': _elapsedSeconds,
          'reps': 1, // Default to 1 rep for time-based practice
        });
        print('PracticeSessionManager: Saved statistics for ${_activePracticeItem!.name}: ${_elapsedSeconds} seconds');
      } catch (e) {
        print('PracticeSessionManager: Error saving statistics: $e');
      }
    }
    
    _activePracticeItem = null;
    _targetSeconds = 60;
    _elapsedSeconds = 0;
    _isTimerRunning = false;
    _timerStartTime = null;
    notifyListeners();
  }

  /// Cancel the session
  void cancelSession() {
    completeSession();
  }

  /// Get session description for display
  String get sessionDescription {
    if (_activePracticeItem == null) return '';
    
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    final targetMinutes = _targetSeconds ~/ 60;
    final targetSecondsRem = _targetSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} / ${targetMinutes.toString().padLeft(2, '0')}:${targetSecondsRem.toString().padLeft(2, '0')}';
  }
}
