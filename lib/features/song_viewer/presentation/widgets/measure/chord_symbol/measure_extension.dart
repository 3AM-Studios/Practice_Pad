import 'package:flutter/material.dart';
import 'package:simple_sheet_music/simple_sheet_music.dart';
import 'chord_symbol.dart';

// Extension to add chord symbols to Measure objects
extension MeasureExtension on Measure {
  // Store chord symbols in this static map, keyed by the measure's identity
  static final Map<Measure, List<ChordSymbol>> _chordSymbols = {};

  // Add chord symbols to a measure
  void setChordSymbols(List<ChordSymbol> symbols) {
    _chordSymbols[this] = symbols;
  }

  // Get chord symbols for a measure
  List<ChordSymbol> get chordSymbols => _chordSymbols[this] ?? [];

  // Check if measure has chord symbols
  bool get hasChordSymbols =>
      _chordSymbols.containsKey(this) && _chordSymbols[this]!.isNotEmpty;

  // Get chord symbols at a specific position
  List<ChordSymbol> chordsAtPosition(int position) {
    return chordSymbols.where((chord) => chord.position == position).toList();
  }
}

// Custom painter to overlay chord symbols onto a SheetMusic widget
class ChordSymbolPainter extends CustomPainter {
  final List<Measure> measures;
  final double staffY = 50; // Default Y position for staff

  ChordSymbolPainter(this.measures);

  @override
  void paint(Canvas canvas, Size size) {
    double measureWidth = size.width / measures.length;

    for (int i = 0; i < measures.length; i++) {
      final measure = measures[i];
      if (!measure.hasChordSymbols) continue;

      double measureX = i * measureWidth;

      for (final chord in measure.chordSymbols) {
        final xPos = measureX + (chord.position * measureWidth / 4);
        final yPos = staffY - 30; // Position above staff

        final textSpan = TextSpan(
          text: chord.displayText,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(canvas, Offset(xPos, yPos));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Widget that combines SheetMusic with chord symbols
class SheetMusicWithChords extends StatefulWidget {
  final List<Measure> measures;
  final double width;
  final double height;

  const SheetMusicWithChords({
    Key? key,
    required this.measures,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  State<SheetMusicWithChords> createState() => _SheetMusicWithChordsState();
}

class _SheetMusicWithChordsState extends State<SheetMusicWithChords> {

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [

        // Overlay for chord symbols
          CustomPaint(
            size: Size(widget.width, widget.height),
            painter: ChordSymbolPainter(widget.measures),
          ),
      ],
    );
  }
}
