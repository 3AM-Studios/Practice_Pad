import 'dart:ui';
import 'label_base.dart';

/// Roman numeral label for PDF annotations
class RomanNumeralLabel extends Label {
  String romanNumeral; // 'I', 'II', 'III', etc.
  
  RomanNumeralLabel({
    required String id,
    required Offset position,
    required this.romanNumeral,
    bool isSelected = false,
    double size = 25.0,
    Color color = const Color(0xFF2196F3),
  }) : super(
    id: id,
    position: position,
    isSelected: isSelected,
    size: size,
    color: color,
  );
  
  @override
  String get displayValue => romanNumeral;
  
  @override
  String get labelType => 'romanNumeral';
  
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['romanNumeral'] = romanNumeral;
    return json;
  }
  
  factory RomanNumeralLabel.fromJson(Map<String, dynamic> json) {
    return RomanNumeralLabel(
      id: json['id'] as String,
      position: Offset(
        (json['position']['dx'] as num).toDouble(),
        (json['position']['dy'] as num).toDouble(),
      ),
      romanNumeral: json['romanNumeral'] as String? ?? 'I',
      size: (json['size'] as num?)?.toDouble() ?? 25.0,
      color: Color((json['color'] as int?) ?? 0xFF2196F3),
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }
  
  @override
  RomanNumeralLabel copyWith({
    String? id,
    Offset? position,
    bool? isSelected,
    double? size,
    Color? color,
    String? romanNumeral,
  }) {
    return RomanNumeralLabel(
      id: id ?? this.id,
      position: position ?? this.position,
      isSelected: isSelected ?? this.isSelected,
      size: size ?? this.size,
      color: color ?? this.color,
      romanNumeral: romanNumeral ?? this.romanNumeral,
    );
  }
  
  /// Get list of common roman numerals (I-XII)
  static List<String> get commonRomanNumerals => [
    'I', 'II', 'III', 'IV', 'V', 'VI',
    'VII'
  ];
}