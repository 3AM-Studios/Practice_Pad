import 'package:flutter/cupertino.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/statistics.dart';
import 'package:practice_pad/services/practice_session_manager.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/concentric_dial_menu.dart';
import 'package:provider/provider.dart';

/// Screen for conducting a practice session with a specific practice item
class PracticeSessionScreen extends StatefulWidget {
  final PracticeItem practiceItem;

  const PracticeSessionScreen({
    super.key,
    required this.practiceItem,
  });

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  // Practice type selection - now only time-based
  
  // Time-based practice state
  final int _targetMinutes = 1;
  int _targetSeconds = 0;
  int _elapsedSeconds = 0;
  bool _isTimerRunning = false;
  
  // Keys practice state
  final List<String> _majorKeys = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'];
  late Map<String, int> _keysPracticed;
  
  // Timer for time-based practice
  // Removed - now using global session manager timer
  
  // Reference to session manager for safe disposal
  PracticeSessionManager? _sessionManager;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize keys practiced from the practice item
    _keysPracticed = Map.from(widget.practiceItem.keysPracticed);
    
    // Check if there's already an active session for this item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionManager = Provider.of<PracticeSessionManager>(context, listen: false);
      
      if (_sessionManager!.hasActiveSession && 
          _sessionManager!.activePracticeItem?.id == widget.practiceItem.id) {
        // Resume existing session
        setState(() {
          _targetSeconds = _sessionManager!.targetSeconds;
          _elapsedSeconds = _sessionManager!.elapsedSeconds;
          _isTimerRunning = _sessionManager!.isTimerRunning;
        });
      } else {
        // Start new session
        _sessionManager!.startSession(
          item: widget.practiceItem,
          isRepsBased: false, // Always time-based now
          targetReps: 0,
          targetSeconds: _getTotalTargetSeconds(),
        );
      }
      
      // Add listener to sync with global session manager
      _sessionManager!.addListener(_syncWithGlobalManager);
    });
  }
  
  @override
  void dispose() {
    // Use the stored reference instead of Provider.of(context)
    _sessionManager?.removeListener(_syncWithGlobalManager);
    super.dispose();
  }
  
  void _syncWithGlobalManager() {
    if (mounted && _sessionManager != null && _sessionManager!.hasActiveSession && 
        _sessionManager!.activePracticeItem?.id == widget.practiceItem.id) {
      setState(() {
        _elapsedSeconds = _sessionManager!.elapsedSeconds;
        _isTimerRunning = _sessionManager!.isTimerRunning;
      });
    }
  }
  
  int _getTotalTargetSeconds() {
    return (_targetMinutes * 60) + _targetSeconds;
  }
  
  void _startTimer() {
    setState(() {
      _isTimerRunning = true;
    });
    
    // Use the global session manager's timer instead of local timer
    _sessionManager?.startTimer();
  }
  
  void _stopTimer() {
    setState(() {
      _isTimerRunning = false;
    });
    
    // Use the global session manager's timer instead of local timer
    _sessionManager?.stopTimer();
  }
  
  void _resetTimer() {
    setState(() {
      _isTimerRunning = false;
      _elapsedSeconds = 0;
    });
    
    // Reset the global manager timer as well
    _sessionManager?.updateTimer(0, false);
  }
  
  void _completePracticeSession() async {
    if (_sessionManager == null) return;
    
    try {
      print('DEBUG: Starting practice session completion');
      
      // Update the practice item with the new keys practiced counts
      widget.practiceItem.keysPracticed.clear();
      widget.practiceItem.keysPracticed.addAll(_keysPracticed);
      
      // Calculate total reps across all keys
      final totalReps = _keysPracticed.values.fold(0, (sum, reps) => sum + reps);
      
      print('DEBUG: Total reps calculated: $totalReps');
      
      Map<String, dynamic> practiceAmount = {
        'time': _elapsedSeconds,
        'keysPracticed': Map.from(_keysPracticed),
        'totalReps': totalReps,
      };
      
      // Create and save the practice session as statistics
      final statistics = Statistics(
        practiceItemId: widget.practiceItem.id,
        timestamp: DateTime.now(),
        totalReps: totalReps,
        totalTime: Duration(seconds: _elapsedSeconds),
        metadata: practiceAmount,
      );
      
      print('DEBUG: Statistics object created');
      
      // Save to statistics
      await statistics.save();
      
      print('DEBUG: Statistics saved successfully');
      
      // Complete the session in the global manager
      _sessionManager!.completeSession();
      
      print('DEBUG: Session completed in manager');
      
      // Show success message
      if (mounted) {
        print('DEBUG: Showing success dialog');
        showCupertinoDialog(
          context: context,
          barrierDismissible: false, // Prevent dismissing by tapping outside
          builder: (BuildContext dialogContext) => CupertinoAlertDialog(
            title: const Text('Practice Session Complete!'),
            content: Text(
              'Great work practicing "${widget.practiceItem.name}"!\n\n'
              'You completed $totalReps repetitions across ${_keysPracticed.entries.where((e) => e.value > 0).length} keys.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Continue'),
                onPressed: () {
                  print('DEBUG: Dialog continue pressed');
                  Navigator.of(dialogContext).pop(); // Close dialog using dialog context
                  Navigator.of(context).pop(true); // Return to previous screen using original context
                },
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      print('DEBUG: Error in _completePracticeSession: $e');
      print('DEBUG: Stack trace: $stackTrace');
      
      // Show error message
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save practice session: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }
  
  void _updateGlobalManager() {
    if (_sessionManager == null) return;
    _sessionManager!.updateTimer(_elapsedSeconds, _isTimerRunning);
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Practice: ${widget.practiceItem.name}'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Back'),
          onPressed: () {
            // Don't cancel the session, just go back - session continues running
            Navigator.of(context).pop(false);
          },
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('End'),
          onPressed: () {
            _showEndSessionDialog();
          },
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item description
              if (widget.practiceItem.description.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.practiceItem.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Practice interface
              Expanded(
                child: _build12KeysInterface(),
              ),
              
              // Complete session button
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _hasAnyReps() || _elapsedSeconds > 0
                      ? _completePracticeSession
                      : null,
                  child: const Text('Complete Session'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasAnyReps() {
    return _keysPracticed.values.any((reps) => reps > 0);
  }
  
  Widget _build12KeysInterface() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Practice in All 12 Keys',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _formatTime(_elapsedSeconds),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Timer controls
        Row(
          children: [
            Expanded(
              child: CupertinoButton.filled(
                onPressed: !_isTimerRunning ? _startTimer : _stopTimer,
                child: Text(_isTimerRunning ? 'Stop' : 'Start'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CupertinoButton.filled(
                onPressed: _resetTimer,
                child: const Text('Reset'),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // 12 Keys Dial and Bar Graph
        Expanded(
          child: Row(
            children: [
              // Left side - Concentric Dial
              Expanded(
                flex: 2,
                child: Center(
                  child: ConcentricDialMenu(
                    size: 300,
                    ringSpacing: 0.25, // Keep inner buttons close to outer ones
                    enableInnerHighlight: false, // Don't highlight inner minus buttons
                    enableOuterHighlight: true, // Keep outer highlighting
                    innerButtonScale: 0.3, // Make inner minus buttons much smaller
                    centerText: 'Keys Practiced',
                    outerItems: _majorKeys.map((key) => DialItem(
                      label: key,
                      outerText: '${_keysPracticed[key] ?? 0}',
                    )).toList(),
                    innerItems: _majorKeys.map((key) => DialItem(
                      label: '-', // This will be overridden in the painter
                    )).toList(),
                    onSelectionChanged: (innerIndex, outerIndex) {
                      if (outerIndex != null) {
                        _incrementKeyReps(_majorKeys[outerIndex]);
                      } else if (innerIndex != null) {
                        _decrementKeyReps(_majorKeys[innerIndex]);
                      }
                    },
                  ),
                ),
              ),
              
              // Right side - Bar Graph
              Expanded(
                flex: 2,
                child: _buildBarGraph(),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Instructions
        const Text(
          'Tap a key to add a rep • Tap the small minus button to subtract a rep',
          style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildBarGraph() {
    // Find the maximum reps for scaling
    final maxReps = _keysPracticed.values.isNotEmpty 
        ? _keysPracticed.values.reduce((a, b) => a > b ? a : b)
        : 1;
    
    // Use a minimum height for visualization even when maxReps is 0
    final effectiveMaxReps = maxReps > 0 ? maxReps : 1;
    const maxBarHeight = 300.0; // Increased max height for bigger graph
    
    return Center(
      child: Container(
        height: 500, // Increased container height
        width: 500, // Increased width for bigger graph
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title
            const Text(
              'Reps by Key',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Bar graph - use Flexible to prevent overflow
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _majorKeys.map((key) {
                  final reps = _keysPracticed[key] ?? 0;
                  final heightRatio = reps / effectiveMaxReps;
                  
                  return Flexible(
                    child: Container(
                      width: 18, // Increased bar width
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Prevent overflow
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Bar
                          Container(
                            width: 30, // Increased actual bar width
                            height: reps > 0 ? (heightRatio * maxBarHeight) : 2,
                            decoration: BoxDecoration(
                              color: reps > 0 
                                  ? CupertinoColors.systemBlue 
                                  : CupertinoColors.systemGrey4,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                            child: reps > 0 && (heightRatio * maxBarHeight) > 20 // Show text if bar is tall enough
                                ? Center(
                                    child: Text(
                                      reps.toString(),
                                      style: const TextStyle(
                                        color: CupertinoColors.white,
                                        fontSize: 10, // Increased font size
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          
                          const SizedBox(height: 4),
                          
                          // Key label
                          Text(
                            key,
                            style: const TextStyle(
                              fontSize: 11, // Increased font size
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _incrementKeyReps(String key) {
    setState(() {
      _keysPracticed[key] = (_keysPracticed[key] ?? 0) + 1;
    });
    // Update the practice item immediately
    widget.practiceItem.keysPracticed[key] = _keysPracticed[key]!;
  }
  
  void _decrementKeyReps(String key) {
    setState(() {
      if ((_keysPracticed[key] ?? 0) > 0) {
        _keysPracticed[key] = (_keysPracticed[key] ?? 1) - 1;
      }
    });
    // Update the practice item immediately
    widget.practiceItem.keysPracticed[key] = _keysPracticed[key]!;
  }
  void _showEndSessionDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('End Practice Session'),
          content: const Text('Are you sure you want to end this practice session? Your progress will be saved.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('End Session'),
              onPressed: () {
                _sessionManager?.cancelSession();
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(false); // Close screen
              },
            ),
          ],
        );
      },
    );
  }
}
