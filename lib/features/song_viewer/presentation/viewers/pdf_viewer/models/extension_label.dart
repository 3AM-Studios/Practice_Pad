import 'dart:ui';
import 'label_base.dart';

/// Extension label for PDF annotations with accidental + number system
class ExtensionLabel extends Label {
  String accidental; // '♮', 'b', '#'
  String number;     // '1'-'9'
  
  ExtensionLabel({
    required String id,
    required Offset position,
    required this.accidental,
    required this.number,
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
  String get displayValue => accidental == '♮' ? number : '$accidental$number';
  
  @override
  String get labelType => 'extension';
  
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['accidental'] = accidental;
    json['number'] = number;
    return json;
  }
  
  factory ExtensionLabel.fromJson(Map<String, dynamic> json) {
    // Handle both old format (with 'number' containing combined value) and new format
    String accidental = '♮';
    String number = '1';
    
    if (json.containsKey('accidental') && json.containsKey('number')) {
      // New format
      accidental = json['accidental'] as String;
      number = json['number'] as String;
    } else if (json.containsKey('number')) {
      // Old format - parse combined value
      final combinedNumber = json['number'] as String;
      if (combinedNumber.startsWith('#') || combinedNumber.startsWith('b')) {
        accidental = combinedNumber.substring(0, 1);
        number = combinedNumber.substring(1);
      } else if (combinedNumber == '♮' || combinedNumber == 'b' || combinedNumber == '#') {
        accidental = combinedNumber;
        number = '1';
      } else {
        accidental = '♮';
        number = combinedNumber;
      }
    }
    
    return ExtensionLabel(
      id: json['id'] as String,
      position: Offset(
        (json['position']['dx'] as num).toDouble(),
        (json['position']['dy'] as num).toDouble(),
      ),
      accidental: accidental,
      number: number,
      size: (json['size'] as num?)?.toDouble() ?? 25.0,
      color: Color((json['color'] as int?) ?? 0xFF2196F3),
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }
  
  @override
  ExtensionLabel copyWith({
    String? id,
    Offset? position,
    bool? isSelected,
    double? size,
    Color? color,
    String? accidental,
    String? number,
  }) {
    return ExtensionLabel(
      id: id ?? this.id,
      position: position ?? this.position,
      isSelected: isSelected ?? this.isSelected,
      size: size ?? this.size,
      color: color ?? this.color,
      accidental: accidental ?? this.accidental,
      number: number ?? this.number,
    );
  }
}