import 'package:flutter/material.dart';
import 'package:music_sheet/simple_sheet_music.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart'
    as chord_symbol;

/// A widget that integrates the music_sheet package with your existing chord system
class IntegratedMusicSheetWidget extends StatefulWidget {
  final List<chord_symbol.ChordSymbol> chordSymbols;
  final double width;
  final double height;
  final Function(dynamic symbol, Offset position)? onTap;

  const IntegratedMusicSheetWidget({
    super.key,
    required this.chordSymbols,
    required this.width,
    required this.height,
    this.onTap,
  });

  @override
  State<IntegratedMusicSheetWidget> createState() =>
      _IntegratedMusicSheetWidgetState();
}

class _IntegratedMusicSheetWidgetState
    extends State<IntegratedMusicSheetWidget> {
  /// Convert your chord symbols to visual sheet music measures
  List<Measure> _convertChordSymbolsToMeasures() {
    if (widget.chordSymbols.isEmpty) {
      // Return a default empty measure with basic clef and time signature
      return [
        Measure([
          Clef.treble(),
          TimeSignature.fourFour(),
          KeySignature.cMajor(),
          Rest(RestType.whole),
        ])
      ];
    }

    List<Measure> measures = [];
    
    // Add first measure with clef, time signature, and key signature
    List<Object> firstMeasureContents = [
      Clef.treble(),
      TimeSignature.fourFour(),
      KeySignature.cMajor(),
    ];

    // Convert first few chord symbols to notes (simplified approach)
    for (int i = 0; i < widget.chordSymbols.length && i < 4; i++) {
      final chord = widget.chordSymbols[i];
      
      // Create a simple representation - you can enhance this based on your chord symbol structure
      // For now, we'll create quarter notes based on chord root
      Note note = _createNoteFromChordSymbol(chord);
      firstMeasureContents.add(note);
    }

    // Fill remaining beats with rests if needed
    while (firstMeasureContents.where((item) => item is Note || item is Rest).length < 4) {
      firstMeasureContents.add(Rest(RestType.quarter));
    }

    measures.add(Measure(firstMeasureContents));

    // Add additional measures if there are more chord symbols
    if (widget.chordSymbols.length > 4) {
      List<dynamic> secondMeasureContents = [];
      
      for (int i = 4; i < widget.chordSymbols.length && i < 8; i++) {
        final chord = widget.chordSymbols[i];
        Note note = _createNoteFromChordSymbol(chord);
        secondMeasureContents.add(note);
      }

      // Fill remaining beats with rests if needed
      while (secondMeasureContents.length < 4) {
        secondMeasureContents.add(Rest(RestType.quarter));
      }

      measures.add(Measure(secondMeasureContents));
    }

    return measures;
  }

  /// Create a note from a chord symbol (simplified mapping)
  Note _createNoteFromChordSymbol(chord_symbol.ChordSymbol chord) {
    // This is a simplified mapping - you can enhance it based on your chord symbol structure
    // For now, we'll map common chord roots to pitches
    
    // Try to get the root from the chord symbol
    Pitch pitch = Pitch.c4; // Default
    
    // You can access chord properties here and map them to pitches
    // This is just a basic example - enhance based on your chord symbol implementation
    
    return Note(pitch, noteDuration: NoteDuration.quarter);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: SimpleSheetMusic(
        width: widget.width,
        height: widget.height,
        measures: _convertChordSymbolsToMeasures(),
        onTap: widget.onTap,
        debug: false,
      ),
    );
  }
}

/// Example usage widget showing how to integrate with your existing song viewer
class MusicSheetIntegrationExample extends StatefulWidget {
  const MusicSheetIntegrationExample({super.key});

  @override
  State<MusicSheetIntegrationExample> createState() =>
      _MusicSheetIntegrationExampleState();
}

class _MusicSheetIntegrationExampleState
    extends State<MusicSheetIntegrationExample> {
  // Example chord symbols - replace with your actual chord symbols
  List<chord_symbol.ChordSymbol> _exampleChordSymbols = [];

  @override
  void initState() {
    super.initState();
    _createExampleChordSymbols();
  }

  void _createExampleChordSymbols() {
    // Create some example chord symbols - adapt this to your actual chord symbol creation
    // This is just a placeholder since I don't have access to your chord symbol constructor
    _exampleChordSymbols = [
      // You'll need to replace these with actual chord symbol instances
      // based on your chord symbol implementation
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Sheet Integration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Integrated Music Sheet with Chord Symbols',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Show the integrated music sheet widget
            IntegratedMusicSheetWidget(
              chordSymbols: _exampleChordSymbols,
              width: MediaQuery.of(context).size.width - 32,
              height: 200,
              onTap: (symbol, position) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Tapped music symbol: ${symbol.runtimeType} at $position',
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Chord Symbols:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Display chord symbols info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _exampleChordSymbols.isEmpty 
                  ? 'No chord symbols loaded. Add your chord symbols to see them converted to sheet music.'
                  : 'Loaded ${_exampleChordSymbols.length} chord symbols',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            
            const SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: () {
                // Navigate to the standalone demo
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MusicSheetExample(),
                  ),
                );
              },
              child: const Text('View Standalone Music Sheet Demo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone music sheet example (same as in music_sheet_demo.dart)
class MusicSheetExample extends StatelessWidget {
  const MusicSheetExample({super.key});

  @override
  Widget build(BuildContext context) {
    final sheetMusicSize = MediaQuery.of(context).size;
    final width = sheetMusicSize.width * 0.9;
    final height = sheetMusicSize.height * 0.6;

    Measure measure1 = Measure([
      Clef.treble(),
      TimeSignature.fourFour(),
      KeySignature.cMajor(),
      Note(Pitch.c4, noteDuration: NoteDuration.quarter),
      Note(Pitch.d4, noteDuration: NoteDuration.quarter),
      Note(Pitch.e4, noteDuration: NoteDuration.quarter),
      Note(Pitch.f4, noteDuration: NoteDuration.quarter),
    ]);

    Measure measure2 = Measure([
      ChordNote([
        const ChordNotePart(Pitch.c4),
        const ChordNotePart(Pitch.e4),
        const ChordNotePart(Pitch.g4),
      ], noteDuration: NoteDuration.half),
      Rest(RestType.half),
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Music Sheet Example')),
      body: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SimpleSheetMusic(
            height: height,
            width: width,
            debug: true,
            onTap: (symbol, position) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Tapped: ${symbol is Clef ? 'Clef (${symbol.clefType})' : symbol.runtimeType}',
                  ),
                ),
              );
            },
            measures: [measure1, measure2],
          ),
        ),
      ),
    );
  }
}
