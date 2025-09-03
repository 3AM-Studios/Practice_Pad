import 'dart:ui';

import 'package:flutter/material.dart' hide Image;

import 'package:google_fonts/google_fonts.dart';

import 'controller.dart';
import 'coordinate_transformer.dart';

///Handles all the painting ongoing on the canvas.
class DrawImage extends CustomPainter {
  ///The background for signature painting.
  final Color? backgroundColor;
  
  ///Scale factor for labels (for fullscreen mode scaling)
  final double labelScaleFactor;

  ///Coordinate transformer for converting relative to screen coordinates
  final CoordinateTransformer? coordinateTransformer;

  //Controller is a listenable with all of the paint details.
  late ImagePainterController _controller;

  ///Constructor for the canvas
  DrawImage({
    required ImagePainterController controller,
    this.backgroundColor,
    this.labelScaleFactor = 1.0,
    this.coordinateTransformer,
  }) : super(repaint: controller) {
    _controller = controller;
  }

  /// Convert relative coordinate to screen coordinate for rendering
  Offset _relativeToScreen(Offset relativeOffset) {
    if (coordinateTransformer == null) {
      // Fallback: assume coordinates are already screen coordinates
      return relativeOffset;
    }
    return coordinateTransformer!.relativeToScreen(relativeOffset);
  }


  @override
  void paint(Canvas canvas, Size size) {
    // Fill background with backgroundColor if provided
    if (backgroundColor != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = backgroundColor!,
      );
    }

    ///paints [ui.Image] on the canvas for reference to draw over it.
    paintImage(
      canvas: canvas,
      image: _controller.image!,
      filterQuality: FilterQuality.high,
      rect: Rect.fromPoints(
        const Offset(0, 0),
        Offset(size.width, size.height),
      ),
    );

    ///paints all the previoud paintInfo history recorded on [PaintHistory]
    for (final item in _controller.paintHistory) {
      final _offset = item.offsets;
      final _painter = item.paint;
      // Apply unified scaling to stroke width
      // Assume stored strokeWidth is relative to a 1000px baseline image
      if (coordinateTransformer != null) {
        final relativeStrokeWidth = item.strokeWidth / 1000.0; // Convert stored value to relative
        _painter.strokeWidth = coordinateTransformer!.scaleStroke(relativeStrokeWidth);
      }
      switch (item.mode) {
        case PaintMode.rect:
          canvas.drawRect(Rect.fromPoints(_relativeToScreen(_offset[0]!), _relativeToScreen(_offset[1]!)), _painter);
          break;
        case PaintMode.line:
          canvas.drawLine(_relativeToScreen(_offset[0]!), _relativeToScreen(_offset[1]!), _painter);
          break;
        case PaintMode.circle:
          final screenCenter = _relativeToScreen(_offset[1]!);
          final screenStart = _relativeToScreen(_offset[0]!);
          final path = Path();
          path.addOval(
            Rect.fromCircle(
                center: screenCenter,
                radius: (screenStart - screenCenter).distance),
          );
          canvas.drawPath(path, _painter);
          break;
        case PaintMode.arrow:
          drawArrow(canvas, _relativeToScreen(_offset[0]!), _relativeToScreen(_offset[1]!), _painter);
          break;
        case PaintMode.dashLine:
          final screenStart = _relativeToScreen(_offset[0]!);
          final screenEnd = _relativeToScreen(_offset[1]!);
          final path = Path()
            ..moveTo(screenStart.dx, screenStart.dy)
            ..lineTo(screenEnd.dx, screenEnd.dy);
          canvas.drawPath(_dashPath(path, _painter.strokeWidth), _painter);
          break;
        case PaintMode.freeStyle:
          for (int i = 0; i < _offset.length - 1; i++) {
            if (_offset[i] != null && _offset[i + 1] != null) {
              final screenStart = _relativeToScreen(_offset[i]!);
              final screenEnd = _relativeToScreen(_offset[i + 1]!);
              final _path = Path()
                ..moveTo(screenStart.dx, screenStart.dy)
                ..lineTo(screenEnd.dx, screenEnd.dy);
              canvas.drawPath(_path, _painter..strokeCap = StrokeCap.round);
            } else if (_offset[i] != null && _offset[i + 1] == null) {
              canvas.drawPoints(PointMode.points, [_relativeToScreen(_offset[i]!)],
                  _painter..strokeCap = StrokeCap.round);
            }
          }
          break;
        case PaintMode.text:
          final textSpan = TextSpan(
            text: item.text,
            style: TextStyle(
              color: _painter.color,
              fontSize: 6 * _painter.strokeWidth,
              fontWeight: FontWeight.bold,
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout(minWidth: 0, maxWidth: size.width);
          final textOffset = _offset.isEmpty
              ? Offset(size.width / 2 - textPainter.width / 2,
                  size.height / 2 - textPainter.height / 2)
              : () {
                  final screenPos = _relativeToScreen(_offset[0]!);
                  return Offset(screenPos.dx - textPainter.width / 2,
                      screenPos.dy - textPainter.height / 2);
                }();
          textPainter.paint(canvas, textOffset);
          break;
        default:
      }
    }

    ///Draws ongoing action on the canvas while indrag.
    if (_controller.busy) {
      final _start = _controller.start;
      final _end = _controller.end;
      final _paint = _controller.brush;
      // Apply unified scaling to live drawing stroke width  
      // Assume current strokeWidth is relative to a 1000px baseline image
      if (coordinateTransformer != null) {
        final relativeStrokeWidth = _controller.strokeWidth / 1000.0; // Convert current value to relative
        _paint.strokeWidth = coordinateTransformer!.scaleStroke(relativeStrokeWidth);
      }
      switch (_controller.mode) {
        case PaintMode.rect:
          canvas.drawRect(Rect.fromPoints(_relativeToScreen(_start!), _relativeToScreen(_end!)), _paint);
          break;
        case PaintMode.line:
          canvas.drawLine(_relativeToScreen(_start!), _relativeToScreen(_end!), _paint);
          break;
        case PaintMode.circle:
          final screenCenter = _relativeToScreen(_end!);
          final screenStart = _relativeToScreen(_start!);
          final path = Path();
          path.addOval(Rect.fromCircle(
              center: screenCenter, radius: (screenStart - screenCenter).distance));
          canvas.drawPath(path, _paint);
          break;
        case PaintMode.arrow:
          drawArrow(canvas, _relativeToScreen(_start!), _relativeToScreen(_end!), _paint);
          break;
        case PaintMode.dashLine:
          final screenStart = _relativeToScreen(_start!);
          final screenEnd = _relativeToScreen(_end!);
          final path = Path()
            ..moveTo(screenStart.dx, screenStart.dy)
            ..lineTo(screenEnd.dx, screenEnd.dy);
          canvas.drawPath(_dashPath(path, _paint.strokeWidth), _paint);
          break;
        case PaintMode.freeStyle:
          final points = _controller.offsets;
          for (int i = 0; i < _controller.offsets.length - 1; i++) {
            if (points[i] != null && points[i + 1] != null) {
              final screenStart = _relativeToScreen(points[i]!);
              final screenEnd = _relativeToScreen(points[i + 1]!);
              final _path = Path()
                ..moveTo(screenStart.dx, screenStart.dy)
                ..lineTo(screenEnd.dx, screenEnd.dy);
              canvas.drawPath(_path, _paint..strokeCap = StrokeCap.round);
            } else if (points[i] != null && points[i + 1] == null) {
              canvas.drawPoints(PointMode.points, [_relativeToScreen(points[i]!)],
                  _paint..strokeCap = StrokeCap.round);
            }
          }
          break;
        default:
      }
    }

    ///Draws all labels on the canvas.
    for (final label in _controller.labels) {
      _drawLabel(canvas, label);
    }

    ///Draws all the completed actions of painting on the canvas.
  }

  ///Draws line as well as the arrowhead on top of it.
  ///Uses [strokeWidth] of the painter for sizing.
  void drawArrow(Canvas canvas, Offset start, Offset end, Paint painter) {
    final arrowPainter = Paint()
      ..color = painter.color
      ..strokeWidth = painter.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, painter);
    final _pathOffset = painter.strokeWidth / 15;
    final path = Path()
      ..lineTo(-15 * _pathOffset, 10 * _pathOffset)
      ..lineTo(-15 * _pathOffset, -10 * _pathOffset)
      ..close();
    canvas.save();
    canvas.translate(end.dx, end.dy);
    canvas.rotate((end - start).direction);
    canvas.drawPath(path, arrowPainter);
    canvas.restore();
  }

  ///Draws any label on the canvas.
  void _drawLabel(Canvas canvas, Label label) {
    // Convert relative position to screen position
    final screenPosition = _relativeToScreen(label.position);
    
    // Use unified scaling system for font size
    // Convert label.size (stored as absolute) to relative then scale it
    final relativeSize = label.size / 1000.0; // Assume 1000px as baseline reference
    final fontSize = coordinateTransformer?.scaleFont(relativeSize * 0.8) ?? (label.size * labelScaleFactor * 0.8);
    
    // Check if this is a roman numeral that needs superscript formatting
    if (label is RomanNumeralLabel) {
      // For roman numerals, draw selection background if selected
      if (label.isSelected) {
        final textSpan = TextSpan(
          text: label.displayValue,
          style: GoogleFonts.sourceSerif4(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        );
        final tempPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        tempPainter.layout();
        
        final selectionPadding = 6.0 * labelScaleFactor;
        final selectionRect = Rect.fromCenter(
          center: screenPosition,
          width: tempPainter.width + selectionPadding * 2,
          height: tempPainter.height + selectionPadding * 2,
        );
        
        final selectionPaint = Paint()
          ..color = label.color.withOpacity(0.8)
          ..style = PaintingStyle.fill;
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(selectionRect, const Radius.circular(4.0)),
          selectionPaint,
        );
      }
      
      final textColor = label.isSelected ? Colors.white : label.color;
      final relativeBaseLabelSize = label.size / 1000.0; // Convert to relative
      final baseLabelSize = coordinateTransformer?.scaleFont(relativeBaseLabelSize) ?? (label.size * labelScaleFactor);
      _drawRomanNumeralWithSuperscript(canvas, label, screenPosition, textColor, fontSize, baseLabelSize);
    } else {
      // Extension labels - draw with solid color background and white text
      final textSpan = TextSpan(
        text: label.displayValue,
        style: TextStyle(
          color: Colors.white, // Always white text
          fontSize: fontSize,
          fontWeight: FontWeight.w900, // Extra bold for visibility
        ),
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout(minWidth: 0, maxWidth: double.infinity);
      final relativePadding = 0.003;
      // Draw solid color background box - padding scales with font size
      //final boxPadding = (fontSize * 0.15).clamp(1.5, 50.0);
      final boxPadding = coordinateTransformer?.scaleFont(relativePadding) ?? (relativePadding * labelScaleFactor * 1000.0);
      final boxRect = Rect.fromCenter(
        center: screenPosition,
        width: textPainter.width + boxPadding * 2,
        height: textPainter.height + boxPadding * 2,
      );
      
      final boxPaint = Paint()
        ..color = label.color // Always use label color as solid background
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(4.0)),
        boxPaint,
      );
      
      final textOffset = Offset(
        screenPosition.dx - textPainter.width / 2,
        screenPosition.dy - textPainter.height / 2,
      );
      
      textPainter.paint(canvas, textOffset);
    }
  }

  ///Draws roman numeral text with superscript quality
  void _drawRomanNumeralWithSuperscript(Canvas canvas, RomanNumeralLabel label, Offset position, Color textColor, double fontSize, double labelSize) {
    final chordText = label.displayValue;
    
    // Parse accidental, roman numeral, and quality separately
    String accidental = '';
    String baseNumeral = '';
    String quality = '';
    
    String remainingText = chordText;
    
    // First, extract accidental if present
    if (remainingText.startsWith('♯') || remainingText.startsWith('♭')) {
      accidental = remainingText.substring(0, 1);
      remainingText = remainingText.substring(1);
    }
    
    // Then extract roman numeral and quality
    final romanNumeralPattern = RegExp(r'^(i{1,3}v?|iv|v|vi{0,2}|VII?)', caseSensitive: false);
    final romanMatch = romanNumeralPattern.firstMatch(remainingText);
    
    if (romanMatch != null) {
      baseNumeral = romanMatch.group(0)!;
      quality = remainingText.substring(romanMatch.end).trim();
    } else {
      // Fallback: treat entire remaining text as base
      baseNumeral = remainingText;
      quality = '';
    }
    
    // Create separate text painters for each component
    TextPainter? accidentalTextPainter;
    if (accidental.isNotEmpty) {
      final accidentalFontSize = fontSize * 0.7; // Smaller than main text
      accidentalTextPainter = TextPainter(
        text: TextSpan(
          text: accidental,
          style: GoogleFonts.sourceSerif4(
            color: textColor, 
            fontWeight: FontWeight.w600, 
            fontSize: accidentalFontSize
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      accidentalTextPainter.layout(minWidth: 0, maxWidth: double.infinity);
    }
    
    final baseTextPainter = TextPainter(
      text: TextSpan(
        text: baseNumeral,
        style: GoogleFonts.sourceSerif4(
          color: textColor, 
          fontWeight: FontWeight.w600, 
          fontSize: fontSize
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    
    baseTextPainter.layout(minWidth: 0, maxWidth: double.infinity);
    
    TextPainter? qualityTextPainter;
    if (quality.isNotEmpty) {
      final superscriptFontSize = fontSize * 0.5; // Made smaller
      qualityTextPainter = TextPainter(
        text: TextSpan(
          text: quality,
          style: GoogleFonts.sourceSerif4(
            color: textColor, 
            fontWeight: FontWeight.w600, 
            fontSize: superscriptFontSize
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      qualityTextPainter.layout(minWidth: 0, maxWidth: double.infinity);
    }
    
    // Calculate total width and positioning
    final accidentalWidth = accidentalTextPainter?.width ?? 0;
    final baseWidth = baseTextPainter.width;
    final qualityWidth = qualityTextPainter?.width ?? 0;
    final totalWidth = accidentalWidth + baseWidth + qualityWidth;
    
    double currentX = position.dx - totalWidth / 2;
    
    // Draw accidental (smaller and higher)
    if (accidentalTextPainter != null) {
      final accidentalOffset = Offset(
        currentX,
        position.dy - baseTextPainter.height / 2 - fontSize * 0.05, // Higher position
      );
      accidentalTextPainter.paint(canvas, accidentalOffset);
      currentX += accidentalWidth;
    }
    
    // Draw base numeral
    final baseOffset = Offset(
      currentX,
      position.dy - baseTextPainter.height / 2,
    );
    baseTextPainter.paint(canvas, baseOffset);
    currentX += baseWidth;
    
    // Draw superscript quality (offset up and to the right)
    if (qualityTextPainter != null) {
      final qualityOffset = Offset(
        currentX,
        position.dy - baseTextPainter.height / 2 - fontSize * 0.3, // Higher than base
      );
      qualityTextPainter.paint(canvas, qualityOffset);
    }
  }

  ///Draws dashed path.
  ///It depends on [strokeWidth] for space to line proportion.
  Path _dashPath(Path path, double width) {
    final dashPath = Path();
    final dashWidth = 10.0 * width / 5;
    final dashSpace = 10.0 * width / 5;
    var distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth;
        distance += dashSpace;
      }
    }
    return dashPath;
  }

  @override
  bool shouldRepaint(DrawImage oldInfo) {
    return oldInfo._controller != _controller;
  }
}

///All the paint method available for use.

enum PaintMode {
  ///Prefer using [None] while doing scaling operations.
  none,

  ///Allows for drawing freehand shapes or text.
  freeStyle,

  ///Allows to draw line between two points.
  line,

  ///Allows to draw rectangle.
  rect,

  ///Allows to write texts over an image.
  text,

  ///Allows us to draw line with arrow at the end point.
  arrow,

  ///Allows to draw circle from a point.
  circle,

  ///Allows to draw dashed line between two point.
  dashLine
}

///[PaintInfo] keeps track of a single unit of shape, whichever selected.
class PaintInfo {
  ///Mode of the paint method.
  final PaintMode mode;

  //Used to save color
  final Color color;

  //Used to store strokesize of the mode.
  final double strokeWidth;

  ///Used to save offsets.
  ///Two point in case of other shapes and list of points for [FreeStyle].
  List<Offset?> offsets;

  ///Used to save text in case of text type.
  String text;

  //To determine whether the drawn shape is filled or not.
  bool fill;

  Paint get paint => Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = shouldFill ? PaintingStyle.fill : PaintingStyle.stroke;

  bool get shouldFill {
    if (mode == PaintMode.circle || mode == PaintMode.rect) {
      return fill;
    } else {
      return false;
    }
  }

  ///In case of string, it is used to save string value entered.
  PaintInfo({
    required this.mode,
    required this.offsets,
    required this.color,
    required this.strokeWidth,
    this.text = '',
    this.fill = false,
  });
}
