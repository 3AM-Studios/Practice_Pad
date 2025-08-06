import 'package:flutter/material.dart';
import 'package:music_sheet/index.dart';
import 'package:music_sheet/simple_sheet_music.dart';

void main() {
  runApp(const MusicSheetApp());
}

class MusicSheetApp extends StatelessWidget {
  const MusicSheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Sheet Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MusicSheetExample(),
    );
  }
}

class MusicSheetExample extends StatelessWidget {
  const MusicSheetExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music Sheet Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SimpleSheetMusicDemo()));
              },
              child: const Text('Basic Sheet Music Example'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MidiExampleDemo()));
              },
              child: const Text('MIDI Example'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdvancedExampleDemo()));
              },
              child: const Text('Advanced Example'),
            ),
          ],
        ),
      ),
    );
  }
}

class SimpleSheetMusicDemo extends StatefulWidget {
  const SimpleSheetMusicDemo({super.key});

  @override
  State<StatefulWidget> createState() => SimpleSheetMusicDemoState();
}

class SimpleSheetMusicDemoState extends State<SimpleSheetMusicDemo> {
  late List<Measure> _measures;

  @override
  void initState() {
    super.initState();
    _measures = [
      Measure([
        Clef.treble(),
        TimeSignature.twoFour(),
        KeySignature.dMajor(),
        ChordNote([
          const ChordNotePart(Pitch.b4),
          const ChordNotePart(Pitch.g5),
          const ChordNotePart(Pitch.a4),
        ]),
        Rest(RestType.quarter),
        Note(Pitch.a4, noteDuration: NoteDuration.quarter),
        Rest(RestType.sixteenth),
      ]),
      Measure([
        ChordNote([
          const ChordNotePart(Pitch.c4),
          const ChordNotePart(Pitch.c5),
        ], noteDuration: NoteDuration.sixteenth),
        Note(Pitch.a4,
            noteDuration: NoteDuration.sixteenth, accidental: Accidental.flat)
      ]),
      Measure(
        [
          Clef.bass(),
          TimeSignature.fourFour(),
          KeySignature.cMinor(),
          ChordNote(
            [
              const ChordNotePart(Pitch.c2),
              const ChordNotePart(Pitch.c3),
            ],
          ),
          Rest(RestType.quarter),
          Note(Pitch.a3,
              noteDuration: NoteDuration.whole, accidental: Accidental.flat),
        ],
        isNewLine: true,
      ),
    ];
  }

  void _onSymbolAdd(MusicalSymbol symbol, int measureIndex, int positionIndex) {
    setState(() {
      final updatedMeasures = List<Measure>.from(_measures);
      final measureToUpdate = updatedMeasures[measureIndex];
      final updatedSymbols = List<MusicalSymbol>.from(measureToUpdate.musicalSymbols);
      updatedSymbols.insert(positionIndex, symbol);
      updatedMeasures[measureIndex] = Measure(updatedSymbols, isNewLine: measureToUpdate.isNewLine);
      _measures = updatedMeasures;
    });
  }

  void _onSymbolUpdate(MusicalSymbol symbol, int measureIndex, int positionIndex) {
    setState(() {
      final updatedMeasures = List<Measure>.from(_measures);
      final measureToUpdate = updatedMeasures[measureIndex];
      final updatedSymbols = List<MusicalSymbol>.from(measureToUpdate.musicalSymbols);
      updatedSymbols[positionIndex] = symbol;
      updatedMeasures[measureIndex] = Measure(updatedSymbols, isNewLine: measureToUpdate.isNewLine);
      _measures = updatedMeasures;
    });
  }

  void _onSymbolDelete(int measureIndex, int positionIndex) {
    setState(() {
      final updatedMeasures = List<Measure>.from(_measures);
      final measureToUpdate = updatedMeasures[measureIndex];
      final updatedSymbols = List<MusicalSymbol>.from(measureToUpdate.musicalSymbols);
      updatedSymbols.removeAt(positionIndex);
      updatedMeasures[measureIndex] = Measure(updatedSymbols, isNewLine: measureToUpdate.isNewLine);
      _measures = updatedMeasures;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetMusicSize = MediaQuery.of(context).size;
    final width = sheetMusicSize.width;
    final height = sheetMusicSize.height / 2;

    return Scaffold(
        appBar: AppBar(title: const Text('Simple Sheet Music Demo')),
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
                // Handle the tapped symbol
                print(
                    'Tapped symbol: ${symbol is Clef ? symbol.clefType : symbol.runtimeType}');
                print('At position: $position');

                // Show a snackbar with the tapped symbol info
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Tapped: ${symbol is Clef ? 'Clef (${symbol.clefType})' : symbol.runtimeType}',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              measures: _measures,
              onSymbolAdd: _onSymbolAdd,
              onSymbolUpdate: _onSymbolUpdate,
              onSymbolDelete: _onSymbolDelete,
            ),
          ),
        ));
  }
}

class MidiExampleDemo extends StatefulWidget {
  const MidiExampleDemo({super.key});

  @override
  State<MidiExampleDemo> createState() => _MidiExampleDemoState();
}

class _MidiExampleDemoState extends State<MidiExampleDemo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MIDI Example')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 80,
              color: Colors.blue,
            ),
            SizedBox(height: 20),
            Text(
              'MIDI functionality example placeholder.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Implement MIDI features using the music_sheet package.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class AdvancedExampleDemo extends StatefulWidget {
  const AdvancedExampleDemo({super.key});

  @override
  State<AdvancedExampleDemo> createState() => _AdvancedExampleDemoState();
}

class _AdvancedExampleDemoState extends State<AdvancedExampleDemo> {
  @override
  Widget build(BuildContext context) {
    final sheetMusicSize = MediaQuery.of(context).size;
    final width = sheetMusicSize.width;
    final height = sheetMusicSize.height * 0.7;

    // Create a more complex example with multiple measures
    List<Measure> measures = [
      // Measure 1 - Treble clef with key signature and time signature
      Measure([
        Clef.treble(),
        KeySignature.gMajor(),
        TimeSignature.fourFour(),
        Note(Pitch.g4, noteDuration: NoteDuration.quarter),
        Note(Pitch.a4, noteDuration: NoteDuration.quarter),
        Note(Pitch.b4, noteDuration: NoteDuration.quarter),
        Note(Pitch.c5, noteDuration: NoteDuration.quarter),
      ]),
      
      // Measure 2 - Chord and rest
      Measure([
        ChordNote([
          const ChordNotePart(Pitch.g4),
          const ChordNotePart(Pitch.b4),
          const ChordNotePart(Pitch.d5),
        ], noteDuration: NoteDuration.half),
        Rest(RestType.half),
      ]),
      
      // Measure 3 - Mixed notes with accidentals
      Measure([
        Note(Pitch.f4, noteDuration: NoteDuration.quarter, accidental: Accidental.sharp),
        Note(Pitch.g4, noteDuration: NoteDuration.quarter),
        Note(Pitch.a4, noteDuration: NoteDuration.eighth),
        Note(Pitch.b4, noteDuration: NoteDuration.eighth),
        Note(Pitch.c5, noteDuration: NoteDuration.quarter),
      ]),
      
      // Measure 4 - Bass clef on new line
      Measure([
        Clef.bass(),
        Note(Pitch.c3, noteDuration: NoteDuration.quarter),
        Note(Pitch.d3, noteDuration: NoteDuration.quarter),
        Note(Pitch.e3, noteDuration: NoteDuration.quarter),
        Note(Pitch.f3, noteDuration: NoteDuration.quarter),
      ], isNewLine: true),
      
      // Measure 5 - Bass clef chord
      Measure([
        ChordNote([
          const ChordNotePart(Pitch.c3),
          const ChordNotePart(Pitch.e3),
          const ChordNotePart(Pitch.g3),
        ], noteDuration: NoteDuration.whole),
      ]),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Sheet Music Demo')),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Advanced Example with Multiple Clefs and Complex Notation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 2),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: SimpleSheetMusic(
                    height: height,
                    width: width,
                    debug: false, // Turn off debug for cleaner look
                    onTap: (symbol, position) {
                      // Handle the tapped symbol with more detailed feedback
                      String symbolInfo;
                      if (symbol is Clef) {
                        symbolInfo = 'Clef: ${symbol.clefType}';
                      } else if (symbol is Note) {
                        symbolInfo = 'Note: ${symbol.pitch} (${symbol.noteDuration})';
                      } else if (symbol is ChordNote) {
                        symbolInfo = 'Chord with ${symbol.noteParts.length} notes';
                      } else if (symbol is Rest) {
                        symbolInfo = 'Rest: ${symbol.restType}';
                      } else if (symbol is KeySignature) {
                        symbolInfo = 'Key Signature';
                      } else if (symbol is TimeSignature) {
                        symbolInfo = 'Time Signature';
                      } else {
                        symbolInfo = symbol.runtimeType.toString();
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tapped: $symbolInfo at position $position'),
                          duration: const Duration(seconds: 3),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    measures: measures,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tap on any musical symbol to see details!',
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
