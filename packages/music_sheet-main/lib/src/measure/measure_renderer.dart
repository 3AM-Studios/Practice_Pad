import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_sheet/src/constants.dart';
import 'package:music_sheet/src/measure/measure_metrics.dart';
import 'package:music_sheet/src/music_objects/clef/clef.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_renderer.dart';
import 'package:music_sheet/src/music_objects/notes/note_pitch.dart';
import 'package:music_sheet/src/sheet_music_layout.dart';

/// The renderer for a measure in sheet music.
class MeasureRenderer {
  MeasureRenderer(
    this.symbolRenderers,
    this.measureMetrics,
    this.layout, {
    required this.measureOriginX,
    required this.staffLineCenterY,
    this.symbolPositionCallback,
    this.measure, // Add the measure reference
  });

  final List<MusicalSymbolRenderer> symbolRenderers;
  final MeasureMetrics measureMetrics;
  final double measureOriginX;
  final double staffLineCenterY;
  final dynamic measure; // Reference to the actual measure object

  /// Callback to register the position of a symbol
  SymbolPositionCallback? symbolPositionCallback;

  /// Holds the calculated bounding box for each musical symbol after rendering.
  final Map<MusicalSymbol, Rect> _symbolBounds = {};

  /// A public getter to access the layout information of the symbols.
  Map<MusicalSymbol, Rect> get symbolBounds => _symbolBounds;

  Rect getBounds() {
    if (symbolRenderers.isEmpty) {
      return Rect.zero;
    }
    final firstSymbol = symbolRenderers.first.getBounds();
    return symbolRenderers.skip(1).fold(firstSymbol, (previousValue, element) => previousValue.expandToInclude(element.getBounds()));
  }

  int getInsertionIndexForX(double x) {
    // The symbolRenderers are already ordered from left to right.
    for (var i = 0; i < symbolRenderers.length; i++) {
      final symbolRenderer = symbolRenderers[i];
      // Get the bounds for the corresponding musical symbol.
      final bounds = _symbolBounds[symbolRenderer.musicalSymbol];
      if (bounds != null) {
        // If the tap is to the left of the center of the current symbol,
        // then the new note should be inserted at this symbol's index.
        if (x < bounds.center.dx) {
          return i;
        }
      }
    }
    // If the tap was to the right of all symbols, insert at the end.
    return symbolRenderers.length;
  }

  /// Performs a hit test at the given [position] and returns the corresponding [MusicalSymbolRenderer].
  ///
  /// Returns `null` if no symbol is hit.
  MusicalSymbolRenderer? hitTest(Offset position) {
    for (final object in symbolRenderers) {
      if (object.isHit(position)) {
        return object;
      }
    }
    return null;
  }

  /// Finds which musical symbol is at a given [position].
  ///
  /// This is used to detect if a user interacts with an existing note or symbol.
  /// Returns `null` if no symbol is found at the position.
  MusicalSymbol? getSymbolAt(Offset position) {
    for (final entry in _symbolBounds.entries) {
      if (entry.value.contains(position)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Converts a vertical y-position to the nearest valid musical pitch on the staff.
  ///
  /// This provides the core "snapping" logic for placing notes.
  Pitch getPitchForY(double y, Clef clef) {
    // The y-position of the center line of the staff (e.g., the B line in Treble Clef).
    const centerLineY = 0.0; // The center line is our reference point

    // The vertical distance between each step on the staff (line to space).
    final halfStepY = Constants.staffSpace / 2;

    // Calculate how many half-steps away from the center line the y-position is.
    // A positive value means above the center line, positive means below.
    final stepsFromCenter = -((y - staffLineCenterY - centerLineY) / halfStepY).round();

    // Get the pitch of the center line for the current clef.
    final centerLinePitch = clef.centerLinePitch;

    // Calculate the new pitch by transposing from the center line pitch.
    // We subtract because moving up the staff (decreasing y) increases the pitch.
    if (stepsFromCenter > 0) {
      return centerLinePitch.upN(stepsFromCenter);
    } else {
      return centerLinePitch.downN(-stepsFromCenter);
    }
  }

  /// Renders the measure on the given [canvas] with the specified [size].
  void render(Canvas canvas, Size size) {
    _renderStaffLine(canvas);
    _symbolBounds.clear(); // Clear layout info from the previous frame

    // Render chord symbols first (so they appear above the staff)
    //_renderChordSymbols(canvas, size);

    for (final symbol in symbolRenderers) {
      // Get and store the symbol's bounding box for hit-testing
      final bounds = symbol.getBounds();
      _symbolBounds[symbol.musicalSymbol] = bounds;

      // Register the position of the symbol using the callback
      if (symbolPositionCallback != null) {
        symbolPositionCallback!(symbol.musicalSymbol, bounds);
      }

      // Render the symbol
      symbol.render(canvas);
    }

    _renderBarline(canvas);
  }

  /// Renders chord symbols above the measure if this is a ChordMeasure
  void _renderChordSymbols(Canvas canvas, Size size) {
    // Check if this measure has chord symbols using runtime type checking
    try {
      // Use reflection to check if this measure has chordSymbols
      final dynamic chordSymbols = (measure as dynamic).chordSymbols;

      if (chordSymbols != null &&
          chordSymbols is List &&
          chordSymbols.isNotEmpty) {
        // Render each chord symbol
        for (final dynamic chordSymbol in chordSymbols) {
          if (chordSymbol != null) {
            // Call the render method on the chord symbol
            final renderMethod = chordSymbol.render;
            if (renderMethod != null) {
              renderMethod(
                  canvas, size, measureOriginX, staffLineCenterY, width);
            }
          }
        }
      }
    } catch (e) {
      // This is not a ChordMeasure or doesn't have chord symbols, which is fine
      // Just continue without rendering chord symbols
    }
  }

  void _renderStaffLine(Canvas canvas) {
    final initX = measureOriginX + _barlineSpacing;
    final staffLineHeights = [
      staffLineCenterY - Constants.staffSpace * 2,
      staffLineCenterY - Constants.staffSpace,
      staffLineCenterY,
      staffLineCenterY + Constants.staffSpace,
      staffLineCenterY + Constants.staffSpace * 2,
    ];
    for (final height in staffLineHeights) {
      canvas.drawLine(
        Offset(initX, height),
        Offset(initX + width, height),
        Paint()
          ..color = layout.lineColor
          ..strokeWidth = measureMetrics.staffLineThickness,
      );
    }
  }

  void _renderBarline(Canvas canvas) {
    final barlineX = measureOriginX + width + _barlineSpacing;

    final paint = Paint()
      ..color = layout.lineColor
      ..strokeWidth = measureMetrics.staffLineThickness;

    if (measureMetrics.isLastMeasure) {
      _drawFinalBarline(canvas, barlineX);
    } else {
      // Always draw barline between measures
      canvas.drawLine(
        Offset(barlineX, _barlineStartY),
        Offset(barlineX, _barlineEndY),
        paint,
      );
    }
  }

  /// Draws the final barline with a thick and thin line.
  void _drawFinalBarline(Canvas canvas, double barlineX) {
    final thickPaint = Paint()
      ..color = layout.lineColor
      ..strokeWidth = measureMetrics.staffLineThickness * 3;

    // Calculate spacing dynamically
    final thinBarX = barlineX - measureMetrics.staffLineThickness * 4;
    final thickBarX = barlineX - measureMetrics.staffLineThickness * 1.5;

    // Thin line (left)
    canvas
      ..drawLine(
        Offset(thinBarX, _barlineStartY),
        Offset(thinBarX, _barlineEndY),
        Paint()
          ..color = layout.lineColor
          ..strokeWidth = measureMetrics.staffLineThickness,
      )
      // Thick line (right)
      ..drawLine(
        Offset(thickBarX, _barlineStartY),
        Offset(thickBarX, _barlineEndY),
        thickPaint,
      );
  }

  /// Dynamic spacing for barline padding
  double get _barlineSpacing => measureMetrics.staffLineThickness * 2;

  /// Dynamic start and end Y positions for barlines
  double get _barlineStartY => staffLineCenterY - 2 * Constants.staffSpace;
  double get _barlineEndY => staffLineCenterY + 2 * Constants.staffSpace;

  final SheetMusicLayout layout;

  /// The width of the measure.
  double get width =>
      measureMetrics.objectsWidth + measureMetrics.horizontalMarginSum / scale;

  /// The scale of the measure.
  double get scale => layout.canvasScale;
}