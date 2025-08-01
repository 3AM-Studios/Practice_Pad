import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:practice_pad/features/practice/models/circle_of_fifths_keys.dart';
import 'package:practice_pad/models/practice_item.dart';

class CircleOfFifthsViewModel extends ChangeNotifier {
  final PracticeItem practiceItem; // The item being practiced
  int numberOfCycles; // Number of cycles for this specific practice session

  // Circle State
  int _currentKeyIndex =
      0; // Index in circleOfFifthsKeyNames, C is default (top)
  int get currentKeyIndex => _currentKeyIndex;
  String get currentTopKeyName => circleOfFifthsKeyNames[_currentKeyIndex];

  // Settings
  int _bpm = 120;
  int get bpm => _bpm;
  set bpm(int value) {
    _bpm = value.clamp(30, 240); // Example clamp
    notifyListeners();
  }

  // Time Signature (simplified for now, can be expanded)
  // For simplicity, let's assume each key gets a certain number of beats
  // or the key changes every N beats of the metronome.
  // A full TimeSignature class might be needed for complex signatures.
  int _beatsPerKeyChange =
      4; // e.g., in 4/4, key changes every 4 beats (1 measure)
  int get beatsPerKeyChange => _beatsPerKeyChange;
  set beatsPerKeyChange(int value) {
    _beatsPerKeyChange = value.clamp(1, 16);
    notifyListeners();
  }
  // Could add String timeSignatureDisplay = "4/4"; and update it based on beatsPerKeyChange
  // or a more complex TimeSignature model.

  // Playback State
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  int _playbackKeyIndex = 0; // Tracks the current key during playback
  int get playbackKeyIndex => _playbackKeyIndex;

  int _completedCycles = 0; // Renamed from _currentCycle for clarity
  int get cyclesCompletedThisSession => _completedCycles;

  // For UI display (1-indexed)
  int get currentCycleDisplay {
    if (!_isPlaying && _completedCycles == 0) {
      return 1; // Show 1 by default before starting
    }
    if (_completedCycles >= numberOfCycles) return numberOfCycles;
    return _completedCycles + 1;
  }

  int _currentBeatInKey = 0;

  Timer? _metronomeTimer;
  Timer?
      _keyChangeTimer; // Alternative or complementary to metronome for key changes

  CircleOfFifthsViewModel(
      {required this.practiceItem, required this.numberOfCycles});

  void setNumberOfCycles(int value) {
    if (value >= 1 && value <= 20) {
      // Assuming max 20 cycles for slider
      numberOfCycles = value;
      if (_completedCycles >= numberOfCycles) {
        _completedCycles =
            numberOfCycles - 1; // Adjust if current completed is now too high
        if (_completedCycles < 0) _completedCycles = 0;
      }
      notifyListeners();
    }
  }

  void incrementTotalCycles() {
    setNumberOfCycles(numberOfCycles + 1);
  }

  void decrementTotalCycles() {
    setNumberOfCycles(numberOfCycles - 1);
  }

  void rotateCircle(int steps) {
    if (_isPlaying) return; // Don't allow rotation while playing
    _currentKeyIndex =
        (_currentKeyIndex + steps) % circleOfFifthsKeyNames.length;
    if (_currentKeyIndex < 0) {
      _currentKeyIndex +=
          circleOfFifthsKeyNames.length; // Ensure positive index
    }
    notifyListeners();
  }

  void setStartingKey(String keyName) {
    if (_isPlaying) return;
    final index = circleOfFifthsKeyNames.indexOf(keyName);
    if (index != -1) {
      _currentKeyIndex = index;
      notifyListeners();
    }
  }

  void play() {
    if (_isPlaying) return;
    _isPlaying = true;
    _playbackKeyIndex = _currentKeyIndex; // Start from the selected top key
    _completedCycles = 0; // Reset completed cycles when play is pressed
    _currentBeatInKey = 0;
    notifyListeners();
    _startMetronomeAndKeyCycling();
  }

  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _metronomeTimer?.cancel();
    _keyChangeTimer?.cancel();
    notifyListeners();
  }

  void reset() {
    pause();
    _currentKeyIndex = 0; // Reset to C
    // _bpm = 120; // Keep user's BPM setting
    // _beatsPerKeyChange = 4; // Keep user's beats per key
    _playbackKeyIndex = _currentKeyIndex;
    _completedCycles = 0;
    _currentBeatInKey = 0;
    // numberOfCycles remains user-defined, don't reset it here
    notifyListeners();
  }

  void _startMetronomeAndKeyCycling() {
    if (!_isPlaying) return;

    final double beatIntervalSeconds = 60.0 / _bpm;

    _metronomeTimer = Timer.periodic(
        Duration(milliseconds: (beatIntervalSeconds * 1000).toInt()), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      // Metronome tick logic (e.g., play sound) - to be added
      // print("Metronome Tick! Beat: ${_currentBeatInKey + 1}");

      _currentBeatInKey++;
      if (_currentBeatInKey >= _beatsPerKeyChange) {
        _currentBeatInKey = 0;
        _advanceKey();
      }
      notifyListeners(); // For UI updates reflecting current beat/key
    });
  }

  void _advanceKey() {
    _playbackKeyIndex = (_playbackKeyIndex + 1) % circleOfFifthsKeyNames.length;
    if (_playbackKeyIndex == _currentKeyIndex) {
      // Completed one full cycle relative to start
      _completedCycles++;
      if (_completedCycles >= numberOfCycles) {
        pause(); // All cycles complete
        // Optionally, you could set _completedCycles = numberOfCycles here to ensure UI display is exact
      }
    }
    // notifyListeners(); // Already notified by metronome timer logic
  }

  @override
  void dispose() {
    _metronomeTimer?.cancel();
    _keyChangeTimer?.cancel();
    super.dispose();
  }
}
