import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';

import '_image_painter.dart';
import '_signature_painter.dart';
import 'controller.dart';
import 'delegates/text_delegate.dart';
import 'widgets/_color_widget.dart';
import 'widgets/_mode_widget.dart';
import 'widgets/_range_slider.dart';
import 'widgets/_text_dialog.dart';

export '_image_painter.dart';

@immutable
class MenuButton {
  const MenuButton({
    required this.icon,
    required this.tooltip,
    required this.subButtons,
  });
  final IconData icon;
  final String tooltip;
  final List<SubButton> subButtons;
}

@immutable
class SubButton {
  const SubButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

///[ImagePainter] widget.
@immutable
class ImagePainter extends StatefulWidget {
  const ImagePainter._({
    Key? key,
    required this.controller,
    this.assetPath,
    this.networkUrl,
    this.byteArray,
    this.file,
    this.height,
    this.width,
    this.placeHolder,
    this.isScalable,
    this.brushIcon,
    this.clearAllIcon,
    this.colorIcon,
    this.undoIcon,
    this.isSignature = false,
    this.controlsAtTop = true,
    this.signatureBackgroundColor = Colors.white,
    this.colors,
    this.onColorChanged,
    this.onStrokeWidthChanged,
    this.onPaintModeChanged,
    this.textDelegate,
    this.showControls = true,
    this.controlsBackgroundColor,
    this.optionSelectedColor,
    this.optionUnselectedColor,
    this.optionColor,
    this.onUndo,
    this.onClear,
    this.customMenuButtons,
    this.romanNumeralControlsWidget,
    this.extensionLabelControlsWidget,
  }) : super(key: key);

  ///Constructor for loading image from network url.
  factory ImagePainter.network(
    String url, {
    required ImagePainterController controller,
    Key? key,
    double? height,
    double? width,
    Widget? placeholderWidget,
    bool? scalable,
    List<Color>? colors,
    Widget? brushIcon,
    Widget? undoIcon,
    Widget? clearAllIcon,
    Widget? colorIcon,
    ValueChanged<PaintMode>? onPaintModeChanged,
    ValueChanged<Color>? onColorChanged,
    ValueChanged<double>? onStrokeWidthChanged,
    TextDelegate? textDelegate,
    bool? controlsAtTop,
    bool? showControls,
    Color? controlsBackgroundColor,
    Color? selectedColor,
    Color? unselectedColor,
    Color? optionColor,
    VoidCallback? onUndo,
    VoidCallback? onClear,
    List<MenuButton>? customMenuButtons,
    Widget? romanNumeralControlsWidget,
    Widget? extensionLabelControlsWidget,
  }) {
    return ImagePainter._(
      key: key,
      controller: controller,
      networkUrl: url,
      height: height,
      width: width,
      placeHolder: placeholderWidget,
      isScalable: scalable,
      colors: colors,
      brushIcon: brushIcon,
      undoIcon: undoIcon,
      colorIcon: colorIcon,
      clearAllIcon: clearAllIcon,
      onPaintModeChanged: onPaintModeChanged,
      onColorChanged: onColorChanged,
      onStrokeWidthChanged: onStrokeWidthChanged,
      textDelegate: textDelegate,
      controlsAtTop: controlsAtTop ?? true,
      showControls: showControls ?? true,
      controlsBackgroundColor: controlsBackgroundColor,
      optionSelectedColor: selectedColor,
      optionUnselectedColor: unselectedColor,
      optionColor: optionColor,
      onUndo: onUndo,
      onClear: onClear,
      customMenuButtons: customMenuButtons,
      romanNumeralControlsWidget: romanNumeralControlsWidget,
      extensionLabelControlsWidget: extensionLabelControlsWidget,
    );
  }

  ///Constructor for loading image from assetPath.
  factory ImagePainter.asset(
    String path, {
    required ImagePainterController controller,
    Key? key,
    double? height,
    double? width,
    bool? scalable,
    Widget? placeholderWidget,
    List<Color>? colors,
    Widget? brushIcon,
    Widget? undoIcon,
    Widget? clearAllIcon,
    Widget? colorIcon,
    ValueChanged<PaintMode>? onPaintModeChanged,
    ValueChanged<Color>? onColorChanged,
    ValueChanged<double>? onStrokeWidthChanged,
    TextDelegate? textDelegate,
    bool? controlsAtTop,
    bool? showControls,
    Color? controlsBackgroundColor,
    Color? selectedColor,
    Color? unselectedColor,
    Color? optionColor,
    VoidCallback? onUndo,
    VoidCallback? onClear,
    List<MenuButton>? customMenuButtons,
    Widget? romanNumeralControlsWidget,
    Widget? extensionLabelControlsWidget,
  }) {
    return ImagePainter._(
      controller: controller,
      key: key,
      assetPath: path,
      height: height,
      width: width,
      isScalable: scalable ?? false,
      placeHolder: placeholderWidget,
      colors: colors,
      brushIcon: brushIcon,
      undoIcon: undoIcon,
      colorIcon: colorIcon,
      clearAllIcon: clearAllIcon,
      onPaintModeChanged: onPaintModeChanged,
      onColorChanged: onColorChanged,
      onStrokeWidthChanged: onStrokeWidthChanged,
      textDelegate: textDelegate,
      controlsAtTop: controlsAtTop ?? true,
      showControls: showControls ?? true,
      controlsBackgroundColor: controlsBackgroundColor,
      optionSelectedColor: selectedColor,
      optionUnselectedColor: unselectedColor,
      optionColor: optionColor,
      onUndo: onUndo,
      onClear: onClear,
      customMenuButtons: customMenuButtons,
      romanNumeralControlsWidget: romanNumeralControlsWidget,
      extensionLabelControlsWidget: extensionLabelControlsWidget,
    );
  }

  ///Constructor for loading image from [File].
  factory ImagePainter.file(
    File file, {
    required ImagePainterController controller,
    Key? key,
    double? height,
    double? width,
    bool? scalable,
    Widget? placeholderWidget,
    List<Color>? colors,
    Widget? brushIcon,
    Widget? undoIcon,
    Widget? clearAllIcon,
    Widget? colorIcon,
    ValueChanged<PaintMode>? onPaintModeChanged,
    ValueChanged<Color>? onColorChanged,
    ValueChanged<double>? onStrokeWidthChanged,
    TextDelegate? textDelegate,
    bool? controlsAtTop,
    bool? showControls,
    Color? controlsBackgroundColor,
    Color? selectedColor,
    Color? unselectedColor,
    Color? optionColor,
    VoidCallback? onUndo,
    VoidCallback? onClear,
    List<MenuButton>? customMenuButtons,
    Widget? romanNumeralControlsWidget,
    Widget? extensionLabelControlsWidget,
  }) {
    return ImagePainter._(
      controller: controller,
      key: key,
      file: file,
      height: height,
      width: width,
      placeHolder: placeholderWidget,
      colors: colors,
      isScalable: scalable ?? false,
      brushIcon: brushIcon,
      undoIcon: undoIcon,
      colorIcon: colorIcon,
      clearAllIcon: clearAllIcon,
      onPaintModeChanged: onPaintModeChanged,
      onColorChanged: onColorChanged,
      onStrokeWidthChanged: onStrokeWidthChanged,
      textDelegate: textDelegate,
      controlsAtTop: controlsAtTop ?? true,
      showControls: showControls ?? true,
      controlsBackgroundColor: controlsBackgroundColor,
      optionSelectedColor: selectedColor,
      optionUnselectedColor: unselectedColor,
      optionColor: optionColor,
      onUndo: onUndo,
      onClear: onClear,
      customMenuButtons: customMenuButtons,
      romanNumeralControlsWidget: romanNumeralControlsWidget,
      extensionLabelControlsWidget: extensionLabelControlsWidget,
    );
  }

  ///Constructor for loading image from memory.
  factory ImagePainter.memory(
    Uint8List byteArray, {
    required ImagePainterController controller,
    Key? key,
    double? height,
    double? width,
    bool? scalable,
    Widget? placeholderWidget,
    List<Color>? colors,
    Widget? brushIcon,
    Widget? undoIcon,
    Widget? clearAllIcon,
    Widget? colorIcon,
    ValueChanged<PaintMode>? onPaintModeChanged,
    ValueChanged<Color>? onColorChanged,
    ValueChanged<double>? onStrokeWidthChanged,
    TextDelegate? textDelegate,
    bool? controlsAtTop,
    bool? showControls,
    Color? controlsBackgroundColor,
    Color? selectedColor,
    Color? unselectedColor,
    Color? optionColor,
    VoidCallback? onUndo,
    VoidCallback? onClear,
    List<MenuButton>? customMenuButtons,
    Widget? romanNumeralControlsWidget,
    Widget? extensionLabelControlsWidget,
  }) {
    return ImagePainter._(
      controller: controller,
      key: key,
      byteArray: byteArray,
      height: height,
      width: width,
      placeHolder: placeholderWidget,
      isScalable: scalable ?? false,
      colors: colors,
      brushIcon: brushIcon,
      undoIcon: undoIcon,
      colorIcon: colorIcon,
      clearAllIcon: clearAllIcon,
      onPaintModeChanged: onPaintModeChanged,
      onColorChanged: onColorChanged,
      onStrokeWidthChanged: onStrokeWidthChanged,
      textDelegate: textDelegate,
      controlsAtTop: controlsAtTop ?? true,
      showControls: showControls ?? true,
      controlsBackgroundColor: controlsBackgroundColor,
      optionSelectedColor: selectedColor,
      optionUnselectedColor: unselectedColor,
      optionColor: optionColor,
      onUndo: onUndo,
      onClear: onClear,
      customMenuButtons: customMenuButtons,
      romanNumeralControlsWidget: romanNumeralControlsWidget,
      extensionLabelControlsWidget: extensionLabelControlsWidget,
    );
  }

  ///Constructor for signature painting.
  factory ImagePainter.signature({
    required ImagePainterController controller,
    required double height,
    required double width,
    Key? key,
    Color? signatureBgColor,
    List<Color>? colors,
    Widget? brushIcon,
    Widget? undoIcon,
    Widget? clearAllIcon,
    Widget? colorIcon,
    ValueChanged<PaintMode>? onPaintModeChanged,
    ValueChanged<Color>? onColorChanged,
    ValueChanged<double>? onStrokeWidthChanged,
    TextDelegate? textDelegate,
    bool? controlsAtTop,
    bool? showControls,
    Color? controlsBackgroundColor,
    Color? selectedColor,
    Color? unselectedColor,
    Color? optionColor,
    VoidCallback? onUndo,
    VoidCallback? onClear,
    List<MenuButton>? customMenuButtons,
    Widget? romanNumeralControlsWidget,
    Widget? extensionLabelControlsWidget,
  }) {
    return ImagePainter._(
      controller: controller,
      key: key,
      height: height,
      width: width,
      isSignature: true,
      isScalable: false,
      colors: colors,
      signatureBackgroundColor: signatureBgColor ?? Colors.white,
      brushIcon: brushIcon,
      undoIcon: undoIcon,
      colorIcon: colorIcon,
      clearAllIcon: clearAllIcon,
      onPaintModeChanged: onPaintModeChanged,
      onColorChanged: onColorChanged,
      onStrokeWidthChanged: onStrokeWidthChanged,
      textDelegate: textDelegate,
      controlsAtTop: controlsAtTop ?? true,
      showControls: showControls ?? true,
      controlsBackgroundColor: controlsBackgroundColor,
      optionSelectedColor: selectedColor,
      optionUnselectedColor: unselectedColor,
      optionColor: optionColor,
      onUndo: onUndo,
      onClear: onClear,
      customMenuButtons: customMenuButtons,
      romanNumeralControlsWidget: romanNumeralControlsWidget,
      extensionLabelControlsWidget: extensionLabelControlsWidget,
    );
  }

  /// Class that holds the controller and it's methods.
  final ImagePainterController controller;

  ///Only accessible through [ImagePainter.network] constructor.
  final String? networkUrl;

  ///Only accessible through [ImagePainter.memory] constructor.
  final Uint8List? byteArray;

  ///Only accessible through [ImagePainter.file] constructor.
  final File? file;

  ///Only accessible through [ImagePainter.asset] constructor.
  final String? assetPath;

  ///Height of the Widget. Image is subjected to fit within the given height.
  final double? height;

  ///Width of the widget. Image is subjected to fit within the given width.
  final double? width;

  ///Widget to be shown during the conversion of provided image to [ui.Image].
  final Widget? placeHolder;

  ///Defines whether the widget should be scaled or not. Defaults to [false].
  final bool? isScalable;

  ///Flag to determine signature or image;
  final bool isSignature;

  ///Signature mode background color
  final Color signatureBackgroundColor;

  ///List of colors for color selection
  ///If not provided, default colors are used.
  final List<Color>? colors;

  ///Icon Widget of strokeWidth.
  final Widget? brushIcon;

  ///Widget of Color Icon in control bar.
  final Widget? colorIcon;

  ///Widget for Undo last action on control bar.
  final Widget? undoIcon;

  ///Widget for clearing all actions on control bar.
  final Widget? clearAllIcon;

  ///Define where the controls is located.
  ///`true` represents top.
  final bool controlsAtTop;

  final ValueChanged<Color>? onColorChanged;

  final ValueChanged<double>? onStrokeWidthChanged;

  final ValueChanged<PaintMode>? onPaintModeChanged;

  //the text delegate
  final TextDelegate? textDelegate;

  ///It will control displaying the Control Bar
  final bool showControls;

  final Color? controlsBackgroundColor;

  final Color? optionSelectedColor;

  final Color? optionUnselectedColor;

  final Color? optionColor;

  final VoidCallback? onUndo;

  final VoidCallback? onClear;

  final List<MenuButton>? customMenuButtons;

  ///Custom widget for roman numeral label controls
  final Widget? romanNumeralControlsWidget;

  ///Custom widget for extension label controls  
  final Widget? extensionLabelControlsWidget;

  @override
  ImagePainterState createState() => ImagePainterState();
}

///
class ImagePainterState extends State<ImagePainter> {
  final _repaintKey = GlobalKey();
  ui.Image? _image;
  late final ImagePainterController _controller;
  late final ValueNotifier<bool> _isLoaded;
  late final TextEditingController _textController;
  late final TransformationController _transformationController;

  int _strokeMultiplier = 1;
  late TextDelegate textDelegate;
  
  // Label interaction state
  bool _isDraggingLabel = false;
  Label? _draggedLabel;
  bool _showAllColors = false;
  int _currentPointerCount = 0;
  @override
  void initState() {
    super.initState();
    _isLoaded = ValueNotifier<bool>(false);
    _isMenuOpen = ValueNotifier<bool>(false);
    _currentMenuLevel = ValueNotifier<String>('closed');
    _controller = widget.controller;
    if (widget.isSignature) {
      _controller.update(
        mode: PaintMode.freeStyle,
        color: Colors.black,
      );
      _controller.setRect(Size(widget.width!, widget.height!));
    }
    _resolveAndConvertImage();
    _textController = TextEditingController();
    _transformationController = TransformationController();
    textDelegate = widget.textDelegate ?? TextDelegate();
  }

  @override
  void dispose() {
    _controller.dispose();
    _isLoaded.dispose();
    _isMenuOpen.dispose();
    _currentMenuLevel.dispose();
    _textController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  bool get isEdited => _controller.paintHistory.isNotEmpty;

  Size get imageSize =>
      Size(_image?.width.toDouble() ?? 0, _image?.height.toDouble() ?? 0);

  ///Converts the incoming image type from constructor to [ui.Image]
  Future<void> _resolveAndConvertImage() async {
    if (widget.networkUrl != null) {
      _image = await _loadNetworkImage(widget.networkUrl!);
      if (_image != null) {
        _controller.setImage(_image!);
        _setStrokeMultiplier();
      } else {
        throw ("${widget.networkUrl} couldn't be resolved.");
      }
    } else if (widget.assetPath != null) {
      final img = await rootBundle.load(widget.assetPath!);
      _image = await _convertImage(Uint8List.view(img.buffer));
      if (_image != null) {
        _controller.setImage(_image!);
        _setStrokeMultiplier();
      } else {
        throw ("${widget.assetPath} couldn't be resolved.");
      }
    } else if (widget.file != null) {
      final img = await widget.file!.readAsBytes();
      _image = await _convertImage(img);
      if (_image != null) {
        _controller.setImage(_image!);
        _setStrokeMultiplier();
      } else {
        throw ("Image couldn't be resolved from provided file.");
      }
    } else if (widget.byteArray != null) {
      _image = await _convertImage(widget.byteArray!);
      if (_image != null) {
        _controller.setImage(_image!);
        _setStrokeMultiplier();
      } else {
        throw ("Image couldn't be resolved from provided byteArray.");
      }
    } else {
      _isLoaded.value = true;
    }
  }

  ///Dynamically sets stroke multiplier on the basis of widget size.
  ///Implemented to avoid thin stroke on high res images.
  _setStrokeMultiplier() {
    if ((_image!.height + _image!.width) > 1000) {
      _strokeMultiplier = (_image!.height + _image!.width) ~/ 1000;
    }
    _controller.update(strokeMultiplier: _strokeMultiplier);
  }

  ///Completer function to convert asset or file image to [ui.Image] before drawing on custompainter.
  Future<ui.Image> _convertImage(Uint8List img) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(img, (image) {
      _isLoaded.value = true;
      return completer.complete(image);
    });
    return completer.future;
  }

  ///Completer function to convert network image to [ui.Image] before drawing on custompainter.
  Future<ui.Image> _loadNetworkImage(String path) async {
    final completer = Completer<ImageInfo>();
    final img = NetworkImage(path);
    img.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((info, _) => completer.complete(info)));
    final imageInfo = await completer.future;
    _isLoaded.value = true;
    return imageInfo.image;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoaded,
      builder: (_, loaded, __) {
        if (loaded) {
          return widget.isSignature ? _paintSignature() : _paintImage();
        } else {
          return Container(
            height: widget.height ?? double.maxFinite,
            width: widget.width ?? double.maxFinite,
            child: Center(
              child: widget.placeHolder ?? const CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }

  ///paints image on given constrains for drawing if image is not null.
  Widget _paintImage() {
    return Container(
      height: widget.height ?? double.maxFinite,
      width: widget.width ?? double.maxFinite,
      child: Stack(
        children: [
          Column(
            children: [
              if (widget.controlsAtTop && widget.showControls) _buildTopControlsRow(),
              Expanded(
                child:
                AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return InteractiveViewer(
                        transformationController: _transformationController,
                        maxScale: 5.0,
                        minScale: 0.8,
                        panEnabled: (_currentMenuLevel.value == 'closed' || _currentMenuLevel.value == 'main' || _currentPointerCount > 1) && !_isDraggingLabel,
                        scaleEnabled: widget.isScalable!,
                        boundaryMargin: const EdgeInsets.all(20),
                        onInteractionStart: _scaleStartGesture,
                        onInteractionUpdate: _scaleUpdateGesture,
                        onInteractionEnd: _scaleEndGesture,
                        child: Container(
                          width: double.infinity,
                          child: AspectRatio(
                            aspectRatio: imageSize.width / imageSize.height,
                            child: CustomPaint(
                              size: imageSize,
                              willChange: true,
                              isComplex: true,
                              painter: DrawImage(
                                controller: _controller,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SizedBox(height: MediaQuery.of(context).padding.bottom)
            ],
          ),
          if (!widget.controlsAtTop && widget.showControls) _buildControls(),
        ],
      ),
    );
  }

  Widget _paintSignature() {
    return Stack(
      children: [
        RepaintBoundary(
          key: _repaintKey,
          child: ClipRect(
            child: Container(
              width: widget.width ?? double.maxFinite,
              height: widget.height ?? double.maxFinite,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  return InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: false,
                    scaleEnabled: false,
                    onInteractionStart: _scaleStartGesture,
                    onInteractionUpdate: _scaleUpdateGesture,
                    onInteractionEnd: _scaleEndGesture,
                    child: CustomPaint(
                      willChange: true,
                      isComplex: true,
                      painter: SignaturePainter(
                        backgroundColor: widget.signatureBackgroundColor,
                        controller: _controller,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.showControls)
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: textDelegate.undo,
                  icon: widget.undoIcon ??
                      Icon(Icons.reply, color: Colors.grey[700]),
                  onPressed: () => _controller.undo(),
                ),
                IconButton(
                  tooltip: textDelegate.clearAllProgress,
                  icon: widget.clearAllIcon ??
                      Icon(Icons.clear, color: Colors.grey[700]),
                  onPressed: () => _controller.clear(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  _scaleStartGesture(ScaleStartDetails onStart) {
    // Track current pointer count
    setState(() {
      _currentPointerCount = onStart.pointerCount;
    });
    
    // Don't handle gestures if multi-touch (panning/zooming) or not in active drawing/label modes
    if (onStart.pointerCount > 1 || (_currentMenuLevel.value != 'drawing' && _currentMenuLevel.value != 'extension_labels' && _currentMenuLevel.value != 'roman_labels')) {
      return;
    }
    
    final _zoomAdjustedOffset =
        _transformationController.toScene(onStart.localFocalPoint);
    final _imageOffset = _convertToImageCoordinates(_zoomAdjustedOffset);
    
    _isDraggingLabel = false;
    _draggedLabel = null;
    
    if (!widget.isSignature) {
      // Handle extension label mode
      if (_controller.isLabelMode && _currentMenuLevel.value == 'extension_labels') {
        // Check if tapping on existing extension label first
        ExtensionLabel? tappedLabel;
        for (final label in _controller.extensionLabels) {
          // Check if tap is within square label bounds
          final labelBounds = Rect.fromCenter(
            center: label.position,
            width: label.size,
            height: label.size,
          );
          if (labelBounds.contains(_imageOffset)) {
            tappedLabel = label;
            break;
          }
        }
        
        if (tappedLabel != null) {
          // Select the tapped label and prepare for potential drag
          _controller.selectGenericLabel(tappedLabel);
          _draggedLabel = tappedLabel;
        } else {
          // Add new extension label at tap position
          _controller.addExtensionLabel(_imageOffset);
        }
      } else if (_controller.isLabelMode && _currentMenuLevel.value == 'roman_labels') {
        // Handle Roman numeral label tapping/creation
        Label? tappedLabel;
        for (final label in _controller.labels) {
          final labelBounds = Rect.fromCenter(
            center: label.position,
            width: label.size,
            height: label.size,
          );
          if (labelBounds.contains(_imageOffset)) {
            tappedLabel = label;
            break;
          }
        }
        
        if (tappedLabel != null) {
          // Select the tapped label and prepare for potential drag
          _controller.selectGenericLabel(tappedLabel);
          _draggedLabel = tappedLabel;
        } else {
          // Add new Roman numeral label at tap position
          _controller.addRomanNumeralLabel(_imageOffset);
        }
      } else if (_currentMenuLevel.value == 'drawing') {
        // Check if tapping on label in drawing mode (to prevent drawing on labels)
        for (final label in _controller.extensionLabels) {
          final labelBounds = Rect.fromCenter(
            center: label.position,
            width: label.size,
            height: label.size,
          );
          if (labelBounds.contains(_imageOffset)) {
            return; // Don't start drawing if tapping on a label
          }
        }
        // Normal drawing mode - only when drawing menu is open
        _controller.setStart(_imageOffset);
        _controller.addOffsets(_imageOffset);
      }
    }
  }

  ///Fires while user is interacting with the screen to record painting.
  void _scaleUpdateGesture(ScaleUpdateDetails onUpdate) {
    // Don't handle update if multi-touch or not in active drawing/label modes
    if (_currentPointerCount > 1 || (_currentMenuLevel.value != 'drawing' && _currentMenuLevel.value != 'extension_labels' && _currentMenuLevel.value != 'roman_labels')) {
      return;
    }
    final _zoomAdjustedOffset =
        _transformationController.toScene(onUpdate.localFocalPoint);
    final _imageOffset = _convertToImageCoordinates(_zoomAdjustedOffset);
    
    if (_controller.isLabelMode && (_currentMenuLevel.value == 'extension_labels' || _currentMenuLevel.value == 'roman_labels') && _draggedLabel != null) {
      // Only start dragging if we've moved enough to indicate intent to drag
      if (!_isDraggingLabel) {
        final startOffset = _draggedLabel!.position;
        final distance = (_imageOffset - startOffset).distance;
        if (distance > 5.0) { // Threshold to distinguish tap from drag
          setState(() {
            _isDraggingLabel = true;
          });
        }
      }
      
      if (_isDraggingLabel) {
        // Move the dragged label
        _controller.moveGenericLabel(_draggedLabel!, _imageOffset);
      }
    } else if (_currentMenuLevel.value == 'drawing') {
      // Check if dragging on any label (to prevent drawing on labels)
      bool isDraggingOnLabel = false;
      for (final label in _controller.extensionLabels) {
        final labelBounds = Rect.fromCenter(
          center: label.position,
          width: label.size,
          height: label.size,
        );
        if (labelBounds.contains(_imageOffset)) {
          isDraggingOnLabel = true;
          break;
        }
      }
      
      if (!isDraggingOnLabel) {
        // Normal drawing mode - only when drawing menu is open
        _controller.setInProgress(true);
        if (_controller.start == null) {
          _controller.setStart(_imageOffset);
        }
        _controller.setEnd(_imageOffset);
        if (_controller.mode == PaintMode.freeStyle) {
          _controller.addOffsets(_imageOffset);
        }
        if (_controller.onTextUpdateMode) {
          _controller.paintHistory
              .lastWhere((element) => element.mode == PaintMode.text)
              .offsets = [_imageOffset];
        }
      }
    }
  }

  ///Fires when user stops interacting with the screen.
  void _scaleEndGesture(ScaleEndDetails onEnd) {
    // Reset interaction state
    setState(() {
      _isDraggingLabel = false;
      _draggedLabel = null;
      _currentPointerCount = 0;
    });
    
    _controller.setInProgress(false);
    if (_controller.start != null &&
        _controller.end != null &&
        (_controller.mode == PaintMode.freeStyle)) {
      _controller.addOffsets(null);
      _addFreeStylePoints();
      _controller.offsets.clear();
    } else if (_controller.start != null &&
        _controller.end != null &&
        _controller.mode != PaintMode.text) {
      _addEndPoints();
    }
    _controller.resetStartAndEnd();
  }

  void _addEndPoints() => _addPaintHistory(
        PaintInfo(
          offsets: <Offset?>[_controller.start, _controller.end],
          mode: _controller.mode,
          color: _controller.color,
          strokeWidth: _controller.scaledStrokeWidth,
          fill: _controller.fill,
        ),
      );

  void _addFreeStylePoints() => _addPaintHistory(
        PaintInfo(
          offsets: <Offset?>[..._controller.offsets],
          mode: PaintMode.freeStyle,
          color: _controller.color,
          strokeWidth: _controller.scaledStrokeWidth,
        ),
      );

  Widget _buildTopControlsRow() {
    return Container(
      padding: const EdgeInsets.all(4),
      color: widget.controlsBackgroundColor ?? Colors.grey[200],
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final icon = paintModes(textDelegate)
                  .firstWhere((item) => item.mode == _controller.mode)
                  .icon;
              return PopupMenuButton(
                tooltip: textDelegate.changeMode,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
                surfaceTintColor: Colors.transparent,
                icon: Icon(icon, color: widget.optionColor ?? Colors.grey[700]),
                itemBuilder: (_) => [_showOptionsRowPopup()],
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return PopupMenuButton(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                surfaceTintColor: Colors.transparent,
                tooltip: textDelegate.changeColor,
                icon: widget.colorIcon ??
                    Container(
                      padding: const EdgeInsets.all(2.0),
                      height: 24,
                      width: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                        color: _controller.color,
                      ),
                    ),
                itemBuilder: (_) => [_showColorPickerPopup()],
              );
            },
          ),
          PopupMenuButton(
            tooltip: textDelegate.changeBrushSize,
            surfaceTintColor: Colors.transparent,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon:
                widget.brushIcon ?? Icon(Icons.brush, color: Colors.grey[700]),
            itemBuilder: (_) => [_showRangeSliderPopup()],
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              if (_controller.canFill()) {
                return Row(
                  children: [
                    Checkbox(
                      value: _controller.shouldFill,
                      onChanged: (val) {
                        _controller.update(fill: val);
                      },
                    ),
                    Text(
                      textDelegate.fill,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  ],
                );
              } else {
                return const SizedBox();
              }
            },
          ),
          const Spacer(),
          IconButton(
            tooltip: textDelegate.undo,
            icon: widget.undoIcon ?? Icon(Icons.reply, color: Colors.grey[700]),
            onPressed: () {
              widget.onUndo?.call();
              _controller.undo();
            },
          ),
          IconButton(
            tooltip: textDelegate.clearAllProgress,
            icon: widget.clearAllIcon ??
                Icon(Icons.clear, color: Colors.grey[700]),
            onPressed: () {
              widget.onClear?.call();
              _controller.clear();
            },
          ),
        ],
      ),
    );
  }

  PopupMenuItem _showOptionsRowPopup() {
    return PopupMenuItem(
      enabled: false,
      child: Center(
        child: SizedBox(
          child: Wrap(
            children: paintModes(textDelegate)
                .map(
                  (item) => SelectionItems(
                    data: item,
                    isSelected: _controller.mode == item.mode,
                    selectedColor: widget.optionSelectedColor,
                    unselectedColor: widget.optionUnselectedColor,
                    onTap: () {
                      if (widget.onPaintModeChanged != null) {
                        widget.onPaintModeChanged!(item.mode);
                      }
                      _controller.setMode(item.mode);

                      Navigator.of(context).pop();
                      if (item.mode == PaintMode.text) {
                        _openTextDialog();
                      }
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  PopupMenuItem _showRangeSliderPopup() {
    return PopupMenuItem(
      enabled: false,
      child: SizedBox(
        width: double.maxFinite,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return RangedSlider(
              value: _controller.strokeWidth,
              onChanged: (value) {
                _controller.setStrokeWidth(value);
                if (widget.onStrokeWidthChanged != null) {
                  widget.onStrokeWidthChanged!(value);
                }
              },
            );
          },
        ),
      ),
    );
  }

  PopupMenuItem _showColorPickerPopup() {
    return PopupMenuItem(
      enabled: false,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: (widget.colors ?? editorColors).map((color) {
            return ColorItem(
              isSelected: color == _controller.color,
              color: color,
              onTap: () {
                _controller.setColor(color);
                if (widget.onColorChanged != null) {
                  widget.onColorChanged!(color);
                }
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _addPaintHistory(PaintInfo info) {
    if (info.mode != PaintMode.none) {
      _controller.addPaintInfo(info);
    }
  }

  void _openTextDialog() {
    _controller.setMode(PaintMode.text);
    final fontSize = 6 * _controller.strokeWidth;
    TextDialog.show(
      context,
      _textController,
      fontSize,
      _controller.color,
      textDelegate,
      onFinished: (context) {
        if (_textController.text.isNotEmpty) {
          _addPaintHistory(
            PaintInfo(
              mode: PaintMode.text,
              text: _textController.text,
              offsets: [],
              color: _controller.color,
              strokeWidth: _controller.scaledStrokeWidth,
            ),
          );
          _textController.clear();
        }
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 80,
      left: 16,
      child: _buildVerticalMenu(),
    );
  }

  late ValueNotifier<bool> _isMenuOpen;
  late ValueNotifier<String> _currentMenuLevel; // 'closed', 'main', 'drawing', 'custom_X'
  String? _currentCustomButtonIndex;

  Widget _buildVerticalMenu() {
    return ValueListenableBuilder<String>(
      valueListenable: _currentMenuLevel,
      builder: (context, menuLevel, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show different menu levels
            if (menuLevel == 'main') ...[
              // Main menu level - show main category buttons
              ..._buildMainMenuButtons(),
            ] else if (menuLevel == 'drawing') ...[
              // Drawing controls level
              ..._buildDrawingControlButtons(),
            ] else if (menuLevel == 'label_types') ...[
              // Label type selection level
              ..._buildLabelTypeButtons(),
            ] else if (menuLevel == 'extension_labels') ...[
              // Extension label controls level - use custom widget if provided
              if (widget.extensionLabelControlsWidget != null) 
                widget.extensionLabelControlsWidget!
              else 
                ..._buildLabelControlButtons(),
            ] else if (menuLevel == 'roman_labels') ...[
              // Roman numeral label controls level - use custom widget if provided
              if (widget.romanNumeralControlsWidget != null) 
                widget.romanNumeralControlsWidget!
              else 
                ..._buildRomanNumeralControlButtons(),
            ] else if (menuLevel.startsWith('custom_')) ...[
              // Custom button sub-menu
              ..._buildCustomButtonSubMenu(menuLevel),
            ],
            
            // Main menu toggle button (circle)
            _buildClayButton(
              icon: Icon(_getMainButtonIcon(menuLevel)),
              onPressed: () => _handleMainButtonPress(menuLevel),
              tooltip: _getMainButtonTooltip(menuLevel),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildMainMenuButtons() {
    List<Widget> buttons = [
      // Drawing button
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _buildClayButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            _currentMenuLevel.value = 'drawing';
            // Set to freeStyle (pen) by default for immediate drawing
            _controller.setMode(PaintMode.freeStyle);
          },
          tooltip: 'Drawing Tools',
        ),
      ),
      // Labels button
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _buildClayButton(
          icon: const Icon(Icons.label),
          onPressed: () {
            _currentMenuLevel.value = 'label_types';
            // Don't enter label mode yet - let user select type first
          },
          tooltip: 'Labels',
        ),
      ),
    ];

    // Add custom menu buttons
    if (widget.customMenuButtons != null) {
      for (int i = 0; i < widget.customMenuButtons!.length; i++) {
        final customButton = widget.customMenuButtons![i];
        buttons.add(
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildClayButton(
              icon: Icon(customButton.icon),
              onPressed: () {
                _currentCustomButtonIndex = i.toString();
                _currentMenuLevel.value = 'custom_$i';
              },
              tooltip: customButton.tooltip,
            ),
          ),
        );
      }
    }

    return buttons;
  }

  List<Widget> _buildCustomButtonSubMenu(String menuLevel) {
    final index = int.parse(menuLevel.replaceFirst('custom_', ''));
    if (widget.customMenuButtons == null || index >= widget.customMenuButtons!.length) {
      return [];
    }

    final customButton = widget.customMenuButtons![index];
    return customButton.subButtons.map((subButton) => 
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _buildClayButton(
          icon: Icon(subButton.icon),
          onPressed: subButton.onPressed,
          tooltip: subButton.tooltip,
        ),
      ),
    ).toList();
  }

  List<Widget> _buildDrawingControlButtons() {
    return [
      // Mode selector
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final icon = paintModes(textDelegate)
                .firstWhere((item) => item.mode == _controller.mode)
                .icon;
            return _buildClayMenuButton(
              icon: Icon(icon, color: widget.optionColor ?? Colors.grey[700]),
              onPressed: _showModeMenu,
              tooltip: textDelegate.changeMode,
            );
          },
        ),
      ),
      
      // Color picker
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return _buildClayMenuButton(
              icon: widget.colorIcon ??
                  Container(
                    padding: const EdgeInsets.all(2.0),
                    height: 24,
                    width: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                      color: _controller.color,
                    ),
                  ),
              onPressed: _showColorMenu,
              tooltip: textDelegate.changeColor,
            );
          },
        ),
      ),
      
      // Brush size
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _buildClayMenuButton(
          icon: widget.brushIcon ?? Icon(Icons.brush, color: Colors.grey[700]),
          onPressed: _showBrushMenu,
          tooltip: textDelegate.changeBrushSize,
        ),
      ),
      
      // Undo button
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _buildClayButton(
          icon: widget.undoIcon ?? Icon(Icons.reply, color: Colors.grey[700]),
          onPressed: () {
            widget.onUndo?.call();
            _controller.undo();
          },
          tooltip: textDelegate.undo,
        ),
      ),
      
      // Clear all button
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _buildClayButton(
          icon: widget.clearAllIcon ?? Icon(Icons.clear, color: Colors.grey[700]),
          onPressed: () {
            widget.onClear?.call();
            _controller.clear();
          },
          tooltip: textDelegate.clearAllProgress,
        ),
      ),
      
      // Fill option (if applicable)
      AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          if (_controller.canFill()) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: _buildClayCheckbox(),
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    ];
  }

  List<Widget> _buildLabelControlButtons() {
    return [
      // TOP SECTION: Colors and Delete button
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Compact color picker
            Row(
              children: [
                // Current color button that shows/hides all colors
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    return _buildClayButton(
                      icon: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                          color: _controller.labelColor,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _showAllColors = !_showAllColors;
                        });
                      },
                      tooltip: 'Color',
                    );
                  },
                ),
                // Expandable color options
                if (_showAllColors) ...[
                  const SizedBox(width: 8),
                  _buildColorButton(const Color(0xFF2196F3)), // Blue
                  const SizedBox(width: 4),
                  _buildColorButton(const Color(0xFF4CAF50)), // Green
                  const SizedBox(width: 4),
                  _buildColorButton(const Color(0xFFFF9800)), // Orange
                  const SizedBox(width: 4),
                  _buildColorButton(const Color(0xFFF44336)), // Red
                  const SizedBox(width: 4),
                  _buildColorButton(const Color(0xFF9C27B0)), // Purple
                  const SizedBox(width: 4),
                  _buildColorButton(const Color(0xFFFFFFFF)), // White
                ],
              ],
            ),
            // Delete button (if label selected)
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                if (_controller.selectedLabel != null) {
                  return _buildClayButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () {
                      _controller.deleteSelectedLabel();
                    },
                    tooltip: 'Delete Label',
                  );
                } else {
                  return const SizedBox(width: 40); // Placeholder to maintain layout
                }
              },
            ),
          ],
        ),
      ),
      
      // Size controls
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildClayButton(
              icon: const Icon(Icons.remove, size: 16),
              onPressed: () {
                _controller.decreaseLabelSize();
              },
              tooltip: 'Decrease Size',
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_controller.labelSize.round()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            _buildClayButton(
              icon: const Icon(Icons.add, size: 16),
              onPressed: () {
                _controller.increaseLabelSize();
              },
              tooltip: 'Increase Size',
            ),
          ],
        ),
      ),
      
      // Accidental buttons row (♮, b, #)
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAccidentalButton('♮'),
            _buildAccidentalButton('b'),
            _buildAccidentalButton('#'),
          ],
        ),
      ),
      
      // BOTTOM SECTION: Number pad (3x3 grid)
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            // Numbers 1-9 in 3x3 grid
            for (int row = 0; row < 3; row++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (int col = 0; col < 3; col++)
                      _buildNumberButton('${row * 3 + col + 1}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _buildAccidentalButton(String accidental) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final isSelected = _controller.currentAccidental == accidental;
        return Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(2),
          child: _buildClayButton(
            icon: Text(
              accidental,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected 
                    ? Colors.blue
                    : Colors.grey[700],
              ),
            ),
            onPressed: () {
              _controller.setCurrentAccidental(accidental);
            },
            tooltip: 'Accidental $accidental',
          ),
        );
      },
    );
  }

  Widget _buildNumberButton(String number) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final isSelected = _controller.currentNumber == number;
        return Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(2),
          child: _buildClayButton(
            icon: Text(
              number,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected 
                    ? Colors.blue
                    : Colors.grey[700],
              ),
            ),
            onPressed: () {
              _controller.setCurrentNumber(number);
            },
            tooltip: 'Number $number',
          ),
        );
      },
    );
  }

  Widget _buildColorButton(Color color) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final isSelected = _controller.labelColor == color;
        final isTransparent = color.opacity == 0;
        
        return Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(2),
          child: _buildClayButton(
            icon: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isTransparent ? Colors.white : color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.grey,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected ? [
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ] : null,
              ),
              child: isTransparent ? const Center(
                child: Icon(
                  Icons.clear,
                  size: 16,
                  color: Colors.grey,
                ),
              ) : null,
            ),
            onPressed: () {
              _controller.setLabelColor(color);
            },
            tooltip: isTransparent ? 'Clear' : 'Color',
          ),
        );
      },
    );
  }

  /// Build label type selection buttons
  List<Widget> _buildLabelTypeButtons() {
    return [
      // Extension Labels button
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _buildClayButton(
          icon: const Icon(Icons.numbers),
          onPressed: () {
            _currentMenuLevel.value = 'extension_labels';
            _controller.setLabelMode(true);
          },
          tooltip: 'Extension Labels (♮,b,#)',
        ),
      ),
      // Roman Numeral Labels button
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _buildClayButton(
          icon: const Icon(Icons.format_list_numbered_rtl),
          onPressed: () {
            _currentMenuLevel.value = 'roman_labels';
            _controller.setLabelMode(true);
          },
          tooltip: 'Roman Numerals (I,II,III...)',
        ),
      ),
    ];
  }

  /// Build Roman numeral label control buttons
  List<Widget> _buildRomanNumeralControlButtons() {
    return [
      // Text input for chord text
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 40,
        child: TextField(
          controller: TextEditingController(text: _controller.currentChordText),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: 'Chord (e.g., I, ii, V7, viø7)',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            filled: true,
            fillColor: Colors.grey[100],
          ),
          onChanged: (value) => _controller.setCurrentChordText(value),
        ),
      ),

      // Row 1: Quality modifiers and Delete button
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildModifierButton('7th', () => _controller.setCurrentChordText(_addSeventh(_controller.currentChordText))),
              const SizedBox(width: 6),
              _buildModifierButton('Maj', () => _controller.setCurrentChordText(_applyQuality(_getBaseNumeral(_controller.currentChordText), 'Maj'))),
              const SizedBox(width: 6),
              _buildModifierButton('Min', () => _controller.setCurrentChordText(_applyQuality(_getBaseNumeral(_controller.currentChordText), 'Min'))),
              const SizedBox(width: 6),
              _buildModifierButton('ø', () => _controller.setCurrentChordText(_applyQuality(_getBaseNumeral(_controller.currentChordText), 'ø'))),
              const SizedBox(width: 6),
              _buildModifierButton('°', () => _controller.setCurrentChordText(_applyQuality(_getBaseNumeral(_controller.currentChordText), 'o'))),
              const SizedBox(width: 12),
              // Delete button
              if (_controller.selectedLabel != null && _controller.selectedLabel is RomanNumeralLabel)
                _buildClayButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  onPressed: () => _controller.deleteSelectedLabel(),
                  tooltip: 'Delete Label',
                ),
            ],
          ),
        ),
      ),

      // Row 2: Roman numeral buttons
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            // First row: I-VI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final numeral in ['I', 'II', 'III', 'IV', 'V', 'VI'])
                  _buildRomanNumeralButton(numeral),
              ],
            ),
            const SizedBox(height: 6),
            // Second row: VII (centered)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRomanNumeralButton('VII'),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  IconData _getMainButtonIcon(String menuLevel) {
    if (menuLevel.startsWith('custom_')) {
      return Icons.arrow_back;
    }
    switch (menuLevel) {
      case 'main':
        return Icons.close;
      case 'drawing':
        return Icons.arrow_back;
      case 'label_types':
      case 'extension_labels':
      case 'roman_labels':
        return Icons.arrow_back;
      case 'closed':
      default:
        return Icons.add;
    }
  }

  String _getMainButtonTooltip(String menuLevel) {
    if (menuLevel.startsWith('custom_')) {
      return 'Back to Main Menu';
    }
    switch (menuLevel) {
      case 'main':
        return 'Close Menu';
      case 'drawing':
        return 'Back to Main Menu';
      case 'label_types':
      case 'extension_labels':
      case 'roman_labels':
        return 'Back to Main Menu';
      case 'closed':
      default:
        return 'Open Menu';
    }
  }

  void _handleMainButtonPress(String menuLevel) {
    if (menuLevel.startsWith('custom_')) {
      _currentMenuLevel.value = 'main';
      return;
    }
    
    switch (menuLevel) {
      case 'closed':
        _currentMenuLevel.value = 'main';
        break;
      case 'main':
        _currentMenuLevel.value = 'closed';
        break;
      case 'drawing':
        _currentMenuLevel.value = 'main';
        // Disable drawing mode when leaving drawing controls
        _controller.setMode(PaintMode.none);
        break;
      case 'label_types':
      case 'extension_labels':
      case 'roman_labels':
        _currentMenuLevel.value = 'main';
        // Handle different back navigation for different label menu levels
        if (menuLevel == 'label_types') {
          _currentMenuLevel.value = 'main';
        } else {
          // extension_labels or roman_labels go back to label_types
          _currentMenuLevel.value = 'label_types';
          _controller.setLabelMode(false);
        }
        break;
    }
  }

  /// Convert widget coordinates to image coordinates accounting for AspectRatio scaling
  Offset _convertToImageCoordinates(Offset widgetOffset) {
    // The AspectRatio widget scales the CustomPaint to fit within the available space
    // We need to map the widget coordinates back to the original image coordinates
    return Offset(
      widgetOffset.dx,
      widgetOffset.dy,
    );
  }

  Widget _buildClayButton({
    required Widget icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return FloatingActionButton(
      mini: true,
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 8,
      tooltip: tooltip,
      child: icon,
    );
  }

  Widget _buildClayMenuButton({
    required Widget icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return FloatingActionButton(
      mini: true,
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 8,
      tooltip: tooltip,
      child: icon,
    );
  }

  Widget _buildClayCheckbox() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: _controller.shouldFill,
            onChanged: (val) {
              _controller.update(fill: val);
            },
          ),
          Text(
            textDelegate.fill,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        ],
      ),
    );
  }

  void _showModeMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(textDelegate.changeMode),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: paintModes(textDelegate).map((item) => 
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                selected: _controller.mode == item.mode,
                onTap: () {
                  if (widget.onPaintModeChanged != null) {
                    widget.onPaintModeChanged!(item.mode);
                  }
                  _controller.setMode(item.mode);
                  Navigator.of(context).pop();
                  if (item.mode == PaintMode.text) {
                    _openTextDialog();
                  }
                },
              ),
            ).toList(),
          ),
        ),
      ),
    );
  }

  void _showColorMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(textDelegate.changeColor),
        content: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: (widget.colors ?? editorColors).map((color) {
            return GestureDetector(
              onTap: () {
                _controller.setColor(color);
                if (widget.onColorChanged != null) {
                  widget.onColorChanged!(color);
                }
                Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color == _controller.color ? Colors.grey.shade800 : Colors.grey.shade300,
                    width: color == _controller.color ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showBrushMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(textDelegate.changeBrushSize),
        content: StatefulBuilder(
          builder: (context, setState) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Brush Size: ${_controller.strokeWidth.toInt()}'),
                    Slider(
                      value: _controller.strokeWidth,
                      min: 1.0,
                      max: 20.0,
                      divisions: 19,
                      onChanged: (value) {
                        _controller.setStrokeWidth(value);
                        if (widget.onStrokeWidthChanged != null) {
                          widget.onStrokeWidthChanged!(value);
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Helper methods for Roman numeral chord editing
  String _getBaseNumeral(String chord) {
    String text = chord;
    // Remove quality indicators and seventh
    text = text.replaceAll('7', '');
    text = text.replaceAll('ø', '');
    text = text.replaceAll('°', '');
    
    // Convert to uppercase to get base
    String base = text.toUpperCase();
    return base.isNotEmpty ? base : 'I';
  }

  String _applyQuality(String base, String quality) {
    switch (quality) {
      case 'Maj':
        return base.toUpperCase();
      case 'Min':
        return base.toLowerCase();
      case 'ø':
        return '${base.toLowerCase()}ø';
      case 'o':
        return '${base.toLowerCase()}°';
      default:
        return base.toUpperCase();
    }
  }

  String _addSeventh(String chord) {
    if (chord.contains('7')) {
      return chord.replaceAll('7', ''); // Remove if already has 7th
    } else {
      return '${chord}7'; // Add 7th
    }
  }

  Widget _buildModifierButton(String label, VoidCallback onPressed) {
    return Container(
      height: 32,
      child: FloatingActionButton(
        mini: true,
        onPressed: onPressed,
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.grey[700],
        elevation: 4,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRomanNumeralButton(String numeral) {
    final isCurrentBase = _getBaseNumeral(_controller.currentChordText).toUpperCase() == numeral;
    
    return Container(
      width: 40,
      height: 32,
      child: FloatingActionButton(
        mini: true,
        onPressed: () {
          final currentQuality = _getCurrentQuality(_controller.currentChordText);
          final hasSeventh = _controller.currentChordText.contains('7');
          String newChord = _applyQuality(numeral, currentQuality);
          if (hasSeventh) newChord += '7';
          _controller.setCurrentChordText(newChord);
        },
        backgroundColor: isCurrentBase ? Colors.blue[100] : Colors.grey[200],
        foregroundColor: isCurrentBase ? Colors.blue[800] : Colors.grey[700],
        elevation: isCurrentBase ? 2 : 4,
        child: Text(
          numeral,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getCurrentQuality(String chord) {
    if (chord.contains('ø')) return 'ø';
    if (chord.contains('°')) return 'o';
    if (chord == chord.toLowerCase() && chord.isNotEmpty) return 'Min';
    return 'Maj';
  }
}
