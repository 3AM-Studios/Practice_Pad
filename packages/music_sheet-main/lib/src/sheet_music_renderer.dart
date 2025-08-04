import 'package:flutter/material.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/music_objects/notes/single_note/note.dart';
import 'package:music_sheet/src/sheet_music_layout.dart';

class SheetMusicRenderer extends CustomPainter {
  final SheetMusicLayout sheetMusicLayout;
  final Note? draggedNote;
  final Offset? dragPosition;
  final Rect? pitchHighlightRect;
  final MusicalSymbol? selectedNote;

    const SheetMusicRenderer({
    required this.sheetMusicLayout,
    this.draggedNote,
    this.dragPosition,
    this.pitchHighlightRect,
    this.selectedNote,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(sheetMusicLayout.canvasScale);

    if (pitchHighlightRect != null) {
      final paint = Paint()..color = Colors.blue.withOpacity(0.3);
      canvas.drawRect(pitchHighlightRect!, paint);
    }

    // Tell the layout to draw the static score, but HIDE the original note
    // if we are dragging an existing one.
    sheetMusicLayout.render(canvas, size, symbolToExclude: draggedNote);

    // Now, draw the dragged note at the cursor's position
    if (draggedNote != null && dragPosition != null) {
      final unscaledDragPosition = dragPosition! / sheetMusicLayout.canvasScale;
      // This is simplified; use your glyph drawing logic here.
      final notePaint = Paint()..color = Colors.black.withOpacity(0.7);
      canvas.drawCircle(unscaledDragPosition, 10.0, notePaint);
    }
  }

  @override
  bool shouldRepaint(SheetMusicRenderer oldDelegate) {
    // Repaint if the static layout changes OR if the drag state changes.
        return oldDelegate.sheetMusicLayout != sheetMusicLayout ||
        oldDelegate.draggedNote != draggedNote ||
        oldDelegate.dragPosition != dragPosition ||
        oldDelegate.pitchHighlightRect != pitchHighlightRect ||
        oldDelegate.selectedNote != selectedNote;
  }
}