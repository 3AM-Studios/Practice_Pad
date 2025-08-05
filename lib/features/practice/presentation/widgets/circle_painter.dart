import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:practice_pad/features/practice/models/circle_of_fifths_keys.dart';

class CirclePainter extends CustomPainter {
  final int currentKeyIndex; // Index of the key at the 12 o'clock position
  final int? playbackKeyIndex; // Index of the key currently playing (optional)
  final Function(String keyName) onKeyTapped;

  CirclePainter({
    required this.currentKeyIndex,
    this.playbackKeyIndex,
    required this.onKeyTapped,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius =
        math.min(size.width, size.height) / 2 - 20; // Outer radius
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Paint for the circle
    final Paint circlePaint = Paint()
      ..color = CupertinoColors.systemGrey4
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, circlePaint);

    // Paint for the key names
    const textStyle = TextStyle(
      color: CupertinoColors.label,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );

    final highlightedTextStyle = textStyle.copyWith(
      color: CupertinoColors.systemRed,
      fontWeight: FontWeight.bold,
      fontSize: 18,
    );

    final playingTextStyle = textStyle.copyWith(
      color: CupertinoColors.activeGreen,
      fontWeight: FontWeight.bold,
      fontSize: 18,
    );

    final double angleStep = 2 * math.pi / circleOfFifthsKeyNames.length;

    // Store tap regions for keys
    final List<Path> keyTapRegions = [];
    final List<String> keyNamesForTap = [];

    for (int i = 0; i < circleOfFifthsKeyNames.length; i++) {
      // Calculate the position of the key name on the circle
      // The key at currentKeyIndex should be at the top ( -math.pi / 2)
      final double angle = (i - currentKeyIndex) * angleStep - (math.pi / 2);

      final String keyName = circleOfFifthsKeyNames[i];
      final TextSpan span = TextSpan(
        text: getDisplayKeyName(keyName),
        style: i == playbackKeyIndex
            ? playingTextStyle
            : (i == currentKeyIndex ? highlightedTextStyle : textStyle),
      );
      final TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      final double x =
          center.dx + (radius - 10) * math.cos(angle) - tp.width / 2;
      final double y =
          center.dy + (radius - 10) * math.sin(angle) - tp.height / 2;

      // For tap detection, create a region around the text
      final Rect tapRect = Rect.fromCenter(
        center: Offset(x + tp.width / 2, y + tp.height / 2),
        width: tp.width + 20, // Add some padding for easier tapping
        height: tp.height + 20,
      );
      final Path path = Path()..addRect(tapRect);
      keyTapRegions.add(path);
      keyNamesForTap.add(keyName);

      tp.paint(canvas, Offset(x, y));
    }

    // This painter doesn't handle tap detection directly.
    // It's up to the widget using this painter to handle gestures
    // and use the onKeyTapped callback. For simplicity in this example,
    // we're preparing the regions, but actual hit testing would be in the widget.
  }

  @override
  bool shouldRepaint(covariant CirclePainter oldDelegate) {
    return oldDelegate.currentKeyIndex != currentKeyIndex ||
        oldDelegate.playbackKeyIndex != playbackKeyIndex;
  }

  // Optional: Add hitTest method if you want CustomPainter to participate in hit testing
  // This is more complex and might be better handled by GestureDetector in the parent widget.
}
