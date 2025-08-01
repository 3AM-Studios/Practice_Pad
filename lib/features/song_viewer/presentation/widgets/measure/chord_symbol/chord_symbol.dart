import 'package:simple_sheet_music/simple_sheet_music.dart';
import 'package:flutter/material.dart';

/// Represents a chord symbol with Roman numeral analysis capability and MusicXML support.
/// 
/// This unified class handles both MusicXML chord parsing and chord symbol display
/// with Roman numeral analysis.
/// 
/// Example usage:
/// ```dart
/// // From MusicXML data
/// final chord = ChordSymbol.fromMusicXML('G', 0, '7', 1.0, 1, keySignature: KeySignatureType.cMajor);
/// print(chord.displayText); // Shows: G7\nV^7
/// 
/// // Direct creation
/// final chord = ChordSymbol('G', '7', keySignature: KeySignatureType.cMajor);
/// print(chord.displayText); // Shows: G7\nV^7
/// ```
class ChordSymbol {
  /// The root note name (e.g., 'C', 'F#', 'Bb') - for direct creation
  final String? rootName;
  
  /// The chord quality (e.g., 'maj', 'min', '7', 'maj7', 'dim', 'm7b5') - for direct creation
  final String? quality;
  
  /// MusicXML root step (e.g., 'C', 'F', 'G') - for MusicXML parsing
  final String? rootStep;
  
  /// MusicXML root alteration (-1 for flat, 0 for natural, 1 for sharp) - for MusicXML parsing
  final int? rootAlter;
  
  /// MusicXML chord kind (e.g., 'major', 'minor', 'dominant-seventh') - for MusicXML parsing
  final String? kind;
  
  /// Duration in beats - for MusicXML parsing
  final double? durationBeats;
  
  /// Measure number - for MusicXML parsing
  final int? measureNumber;
  
  /// Beat position within the measure (0-based)
  final int position;
  
  /// The original key signature context for Roman numeral analysis
  /// If null, only the chord symbol will be displayed without Roman numerals
  final KeySignatureType? originalKeySignature;
  
  /// The modified key signature context for Roman numeral analysis
  /// Used when analyzing chords in a different key context
  final KeySignatureType? modifiedKeySignature;
  
  /// The generated chord notes based on the root and quality
  late final List<Pitch> chordNotes;

  /// Backward compatibility getter for keySignature - returns originalKeySignature
  KeySignatureType? get keySignature => originalKeySignature;

  /// Creates a new chord symbol directly from root name and quality.
  /// 
  /// [rootName] - The root note (e.g., 'C', 'F#', 'Bb')
  /// [quality] - The chord quality (e.g., 'maj', 'min', '7', 'maj7')
  /// [position] - Beat position in the measure (default: 0)
  /// [originalKeySignature] - Original key context for Roman numeral analysis (optional)
  /// [modifiedKeySignature] - Modified key context for Roman numeral analysis (optional)
  ChordSymbol(String rootName, String quality, {this.position = 0, this.originalKeySignature, this.modifiedKeySignature})
      : rootName = rootName,
        quality = quality,
        rootStep = null,
        rootAlter = null,
        kind = null,
        durationBeats = null,
        measureNumber = null {
    chordNotes = generateChordNotes();
  }

  /// Creates a new chord symbol from MusicXML data.
  /// 
  /// [rootStep] - MusicXML root step (e.g., 'C', 'F', 'G')
  /// [rootAlter] - MusicXML root alteration (-1 flat, 0 natural, 1 sharp)
  /// [kind] - MusicXML chord kind (e.g., 'major', 'minor', 'dominant-seventh')
  /// [durationBeats] - Duration in beats
  /// [measureNumber] - Measure number
  /// [position] - Beat position in the measure (default: 0)
  /// [originalKeySignature] - Original key context for Roman numeral analysis (optional)
  /// [modifiedKeySignature] - Modified key context for Roman numeral analysis (optional)
  ChordSymbol.fromMusicXML(
    String rootStep,
    int rootAlter,
    String kind,
    double durationBeats,
    int measureNumber, {
    this.position = 0,
    this.originalKeySignature,
    this.modifiedKeySignature,
  })  : rootStep = rootStep,
        rootAlter = rootAlter,
        kind = kind,
        durationBeats = durationBeats,
        measureNumber = measureNumber,
        rootName = null,
        quality = null {
    chordNotes = generateChordNotes();
  }

  /// Gets the effective root name, either from direct creation or computed from MusicXML
  String get effectiveRootName {
    if (rootName != null) return rootName!;
    if (rootStep != null && rootAlter != null) {
      String alterSymbol = '';
      if (rootAlter == 1) alterSymbol = '#';
      if (rootAlter == -1) alterSymbol = '♭';
      return '$rootStep$alterSymbol';
    }
    return 'C'; // fallback
  }

  /// Gets the effective quality, either from direct creation or computed from MusicXML
  String get effectiveQuality {
    if (quality != null) return quality!;
    if (kind != null) return _convertKindToQuality(kind!);
    return 'maj'; // fallback
  }

  /// Gets the display symbol for chord display (without Roman numeral analysis)
  String get displaySymbol {
    if (rootName != null && quality != null) {
      return '$rootName$quality';
    }
    if (rootStep != null && kind != null) {
      String alterSymbol = '';
      if (rootAlter == 1) alterSymbol = '#';
      if (rootAlter == -1) alterSymbol = 'b';
      return '$rootStep$alterSymbol$kind';
    }
    return 'Cmaj'; // fallback
  }

  /// Converts MusicXML chord kind to ChordSymbol quality
  String _convertKindToQuality(String kind) {
    // Don't convert to lowercase immediately - need to distinguish M7 from m7
    final kindTrimmed = kind.trim();
    
    switch (kindTrimmed) {
      case 'major':
      case 'maj':
      case 'M':
        return 'maj';
      case 'minor':
      case 'min':
      case 'm':
        return 'min';
      case 'dominant':
      case 'dominant-seventh':
      case '7':
        return '7';
      case 'major-seventh':
      case 'maj7':
        return 'maj7';
      case 'minor-seventh':
      case 'm7':
        return 'min7';
      case 'minor-ninth':
      case 'm9':
        return 'm9';
      case 'major-ninth':
      case 'maj9':
        return 'maj9';
      case '9':
        return '9';
      case '7b9':
        return '7b9';
      case '7#9':
        return '7#9';
      case '7b5':
        return '7b5';
      case '7#5':
        return '7#5';
      case 'diminished':
      case 'dim':
        return 'dim';
      case 'diminished-seventh':
      case 'dim7':
        return 'dim7';
      case 'half-diminished':
      case 'm7b5':
        return 'm7b5';
      case 'augmented':
      case 'aug':
        return 'aug';
      case 'augmented-seventh':
      case 'aug7':
      case '7+':
        return 'aug7';
      case 'suspended-fourth':
      case 'sus4':
        return 'sus4';
      case 'suspended-second':
      case 'sus2':
        return 'sus2';
      case 'add9':
        return 'add9';
      case 'major-sixth':
      case '6':
        return '6';
      case 'minor-sixth':
      case 'm6':
        return 'm6';
      default:
        // Handle case-sensitive parsing for M7 vs m7
        if (kindTrimmed == 'M7') return 'maj7';  // M7 = major 7th
        if (kindTrimmed == 'm7') return 'min7';  // m7 = minor 7th
        
        // For unknown chords, try to preserve the original text
        return kindTrimmed.isNotEmpty ? kindTrimmed : 'maj';
    }
  }

  /// Gets formatted chord symbol with proper superscript notation
  /// Returns a list of TextSpan for rich text display  
  List<TextSpan> getFormattedChordSymbol() {
    final rootName = effectiveRootName;
    final quality = effectiveQuality;
    final formattedQuality = formatChordQuality(quality);
    
    List<TextSpan> spans = [
      TextSpan(
        text: rootName,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
    
    // Add quality with proper superscript formatting
    if (formattedQuality.isNotEmpty) {
      spans.add(TextSpan(
        text: formattedQuality,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    
    return spans;
  }

  /// Formats chord quality text with proper superscript notation
  /// This is the SINGLE SOURCE OF TRUTH for all chord quality formatting
  static String formatChordQuality(String quality) {
    // Handle chord quality patterns with proper superscript notation
    return quality
        .replaceAll('m7b5', 'ø⁷')   // Half-diminished (must be before m7 replacement)
        .replaceAll('half-diminished', 'ø⁷')
        .replaceAll('min7', '⁻⁷')  // Minor 7th
        .replaceAll('maj7', 'ᴹ⁷')  // Major 7th with capital M
        .replaceAll('m7', '⁻⁷')    // Minor 7th (alternative)
        .replaceAll('M7', 'ᴹ⁷')    // Major 7th (alternative)
        .replaceAll('m9', '⁻⁹')    // Minor 9th
        .replaceAll('maj9', 'ᴹ⁹')  // Major 9th with capital M
        .replaceAll('m6', '⁻⁶')    // Minor 6th
        .replaceAll('6', '⁶')      // Major 6th
        .replaceAll('7b9', '⁷ᵇ⁹')  // Dominant 7th flat 9
        .replaceAll('7#9', '⁷♯⁹')  // Dominant 7th sharp 9
        .replaceAll('7b5', '⁷ᵇ⁵')  // Dominant 7th flat 5
        .replaceAll('7#5', '⁷♯⁵')  // Dominant 7th sharp 5
        .replaceAll('7+', '⁷⁺')    // Dominant 7th augmented 5
        .replaceAll('aug7', '⁺⁷')  // Augmented 7th
        .replaceAll('augmented-seventh', '⁺⁷')
        .replaceAll('dim7', '°⁷')  // Diminished 7th
        .replaceAll('dim', '°')    // Diminished
        .replaceAll('diminished', '°')
        .replaceAll('sus4', 'ˢᵘˢ⁴') // Suspended 4th
        .replaceAll('sus2', 'ˢᵘˢ²') // Suspended 2nd
        .replaceAll('add9', 'ᵃᵈᵈ⁹') // Add 9
        .replaceAll('aug', '⁺')    // Augmented
        .replaceAll('min', '')     // Minor triad (no symbol)
        .replaceAll('maj', 'ᴹᵃʲ')  // Major triad with superscript 
        .replaceAll('9', '⁹')     // 9th chord
        .replaceAll('11', '¹¹')   // 11th chord
        .replaceAll('13', '¹³')   // 13th chord
        .replaceAll('7', '⁷');    // Dominant 7th (keep this last to avoid conflicts)
  }

  /// Determines if this chord is diatonic to the current key signature
  bool get isDiatonic {
    if (originalKeySignature == null) return true; // If no key context, assume diatonic
    
    // Get the key root and chord root
    final keyRoot = _getKeyRoot();
    final chordRoot = effectiveRootName;
    
    // Calculate the interval from key root to chord root
    final keyRootValue = _getMidiValueFromNoteName(keyRoot);
    final chordRootValue = _getMidiValueFromNoteName(chordRoot);
    
    int interval = (chordRootValue - keyRootValue) % 12;
    if (interval < 0) interval += 12;
    
    // Determine if we're in a minor key first
    final isMinorKey = _isKeyMinor();
    
    // Map interval to scale degree based on key type
    int? scaleDegree;
    if (isMinorKey) {
      // Natural minor scale intervals to scale degrees
      final minorIntervalToScaleDegree = {
        0: 1,   // i (tonic)
        2: 2,   // ii (major 2nd)
        3: 3,   // bIII (minor 3rd)
        5: 4,   // iv (perfect 4th)
        7: 5,   // v (perfect 5th)
        8: 6,   // bVI (minor 6th)
        10: 7,  // bVII (minor 7th)
      };
      scaleDegree = minorIntervalToScaleDegree[interval];
    } else {
      // Major scale intervals to scale degrees
      final majorIntervalToScaleDegree = {
        0: 1,   // I (tonic)
        2: 2,   // ii (major 2nd)
        4: 3,   // iii (major 3rd)
        5: 4,   // IV (perfect 4th)
        7: 5,   // V (perfect 5th)
        9: 6,   // vi (major 6th)
        11: 7,  // vii (major 7th)
      };
      scaleDegree = majorIntervalToScaleDegree[interval];
    }
    if (scaleDegree == null) {
      // Root is not on a diatonic scale degree
      return false;
    }
    
    // Get expected diatonic chord qualities for this scale degree
    final expectedQualities = _getDiatonicChordQualities(scaleDegree, isMinorKey);
    
    // Check if the actual chord quality matches any expected diatonic quality
    final effectiveQualityValue = effectiveQuality;
    final isDiatonicChord = expectedQualities.contains(effectiveQualityValue);
    
    return isDiatonicChord;
  }

  /// Determines if this chord is diatonic to the specified key signature
  bool isDiatonicTo(KeySignatureType keySignature) {
    final keyRoot = _getKeyRootForSignature(keySignature);
    final chordRoot = effectiveRootName;
    
    // Calculate the interval from key root to chord root
    final keyRootValue = _getMidiValueFromNoteName(keyRoot);
    final chordRootValue = _getMidiValueFromNoteName(chordRoot);
    
    int interval = (chordRootValue - keyRootValue) % 12;
    if (interval < 0) interval += 12;
    
    // Determine if we're in a minor key
    final isMinorKey = _isKeyMinorForSignature(keySignature);
    
    // Map interval to scale degree based on key type
    int? scaleDegree;
    if (isMinorKey) {
      // Natural minor scale intervals to scale degrees
      final minorIntervalToScaleDegree = {
        0: 1,   // i (tonic)
        2: 2,   // ii (major 2nd)
        3: 3,   // bIII (minor 3rd)
        5: 4,   // iv (perfect 4th)
        7: 5,   // v (perfect 5th)
        8: 6,   // bVI (minor 6th)
        10: 7,  // bVII (minor 7th)
      };
      scaleDegree = minorIntervalToScaleDegree[interval];
    } else {
      // Major scale intervals to scale degrees
      final majorIntervalToScaleDegree = {
        0: 1,   // I (tonic)
        2: 2,   // ii (major 2nd)
        4: 3,   // iii (major 3rd)
        5: 4,   // IV (perfect 4th)
        7: 5,   // V (perfect 5th)
        9: 6,   // vi (major 6th)
        11: 7,  // vii (major 7th)
      };
      scaleDegree = majorIntervalToScaleDegree[interval];
    }
    
    if (scaleDegree == null) {
      return false; // Not on a diatonic scale degree
    }
    
    // Get expected qualities for this scale degree
    final expectedQualities = _getDiatonicChordQualities(scaleDegree, isMinorKey);
    final effectiveQualityValue = effectiveQuality;
    
    final isDiatonicChord = expectedQualities.contains(effectiveQualityValue);
    
    return isDiatonicChord;
  }

  /// Helper method to get key root for a specific key signature
  String _getKeyRootForSignature(KeySignatureType keySignature) {
    final keyMap = {
      // Sharp keys
      KeySignatureType.cMajor: 'C',
      KeySignatureType.gMajor: 'G',
      KeySignatureType.dMajor: 'D',
      KeySignatureType.aMajor: 'A',
      KeySignatureType.eMajor: 'E',
      KeySignatureType.bMajor: 'B',
      KeySignatureType.fSharpMajor: 'F#',
      KeySignatureType.cSharpMajor: 'C#',
      
      // Flat keys
      KeySignatureType.fMajor: 'F',
      KeySignatureType.bFlatMajor: 'B♭',
      KeySignatureType.eFlatMajor: 'E♭',
      KeySignatureType.aFlatMajor: 'A♭',
      KeySignatureType.dFlatMajor: 'D♭',
      KeySignatureType.gFlatMajor: 'G♭',
      KeySignatureType.cFlatMajor: 'C♭',
      
      // Minor keys
      KeySignatureType.aMinor: 'A',
      KeySignatureType.eMinor: 'E',
      KeySignatureType.bMinor: 'B',
      KeySignatureType.fSharpMinor: 'F#',
      KeySignatureType.cSharpMinor: 'C#',
      KeySignatureType.gSharpMinor: 'G#',
      KeySignatureType.dSharpMinor: 'D#',
      KeySignatureType.aSharpMinor: 'A#',
      KeySignatureType.dMinor: 'D',
      KeySignatureType.gMinor: 'G',
      KeySignatureType.cMinor: 'C',
      KeySignatureType.fMinor: 'F',
      KeySignatureType.bFlatMinor: 'B♭',
      KeySignatureType.eFlatMinor: 'E♭',
      KeySignatureType.aFlatMinor: 'A♭',
    };
    
    return keyMap[keySignature] ?? 'C';
  }

  /// Helper method to check if a specific key signature is minor
  bool _isKeyMinorForSignature(KeySignatureType keySignature) {
    return keySignature.name.contains('Minor') || keySignature.name.contains('minor');
  }

  /// Gets the expected diatonic chord qualities for a given scale degree
  Set<String> _getDiatonicChordQualities(int scaleDegree, bool isMinorKey) {
    if (isMinorKey) {
      // Natural Minor Key Diatonic Seventh Chords (and extensions)
      switch (scaleDegree) {
        case 1: return {'min', 'min7', 'm9'};     // i, imin7, im9
        case 2: return {'dim', 'm7b5'};           // ii°, iiø7
        case 3: return {'maj', 'maj7', 'maj9'};   // III, IIImaj7, IIImaj9
        case 4: return {'min', 'min7', 'm9'};     // iv, ivmin7, ivm9
        case 5: return {'min', 'min7', 'm9'};     // v, vmin7, vm9 (natural minor)
        case 6: return {'maj', 'maj7', 'maj9'};   // VI, VImaj7, VImaj9
        case 7: return {'maj', '7', '9'};         // VII, VII7, VII9 (dominant)
        default: return {};
      }
    } else {
      // Major Key Diatonic Seventh Chords (and extensions)
      switch (scaleDegree) {
        case 1: return {'maj', 'maj7', 'maj9'};   // I, Imaj7, Imaj9
        case 2: return {'min', 'min7', 'm9'};     // ii, iimin7, iim9
        case 3: return {'min', 'min7', 'm9'};     // iii, iiimin7, iiim9
        case 4: return {'maj', 'maj7', 'maj9'};   // IV, IVmaj7, IVmaj9
        case 5: return {'maj', '7', '9'};         // V, V7, V9 (dominant)
        case 6: return {'min', 'min7', 'm9'};     // vi, vimin7, vim9
        case 7: return {'dim', 'm7b5'};           // vii°, viiø7
        default: return {};
      }
    }
  }

  /// Determines if the current key signature represents a minor key
  bool _isKeyMinor() {
    if (originalKeySignature == null) return false;
    // Use the existing method with a different approach
    return originalKeySignature!.name.contains('Minor') || originalKeySignature!.name.contains('minor');
  }

  /// Gets the root note of the current key signature
  String _getKeyRoot() {
    if (originalKeySignature == null) return 'C';
    
    // Map key signatures to their root notes - complete mapping
    final keyMap = {
      // Sharp keys
      KeySignatureType.cMajor: 'C',
      KeySignatureType.gMajor: 'G',
      KeySignatureType.dMajor: 'D',
      KeySignatureType.aMajor: 'A',
      KeySignatureType.eMajor: 'E',
      KeySignatureType.bMajor: 'B',
      KeySignatureType.fSharpMajor: 'F#',
      KeySignatureType.cSharpMajor: 'C#',
      
      // Flat keys
      KeySignatureType.fMajor: 'F',
      KeySignatureType.bFlatMajor: 'B♭',
      KeySignatureType.eFlatMajor: 'E♭',
      KeySignatureType.aFlatMajor: 'A♭',
      KeySignatureType.dFlatMajor: 'D♭',
      KeySignatureType.gFlatMajor: 'G♭',
      KeySignatureType.cFlatMajor: 'C♭',
      
      // Minor keys
      KeySignatureType.aMinor: 'A',
      KeySignatureType.eMinor: 'E',
      KeySignatureType.bMinor: 'B',
      KeySignatureType.fSharpMinor: 'F#',
      KeySignatureType.cSharpMinor: 'C#',
      KeySignatureType.gSharpMinor: 'G#',
      KeySignatureType.dSharpMinor: 'D#',
      KeySignatureType.aSharpMinor: 'A#',
      KeySignatureType.dMinor: 'D',
      KeySignatureType.gMinor: 'G',
      KeySignatureType.cMinor: 'C',
      KeySignatureType.fMinor: 'F',
      KeySignatureType.bFlatMinor: 'B♭',
      KeySignatureType.eFlatMinor: 'E♭',
      KeySignatureType.aFlatMinor: 'A♭',
    };
    
    return keyMap[originalKeySignature] ?? 'C';
  }

  /// Normalizes a note name to remove accidentals for scale degree calculation
  String _normalizeNoteName(String noteName) {
    return noteName.replaceAll(RegExp(r'[#b]'), '');
  }

  /// Generates the individual notes that make up this chord
  /// Returns a list of Pitch objects representing the chord tones
  List<Pitch> generateChordNotes() {
    // Basic implementation - would expand for full music theory support
    final Map<String, List<int>> qualityIntervals = {
      'maj': [0, 4, 7],
      'min': [0, 3, 7],
      'maj7': [0, 4, 7, 11],
      'min7': [0, 3, 7, 10],
      '7': [0, 4, 7, 10],
      'dim': [0, 3, 6],           // Diminished triad
      'dim7': [0, 3, 6, 9],       // Fully diminished 7th
      'm7b5': [0, 3, 6, 10],      // Half-diminished 7th
      'aug': [0, 4, 8],           // Augmented triad
      'sus4': [0, 5, 7],          // Suspended 4th
      'sus2': [0, 2, 7],          // Suspended 2nd
      'add9': [0, 4, 7, 14],      // Add 9th
      '6': [0, 4, 7, 9],          // Major 6th
      'm6': [0, 3, 7, 9],         // Minor 6th
      // Add more chord qualities as needed
    };

    // Find the root note's pitch
    final rootPitch = _findPitchFromName(effectiveRootName);
    if (rootPitch == null) return [];

    // Get intervals for this quality or use major as fallback
    final intervals = qualityIntervals[effectiveQuality] ?? qualityIntervals['maj']!;

    // Generate the chord notes
    return intervals.map((interval) {
      int rootValue = _midiValueForPitch(rootPitch);
      return _pitchFromMidiValue(rootValue + interval);
    }).toList();
  }

  Pitch? _findPitchFromName(String name) {
    // Default to octave 3 for chord symbols
    final fullName = name + '3';
    try {
      return Pitch.values.firstWhere((p) => p.name == fullName);
    } catch (e) {
      return null;
    }
  }

  int _midiValueForPitch(Pitch pitch) {
    // Simple implementation - would need to be more robust
    final noteName = pitch.name[0];
    final octave = int.parse(pitch.name[1]);

    final noteIndex = ['C', 'D', 'E', 'F', 'G', 'A', 'B'].indexOf(noteName);
    return (octave * 12) + noteIndex + 60; // Middle C (C4) is 60
  }

  Pitch _pitchFromMidiValue(int midiValue) {
    final noteIndex = midiValue % 12;
    final noteName = [
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
    ][noteIndex];

    final fullName = noteName + '3'; // Keep in octave 3
    return Pitch.values
        .firstWhere((p) => p.name == fullName, orElse: () => Pitch.c3);
  }

  /// Get the Roman numeral representation of this chord relative to the given key
  /// [original] - If true, use originalKeySignature; if false, use modifiedKeySignature
  String getRomanNumeral({bool original = true}) {
    final keySignature = original ? originalKeySignature : modifiedKeySignature;
    if (keySignature == null) return '';
    
    return getRomanNumeralWithKey(keySignature);
  }

  /// Get the Roman numeral representation of this chord relative to a specific key
  String getRomanNumeralWithKey(KeySignatureType keySignature) {
    final tonic = _getTonicFromKeySignature(keySignature);
    final chordRoot = _getChordRootMidiValue();
    final tonicMidi = _getMidiValueFromNoteName(tonic);
    
    // Calculate the interval from tonic to chord root
    // Handle negative results properly
    int interval = (chordRoot - tonicMidi) % 12;
    if (interval < 0) interval += 12;
    
    // Determine if we're in a major or minor key
    bool isMinorKey = _isMinorKey(keySignature);
    
    return _intervalToRomanNumeral(interval, isMinorKey);
  }

  /// Get the quality superscript for Roman numeral notation
  /// Uses the unified formatting method
  String getQualitySuperscript() {
    return formatChordQuality(effectiveQuality);
  }

  String _getTonicFromKeySignature(KeySignatureType keySignature) {
    switch (keySignature) {
      case KeySignatureType.cMajor:
      case KeySignatureType.aMinor:
        return keySignature == KeySignatureType.cMajor ? 'C' : 'A';
      case KeySignatureType.gMajor:
      case KeySignatureType.eMinor:
        return keySignature == KeySignatureType.gMajor ? 'G' : 'E';
      case KeySignatureType.dMajor:
      case KeySignatureType.bMinor:
        return keySignature == KeySignatureType.dMajor ? 'D' : 'B';
      case KeySignatureType.aMajor:
      case KeySignatureType.fSharpMinor:
        return keySignature == KeySignatureType.aMajor ? 'A' : 'F#';
      case KeySignatureType.eMajor:
      case KeySignatureType.cSharpMinor:
        return keySignature == KeySignatureType.eMajor ? 'E' : 'C#';
      case KeySignatureType.bMajor:
      case KeySignatureType.gSharpMinor:
        return keySignature == KeySignatureType.bMajor ? 'B' : 'G#';
      case KeySignatureType.fSharpMajor:
      case KeySignatureType.dSharpMinor:
        return keySignature == KeySignatureType.fSharpMajor ? 'F#' : 'D#';
      case KeySignatureType.cSharpMajor:
      case KeySignatureType.aSharpMinor:
        return keySignature == KeySignatureType.cSharpMajor ? 'C#' : 'A#';
      case KeySignatureType.fMajor:
      case KeySignatureType.dMinor:
        return keySignature == KeySignatureType.fMajor ? 'F' : 'D';
      case KeySignatureType.bFlatMajor:
      case KeySignatureType.gMinor:
        return keySignature == KeySignatureType.bFlatMajor ? 'B♭' : 'G';
      case KeySignatureType.eFlatMajor:
      case KeySignatureType.cMinor:
        return keySignature == KeySignatureType.eFlatMajor ? 'E♭' : 'C';
      case KeySignatureType.aFlatMajor:
      case KeySignatureType.fMinor:
        return keySignature == KeySignatureType.aFlatMajor ? 'A♭' : 'F';
      case KeySignatureType.dFlatMajor:
      case KeySignatureType.bFlatMinor:
        return keySignature == KeySignatureType.dFlatMajor ? 'D♭' : 'B♭';
      case KeySignatureType.gFlatMajor:
      case KeySignatureType.eFlatMinor:
        return keySignature == KeySignatureType.gFlatMajor ? 'G♭' : 'E♭';
      case KeySignatureType.cFlatMajor:
      case KeySignatureType.aFlatMinor:
        return keySignature == KeySignatureType.cFlatMajor ? 'C♭' : 'A♭';
    }
  }

  bool _isMinorKey(KeySignatureType keySignature) {
    return keySignature.name.contains('Minor') || keySignature.name.contains('minor');
  }

  int _getChordRootMidiValue() {
    return _getMidiValueFromNoteName(effectiveRootName);
  }

  int _getMidiValueFromNoteName(String noteName) {
    final noteValues = {
      'C': 0, 'C#': 1, 'Db': 1, 'D♭': 1,
      'D': 2, 'D#': 3, 'Eb': 3, 'E♭': 3,
      'E': 4,
      'F': 5, 'F#': 6, 'Gb': 6, 'G♭': 6,
      'G': 7, 'G#': 8, 'Ab': 8, 'A♭': 8,
      'A': 9, 'A#': 10, 'Bb': 10, 'B♭': 10,
      'B': 11, 'Cb': 11, 'C♭': 11
    };
    return noteValues[noteName] ?? 0;
  }

  String _intervalToRomanNumeral(int interval, bool isMinorKey) {
    // First, let's be very explicit about what each interval should map to
    // regardless of key type - we'll adjust case based on chord quality
    
    String baseNumeral;
    
    // Standard chromatic mapping - same for both major and minor keys
    // The difference will be in the expected diatonic degrees and case adjustment
    switch (interval) {
      case 0: baseNumeral = 'I'; break;     // Tonic
      case 1: baseNumeral = '♭II'; break;   // Flat second (Neapolitan)
      case 2: baseNumeral = 'II'; break;    // Second
      case 3: baseNumeral = '♭III'; break;  // Flat third
      case 4: baseNumeral = 'III'; break;   // Third
      case 5: baseNumeral = 'IV'; break;    // Fourth
      case 6: baseNumeral = '♯IV'; break;   // Sharp fourth / Flat fifth (tritone)
      case 7: baseNumeral = 'V'; break;     // Fifth
      case 8: baseNumeral = '♭VI'; break;   // Flat sixth
      case 9: baseNumeral = 'VI'; break;    // Sixth
      case 10: baseNumeral = '♭VII'; break; // Flat seventh
      case 11: baseNumeral = 'VII'; break;  // Seventh
      default: baseNumeral = 'I'; break;    // Fallback
    }
    
    // Adjust case and symbols based on chord quality
    return _adjustRomanNumeralForQuality(baseNumeral, interval, isMinorKey);
  }

  String _adjustRomanNumeralForQuality(String baseNumeral, int interval, bool isMinorKey) {
    // Remove any existing quality symbols from the base numeral
    String cleanNumeral = baseNumeral.replaceAll('°', '').replaceAll('ø', '').replaceAll('+', '');
    
    // Determine if the chord should be uppercase (major-type) or lowercase (minor-type) based on quality
    String result;
    final effectiveQualityValue = effectiveQuality;
    switch (effectiveQualityValue) {
      case 'maj':
      case 'maj7':
      case 'maj9':
      case '6':
      case 'add9':
      case 'sus4':
      case 'sus2':
      case '7':      // Dominant 7th - major triad with minor 7th
      case '9':      // Dominant 9 (major triad)
      case '11':     // Dominant 11 (major triad)
      case '13':     // Dominant 13 (major triad)
      case '7b9':
      case '7#9':
      case '7b5':
      case '7#5':
        // Major-type chords - use uppercase
        result = cleanNumeral.toUpperCase();
        break;
        
      case 'min':
      case 'min7':
      case 'm6':
      case 'm9':
        // Minor-type chords - use lowercase
        result = cleanNumeral.toLowerCase();
        break;
        
      case 'dim':
      case 'dim7':
        // Diminished - lowercase (° goes in superscript)
        result = cleanNumeral.toLowerCase();
        break;
        
      case 'm7b5':
        // Half-diminished - lowercase (ø goes in superscript)
        result = cleanNumeral.toLowerCase();
        break;
        
      case 'aug':
      case 'aug7':
      case '7+':
        // Augmented - uppercase (+ symbol goes in superscript)
        result = cleanNumeral.toUpperCase();
        break;
        
      default:
        // For unknown qualities, analyze the quality string
        if (effectiveQualityValue.contains('m') && !effectiveQualityValue.contains('maj')) {
          result = cleanNumeral.toLowerCase();
        } else if (effectiveQualityValue.contains('dim')) {
          result = cleanNumeral.toLowerCase();
        } else if (effectiveQualityValue.contains('aug') || effectiveQualityValue.contains('+')) {
          result = cleanNumeral.toUpperCase();
        } else {
          result = cleanNumeral.toUpperCase();
        }
        break;
    }
    
    return result;
  }

  /// Returns the display text showing both chord symbol and Roman numeral analysis.
  /// 
  /// Format: "[ChordName][Quality]\n[RomanNumeral]^[QualitySuperscript]"
  /// 
  /// Examples:
  /// - "Cmaj" in C Major -> "Cmaj\nI"
  /// - "G7" in C Major -> "G7\nV^7"  
  /// - "Fmaj7" in C Major -> "Fmaj7\nIV^M7"
  String get displayText {
    final roman = getRomanNumeral();
    final qualitySuperscript = getQualitySuperscript();
    
    if (roman.isEmpty) {
      return '${effectiveRootName}${effectiveQuality}';
    }
    
    final romanWithQuality = qualitySuperscript.isEmpty 
        ? roman 
        : '$roman^$qualitySuperscript';
    
    return '${effectiveRootName}${effectiveQuality}\n$romanWithQuality';
  }
}
