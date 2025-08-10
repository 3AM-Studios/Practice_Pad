import 'package:music_sheet/src/music_objects/notes/single_note/note.dart';
import 'package:music_sheet/src/music_objects/notes/note_duration.dart';

/// Represents a group of notes that should be connected with beams.
/// This includes eighth notes, sixteenth notes, and other subdivided notes.
class BeamGroup {
  BeamGroup(this.notes);

  final List<Note> notes;

  /// Returns true if this group contains notes that should be beamed together
  bool get shouldBeBeamed => notes.length >= 2 && notes.every(_canBeBeamed);

  /// Returns the number of beam levels needed (1 for eighth notes, 2 for sixteenth notes, etc.)
  int get beamLevels {
    if (notes.isEmpty) return 0;
    
    final maxBeamLevel = notes
        .map((note) => getBeamLevel(note.noteDuration))
        .reduce((a, b) => a > b ? a : b);
    
    return maxBeamLevel;
  }

  /// Returns true if the note can be part of a beam group
  static bool _canBeBeamed(Note note) {
    return note.noteDuration.hasFlag && note.noteDuration.hasStem;
  }

  /// Returns the beam level for a given note duration
  static int getBeamLevel(NoteDuration duration) {
    switch (duration) {
      case NoteDuration.eighth:
        return 1;
      case NoteDuration.sixteenth:
        return 2;
      case NoteDuration.thirtySecond:
        return 3;
      case NoteDuration.sixtyFourth:
        return 4;
      case NoteDuration.hundredsTwentyEighth:
        return 5;
      default:
        return 0;
    }
  }
}

/// Analyzes a list of musical symbols and groups notes into beam groups based on music theory rules
class BeamGroupAnalyzer {
  /// Creates beam groups from a list of musical symbols (Notes, Rests, etc.)
  /// This considers the full sequence to properly break beams at rests or other symbols
  static List<BeamGroup> createBeamGroupsFromSymbols(List<dynamic> musicalSymbols) {
    final groups = <BeamGroup>[];
    var currentGroup = <Note>[];

    for (var i = 0; i < musicalSymbols.length; i++) {
      final symbol = musicalSymbols[i];

      if (symbol is Note && BeamGroup._canBeBeamed(symbol)) {
        // Check stem direction compatibility
        if (currentGroup.isNotEmpty && !_hasSameStemDirection(currentGroup.first, symbol)) {
          // Stem direction changed, end current group
          if (currentGroup.length >= 2) {
            groups.add(BeamGroup(List.from(currentGroup)));
          }
          currentGroup.clear();
          currentGroup.add(symbol);
        } else {
          currentGroup.add(symbol);
        }
        
        // Check if we should end the current group based on music theory rules
        final shouldEndGroup = _shouldEndBeamGroupFromSymbols(musicalSymbols, i, currentGroup);
        
        if (shouldEndGroup || i == musicalSymbols.length - 1) {
          if (currentGroup.length >= 2) {
            groups.add(BeamGroup(List.from(currentGroup)));
          }
          currentGroup.clear();
        }
      } else {
        // Non-Note symbol (Rest, etc.) or non-beamable note encountered, end current group
        if (currentGroup.length >= 2) {
          groups.add(BeamGroup(List.from(currentGroup)));
        }
        currentGroup.clear();
      }
    }

    return groups;
  }

  /// Creates beam groups from a list of notes (legacy method for backward compatibility)
  static List<BeamGroup> createBeamGroups(List<Note> notes) {
    final groups = <BeamGroup>[];
    var currentGroup = <Note>[];

    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];

      // Check if this note can be beamed
      if (BeamGroup._canBeBeamed(note)) {
        // Check stem direction compatibility
        if (currentGroup.isNotEmpty && !_hasSameStemDirection(currentGroup.first, note)) {
          // Stem direction changed, end current group
          if (currentGroup.length >= 2) {
            groups.add(BeamGroup(List.from(currentGroup)));
          }
          currentGroup.clear();
          currentGroup.add(note);
        } else {
          currentGroup.add(note);
        }
        
        // Check if we should end the current group
        final shouldEndGroup = _shouldEndBeamGroup(notes, i, currentGroup);
        
        if (shouldEndGroup || i == notes.length - 1) {
          if (currentGroup.length >= 2) {
            groups.add(BeamGroup(List.from(currentGroup)));
          }
          currentGroup.clear();
        }
      } else {
        // Non-beamable note encountered, end current group
        if (currentGroup.length >= 2) {
          groups.add(BeamGroup(List.from(currentGroup)));
        }
        currentGroup.clear();
      }
    }

    return groups;
  }

  /// Checks if two notes should have the same stem direction when beamed together
  static bool _hasSameStemDirection(Note note1, Note note2) {
    final stemDirection1 = _getDefaultStemDirection(note1);
    final stemDirection2 = _getDefaultStemDirection(note2);
    return stemDirection1 == stemDirection2;
  }

  /// Gets the default stem direction for a note based on its pitch position
  static bool _getDefaultStemDirection(Note note) {
    // Use a more accurate middle staff position for treble clef
    // Middle C (C4) is position 23, but the staff center line is B4 (position 29)
    // Notes on or above the middle line (B4) should have stems down
    // Notes below the middle line should have stems up
    return note.pitch.position < 29; // true = stems up, false = stems down
  }

  /// Determines if a beam group should end at the current position when analyzing musical symbols
  static bool _shouldEndBeamGroupFromSymbols(List<dynamic> symbols, int currentIndex, List<Note> currentGroup) {
    if (currentGroup.isEmpty) return false;
    
    final nextSymbol = currentIndex + 1 < symbols.length ? symbols[currentIndex + 1] : null;
    
    // End group if next symbol is not a beamable note
    if (nextSymbol != null) {
      if (nextSymbol is! Note || !BeamGroup._canBeBeamed(nextSymbol)) {
        return true;
      }
    }
    
    // Don't group more than 4 consecutive notes for readability
    if (currentGroup.length >= 4) {
      return true;
    }
    
    // Additional music theory rules could be added here:
    // - Beat boundary detection (don't beam across strong beats)
    // - Time signature awareness
    
    return false;
  }

  /// Determines if a beam group should end at the current position (legacy method)
  static bool _shouldEndBeamGroup(List<Note> notes, int currentIndex, List<Note> currentGroup) {
    if (currentGroup.isEmpty) return false;
    
    final nextNote = currentIndex + 1 < notes.length ? notes[currentIndex + 1] : null;
    
    // End group if next note can't be beamed
    if (nextNote != null && !BeamGroup._canBeBeamed(nextNote)) {
      return true;
    }
    
    // For now, we'll use simple grouping rules
    // In more advanced implementations, we could add:
    // - Beat boundary detection (don't beam across strong beats)
    // - Time signature awareness
    // - Rest handling
    
    // Don't group more than 4 consecutive notes for readability
    if (currentGroup.length >= 4) {
      return true;
    }
    
    return false;
  }
}