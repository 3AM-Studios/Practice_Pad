import 'package:flutter/cupertino.dart';
import 'package:clay_containers/clay_containers.dart';
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
      child: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Add padding for navigation bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
              
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Item description (if exists)
                    if (widget.practiceItem.description.isNotEmpty) ...[
                      ClayContainer(
                        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                        borderRadius: 16,
                        depth: 8,
                        spread: 1,
                        curveType: CurveType.concave,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            widget.practiceItem.description,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: CupertinoTheme.of(context).textTheme.textStyle.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    
                    // Main practice interface
                    _buildPracticeInterface(),
                    
                    const SizedBox(height: 32),
                    
                    // Complete session button
                    ClayContainer(
                      color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                      borderRadius: 16,
                      depth: 8,
                      spread: 1,
                      curveType: CurveType.concave,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        child: CupertinoButton.filled(
                          onPressed: _hasAnyReps() || _elapsedSeconds > 0
                              ? _completePracticeSession
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: const Text(
                            'Complete Session',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ]),
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
  
  Widget _buildPracticeInterface() {
    return Column(
      children: [
        // Title and timer section
        ClayContainer(
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
          borderRadius: 20,
          depth: 15,
          spread: 2,
          curveType: CurveType.concave,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Practice in All 12 Keys',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: CupertinoTheme.of(context).textTheme.textStyle.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Timer display
                ClayContainer(
                  color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                  borderRadius: 16,
                  depth: 8,
                  spread: 1,
                  curveType: CurveType.none,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      _formatTime(_elapsedSeconds),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Timer controls
                Row(
                  children: [
                    Expanded(
                      child: ClayContainer(
                        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                        borderRadius: 12,
                        depth: 6,
                        spread: 1,
                        curveType: CurveType.concave,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          child: CupertinoButton.filled(
                            onPressed: !_isTimerRunning ? _startTimer : _stopTimer,
                            borderRadius: BorderRadius.circular(10),
                            child: Text(
                              _isTimerRunning ? 'Stop' : 'Start',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ClayContainer(
                        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                        borderRadius: 12,
                        depth: 6,
                        spread: 1,
                        curveType: CurveType.concave,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          child: CupertinoButton.filled(
                            onPressed: _resetTimer,
                            borderRadius: BorderRadius.circular(10),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Practice tracking section
        ClayContainer(
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
          borderRadius: 20,
          depth: 15,
          spread: 2,
          curveType: CurveType.concave,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Concentric dial and bar graph
                SizedBox(
                  height: 400,
                  child: Row(
                    children: [
                      // Left side - Concentric Dial
                      Expanded(
                        child: Center(
                          child: ConcentricDialMenu(
                            size: 280,
                            ringSpacing: 0.25,
                            enableInnerHighlight: false, // Hide inner button highlights
                            enableOuterHighlight: true,
                            innerButtonScale: 0.0, // Hide inner buttons completely
                            centerText: 'Keys\nPracticed',
                            outerItems: _majorKeys.map((key) => DialItem(
                              label: key,
                              outerText: '${_keysPracticed[key] ?? 0}',
                            )).toList(),
                            innerItems: _majorKeys.map((key) => DialItem(
                              label: '', // Empty to hide completely
                            )).toList(),
                            onSelectionChanged: (innerIndex, outerIndex) {
                              if (outerIndex != null) {
                                _incrementKeyReps(_majorKeys[outerIndex]);
                              }
                              // Ignore inner button taps since they're hidden
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Right side - Bar Graph
                      Expanded(
                        child: _buildStylizedBarGraph(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Instructions
                ClayContainer(
                  color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                  borderRadius: 12,
                  depth: 4,
                  spread: 0,
                  curveType: CurveType.concave,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'Tap a key to add a rep',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: CupertinoTheme.of(context).textTheme.textStyle.color?.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStylizedBarGraph() {
    // Find the maximum reps for scaling
    final maxReps = _keysPracticed.values.isNotEmpty 
        ? _keysPracticed.values.reduce((a, b) => a > b ? a : b)
        : 1;
    
    // Use a minimum height for visualization even when maxReps is 0
    final effectiveMaxReps = maxReps > 0 ? maxReps : 1;
    const maxBarHeight = 200.0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Title
        Text(
          'Reps by Key',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: CupertinoTheme.of(context).textTheme.textStyle.color,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 20),
        
        // Bar graph container
        ClayContainer(
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
          borderRadius: 16,
          depth: 8,
          spread: 1,
          curveType: CurveType.none,
          child: Container(
            height: 280,
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate responsive sizing
                final availableWidth = constraints.maxWidth;
                final barSpacing = availableWidth / _majorKeys.length;
                final maxBarWidth = (barSpacing * 0.6).clamp(8.0, 20.0);
                final fontSize = (barSpacing * 0.2).clamp(8.0, 12.0);
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _majorKeys.map((key) {
                    final reps = _keysPracticed[key] ?? 0;
                    final heightRatio = reps / effectiveMaxReps;
                    
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: (barSpacing * 0.05).clamp(1.0, 4.0)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Reps count (above bar)
                            if (reps > 0)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  reps.toString(),
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoTheme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            
                            // Bar
                            ClayContainer(
                              color: reps > 0 
                                  ? CupertinoTheme.of(context).primaryColor.withOpacity(0.2)
                                  : CupertinoTheme.of(context).scaffoldBackgroundColor,
                              borderRadius: 8,
                              depth: reps > 0 ? 4 : 2,
                              spread: 1,
                              curveType: reps > 0 ? CurveType.convex : CurveType.none,
                              child: Container(
                                width: maxBarWidth,
                                height: reps > 0 ? (heightRatio * maxBarHeight) : 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: reps > 0 ? LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      CupertinoTheme.of(context).primaryColor,
                                      CupertinoTheme.of(context).primaryColor.withOpacity(0.7),
                                    ],
                                  ) : null,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Key label
                            Text(
                              key,
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600,
                                color: reps > 0 
                                    ? CupertinoTheme.of(context).primaryColor
                                    : CupertinoTheme.of(context).textTheme.textStyle.color?.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _incrementKeyReps(String key) {
    setState(() {
      _keysPracticed[key] = (_keysPracticed[key] ?? 0) + 1;
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
