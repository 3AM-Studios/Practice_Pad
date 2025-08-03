import 'package:flutter/material.dart';
import 'package:music_sheet/src/sheet_music_layout.dart';

/// A custom painter that renders the sheet music based on the provided layout.
class SheetMusicRenderer extends CustomPainter {
  const SheetMusicRenderer(this.sheetMusicLayout);

  final SheetMusicLayout sheetMusicLayout;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(sheetMusicLayout.canvasScale);
    sheetMusicLayout.render(canvas, size);
  }

  @override
  bool shouldRepaint(SheetMusicRenderer oldDelegate) {
    // Only repaint if the layout has actually changed, not just on scroll
    return oldDelegate.sheetMusicLayout != sheetMusicLayout ||
           oldDelegate.sheetMusicLayout.metrics != sheetMusicLayout.metrics ||
           oldDelegate.sheetMusicLayout.canvasScale != sheetMusicLayout.canvasScale ||
           oldDelegate.sheetMusicLayout.lineColor != sheetMusicLayout.lineColor;
  }
}
