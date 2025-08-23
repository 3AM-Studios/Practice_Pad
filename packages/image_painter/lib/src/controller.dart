import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../image_painter.dart';
import '_signature_painter.dart';

/// Extension label model for PDF annotations
class ExtensionLabel {
  final String id;
  Offset position;
  String number;
  bool isSelected;
  double size;
  Color color;
  
  ExtensionLabel({
    required this.id,
    required this.position,
    required this.number,
    this.isSelected = false,
    this.size = 25.0,
    this.color = const Color(0xFF2196F3),
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'position': {'dx': position.dx, 'dy': position.dy},
    'number': number,
    'size': size,
    'color': color.value,
  };
  
  factory ExtensionLabel.fromJson(Map<String, dynamic> json) => ExtensionLabel(
    id: json['id'] as String,
    position: Offset(
      (json['position']['dx'] as num).toDouble(),
      (json['position']['dy'] as num).toDouble(),
    ),
    number: json['number'] as String,
    size: (json['size'] as num?)?.toDouble() ?? 25.0,
    color: Color((json['color'] as int?) ?? 0xFF2196F3),
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
  final List<ExtensionLabel> _extensionLabels = [];

  Offset? _start, _end;

  int _strokeMultiplier = 1;
  bool _paintInProgress = false;
  bool _isSignature = false;
  
  // Extension label state
  ExtensionLabel? _selectedLabel;
  bool _isLabelMode = false;
  String _currentAccidental = '♮'; // Default to natural symbol
  String _currentNumber = '1';
  double _labelSize = 25.0; // Default label size
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

  // Extension label getters
  List<ExtensionLabel> get extensionLabels => _extensionLabels;
  ExtensionLabel? get selectedLabel => _selectedLabel;
  bool get isLabelMode => _isLabelMode;
  String get currentAccidental => _currentAccidental;
  String get currentNumber => _currentNumber;
  String get currentLabelNumber => _currentAccidental == '♮' ? _currentNumber : '$_currentAccidental$_currentNumber';
  double get labelSize => _labelSize;
  Color get labelColor => _labelColor;

  ImagePainterController({
    double strokeWidth = 4.0,
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
      for (final label in _extensionLabels) {
        label.isSelected = false;
      }
    }
    notifyListeners();
  }

  void setCurrentAccidental(String accidental) {
    _currentAccidental = accidental;
    if (_selectedLabel != null) {
      _selectedLabel!.number = currentLabelNumber;
    }
    notifyListeners();
  }

  void setCurrentNumber(String number) {
    _currentNumber = number;
    if (_selectedLabel != null) {
      _selectedLabel!.number = currentLabelNumber;
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
      _selectedLabel!.number = currentLabelNumber;
    }
    notifyListeners();
  }

  void setLabelSize(double size) {
    _labelSize = size.clamp(10.0, 50.0); // Clamp between 10 and 50 pixels
    if (_selectedLabel != null) {
      _selectedLabel!.size = _labelSize;
    }
    notifyListeners();
  }

  void increaseLabelSize() {
    setLabelSize(_labelSize + 2.0);
  }

  void decreaseLabelSize() {
    setLabelSize(_labelSize - 2.0);
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
    for (final l in _extensionLabels) {
      l.isSelected = false;
    }
    
    _extensionLabels.add(label);
    _selectedLabel = label;
    label.isSelected = true;
    notifyListeners();
  }

  void selectLabel(ExtensionLabel label) {
    // Deselect all labels
    for (final l in _extensionLabels) {
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
      _extensionLabels.remove(_selectedLabel);
      _selectedLabel = null;
      notifyListeners();
    }
  }

  void clearExtensionLabels() {
    _extensionLabels.clear();
    _selectedLabel = null;
    notifyListeners();
  }

  void setExtensionLabels(List<ExtensionLabel> labels) {
    _extensionLabels.clear();
    _extensionLabels.addAll(labels);
    _selectedLabel = null;
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
