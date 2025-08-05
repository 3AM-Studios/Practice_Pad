# Music Sheet Integration Guide

This guide shows how to use the `music_sheet` package (located in `packages/music_sheet-main`) in your Practice Pad Flutter app.

## Package Setup

The package is already configured in your `pubspec.yaml`:

```yaml
dependencies:
  music_sheet:
    path: packages/music_sheet-main
```

## Quick Start Examples

### 1. Basic Usage

Import the package:
```dart
import 'package:music_sheet/simple_sheet_music.dart';
```

Create basic sheet music:
```dart
Widget build(BuildContext context) {
  Measure measure = Measure([
    Clef.treble(),
    TimeSignature.fourFour(),
    KeySignature.cMajor(),
    Note(Pitch.c4, noteDuration: NoteDuration.quarter),
    Note(Pitch.d4, noteDuration: NoteDuration.quarter),
    Note(Pitch.e4, noteDuration: NoteDuration.quarter),
    Note(Pitch.f4, noteDuration: NoteDuration.quarter),
  ]);

  return SimpleSheetMusic(
    width: 400,
    height: 200,
    measures: [measure],
    onTap: (symbol, position) {
      print('Tapped: $symbol at $position');
    },
  );
}
```

### 2. Running the Demo

To see the music sheet package in action:

1. Run the demo app:
   ```bash
   flutter run --target=lib/music_sheet_demo.dart
   ```

2. Or integrate it into your existing app by importing:
   ```dart
   import 'package:practice_pad/widgets/integrated_music_sheet.dart';
   ```

## Available Demo Files

1. **`lib/music_sheet_demo.dart`** - Standalone demo app with multiple examples
2. **`lib/music_sheet_example.dart`** - Simple example implementation
3. **`lib/widgets/integrated_music_sheet.dart`** - Integration with your existing chord system

## Key Classes and Usage

### Clefs
```dart
Clef.treble()   // Treble clef
Clef.bass()     // Bass clef
Clef.alto()     // Alto clef
Clef.tenor()    // Tenor clef
```

### Time Signatures
```dart
TimeSignature.fourFour()   // 4/4 time
TimeSignature.twoFour()    // 2/4 time
TimeSignature.threeFour()  // 3/4 time
```

### Key Signatures
```dart
KeySignature.cMajor()    // C Major (no accidentals)
KeySignature.gMajor()    // G Major (1 sharp)
KeySignature.dMajor()    // D Major (2 sharps)
KeySignature.fMajor()    // F Major (1 flat)
// ... and many more
```

### Notes
```dart
// Single notes
Note(Pitch.c4, noteDuration: NoteDuration.quarter)
Note(Pitch.g4, noteDuration: NoteDuration.half)
Note(Pitch.a4, noteDuration: NoteDuration.whole)

// Notes with accidentals
Note(Pitch.f4, noteDuration: NoteDuration.quarter, accidental: Accidental.sharp)
Note(Pitch.b4, noteDuration: NoteDuration.quarter, accidental: Accidental.flat)
```

### Chords
```dart
ChordNote([
  const ChordNotePart(Pitch.c4),
  const ChordNotePart(Pitch.e4),
  const ChordNotePart(Pitch.g4),
], noteDuration: NoteDuration.half)
```

### Rests
```dart
Rest(RestType.quarter)    // Quarter rest
Rest(RestType.half)       // Half rest
Rest(RestType.whole)      // Whole rest
Rest(RestType.eighth)     // Eighth rest
Rest(RestType.sixteenth)  // Sixteenth rest
```

### Note Durations
- `NoteDuration.whole`
- `NoteDuration.half`
- `NoteDuration.quarter`
- `NoteDuration.eighth`
- `NoteDuration.sixteenth`

### Pitches
Common pitches include:
- `Pitch.c4`, `Pitch.d4`, `Pitch.e4`, `Pitch.f4`, `Pitch.g4`, `Pitch.a4`, `Pitch.b4`
- `Pitch.c5`, `Pitch.d5`, etc. (higher octave)
- `Pitch.c3`, `Pitch.d3`, etc. (lower octave)

## Advanced Features

### Interactive Sheet Music
```dart
SimpleSheetMusic(
  width: width,
  height: height,
  measures: measures,
  debug: true,  // Shows debug information
  onTap: (symbol, position) {
    // Handle taps on musical symbols
    if (symbol is Clef) {
      print('Tapped clef: ${symbol.clefType}');
    } else if (symbol is Note) {
      print('Tapped note: ${symbol.pitch}');
    }
  },
)
```

### Multiple Measures with Line Breaks
```dart
List<Measure> measures = [
  Measure([
    Clef.treble(),
    TimeSignature.fourFour(),
    // ... notes
  ]),
  Measure([
    // More notes for measure 2
  ]),
  Measure([
    Clef.bass(),  // Switch to bass clef
    // ... bass notes
  ], isNewLine: true),  // Start a new line
];
```

## Integration with Your Chord System

The `IntegratedMusicSheetWidget` in `lib/widgets/integrated_music_sheet.dart` shows how to:

1. Convert your existing `ChordSymbol` objects to sheet music notation
2. Display chord progressions as visual sheet music
3. Handle interactions between chord symbols and sheet music display

## MIDI Support

The package includes MIDI playback capabilities. See the MIDI example in the demo for implementation details.

## Troubleshooting

1. **Import errors**: Make sure you're importing from `package:music_sheet/simple_sheet_music.dart`
2. **Package not found**: Run `flutter pub get` to ensure dependencies are installed
3. **Symbol property errors**: Check the class documentation for correct property names (e.g., `symbol.clefType` not `symbol.id`)

## Next Steps

1. Explore the demo apps to understand the capabilities
2. Integrate sheet music display into your song viewer
3. Connect your chord progression system with visual notation
4. Add MIDI playback functionality for practice sessions

For more examples, check the `packages/music_sheet-main/example/` directory which contains the original package examples.
