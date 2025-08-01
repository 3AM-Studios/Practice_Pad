import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:practice_pad/models/practice_item.dart';

/// Global manager for tracking active practice sessions across the app
class PracticeSessionManager extends ChangeNotifier {
  static final PracticeSessionManager _instance = PracticeSessionManager._internal();
  factory PracticeSessionManager() => _instance;
  PracticeSessionManager._internal();

  PracticeItem? _activePracticeItem;
  bool _isRepsBased = true;
  int _targetReps = 1;
  int _completedReps = 0;
  int _targetSeconds = 60;
  int _elapsedSeconds = 0;
  bool _isTimerRunning = false;
  Timer? _timer;

  // Getters
  PracticeItem? get activePracticeItem => _activePracticeItem;
  bool get hasActiveSession => _activePracticeItem != null;
  bool get isRepsBased => _isRepsBased;
  int get targetReps => _targetReps;
  int get completedReps => _completedReps;
  int get targetSeconds => _targetSeconds;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isTimerRunning => _isTimerRunning;
  
  int get remainingSeconds => _targetSeconds - _elapsedSeconds;
  double get progressPercentage {
    if (_isRepsBased) {
      return _targetReps > 0 ? _completedReps / _targetReps : 0;
    } else {
      return _targetSeconds > 0 ? _elapsedSeconds / _targetSeconds : 0;
    }
  }

  /// Start a new practice session
  void startSession({
    required PracticeItem item,
    required bool isRepsBased,
    int targetReps = 1,
    int targetSeconds = 60,
  }) {
    _activePracticeItem = item;
    _isRepsBased = isRepsBased;
    _targetReps = targetReps;
    _completedReps = 0;
    _targetSeconds = targetSeconds;
    _elapsedSeconds = 0;
    _isTimerRunning = false;
    notifyListeners();
  }

  /// Update reps count
  void updateReps(int reps) {
    _completedReps = reps.clamp(0, _targetReps);
    notifyListeners();
  }

  /// Increment reps
  void incrementReps() {
    if (_completedReps < _targetReps) {
      _completedReps++;
      notifyListeners();
    }
  }

  /// Decrement reps
  void decrementReps() {
    if (_completedReps > 0) {
      _completedReps--;
      notifyListeners();
    }
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
    _timer?.cancel();
    notifyListeners();
  }

  /// Complete the session
  void completeSession() {
    _timer?.cancel();
    _activePracticeItem = null;
    _isRepsBased = true;
    _targetReps = 1;
    _completedReps = 0;
    _targetSeconds = 60;
    _elapsedSeconds = 0;
    _isTimerRunning = false;
    notifyListeners();
  }

  /// Cancel the session
  void cancelSession() {
    completeSession();
  }

  /// Get session description for display
  String get sessionDescription {
    if (_activePracticeItem == null) return '';
    
    if (_isRepsBased) {
      return '$_completedReps / $_targetReps reps';
    } else {
      final minutes = _elapsedSeconds ~/ 60;
      final seconds = _elapsedSeconds % 60;
      final targetMinutes = _targetSeconds ~/ 60;
      final targetSecondsRem = _targetSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} / ${targetMinutes.toString().padLeft(2, '0')}:${targetSecondsRem.toString().padLeft(2, '0')}';
    }
  }
}
