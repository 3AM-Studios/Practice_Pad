/// Model representing a chord progression for practice sessions
/// The chords field stores Roman numerals with quality annotations (e.g., "ii⁻⁷", "V⁷", "Iᵐᵃʲ⁷")
class ChordProgression {
  final String id;
  final String name;
  final List<String> chords; // Roman numerals with qualities (e.g., ["ii⁻⁷", "V⁷", "Iᵐᵃʲ⁷"])
  final String? key;
  final int? tempo;
  final String? timeSignature;
  final List<String>? romanNumerals; // Duplicate storage for compatibility
  
  ChordProgression({
    required this.id,
    required this.name,
    required this.chords,
    this.key,
    this.tempo,
    this.timeSignature,
    this.romanNumerals,
  });
  
  /// Creates a chord progression from JSON data
  factory ChordProgression.fromJson(Map<String, dynamic> json) {
    return ChordProgression(
      id: json['id'] as String,
      name: json['name'] as String,
      chords: List<String>.from(json['chords'] as List),
      key: json['key'] as String?,
      tempo: json['tempo'] as int?,
      timeSignature: json['timeSignature'] as String?,
      romanNumerals: json['romanNumerals'] != null 
          ? List<String>.from(json['romanNumerals'] as List)
          : null,
    );
  }
  
  /// Converts the chord progression to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'chords': chords,
      'key': key,
      'tempo': tempo,
      'timeSignature': timeSignature,
      'romanNumerals': romanNumerals,
    };
  }
  
  /// Generates Roman numeral representation for the chords
  List<String> generateRomanNumerals() {
    if (romanNumerals != null) return romanNumerals!;
    
    // Since chords now store Roman numerals directly, return them as-is
    return chords;
  }
  
  /// Gets the chord at a specific position (with wrapping)
  String getChordAt(int position) {
    if (chords.isEmpty) return '';
    return chords[position % chords.length];
  }
  
  /// Duration in measures (defaults to chord count)
  int get duration => chords.length;
  
  @override
  String toString() {
    return 'ChordProgression(name: $name, romanNumerals: $chords, key: $key)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChordProgression &&
        other.id == id &&
        other.name == name &&
        other.key == key;
  }
  
  @override
  int get hashCode => Object.hash(id, name, key);
}
