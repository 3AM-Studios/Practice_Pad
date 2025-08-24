// Enhanced Progress Bar with Loop Selection
// Integrated loop functionality with click and drag selection

import 'package:flutter/material.dart';

import '../utils/youtube_player_controller.dart';

/// Colors for the enhanced loop progress bar
class LoopProgressBarColors {
  /// Background color of the progress bar
  final Color? backgroundColor;
  
  /// Color for played portion
  final Color? playedColor;
  
  /// Color for buffered portion  
  final Color? bufferedColor;
  
  /// Color for the main handle
  final Color? handleColor;
  
  /// Color for the loop region
  final Color? loopRegionColor;
  
  /// Color for loop handles
  final Color? loopHandleColor;
  
  /// Color for loop markers
  final Color? loopMarkerColor;

  const LoopProgressBarColors({
    this.backgroundColor,
    this.playedColor,
    this.bufferedColor,
    this.handleColor,
    this.loopRegionColor,
    this.loopHandleColor,
    this.loopMarkerColor,
  });

  LoopProgressBarColors copyWith({
    Color? backgroundColor,
    Color? playedColor,
    Color? bufferedColor,
    Color? handleColor,
    Color? loopRegionColor,
    Color? loopHandleColor,
    Color? loopMarkerColor,
  }) =>
      LoopProgressBarColors(
        backgroundColor: backgroundColor ?? this.backgroundColor,
        playedColor: playedColor ?? this.playedColor,
        bufferedColor: bufferedColor ?? this.bufferedColor,
        handleColor: handleColor ?? this.handleColor,
        loopRegionColor: loopRegionColor ?? this.loopRegionColor,
        loopHandleColor: loopHandleColor ?? this.loopHandleColor,
        loopMarkerColor: loopMarkerColor ?? this.loopMarkerColor,
      );
}

/// Callback signatures for loop events
typedef LoopUpdateCallback = void Function(Duration start, Duration end);
typedef LoopPlayCallback = void Function();
typedef LoopToggleCallback = void Function(bool enabled);

/// Enhanced progress bar with integrated loop functionality
class LoopProgressBar extends StatefulWidget {
  const LoopProgressBar({
    super.key,
    this.controller,
    this.colors,
    this.isExpanded = false,
    this.onLoopUpdate,
    this.onLoopPlay,
    this.onLoopToggle,
    this.loopStart,
    this.loopEnd,
    this.isLoopEnabled = false,
    this.showControls = true,
  });

  final YoutubePlayerController? controller;
  final LoopProgressBarColors? colors;
  final bool isExpanded;
  final LoopUpdateCallback? onLoopUpdate;
  final LoopPlayCallback? onLoopPlay;
  final LoopToggleCallback? onLoopToggle;
  final Duration? loopStart;
  final Duration? loopEnd;
  final bool isLoopEnabled;
  final bool showControls;

  @override
  State<LoopProgressBar> createState() => _LoopProgressBarState();
}

class _LoopProgressBarState extends State<LoopProgressBar>
    with TickerProviderStateMixin {
  late YoutubePlayerController _controller;
  late AnimationController _loopAnimationController;
  late Animation<double> _loopAnimation;

  Offset _touchPoint = Offset.zero;
  double _playedValue = 0.0;
  double _bufferedValue = 0.0;
  bool _touchDown = false;
  late Duration _position;

  // Loop functionality
  double _loopStartValue = 0.0;
  double _loopEndValue = 0.0;
  bool _isDraggingLoop = false;
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;
  bool _hasLoop = false;

  @override
  void initState() {
    super.initState();
    _loopAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _loopAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loopAnimationController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isLoopEnabled) {
      _loopAnimationController.repeat(reverse: true);
    }
    
    // Initialize loop values if provided
    if (widget.loopStart != null && widget.loopEnd != null) {
      _hasLoop = true;
    }
  }

  @override
  void dispose() {
    try {
      _controller.removeListener(positionListener);
    } catch (e) {
      // Controller may already be disposed
    }
    _loopAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LoopProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoopEnabled != oldWidget.isLoopEnabled) {
      if (widget.isLoopEnabled) {
        _loopAnimationController.repeat(reverse: true);
      } else {
        _loopAnimationController.stop();
      }
    }
    
    // Update loop values ONLY if we're not currently dragging
    if (widget.loopStart != null && widget.loopEnd != null && mounted && !_isDraggingLoop) {
      try {
        final totalDuration = _controller.metadata.duration.inMilliseconds;
        if (totalDuration > 0) {
          _loopStartValue = widget.loopStart!.inMilliseconds / totalDuration;
          _loopEndValue = widget.loopEnd!.inMilliseconds / totalDuration;
          _hasLoop = true;
        }
      } catch (e) {
        // Handle controller disposal
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = YoutubePlayerController.of(context);
    if (controller == null) {
      assert(
        widget.controller != null,
        '\n\nNo controller could be found in the provided context.\n\n'
        'Try passing the controller explicitly.',
      );
      _controller = widget.controller!;
    } else {
      _controller = controller;
    }
    
    try {
      _controller.addListener(positionListener);
      positionListener();
    } catch (e) {
      // Handle case where controller is already disposed
      debugPrint('Error adding listener: $e');
    }
  }

  void positionListener() {
    // Check if controller is still valid
    if (!mounted || _controller.value.errorCode != 0) {
      return;
    }
    
    try {
      var totalDuration = _controller.metadata.duration.inMilliseconds;
      if (!totalDuration.isNaN && totalDuration != 0) {
        setState(() {
          _playedValue = _controller.value.position.inMilliseconds / totalDuration;
          _bufferedValue = _controller.value.buffered;
        });
        
        // Update loop values if they exist
        if (widget.loopStart != null && widget.loopEnd != null) {
          _loopStartValue = widget.loopStart!.inMilliseconds / totalDuration;
          _loopEndValue = widget.loopEnd!.inMilliseconds / totalDuration;
          _hasLoop = true;
        }
      }
    } catch (e) {
      // Silently handle disposal errors - this is common during disposal
      // Don't spam console, just return
      return;
    }
  }

  void _setValue() {
    _playedValue = _touchPoint.dx / context.size!.width;
  }

  void _checkTouchPoint() {
    if (_touchPoint.dx <= 0) {
      _touchPoint = Offset(0, _touchPoint.dy);
    }
    if (_touchPoint.dx >= context.size!.width) {
      _touchPoint = Offset(context.size!.width, _touchPoint.dy);
    }
  }

  void _seekToRelativePosition(Offset globalPosition) {
    // Check if controller is still valid and ready
    if (!mounted || _controller.value.errorCode != 0 || !_controller.value.isReady) {
      return;
    }
    
    try {
      final box = context.findRenderObject() as RenderBox;
      _touchPoint = box.globalToLocal(globalPosition);
      _checkTouchPoint();
      final relative = _touchPoint.dx / box.size.width;
      _position = _controller.metadata.duration * relative;
      
      if (!_isDraggingLoop) {
        _controller.seekTo(_position, allowSeekAhead: false);
      }
    } catch (e) {
      // Silently handle disposal errors
      debugPrint('Error seeking to position: $e');
    }
  }


  void _scrubAudioToLoopPosition(double value) {
    // Check if controller is still valid and ready
    if (!mounted || _controller.value.errorCode != 0 || !_controller.value.isReady) {
      return;
    }
    
    try {
      final totalDuration = _controller.metadata.duration;
      if (totalDuration.inMilliseconds <= 0) {
        return;
      }
      
      final position = Duration(
        milliseconds: (value * totalDuration.inMilliseconds).round(),
      );
      
      // Pause playback during drag for real-time scrubbing
      _controller.pause();
      
      // Seek to the dragged position for real-time feedback
      _controller.seekTo(position, allowSeekAhead: true);
      
      // Update the local position value so the UI shows correct position
      setState(() {
        _playedValue = value;
      });
      
    } catch (e) {
      debugPrint('Error scrubbing audio: $e');
    }
  }


  void _updateLoopCallback() {
    if (widget.onLoopUpdate != null && mounted && _controller.value.isReady) {
      try {
        final totalDuration = _controller.metadata.duration;
        if (totalDuration.inMilliseconds <= 0) return;
        
        final startDuration = Duration(
          milliseconds: (_loopStartValue * totalDuration.inMilliseconds).round(),
        );
        final endDuration = Duration(
          milliseconds: (_loopEndValue * totalDuration.inMilliseconds).round(),
        );
        debugPrint('CALLBACK: Updating parent with start=${startDuration.inSeconds}s, end=${endDuration.inSeconds}s');
        widget.onLoopUpdate!(startDuration, endDuration);
      } catch (e) {
        // Silently handle disposal errors
        debugPrint('Error updating loop callback: $e');
      }
    }
  }

  void _clearLoop() {
    setState(() {
      _hasLoop = false;
      _loopStartValue = 0.0;
      _loopEndValue = 0.0;
    });
  }

  void _playFromLoopStart() {
    if (_hasLoop && widget.onLoopPlay != null) {
      widget.onLoopPlay!();
    }
  }

  void _toggleAutoLoop() {
    if (widget.onLoopToggle != null) {
      widget.onLoopToggle!(!widget.isLoopEnabled);
    }
  }

  Widget _buildEnhancedBar() {
    return SizedBox(
      height: widget.showControls ? 60 : 30,
      child: Column(
        children: [
          // Loop controls (only show if showControls is true)
          if (widget.showControls)
            SizedBox(
              height: 30,
              child: Row(
              children: [
                // Loop play button
                AnimatedBuilder(
                  animation: _loopAnimation,
                  builder: (context, child) {
                    return GestureDetector(
                      onTap: _playFromLoopStart,
                      child: Container(
                        width: 32,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _hasLoop
                              ? (widget.colors?.loopHandleColor ?? Colors.amber)
                                  .withOpacity(0.8 + _loopAnimation.value * 0.2)
                              : Colors.grey.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.loop,
                          size: 16,
                          color: _hasLoop ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                
                // Auto-loop toggle
                GestureDetector(
                  onTap: _toggleAutoLoop,
                  child: Container(
                    width: 32,
                    height: 24,
                    decoration: BoxDecoration(
                      color: widget.isLoopEnabled
                          ? Colors.green.withOpacity(0.8)
                          : Colors.grey.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.isLoopEnabled ? Icons.repeat : Icons.repeat_one,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Clear loop button
                if (_hasLoop)
                  GestureDetector(
                    onTap: _clearLoop,
                    child: Container(
                      width: 32,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.clear,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          if (widget.showControls) const SizedBox(height: 4),
          
          // Enhanced progress bar
          Expanded(
            child: GestureDetector(
              onHorizontalDragDown: (details) {
                final box = context.findRenderObject() as RenderBox;
                final localPosition = box.globalToLocal(details.globalPosition);
                final touchX = localPosition.dx;
                final totalWidth = box.size.width;
                
                debugPrint('TOUCH: x=$touchX, width=$totalWidth');
                debugPrint('LOOP: start=$_loopStartValue, end=$_loopEndValue');
                
                // Calculate actual handle positions (EXACT same logic as painter)
                if (_hasLoop && totalWidth > 0) {
                  const handleRadius = 8.0;
                  // This should match the painter exactly
                  final barWidth = totalWidth - (handleRadius * 2);
                  final startHandleX = barWidth * _loopStartValue + handleRadius;
                  final endHandleX = barWidth * _loopEndValue + handleRadius;
                  
                  debugPrint('HANDLES: start=$startHandleX, end=$endHandleX');
                  
                  const touchTolerance = 8.0; // Much smaller - just 8px on each side
                  
                  // Check start handle
                  if (touchX >= (startHandleX - touchTolerance) && 
                      touchX <= (startHandleX + touchTolerance)) {
                    debugPrint('START HANDLE HIT!');
                    setState(() {
                      _isDraggingLoop = true;
                      _isDraggingStart = true;
                      _isDraggingEnd = false;
                    });
                    _scrubAudioToLoopPosition(_loopStartValue);
                    return;
                  }
                  
                  // Check end handle
                  if (touchX >= (endHandleX - touchTolerance) && 
                      touchX <= (endHandleX + touchTolerance)) {
                    debugPrint('END HANDLE HIT!');
                    setState(() {
                      _isDraggingLoop = true;
                      _isDraggingStart = false;
                      _isDraggingEnd = true;
                    });
                    _scrubAudioToLoopPosition(_loopEndValue);
                    return;
                  }
                }
                
                debugPrint('NORMAL TIMELINE HIT');
                // Normal timeline seeking
                try {
                  if (_controller.value.errorCode == 0) {
                    _controller.updateValue(
                      _controller.value.copyWith(isControlsVisible: true, isDragging: true),
                    );
                  }
                } catch (e) {
                  // Handle controller disposal during interaction
                }
                _seekToRelativePosition(details.globalPosition);
                setState(() {
                  _setValue();
                  _touchDown = true;
                });
              },
              onHorizontalDragUpdate: (details) {
                if (_isDraggingLoop) {
                  debugPrint('DRAG UPDATE: Loop dragging');
                  final box = context.findRenderObject() as RenderBox;
                  final localPosition = box.globalToLocal(details.globalPosition);
                  final touchX = localPosition.dx;
                  final totalWidth = box.size.width;
                  
                  if (totalWidth > 0) {
                    const handleRadius = 8.0;
                    final barWidth = totalWidth - (handleRadius * 2);
                    // Convert touchX back to relative position (reverse of painter logic)
                    final relative = ((touchX - handleRadius) / barWidth).clamp(0.0, 1.0);
                    
                    debugPrint('DRAG: touchX=$touchX, barWidth=$barWidth, relative=$relative');
                    
                    setState(() {
                      if (_isDraggingStart) {
                        _loopStartValue = relative.clamp(0.0, _loopEndValue - 0.02);
                        debugPrint('Updated start to: $_loopStartValue');
                      } else if (_isDraggingEnd) {
                        _loopEndValue = relative.clamp(_loopStartValue + 0.02, 1.0);
                        debugPrint('Updated end to: $_loopEndValue');
                      }
                      _hasLoop = true; // Ensure loop is marked as active
                    });
                    
                    // IMMEDIATELY update callback to propagate changes
                    _updateLoopCallback();
                    
                    // Scrub audio 
                    final currentValue = _isDraggingStart ? _loopStartValue : _loopEndValue;
                    _scrubAudioToLoopPosition(currentValue);
                  }
                } else {
                  _seekToRelativePosition(details.globalPosition);
                  setState(_setValue);
                }
              },
              onHorizontalDragEnd: (details) {
                if (_isDraggingLoop) {
                  // Final seek and resume playback
                  final finalValue = _isDraggingStart ? _loopStartValue : _loopEndValue;
                  try {
                    if (mounted && _controller.value.errorCode == 0 && _controller.value.isReady) {
                      final totalDuration = _controller.metadata.duration;
                      if (totalDuration.inMilliseconds > 0) {
                        final position = Duration(
                          milliseconds: (finalValue * totalDuration.inMilliseconds).round(),
                        );
                        _controller.seekTo(position, allowSeekAhead: true);
                        
                        // Resume playback after a brief delay
                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (mounted && _controller.value.errorCode == 0 && _controller.value.isReady) {
                            _controller.play();
                          }
                        });
                      }
                    }
                  } catch (e) {
                    debugPrint('Error with final seek: $e');
                  }
                  
                  setState(() {
                    _isDraggingLoop = false;
                    _isDraggingStart = false;
                    _isDraggingEnd = false;
                    _hasLoop = true;
                  });
                  
                  // Update parent with final values
                  _updateLoopCallback();
                } else {
                  try {
                    if (mounted && _controller.value.errorCode == 0 && _controller.value.isReady) {
                      _controller.updateValue(
                        _controller.value.copyWith(isControlsVisible: false, isDragging: false),
                      );
                      _controller.seekTo(_position, allowSeekAhead: true);
                      _controller.play();
                    }
                  } catch (e) {
                    // Handle controller disposal during interaction
                  }
                  setState(() {
                    _touchDown = false;
                  });
                }
              },
              child: Container(
                color: Colors.transparent,
                constraints: const BoxConstraints.expand(height: 30.0),
                child: CustomPaint(
                  painter: _EnhancedProgressBarPainter(
                    progressWidth: 4.0,
                    handleRadius: 8.0,
                    playedValue: _playedValue,
                    bufferedValue: _bufferedValue,
                    loopStartValue: _loopStartValue,
                    loopEndValue: _loopEndValue,
                    hasLoop: _hasLoop,
                    isLoopEnabled: widget.isLoopEnabled,
                    isDraggingStart: _isDraggingStart,
                    isDraggingEnd: _isDraggingEnd,
                    colors: widget.colors,
                    touchDown: _touchDown,
                    themeData: Theme.of(context),
                    loopAnimation: _loopAnimation.value,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.isExpanded 
        ? Expanded(child: _buildEnhancedBar()) 
        : _buildEnhancedBar();
  }
}

class _EnhancedProgressBarPainter extends CustomPainter {
  final double progressWidth;
  final double handleRadius;
  final double playedValue;
  final double bufferedValue;
  final double loopStartValue;
  final double loopEndValue;
  final bool hasLoop;
  final bool isLoopEnabled;
  final bool isDraggingStart;
  final bool isDraggingEnd;
  final LoopProgressBarColors? colors;
  final bool touchDown;
  final ThemeData themeData;
  final double loopAnimation;

  _EnhancedProgressBarPainter({
    required this.progressWidth,
    required this.handleRadius,
    required this.playedValue,
    required this.bufferedValue,
    required this.loopStartValue,
    required this.loopEndValue,
    required this.hasLoop,
    required this.isLoopEnabled,
    required this.isDraggingStart,
    required this.isDraggingEnd,
    this.colors,
    required this.touchDown,
    required this.themeData,
    required this.loopAnimation,
  });

  @override
  bool shouldRepaint(_EnhancedProgressBarPainter old) {
    return playedValue != old.playedValue ||
        bufferedValue != old.bufferedValue ||
        touchDown != old.touchDown ||
        loopStartValue != old.loopStartValue ||
        loopEndValue != old.loopEndValue ||
        hasLoop != old.hasLoop ||
        isLoopEnabled != old.isLoopEnabled ||
        isDraggingStart != old.isDraggingStart ||
        isDraggingEnd != old.isDraggingEnd ||
        loopAnimation != old.loopAnimation;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;

    final centerY = size.height / 2.0;
    final primaryColor = themeData.colorScheme.primary;

    // Background bar
    paint
      ..color = colors?.backgroundColor ?? Colors.grey.withOpacity(0.3)
      ..strokeWidth = progressWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(handleRadius, centerY),
      Offset(size.width - handleRadius, centerY),
      paint,
    );

    // Buffered section
    if (bufferedValue > 0) {
      paint.color = colors?.bufferedColor ?? Colors.white.withOpacity(0.4);
      canvas.drawLine(
        Offset(handleRadius, centerY),
        Offset((size.width - handleRadius * 2) * bufferedValue + handleRadius, centerY),
        paint,
      );
    }

    // Loop region (if has loop)
    if (hasLoop) {
      final loopStartX = (size.width - handleRadius * 2) * loopStartValue + handleRadius;
      final loopEndX = (size.width - handleRadius * 2) * loopEndValue + handleRadius;

      // Loop region background
      final loopOpacity = 0.2 + (isLoopEnabled ? loopAnimation * 0.1 : 0.0);
      paint
        ..color = (colors?.loopRegionColor ?? Colors.amber).withOpacity(loopOpacity)
        ..strokeWidth = progressWidth + 2;
      canvas.drawLine(
        Offset(loopStartX, centerY),
        Offset(loopEndX, centerY),
        paint,
      );

      // Loop handles - much more prominent
      final handlePaint = Paint()..isAntiAlias = true;
      
      // Start handle - make it very visible
      final startHandleWidth = isDraggingStart ? 8.0 : 5.0;
      final startHandleHeight = isDraggingStart ? 20.0 : 16.0;
      handlePaint
        ..color = colors?.loopHandleColor ?? Colors.amber
        ..strokeWidth = startHandleWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(loopStartX, centerY - startHandleHeight),
        Offset(loopStartX, centerY + startHandleHeight),
        handlePaint,
      );

      // Add a wider touch zone indicator (subtle background)
      if (isDraggingStart) {
        final touchZonePaint = Paint()
          ..color = Colors.amber.withOpacity(0.2)
          ..strokeWidth = 20.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(loopStartX, centerY - startHandleHeight),
          Offset(loopStartX, centerY + startHandleHeight),
          touchZonePaint,
        );
      }

      // End handle - make it very visible
      final endHandleWidth = isDraggingEnd ? 8.0 : 5.0;
      final endHandleHeight = isDraggingEnd ? 20.0 : 16.0;
      handlePaint.strokeWidth = endHandleWidth;
      canvas.drawLine(
        Offset(loopEndX, centerY - endHandleHeight),
        Offset(loopEndX, centerY + endHandleHeight),
        handlePaint,
      );

      // Add a wider touch zone indicator (subtle background)
      if (isDraggingEnd) {
        final touchZonePaint = Paint()
          ..color = Colors.amber.withOpacity(0.2)
          ..strokeWidth = 20.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(loopEndX, centerY - endHandleHeight),
          Offset(loopEndX, centerY + endHandleHeight),
          touchZonePaint,
        );
      }
    }

    // Played section (on top)
    paint
      ..color = colors?.playedColor ?? primaryColor
      ..strokeWidth = progressWidth;
    canvas.drawLine(
      Offset(handleRadius, centerY),
      Offset((size.width - handleRadius * 2) * playedValue + handleRadius, centerY),
      paint,
    );

    // Main playback handle
    final playbackHandleX = (size.width - handleRadius * 2) * playedValue + handleRadius;
    final handlePaint = Paint()..isAntiAlias = true;

    // Handle shadow when touched
    if (touchDown) {
      handlePaint.color = (colors?.handleColor ?? primaryColor).withOpacity(0.3);
      canvas.drawCircle(Offset(playbackHandleX, centerY), handleRadius * 2, handlePaint);
    }

    // Main handle
    handlePaint.color = colors?.handleColor ?? primaryColor;
    canvas.drawCircle(Offset(playbackHandleX, centerY), handleRadius, handlePaint);

    // Handle center dot
    handlePaint.color = Colors.white;
    canvas.drawCircle(Offset(playbackHandleX, centerY), handleRadius * 0.4, handlePaint);
  }
}