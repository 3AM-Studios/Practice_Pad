import 'package:flutter/material.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/sheet_music_layout.dart';

/// This renderer is now ONLY responsible for drawing the static sheet music.
/// It knows nothing about dragging, which makes it very efficient.
class SheetMusicRenderer extends CustomPainter {
  final SheetMusicLayout sheetMusicLayout;
  final MusicalSymbol? selectedSymbol;

  const SheetMusicRenderer({
    required this.sheetMusicLayout,
    this.selectedSymbol,
  }): super(repaint: sheetMusicLayout);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Scale the canvas to the music's coordinate space.
    canvas.scale(sheetMusicLayout.canvasScale);

    // 2. Tell the layout to render everything.
    // The layout's internal measure renderers will handle highlighting
    // the 'selectedSymbol' if it's passed down.
    sheetMusicLayout.render(canvas, size, selectedSymbol: selectedSymbol);
  }

  @override
  bool shouldRepaint(SheetMusicRenderer oldDelegate) {
    // This is a huge performance win.
    // This painter will now ONLY repaint if the underlying layout changes
    // (e.g., notes are added/deleted) or if the selected symbol changes.
    // It will NOT repaint during a drag.
    return oldDelegate.sheetMusicLayout != sheetMusicLayout ||
        oldDelegate.selectedSymbol != selectedSymbol;
  }
}