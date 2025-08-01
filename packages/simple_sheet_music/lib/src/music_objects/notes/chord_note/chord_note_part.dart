import 'dart:ui';

import 'package:simple_sheet_music/src/music_objects/notes/accidental.dart';
import 'package:simple_sheet_music/src/music_objects/notes/note_pitch.dart';

/// Represents a part of a chord note, including the pitch and optional accidental.
class ChordNotePart {
  ChordNotePart(this.pitch, {this.accidental});

  /// The pitch of the chord note part.
  Pitch pitch;

  /// The accidental of the chord note part, if any.
  final Accidental? accidental;

  ChordNotePart moveSemitones(int semitones) {
    if (semitones == 0) return this;
    final pitchNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ];
    final startPitch = pitch;
    final startName = startPitch.name[0];
    final startOctave = int.parse(startPitch.name[1]);

    // Calculate the starting index in pitchNames, considering the accidental
    int startIndex = pitchNames.indexOf(startName);
    if (accidental == Accidental.sharp) startIndex++;
    if (accidental == Accidental.flat) startIndex--;
    startIndex = (startIndex + 12) % 12; // Ensure positive index

    // Calculate the new index and octave
    int newIndex = (startIndex + semitones) % 12;
    int octaveChange = ((startIndex + semitones) / 12).floor();
    int newOctave = startOctave + octaveChange;

    // Determine the new pitch and accidental
    String newPitchName = pitchNames[newIndex];
    Accidental? newAccidental;
    if (newPitchName.length > 1) {
      newAccidental = Accidental.sharp;
      newPitchName = newPitchName[0];
    }

    final newPitchFullName = newPitchName + newOctave.toString();
    final newPitch = Pitch.values.firstWhere((p) => p.name == newPitchFullName);

    return ChordNotePart(newPitch, accidental: newAccidental);
  }
    int getMidiNumber() {
    // MIDI note numbers: C0 is 12, C4 (middle C) is 60
    final pitchValues = {
      'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11
    };

    // Extract the note name and octave from the pitch
    String noteName = pitch.name[0];
    int octave = int.parse(pitch.name[1]);

    // Calculate base MIDI number
    int midiNumber = 12 + (octave * 12) + pitchValues[noteName]!;

    // Adjust for accidental
    if (accidental == Accidental.sharp) {
      midiNumber += 1;
    } else if (accidental == Accidental.flat) {
      midiNumber -= 1;
    }

    return midiNumber;
  }

}

/// Represents the metrics of a chord note head, including the note head path and the associated chord note part.
class ChordNoteHeadMetrics {
  const ChordNoteHeadMetrics(this.noteHeadPath, this.part);

  /// The chord note part associated with the chord note head metrics.
  final ChordNotePart part;

  /// The path of the note head.
  final Path noteHeadPath;

  /// The bounding rectangle of the note head.
  Rect get noteHeadRect => noteHeadPath.getBounds();

  /// The pitch of the chord note part.
  Pitch get pitch => part.pitch;
}
