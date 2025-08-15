import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:flutter/material.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/statistics.dart';
import 'package:practice_pad/services/practice_session_manager.dart';
import 'package:practice_pad/services/local_storage_service.dart';
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
  final List<String> _majorKeys = [
    'C',
    'C#',
    'D',
    'Eb',
    'E',
    'F',
    'F#',
    'G',
    'Ab',
    'A',
    'Bb',
    'B'
  ];
  late Map<String, int> _keysPracticed;
  late Map<String, int> _todaysReps; // Track today's additions

  // Timer for time-based practice
  // Removed - now using global session manager timer

  // Reference to session manager for safe disposal
  PracticeSessionManager? _sessionManager;

  @override
  void initState() {
    super.initState();

    // Initialize keys practiced from the practice item
    _keysPracticed = Map.from(widget.practiceItem.keysPracticed);

    // Initialize today's reps (starts at 0 for all keys)
    _todaysReps = Map.fromIterable(_majorKeys, value: (key) => 0);

    // Check if there's already an active session for this item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionManager =
          Provider.of<PracticeSessionManager>(context, listen: false);

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
    if (mounted &&
        _sessionManager != null &&
        _sessionManager!.hasActiveSession &&
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
      final totalReps =
          _keysPracticed.values.fold(0, (sum, reps) => sum + reps);

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
                  Navigator.of(dialogContext)
                      .pop(); // Close dialog using dialog context
                  Navigator.of(context).pop(
                      true); // Return to previous screen using original context
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
    return Scaffold(
      body: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Main practice interface
                    _buildPracticeInterface(),

                    const SizedBox(height: 10),

                    // Complete session button with clay and wood styling
                    ClayContainer(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: 20,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          image: const DecorationImage(
                            image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: CupertinoButton(
                          onPressed: _hasAnyReps() || _elapsedSeconds > 0
                              ? _completePracticeSession
                              : null,
                          borderRadius: BorderRadius.circular(20),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            'Complete Session',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _hasAnyReps() || _elapsedSeconds > 0
                                  ? CupertinoColors.white
                                  : CupertinoColors.white.withOpacity(0.5),
                              letterSpacing: 0.8,
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
    return ClayContainer(
      color: CupertinoTheme.of(context).scaffoldBackgroundColor,
      borderRadius: 28,
      depth: 20,
      spread: 4,
      curveType: CurveType.concave,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Timer section with regular clay container
            ClayContainer(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: 24,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    // Practice item name with X button
                    Row(
                      children: [
                        ClayContainer(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              image: const DecorationImage(
                                image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                                fit: BoxFit.cover,
                              ),
                              border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: CupertinoButton(
                              padding: const EdgeInsets.all(8),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Icon(
                                CupertinoIcons.xmark,
                                color: CupertinoColors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.practiceItem.name,
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: CupertinoTheme.of(context).textTheme.textStyle.color,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48), // Balance the X button width
                      ],
                    ),
                    // Add description as subtitle if it exists
                    if (widget.practiceItem.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.practiceItem.description,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: CupertinoTheme.of(context).textTheme.textStyle.color?.withOpacity(0.7),
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Timer display with wooden styling
                    ClayContainer(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          image: const DecorationImage(
                            image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatTime(_elapsedSeconds),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: CupertinoColors.white,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Timer controls with clay containers
                    Row(
                      children: [
                        Expanded(
                          child: ClayContainer(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: 16,
                            child: _buildModernButton(
                              text: _isTimerRunning ? 'Stop' : 'Start',
                              onPressed:
                                  !_isTimerRunning ? _startTimer : _stopTimer,
                              color: _isTimerRunning
                                  ? CupertinoColors.systemRed
                                  : CupertinoColors.activeGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ClayContainer(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: 16,
                            child: _buildModernButton(
                              text: 'Reset',
                              onPressed: _resetTimer,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Keys Practiced section with regular clay container
            ClayContainer(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: 32,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // Keys Practiced title with wooden styling
                    ClayContainer(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          image: const DecorationImage(
                            image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Keys Practiced',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.white,
                            letterSpacing: 0.8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                      const SizedBox(height: 28),

                      // Combined Circle of Fifths with Internal Bar Graph
                      SizedBox(
                        height: 420,
                        child: Center(
                          child: _buildCircularKeysWithBarGraph(),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: CupertinoColors.systemGrey4.withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: CupertinoTheme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tap a key to add a rep',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .color
                                    ?.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CupertinoButton(
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCircularKeysWithBarGraph() {
    return ClayContainer(
      color: CupertinoTheme.of(context).scaffoldBackgroundColor,
      borderRadius: 32,
      depth: 18,
      spread: 3,
      curveType: CurveType.concave,
      child: Container(
        width: 430,
        height: 430,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              CupertinoTheme.of(context).scaffoldBackgroundColor,
              CupertinoTheme.of(context)
                  .scaffoldBackgroundColor
                  .withOpacity(0.85),
              CupertinoTheme.of(context)
                  .scaffoldBackgroundColor
                  .withOpacity(0.7),
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: GestureDetector(
          onTapDown: (details) {
            final result = _getKeyFromPosition(details.localPosition);
            if (result != null) {
              _incrementKeyReps(result);
            }
          },
          child: CustomPaint(
            size: const Size(350, 350), // Account for padding (430-80)
            painter: _CircularKeyBarGraphPainter(
              majorKeys: _majorKeys,
              keysPracticed: _keysPracticed,
              todaysReps: _todaysReps,
              textColor: CupertinoTheme.of(context).textTheme.textStyle.color ??
                  CupertinoColors.label,
              primaryColor: CupertinoTheme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  String? _getKeyFromPosition(Offset position) {
    const customPaintSize = 350.0;
    const customPaintCenter = Offset(customPaintSize / 2, customPaintSize / 2);

    // The position is already in CustomPaint coordinates (0-350)
    final dx = position.dx - customPaintCenter.dx;
    final dy = position.dy - customPaintCenter.dy;

    // Use the same radius calculations as in the painter
    const outerRadius = customPaintSize / 2 * 0.8; // 350/2 * 0.8 = 140
    const buttonRadius = customPaintSize / 2 * 0.14; // Match painter buttonRadius

    double minDistance = double.infinity;
    String? closestKey;

    for (int i = 0; i < _majorKeys.length; i++) {
      final anglePerItem = 2 * pi / _majorKeys.length;
      final buttonAngle = i * anglePerItem - pi / 2; // Start from top
      final buttonCenter = Offset(
        customPaintCenter.dx + outerRadius * cos(buttonAngle),
        customPaintCenter.dy + outerRadius * sin(buttonAngle),
      );
      final distanceToButton = sqrt(pow(position.dx - buttonCenter.dx, 2) +
          pow(position.dy - buttonCenter.dy, 2));

      // Use generous threshold for touch interface
      const threshold = 30.0;
      if (distanceToButton < minDistance && distanceToButton <= threshold) {
        minDistance = distanceToButton;
        closestKey = _majorKeys[i];
      }
    }

    return closestKey;
  }

  void _incrementKeyReps(String key) async {
    setState(() {
      _keysPracticed[key] = (_keysPracticed[key] ?? 0) + 1;
      _todaysReps[key] = (_todaysReps[key] ?? 0) + 1; // Track today's additions
    });

    // Update the practice item immediately
    widget.practiceItem.keysPracticed[key] = _keysPracticed[key]!;

    // Save the updated practice item to persistent storage
    await _savePracticeItemProgress();
  }

  Future<void> _savePracticeItemProgress() async {
    try {
      // Load all practice items from storage
      final itemsByArea = await LocalStorageService.loadPracticeItems();

      // Find and update this practice item across all areas
      bool itemUpdated = false;
      for (final areaId in itemsByArea.keys) {
        final items = itemsByArea[areaId]!;
        for (int i = 0; i < items.length; i++) {
          if (items[i].id == widget.practiceItem.id) {
            // Update the item in the list with our current progress
            items[i] = widget.practiceItem;
            itemUpdated = true;
            break;
          }
        }
        if (itemUpdated) break;
      }

      // Save the updated data back to storage
      if (itemUpdated) {
        await LocalStorageService.savePracticeItems(itemsByArea);
      }
    } catch (e) {
      // Silently handle errors - practice can continue even if save fails
    }
  }

  void _showEndSessionDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('End Practice Session'),
          content: const Text(
              'Are you sure you want to end this practice session? Your progress will be saved.'),
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

class _CircularKeyBarGraphPainter extends CustomPainter {
  final List<String> majorKeys;
  final Map<String, int> keysPracticed;
  final Map<String, int> todaysReps;
  final Color textColor;
  final Color primaryColor;

  _CircularKeyBarGraphPainter({
    required this.majorKeys,
    required this.keysPracticed,
    required this.todaysReps,
    required this.textColor,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 * 0.8;
    final buttonRadius = size.width / 2 * 0.14;
    final centerCircleRadius =
        size.width / 2 * 0.08; // Professional center circle

    // Calculate max reps for scaling bars
    final maxReps = keysPracticed.values.isNotEmpty
        ? keysPracticed.values.reduce((a, b) => a > b ? a : b)
        : 1;
    final effectiveMaxReps = maxReps > 0 ? maxReps : 1;
    final maxBarLength =
        size.width / 2 * 0.45; // Slightly shorter bars for cleaner look

    // Draw radial bars from center circle edge (bar graph inside circle)
    for (int i = 0; i < majorKeys.length; i++) {
      final key = majorKeys[i];
      final totalReps = keysPracticed[key] ?? 0;
      final todayReps = todaysReps[key] ?? 0;
      final historicalReps = totalReps - todayReps;
      final anglePerItem = 2 * pi / majorKeys.length;
      final angle = i * anglePerItem - pi / 2; // Start from top

      if (totalReps > 0) {
        final totalBarLength = (totalReps / effectiveMaxReps) * maxBarLength;
        final historicalBarLength = historicalReps > 0
            ? (historicalReps / effectiveMaxReps) * maxBarLength
            : 0;
        final barStartRadius = centerCircleRadius + 3;

        final startPoint = Offset(
          center.dx + barStartRadius * cos(angle),
          center.dy + barStartRadius * sin(angle),
        );

        // Draw historical reps (darker, established color)
        if (historicalReps > 0) {
          final historicalEndPoint = Offset(
            center.dx + (barStartRadius + historicalBarLength) * cos(angle),
            center.dy + (barStartRadius + historicalBarLength) * sin(angle),
          );

          final historicalPaint = Paint()
            ..color = CupertinoColors.systemBlue.withOpacity(0.53)
            ..strokeWidth = 12
            ..strokeCap = StrokeCap.round;

          canvas.drawLine(startPoint, historicalEndPoint, historicalPaint);
        }

        // Draw today's reps (brighter, fresh color)
        if (todayReps > 0) {
          final todayStartPoint = Offset(
            center.dx + (barStartRadius + historicalBarLength) * cos(angle),
            center.dy + (barStartRadius + historicalBarLength) * sin(angle),
          );
          final todayEndPoint = Offset(
            center.dx + (barStartRadius + totalBarLength) * cos(angle),
            center.dy + (barStartRadius + totalBarLength) * sin(angle),
          );

          // Use consistent color for today's progress
          const todayColor = CupertinoColors.activeOrange;

          final todayPaint = Paint()
            ..color = todayColor.withOpacity(0.95)
            ..strokeWidth = 12
            ..strokeCap = StrokeCap.round;

          canvas.drawLine(todayStartPoint, todayEndPoint, todayPaint);

          // Add glow effect for today's bars
          final glowPaint = Paint()
            ..color = todayColor
            ..strokeWidth = 13.3
            ..strokeCap = StrokeCap.round;

          canvas.drawLine(todayStartPoint, todayEndPoint, glowPaint);
        }

        // Add subtle shadow effect for the entire bar
        final shadowPaint = Paint()
          ..color = CupertinoColors.black.withOpacity(0.1)
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round;

        final totalEndPoint = Offset(
          center.dx + (barStartRadius + totalBarLength) * cos(angle),
          center.dy + (barStartRadius + totalBarLength) * sin(angle),
        );

        canvas.drawLine(
          Offset(startPoint.dx + 1.5, startPoint.dy + 1.5),
          Offset(totalEndPoint.dx + 1.5, totalEndPoint.dy + 1.5),
          shadowPaint,
        );
      }
    }

    // Draw outer ring of key buttons with enhanced professional styling
    for (int i = 0; i < majorKeys.length; i++) {
      final key = majorKeys[i];
      final reps = keysPracticed[key] ?? 0;
      final anglePerItem = 2 * pi / majorKeys.length;
      final angle = i * anglePerItem - pi / 2; // Start from top

      final buttonCenter = Offset(
        center.dx + outerRadius * cos(angle),
        center.dy + outerRadius * sin(angle),
      );

      // Draw button shadow first
      final shadowPaint = Paint()
        ..color = CupertinoColors.black.withOpacity(0.1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(buttonCenter.dx + 1, buttonCenter.dy + 1),
          buttonRadius, shadowPaint);

      // Draw button background with gradient
      final buttonPaint = Paint()..style = PaintingStyle.fill;

      final todayReps = todaysReps[key] ?? 0;

      if (todayReps > 0) {
        // Key worked on today - blue
        buttonPaint.color = CupertinoColors.activeOrange;
      } else if (reps > 0) {
        // Key with historical practice but not today - darker grey
        buttonPaint.color = primaryColor.withOpacity(0.8);
      } else {
        // No practice at all - light grey
        buttonPaint.color = CupertinoColors.systemGrey5;
      }

      canvas.drawCircle(buttonCenter, buttonRadius, buttonPaint);

      // Draw button border with enhanced styling
      final borderPaint = Paint()
        ..color = todayReps > 0
            ? CupertinoColors.activeOrange
            : (reps > 0 ? Colors.transparent : Colors.transparent);

      canvas.drawCircle(buttonCenter, buttonRadius, borderPaint);

      // Draw key label with enhanced typography
      final labelPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: key,
          style: TextStyle(
            color: todayReps > 0
                ? CupertinoColors.white
                : (reps > 0
                    ? CupertinoColors.white
                    : textColor.withOpacity(0.7)),
            fontSize: buttonRadius * 0.55,
            fontWeight: todayReps > 0 ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
          buttonCenter.dx - labelPainter.width / 2,
          buttonCenter.dy - labelPainter.height / 2,
        ),
      );

      // Draw rep count outside the button with enhanced styling
      if (reps > 0) {
        final outerTextRadius = outerRadius + buttonRadius + 18;
        final outerTextCenter = Offset(
          center.dx + outerTextRadius * cos(angle),
          center.dy + outerTextRadius * sin(angle),
        );

        // Draw background circle for rep count
        final repBgPaint = Paint()
          ..color = todayReps > 0
              ? CupertinoColors.activeOrange.withOpacity(0.9)
              : primaryColor.withOpacity(0.7)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(outerTextCenter, 12, repBgPaint);

        final outerTextPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: reps.toString(),
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        outerTextPainter.layout();
        outerTextPainter.paint(
          canvas,
          Offset(
            outerTextCenter.dx - outerTextPainter.width / 2,
            outerTextCenter.dy - outerTextPainter.height / 2,
          ),
        );
      }
    }

    // Draw center circle on top (above bars)
    final centerCirclePaint = Paint()
      ..color = CupertinoColors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, centerCircleRadius, centerCirclePaint);

    // Draw center circle border
    final centerBorderPaint = Paint()
      ..color = CupertinoColors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, centerCircleRadius, centerBorderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
