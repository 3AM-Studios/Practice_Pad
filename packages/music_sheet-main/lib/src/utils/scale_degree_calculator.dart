import 'package:music_sheet/src/music_objects/notes/note_pitch.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';

String getScaleDegree(Pitch notePitch, ChordSymbol chordSymbol) {
  final int noteMidi = notePitch.midiNoteNumber;
  final int chordRootMidi = _getMidiValueFromNoteName(chordSymbol.effectiveRootName);

  int interval = (noteMidi - chordRootMidi) % 12;
  if (interval < 0) {
    interval += 12;
  }

  switch (interval) {
    case 0:
      return '1';
    case 1:
      return 'b2';
    case 2:
      return '2';
    case 3:
      return 'b3';
    case 4:
      return '3';
    case 5:
      return '4';
    case 6:
      return '#4';
    case 7:
      return '5';
    case 8:
      return 'b6';
    case 9:
      return '6';
    case 10:
      return 'b7';
    case 11:
      return '7';
    default:
      return '';
  }
}

int _getMidiValueFromNoteName(String noteName) {
  final noteValues = {
    'C': 0,
    'C#': 1,
    'Db': 1,
    'D♭': 1,
    'D': 2,
    'D#': 3,
    'Eb': 3,
    'E♭': 3,
    'E': 4,
    'F': 5,
    'F#': 6,
    'Gb': 6,
    'G♭': 6,
    'G': 7,
    'G#': 8,
    'Ab': 8,
    'A♭': 8,
    'A': 9,
    'A#': 10,
    'Bb': 10,
    'B♭': 10,
    'B': 11,
    'Cb': 11,
    'C♭': 11
  };
  //This is a simplified implementation that doesn't account for octaves.
  //We are only interested in the pitch class, so we can ignore the octave.
  final noteNameWithoutOctave = noteName.replaceAll(RegExp(r'[0-9]'), '');
  return noteValues[noteNameWithoutOctave] ?? 0;
}
