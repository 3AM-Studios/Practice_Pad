import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../image_painter.dart';
import '_signature_painter.dart';
import 'coordinate_transformer.dart';

/// Base label class for PDF annotations
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
    this.size = 10.0,
    this.color = const Color(0xFF2196F3),
  });
  
  String get displayValue;
  String get labelType;
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'position': {'dx': position.dx, 'dy': position.dy},
    'size': size,
    'color': color.value,
    'isSelected': isSelected,
    'labelType': labelType,
  };
}

/// Extension label model for PDF annotations
class ExtensionLabel extends Label {
  String number;
  
  ExtensionLabel({
    required String id,
    required Offset position,
    required this.number,
    bool isSelected = false,
    double size = 10.0,
    Color color = const Color(0xFF2196F3),
  }) : super(
    id: id,
    position: position,
    isSelected: isSelected,
    size: size,
    color: color,
  );
  
  @override
  String get displayValue => number;
  
  @override
  String get labelType => 'extension';
  
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['number'] = number;
    return json;
  }
  
  factory ExtensionLabel.fromJson(Map<String, dynamic> json) => ExtensionLabel(
    id: json['id'] as String,
    position: Offset(
      (json['position']['dx'] as num).toDouble(),
      (json['position']['dy'] as num).toDouble(),
    ),
    number: json['number'] as String,
    size: (json['size'] as num?)?.toDouble() ?? 10.0,
    color: Color((json['color'] as int?) ?? 0xFF2196F3),
    isSelected: json['isSelected'] as bool? ?? false,
  );
}

/// Roman numeral label model for PDF annotations
class RomanNumeralLabel extends Label {
  String romanNumeral;
  
  RomanNumeralLabel({
    required String id,
    required Offset position,
    required this.romanNumeral,
    bool isSelected = false,
    double size = 10.0,
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
  
  factory RomanNumeralLabel.fromJson(Map<String, dynamic> json) => RomanNumeralLabel(
    id: json['id'] as String,
    position: Offset(
      (json['position']['dx'] as num).toDouble(),
      (json['position']['dy'] as num).toDouble(),
    ),
    romanNumeral: json['romanNumeral'] as String? ?? 'I',
    size: (json['size'] as num?)?.toDouble() ?? 10.0,
    color: Color((json['color'] as int?) ?? 0xFF2196F3),
    isSelected: json['isSelected'] as bool? ?? false,
  );
}

class ImagePainterController extends ChangeNotifier {
  late double _strokeWidth;
  late Color _color;
  late PaintMode _mode;
  late String _text;
  late bool _fill;
  late ui.Image? _image;
  Rect _rect = Rect.zero;

  final List<Offset?> _offsets = [];

  final List<PaintInfo> _paintHistory = [];
  final List<Label> _labels = []; // Generic labels list (extension + roman)

  Offset? _start, _end;

  int _strokeMultiplier = 1;
  bool _paintInProgress = false;
  bool _isSignature = false;
  
  // Label state
  Label? _selectedLabel;
  bool _isLabelMode = false;
  String _currentLabelType = 'extension'; // 'extension' or 'romanNumeral'
  
  // Extension label state
  String _currentAccidental = '♮'; // Default to natural symbol
  String _currentNumber = '1';
  
  // Roman numeral state
  String _currentRomanNumeral = 'I';
  String _currentChordText = 'I';
  
  // Shared label state
  double _labelSize = 10.0; // Default label size
  Color _labelColor = const Color(0xFF2196F3); // Default blue color

  ui.Image? get image => _image;

  Paint get brush => Paint()
    ..color = _color
    ..strokeWidth = _strokeWidth * _strokeMultiplier
    ..style = shouldFill ? PaintingStyle.fill : PaintingStyle.stroke;

  PaintMode get mode => _mode;

  double get strokeWidth => _strokeWidth;

  double get scaledStrokeWidth => _strokeWidth * _strokeMultiplier;

  bool get busy => _paintInProgress;

  bool get fill => _fill;

  Color get color => _color;

  List<PaintInfo> get paintHistory => _paintHistory;

  List<Offset?> get offsets => _offsets;

  Offset? get start => _start;

  Offset? get end => _end;

  bool get onTextUpdateMode =>
      _mode == PaintMode.text &&
      _paintHistory
          .where((element) => element.mode == PaintMode.text)
          .isNotEmpty;

  // Label getters
  List<Label> get labels => _labels;
  List<ExtensionLabel> get extensionLabels => _labels.whereType<ExtensionLabel>().toList();
  List<RomanNumeralLabel> get romanNumeralLabels => _labels.whereType<RomanNumeralLabel>().toList();
  Label? get selectedLabel => _selectedLabel;
  bool get isLabelMode => _isLabelMode;
  String get currentLabelType => _currentLabelType;
  
  // Extension label specific getters
  String get currentAccidental => _currentAccidental;
  String get currentNumber => _currentNumber;
  String get currentLabelNumber => _currentAccidental == '♮' ? _currentNumber : '$_currentAccidental$_currentNumber';
  
  // Roman numeral specific getters
  String get currentRomanNumeral => _currentRomanNumeral;
  String get currentChordText => _currentChordText;
  
  // Shared getters
  double get labelSize => _labelSize;
  Color get labelColor => _labelColor;

  ImagePainterController({
    double strokeWidth = 0.3,
    Color color = Colors.red,
    PaintMode mode = PaintMode.freeStyle,
    String text = '',
    bool fill = false,
  }) {
    _strokeWidth = strokeWidth;
    _color = color;
    _mode = mode;
    _text = text;
    _fill = fill;
  }

  void setImage(ui.Image image) {
    _image = image;
    notifyListeners();
  }

  void setRect(Size size) {
    _rect = Rect.fromLTWH(0, 0, size.width, size.height);
    _isSignature = true;
    notifyListeners();
  }

  void addPaintInfo(PaintInfo paintInfo) {
    _paintHistory.add(paintInfo);
    notifyListeners();
  }

  void undo() {
    if (_paintHistory.isNotEmpty) {
      _paintHistory.removeLast();
      notifyListeners();
    }
  }

  void clear() {
    if (_paintHistory.isNotEmpty) {
      _paintHistory.clear();
      notifyListeners();
    }
  }

  void setStrokeWidth(double val) {
    _strokeWidth = val;
    notifyListeners();
  }

  void setColor(Color color) {
    _color = color;
    notifyListeners();
  }

  void setMode(PaintMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void setText(String val) {
    _text = val;
    notifyListeners();
  }

  void addOffsets(Offset? offset) {
    _offsets.add(offset);
    notifyListeners();
  }

  void setStart(Offset? offset) {
    _start = offset;
    notifyListeners();
  }

  void setEnd(Offset? offset) {
    _end = offset;
    notifyListeners();
  }

  void resetStartAndEnd() {
    _start = null;
    _end = null;
    notifyListeners();
  }

  void update({
    double? strokeWidth,
    Color? color,
    bool? fill,
    PaintMode? mode,
    String? text,
    int? strokeMultiplier,
  }) {
    _strokeWidth = strokeWidth ?? _strokeWidth;
    _color = color ?? _color;
    _fill = fill ?? _fill;
    _mode = mode ?? _mode;
    _text = text ?? _text;
    _strokeMultiplier = strokeMultiplier ?? _strokeMultiplier;
    notifyListeners();
  }

  void setInProgress(bool val) {
    _paintInProgress = val;
    notifyListeners();
  }

  bool get shouldFill {
    if (mode == PaintMode.circle || mode == PaintMode.rect) {
      return _fill;
    } else {
      return false;
    }
  }

  /// Generates [Uint8List] of the [ui.Image] generated by the [renderImage()] method.
  /// Can be converted to image file by writing as bytes.
  Future<Uint8List?> _renderImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = DrawImage(controller: this);
    final size = Size(_image!.width.toDouble(), _image!.height.toDouble());
    painter.paint(canvas, size);
    final _convertedImage = await recorder
        .endRecording()
        .toImage(size.width.floor(), size.height.floor());
    final byteData =
        await _convertedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<Uint8List?> _renderSignature() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    SignaturePainter painter =
        SignaturePainter(controller: this, backgroundColor: Colors.blue);

    Size size = Size(_rect.width, _rect.height);

    painter.paint(canvas, size);
    final _convertedImage = await recorder
        .endRecording()
        .toImage(size.width.floor(), size.height.floor());
    final byteData =
        await _convertedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  // Extension label methods
  void setLabelMode(bool isLabelMode) {
    _isLabelMode = isLabelMode;
    if (!isLabelMode) {
      _selectedLabel = null;
      for (final label in _labels) {
        label.isSelected = false;
      }
    }
    notifyListeners();
  }

  void setCurrentAccidental(String accidental) {
    _currentAccidental = accidental;
    if (_selectedLabel != null) {
      if (_selectedLabel is ExtensionLabel) {
        (_selectedLabel as ExtensionLabel).number = currentLabelNumber;
      }
    }
    notifyListeners();
  }

  void setCurrentNumber(String number) {
    _currentNumber = number;
    if (_selectedLabel != null) {
      if (_selectedLabel is ExtensionLabel) {
        (_selectedLabel as ExtensionLabel).number = currentLabelNumber;
      }
    }
    notifyListeners();
  }

  void setCurrentLabelNumber(String number) {
    // This is for backward compatibility - try to parse accidental + number
    if (number.startsWith('#') || number.startsWith('b')) {
      _currentAccidental = number.substring(0, 1);
      _currentNumber = number.substring(1);
    } else if (number == '♮' || number == 'b' || number == '#') {
      _currentAccidental = number;
    } else {
      _currentNumber = number;
    }
    if (_selectedLabel != null) {
      if (_selectedLabel is ExtensionLabel) {
        (_selectedLabel as ExtensionLabel).number = currentLabelNumber;
      }
    }
    notifyListeners();
  }

  void setLabelSize(double size) {
    _labelSize = size.clamp(7.0, 25.0); // Clamp between 7 and 25 pixels
    if (_selectedLabel != null) {
      _selectedLabel!.size = _labelSize;
    }
    notifyListeners();
  }

  void increaseLabelSize() {
    setLabelSize(_labelSize + 1.0);
  }

  void decreaseLabelSize() {
    setLabelSize(_labelSize - 1.0);
  }

  void setLabelColor(Color color) {
    _labelColor = color;
    if (_selectedLabel != null) {
      _selectedLabel!.color = _labelColor;
    }
    notifyListeners();
  }

  void addExtensionLabel(Offset position) {
    if (!_isLabelMode) return;
    
    final label = ExtensionLabel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      position: position,
      number: currentLabelNumber,
      size: _labelSize,
      color: _labelColor,
    );
    
    // Deselect all labels
    for (final l in _labels) {
      l.isSelected = false;
    }
    
    _labels.add(label);
    _selectedLabel = label;
    label.isSelected = true;
    notifyListeners();
  }

  void selectLabel(ExtensionLabel label) {
    // Deselect all labels
    for (final l in _labels) {
      l.isSelected = false;
    }
    // Select the tapped label
    _selectedLabel = label;
    label.isSelected = true;
    notifyListeners();
  }

  void moveLabel(ExtensionLabel label, Offset newPosition) {
    label.position = newPosition;
    notifyListeners();
  }

  void deleteSelectedLabel() {
    if (_selectedLabel != null) {
      _labels.remove(_selectedLabel);
      _selectedLabel = null;
      notifyListeners();
    }
  }

  void clearExtensionLabels() {
    _labels.clear();
    _selectedLabel = null;
    notifyListeners();
  }

  void setExtensionLabels(List<ExtensionLabel> labels) {
    _labels.clear();
    _labels.addAll(labels);
    _selectedLabel = null;
    notifyListeners();
  }

  // Roman numeral methods
  void setCurrentRomanNumeral(String roman) {
    _currentRomanNumeral = roman;
    if (_selectedLabel != null && _selectedLabel is RomanNumeralLabel) {
      (_selectedLabel as RomanNumeralLabel).romanNumeral = roman;
    }
    notifyListeners();
  }

  void setCurrentChordText(String chordText) {
    _currentChordText = chordText;
    _currentRomanNumeral = chordText; // Keep backward compatibility
    if (_selectedLabel != null && _selectedLabel is RomanNumeralLabel) {
      (_selectedLabel as RomanNumeralLabel).romanNumeral = chordText;
    }
    notifyListeners();
  }

  void addRomanNumeralLabel(Offset position) {
    if (!_isLabelMode) return;
    
    final label = RomanNumeralLabel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      position: position,
      romanNumeral: _currentChordText,
      size: _labelSize,
      color: _labelColor,
    );
    
    // Deselect all labels
    for (final l in _labels) {
      l.isSelected = false;
    }
    
    _labels.add(label);
    _selectedLabel = label;
    label.isSelected = true;
    notifyListeners();
  }

  // Generic label methods
  void setLabelType(String type) {
    _currentLabelType = type;
    notifyListeners();
  }

  void selectGenericLabel(Label label) {
    // Deselect all labels
    for (final l in _labels) {
      l.isSelected = false;
    }
    // Select the tapped label
    _selectedLabel = label;
    label.isSelected = true;
    notifyListeners();
  }

  void moveGenericLabel(Label label, Offset newPosition) {
    label.position = newPosition;
    notifyListeners();
  }

  Future<Uint8List?> exportImage() {
    if (_isSignature) {
      return _renderSignature();
    } else {
      return _renderImage();
    }
  }
}

extension ControllerExt on ImagePainterController {
  bool canFill() {
    return mode == PaintMode.circle || mode == PaintMode.rect;
  }
}
