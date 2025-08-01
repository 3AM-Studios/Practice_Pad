import 'package:flutter/material.dart';
import 'package:simple_sheet_music/simple_sheet_music.dart';
import 'chord_symbol/chord_symbol.dart';

class LeadMeasure {
  final List<Note> notes; // Changed from musicalSymbols for clarity
  final List<ChordSymbol> chordSymbols;
  final bool isNewLine;

  LeadMeasure(
    this.notes,
    this.chordSymbols, {
    this.isNewLine = false,
  }) : assert(notes.isNotEmpty);

  // Create a standard Measure from this LeadMeasure
  Measure toMeasure() {
    // Since Measure expects MusicalSymbols, we need to cast
    return Measure(notes, isNewLine: isNewLine);
  }

  // Find chord symbols that occur at a specific position
  List<ChordSymbol> chordsAtPosition(int position) {
    return chordSymbols.where((chord) => chord.position == position).toList();
  }

  // Factory constructor to create from an existing Measure plus chord symbols
  factory LeadMeasure.fromMeasure(Measure measure, List<ChordSymbol> chords) {
    // Extract only the notes from the measure
    final notesList = measure.musicalSymbols.whereType<Note>().toList();

    return LeadMeasure(
      notesList,
      chords,
      isNewLine: measure.isNewLine,
    );
  }
}

// Custom renderer for LeadMeasure to display chord symbols
class LeadMeasureRenderer extends StatelessWidget {
  final LeadMeasure measure;
  final double width;

  const LeadMeasureRenderer({
    super.key,
    required this.measure,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Render chord symbols
        for (var chord in measure.chordSymbols)
          Positioned(
            left: (chord.position * width) / 4, // Simple position calculation
            top: 10,
            child: Text(
              chord.displayText,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
      ],
    );
  }
}
