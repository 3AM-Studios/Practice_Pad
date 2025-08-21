import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/music_objects/notes/single_note/note.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';

/// Associates notes within a measure with their corresponding chord symbols.
/// 
/// If a measure has multiple chord symbols, notes are divided equally between them.
/// For example, if a measure has 2 chord symbols and 4 notes:
/// - Notes 1-2 are associated with chord symbol 1
/// - Notes 3-4 are associated with chord symbol 2
ChordSymbol? getChordSymbolForNote(
  int noteIndex, 
  List<MusicalSymbol> musicalSymbols, 
  List<ChordSymbol> chordSymbols,
) {
  if (chordSymbols.isEmpty) return null;
  
  // Get all notes from the musical symbols
  final notes = musicalSymbols.whereType<Note>().toList();
  if (notes.isEmpty || noteIndex >= notes.length) return null;
  
  // If there's only one chord symbol, all notes use it
  if (chordSymbols.length == 1) return chordSymbols[0];
  
  // Divide notes equally among chord symbols
  final notesPerChord = (notes.length / chordSymbols.length).ceil();
  final chordIndex = (noteIndex / notesPerChord).floor();
  
  // Ensure we don't exceed the chord symbols array bounds
  return chordIndex < chordSymbols.length ? chordSymbols[chordIndex] : chordSymbols.last;
}

/// Gets the extension number (scale degree) for a note relative to a key signature.
/// Returns scale degrees relative to the key center.
String getKeyExtension(Note note, String keySignature) {
  String accidental = '';
  if (note.accidental.toString() == 'Accidental.flat') {
    accidental = 'b';
  }
  if (note.accidental.toString() == 'Accidental.sharp') {
    accidental = '♯';
  }
  
  final String noteName = note.pitch.name.replaceAll(RegExp(r'\d'), '').trim().toUpperCase() + accidental;

  final int noteMidi = _getMidiValueFromNoteName(noteName);
  
  // Extract key root from key signature (e.g., "C major" -> "C", "A minor" -> "A")
  String keyRoot = keySignature.split(' ')[0].toUpperCase();
  final int keyRootPitchClass = _getMidiValueFromNoteName(keyRoot);
  
  // Get the pitch class of the note (0-11) to compare with key root
  final int notePitchClass = noteMidi % 12;
  
  // Calculate how many semitones the note is ABOVE the key root
  int interval = (notePitchClass - keyRootPitchClass + 12) % 12;
  
  // Convert semitone interval to scale degree
  switch (interval) {
    case 0:
      return '1';   // Root (tonic)
    case 1:
      return 'b2';  // Minor second
    case 2:
      return '2';   // Major second
    case 3:
      return 'b3';  // Minor third
    case 4:
      return '3';   // Major third
    case 5:
      return '4';   // Perfect fourth
    case 6:
      return 'b5';  // Tritone (diminished fifth)
    case 7:
      return '5';   // Perfect fifth
    case 8:
      return 'b6';  // Minor sixth
    case 9:
      return '6';   // Major sixth
    case 10:
      return 'b7';  // Minor seventh
    case 11:
      return '7';   // Major seventh
    default:
      return '';
  }
}

/// Gets the extension number (scale degree) for a note relative to its chord symbol.
/// Returns common chord extensions like '1', '3', '5', '7', '9', '11', '13', etc.
String getChordExtension(Note note, ChordSymbol chordSymbol) {
  String accidental = '';
  if (note.accidental.toString() == 'Accidental.flat') {
    accidental = 'b';
  }
  if (note.accidental.toString() == 'Accidental.sharp') {
    accidental = '♯';
  }
  
  final String noteName = note.pitch.name.replaceAll(RegExp(r'\d'), '').trim().toUpperCase() + accidental;


  final int noteMidi = _getMidiValueFromNoteName(noteName);
  final int chordRootPitchClass = _getMidiValueFromNoteName(chordSymbol.effectiveRootName);
  
  // Get the pitch class of the note (0-11) to compare with chord root
  final int notePitchClass = noteMidi % 12;
  
  // Calculate how many semitones the note is ABOVE the chord root
  // This gives us the ascending interval from root to note
  int interval = (notePitchClass - chordRootPitchClass + 12) % 12;
  // Debug logging to help troubleshoot  

  // Convert semitone interval to scale degree
  switch (interval) {
    case 0:
      return '1';   // Root (unison)
    case 1:
      return 'b2';  // Minor second
    case 2:
      return '2';   // Major second
    case 3:
      return 'b3';  // Minor third
    case 4:
      return '3';   // Major third
    case 5:
      return '4';   // Perfect fourth
    case 6:
      return 'b5';  // Tritone (diminished fifth)
    case 7:
      return '5';   // Perfect fifth
    case 8:
      return 'b6';  // Minor sixth
    case 9:
      return '6';   // Major sixth
    case 10:
      return 'b7';  // Minor seventh
    case 11:
      return '7';   // Major seventh
    default:
      return '';
  }
}

/// Converts KeySignatureType enum to readable key name
String convertKeySignatureTypeToString(dynamic keySignatureType) {
  if (keySignatureType == null) return 'C major';
  
  final keyType = keySignatureType.toString().split('.').last;
  // Convert enum name to readable key name (e.g., cMajor -> C major)
  String result = keyType.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match[1]} ${match[2]}');
  return result[0].toUpperCase() + result.substring(1);
}

/// Converts a note name to its MIDI pitch class (0-11, ignoring octave)
int _getMidiValueFromNoteName(String noteName) {
  final noteValues = {
    'C': 0,   // C
    'C♯': 1,  // C♯ / Db
    'Db': 1,
    'D♭': 1,
    'D': 2,   // D
    'D♯': 3,  // D♯ / Eb  
    'Eb': 3,
    'E♭': 3,
    'E': 4,   // E
    'F': 5,   // F
    'F♯': 6,  // F♯ / Gb
    'Gb': 6,
    'G♭': 6,
    'G': 7,   // G
    'G♯': 8,  // G♯ / Ab
    'Ab': 8,
    'A♭': 8,
    'A': 9,   // A
    'A♯': 10, // A♯ / Bb
    'Bb': 10,
    'B♭': 10,
    'B': 11,  // B
    'Cb': 11,
    'C♭': 11
  };
  
  // Remove any octave numbers and extra characters
  final cleanNoteName = noteName.replaceAll(RegExp(r'[0-9]'), '').trim();
  final pitchClass = noteValues[cleanNoteName];
  
  if (pitchClass == null) {
    print('WARNING: Unknown note name: "$noteName" (cleaned: "$cleanNoteName")');
    return 0;
  }
  
  return pitchClass;
}