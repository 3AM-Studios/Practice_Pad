import 'package:flutter/material.dart';

class BeatTimeline extends StatelessWidget {
  final int beatsPerMeasure;
  final double currentProgress; // This can be from 0.0 up to beatsPerMeasure
  final List<double> userInputMarkers;
  final Color textColor;

  const BeatTimeline({
    super.key,
    required this.beatsPerMeasure,
    required this.currentProgress,
    this.userInputMarkers = const [],
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // Clamp the progress to ensure it's within the valid range.
    final clampedProgress =
        currentProgress.clamp(0.0, beatsPerMeasure.toDouble());

    return LayoutBuilder(
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: clampedProgress),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          builder: (context, progress, child) {
            return SizedBox(
              height: 50,
              width: constraints.maxWidth,
              child: CustomPaint(
                painter: _BeatTimelinePainter(
                  beatsPerMeasure: beatsPerMeasure,
                  progress: progress,
                  userInputMarkers: userInputMarkers,
                  textColor: textColor,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BeatTimelinePainter extends CustomPainter {
  final int beatsPerMeasure;
  final double progress;
  final List<double> userInputMarkers;
  final Color textColor;

  _BeatTimelinePainter({
    required this.beatsPerMeasure,
    required this.progress,
    required this.userInputMarkers,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2.0;

    // There are (beatsPerMeasure - 1) segments between the main notches.
    // Handle the edge case of 1 beat per measure to avoid division by zero.
    final beatWidth =
        beatsPerMeasure > 1 ? size.width / (beatsPerMeasure - 1) : size.width;

    // Draw main timeline bar
    canvas.drawLine(const Offset(0, 10), Offset(size.width, 10), paint);

    // Draw beat notches and their corresponding numbers
    for (int i = 0; i < beatsPerMeasure; i++) {
      final x = i * beatWidth;
      // Draw the notch
      canvas.drawLine(Offset(x, 5), Offset(x, 15), paint);

      // Draw the number underneath the notch
      final beatNumber = i + 1;
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$beatNumber',
          style: TextStyle(color: textColor, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - (textPainter.width / 2), 25));
    }

    // Draw user input markers
    final userMarkerPaint = Paint()..color = Colors.green;
    for (final beat in userInputMarkers) {
      if (beat >= 1 && beat <= beatsPerMeasure) {
        // The beat is 1-indexed, so subtract 1 for a 0-indexed position
        final x = (beat - 1) * beatWidth;
        canvas.drawCircle(Offset(x, 10), 5, userMarkerPaint);
      }
    }

    // Draw progress marker only if playback has started
    if (progress >= 1 && progress <= beatsPerMeasure) {
      // The progress is 1-indexed, so subtract 1 for a 0-indexed position
      final progressX = (progress - 1) * beatWidth;
      final progressPaint = Paint()..color = Colors.blue;
      canvas.drawCircle(Offset(progressX, 10), 6, progressPaint);
    }
  }

  @override
  bool shouldRepaint(_BeatTimelinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.userInputMarkers != userInputMarkers ||
        oldDelegate.textColor != textColor;
  }
}
