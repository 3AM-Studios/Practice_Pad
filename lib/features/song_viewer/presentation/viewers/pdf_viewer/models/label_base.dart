import 'dart:ui';

/// Abstract base class for all label types used in PDF annotations
abstract class Label {
  final String id;
  Offset position;
  bool isSelected;
  double size;
  Color color;
  
  Label({
    required this.id,
    required this.position,
    this.isSelected = false,
    this.size = 25.0,
    this.color = const Color(0xFF2196F3),
  });
  
  /// The display value shown on the label (e.g., "1", "#5", "IV")
  String get displayValue;
  
  /// The type identifier for this label type
  String get labelType;
  
  /// Convert label to JSON for persistence
  Map<String, dynamic> toJson() => {
    'id': id,
    'position': {'dx': position.dx, 'dy': position.dy},
    'displayValue': displayValue,
    'size': size,
    'color': color.value,
    'labelType': labelType,
    'isSelected': isSelected,
  };
  
  /// Create a copy of this label with updated properties
  Label copyWith({
    String? id,
    Offset? position,
    bool? isSelected,
    double? size,
    Color? color,
  });
}

/// Enum for different label types
enum LabelType {
  extension,
  romanNumeral,
}

extension LabelTypeExtension on LabelType {
  String get name {
    switch (this) {
      case LabelType.extension:
        return 'extension';
      case LabelType.romanNumeral:
        return 'romanNumeral';
    }
  }
  
  static LabelType fromString(String value) {
    switch (value) {
      case 'extension':
        return LabelType.extension;
      case 'romanNumeral':
        return LabelType.romanNumeral;
      default:
        throw ArgumentError('Unknown label type: $value');
    }
  }
}