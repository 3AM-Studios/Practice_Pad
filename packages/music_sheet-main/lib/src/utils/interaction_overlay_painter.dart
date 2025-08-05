
// Place this new painter class in your widget file.
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:music_sheet/src/simple_sheet_music.dart';



class InteractionOverlayPainter extends CustomPainter {
  final InteractionState interactionState;
  final double canvasScale;

  InteractionOverlayPainter({
    required this.interactionState,
    required this.canvasScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // --- 1. Draw the staff line highlight ---
    final highlightRect = interactionState.pitchHighlightRect;
    if (highlightRect != null) {
      
      // THE FIX: We must scale the Rect down from the large "Canvas Space"
      // to the smaller "Screen Space" before drawing. We do this by
      // multiplying each coordinate by the canvasScale.
      final scaledRect = Rect.fromLTRB(
        highlightRect.left * canvasScale,
        highlightRect.top * canvasScale,
        highlightRect.right * canvasScale,
        highlightRect.bottom * canvasScale,
      );

      final paint = Paint()
        ..color = Colors.red.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawRect(scaledRect, paint);
    }

    // --- 2. Draw the symbol being dragged ---
    final position = interactionState.dragPosition;
    if (position == null) return;

    // Here, we'll draw a placeholder circle.
    // The 'position' comes from the GestureDetector and is already in "Screen Space",
    // so we DO NOT need to scale it at all for drawing on this painter's canvas.
    final placeholderPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(position, 15.0, placeholderPaint);
  }

  @override
  bool shouldRepaint(covariant InteractionOverlayPainter oldDelegate) {
    // This is correct, only repaint when the state changes.
    return oldDelegate.interactionState != interactionState;
  }
}