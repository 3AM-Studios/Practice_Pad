import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';

/// Parses text input into ChordSymbol objects
/// 
/// Supports both Roman numeral and chord name input formats
/// with various quality and extension notations
class ChordSymbolParser {
  
  /// Roman numeral patterns (I-VII in both cases)
  static final RegExp _romanNumeralPattern = RegExp(r'^(i{1,3}v?|iv|v|vi{0,2}|VII?)', caseSensitive: false);
  
  /// Chord root note patterns (A-G with optional accidentals)
  static final RegExp _chordNamePattern = RegExp(r'^[A-G][#b♯♭]?');
  
  /// Quality mappings for parsing
  static const Map<String, String> _qualityMappings = {
    // Major qualities
    'maj': 'maj',
    'M': 'maj',
    '': 'maj',
    
    // Minor qualities
    'min': 'min',
    'm': 'min',
    '-': 'min',
    
    // Seventh chords
    '7': '7',
    'dom7': '7',
    'maj7': 'maj7',
    'M7': 'maj7',
    '△7': 'maj7',
    'min7': 'min7',
    'm7': 'min7',
    '-7': 'min7',
    
    // Diminished
    'dim': 'dim',
    '°': 'dim',
    'dim7': 'dim7',
    '°7': 'dim7',
    
    // Half-diminished
    'm7b5': 'm7b5',
    'ø': 'm7b5',
    'ø7': 'm7b5',
    'half-dim': 'm7b5',
    
    // Augmented
    'aug': 'aug',
    '+': 'aug',
    
    // Suspended
    'sus4': 'sus4',
    'sus': 'sus4',
    'sus2': 'sus2',
    
    // Sixths
    '6': '6',
    'm6': 'm6',
    'min6': 'm6',
    
    // Extended chords
    '9': '9',
    'm9': 'm9',
    'min9': 'm9',
    'maj9': 'maj9',
    'M9': 'maj9',
    'add9': 'add9',
    
    // Altered dominants
    '7b9': '7b9',
    '7#9': '7#9',
    '7b5': '7b5',
    '7#5': '7#5',
    '7+5': '7#5',
  };
  
  
  /// Parses a text input string into a ChordSymbol
  /// 
  /// [input] - The text input (e.g., "Imaj7", "ii7", "V7")
  /// 
  /// Returns a ChordSymbol or throws FormatException if parsing fails
  static ChordSymbol parseChordSymbol(String input) {
    if (input.trim().isEmpty) {
      throw const FormatException('Input cannot be empty');
    }
    
    final cleanInput = input.trim();
    
    // Try parsing as Roman numeral first
    final romanMatch = _romanNumeralPattern.firstMatch(cleanInput);
    if (romanMatch != null) {
      return _parseRomanNumeral(cleanInput, romanMatch);
    }
    
    // Try parsing as chord name - convert to Roman numeral display
    final chordNameMatch = _chordNamePattern.firstMatch(cleanInput);
    if (chordNameMatch != null) {
      return _parseChordName(cleanInput, chordNameMatch);
    }
    
    throw FormatException('Invalid chord format: $input');
  }
  
  /// Parses Roman numeral input and returns a ChordSymbol
  static ChordSymbol _parseRomanNumeral(String input, Match romanMatch) {
    final romanNumeral = romanMatch.group(0)!;
    final qualityPart = input.substring(romanMatch.end).trim();
    
    // Parse quality or use default
    String quality;
    if (qualityPart.isNotEmpty) {
      quality = _parseQuality(qualityPart);
    } else {
      // Default quality based on case
      final isUppercase = romanNumeral[0].toUpperCase() == romanNumeral[0];
      quality = isUppercase ? 'maj' : 'min';
    }
    
    // Use C as dummy root since we want Roman numeral display
    return ChordSymbol('C', quality);
  }
  
  /// Parses chord name input and converts to Roman numeral display
  static ChordSymbol _parseChordName(String input, Match chordNameMatch) {
    final rootName = chordNameMatch.group(0)!;
    final qualityPart = input.substring(chordNameMatch.end).trim();
    
    // For chord names, just display them as-is for now
    // Could convert to Roman numerals if we had a key context
    return ChordSymbol(rootName, qualityPart.isNotEmpty ? _parseQuality(qualityPart) : 'maj');
  }
  
  
  /// Parses quality string and handles extensions/alterations
  static String _parseQuality(String qualityInput) {
    String cleanQuality = qualityInput.toLowerCase().trim();
    
    // Handle compound qualities and extensions
    cleanQuality = _processExtensionsAndAlterations(cleanQuality);
    
    // Check for exact match first (important for compound qualities like m7b5)
    if (_qualityMappings.containsKey(cleanQuality)) {
      return _qualityMappings[cleanQuality]!;
    }
    
    // Map to internal quality string using startsWith for partial matches
    for (final entry in _qualityMappings.entries) {
      if (cleanQuality.startsWith(entry.key.toLowerCase())) {
        final baseQuality = entry.value;
        final remainder = cleanQuality.substring(entry.key.length);
        return baseQuality + remainder;
      }
    }
    
    // If no mapping found, return as-is (for extensions like #11, b13)
    return cleanQuality;
  }
  
  /// Processes extensions and alterations in quality string
  static String _processExtensionsAndAlterations(String quality) {
    // Remove spaces first
    quality = quality.replaceAll(' ', '');
    
    // Replace common symbols
    quality = quality
        .replaceAll('♯', '#')
        .replaceAll('♭', 'b')
        .replaceAll('°', 'dim')
        .replaceAll('ø', 'm7b5')
        .replaceAll('△', 'maj')
        .replaceAll('+', 'aug');
    
    // Handle compound alterations for half-diminished FIRST (before individual patterns)
    quality = quality
        .replaceAll('b5b7', 'm7b5')
        .replaceAll('b7b5', 'm7b5')
        .replaceAll('min7b5', 'm7b5');
    
    return quality;
  }
  
}