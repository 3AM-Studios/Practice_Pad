import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:simple_sheet_music/src/constants.dart';
import 'package:simple_sheet_music/src/measure/measure_metrics.dart';
import 'package:simple_sheet_music/src/music_objects/interface/musical_symbol_renderer.dart';
import 'package:simple_sheet_music/src/sheet_music_layout.dart';

/// The renderer for a measure in sheet music.
class MeasureRenderer {
  const MeasureRenderer(
    this.symbolRenderers,
    this.measureMetrics,
    this.layout, {
    required this.measureOriginX,
    required this.staffLineCenterY,
    this.chordSymbols = const [], // Support multiple chord symbols
  });

  final List<MusicalSymbolRenderer> symbolRenderers;
  final MeasureMetrics measureMetrics;
  final double measureOriginX;
  final double staffLineCenterY;
  final List<dynamic> chordSymbols; // Multiple chord symbols for this measure

  // /// Performs a hit test at the given [position] and returns the corresponding [MusicalSymbolRenderer].
  // ///
  // /// Returns `null` if no symbol is hit.
  // MusicalSymbolRenderer? hitTest(Offset position) {
  //   for (final object in symbolRenderers) {
  //     if (object.isHit(position)) {
  //       return object;
  //     }
  //   }
  //   return null;
  // }

  /// Renders the measure on the given [canvas] with the specified [size].
  void render(Canvas canvas, Size size) {
    _renderStaffLine(canvas);
    
    // // Render chord symbols above the measure
    // for (final chordSymbol in chordSymbols) {
    //   if (chordSymbol != null && chordSymbol.render != null) {
    //     chordSymbol.render(canvas, size, measureOriginX, staffLineCenterY, width);
    //   }
    // }
    
    // Render musical symbols
    for (final symbol in symbolRenderers) {
      symbol.render(canvas);
    }

    // Add bar line at the end of the measure
    _renderBarLine(canvas);
  }

  void _renderStaffLine(Canvas canvas) {
    final initX = measureOriginX;
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

  void _renderBarLine(Canvas canvas) {
    final barLineX = measureOriginX + width - Constants.staffSpace * 0.2; // Small margin before bar line
    
    // Draw vertical bar line at the end of the measure
    canvas.drawLine(
      Offset(barLineX, staffLineCenterY - Constants.staffSpace * 2),
      Offset(barLineX, staffLineCenterY + Constants.staffSpace * 2),
      Paint()
        ..color = layout.lineColor
        ..strokeWidth = measureMetrics.staffLineThickness * 1.2, // Slightly thicker for bar lines
    );
  }

  final SheetMusicLayout layout;

  /// The width of the measure.
  double get width =>
      measureMetrics.objectsWidth + measureMetrics.horizontalMarginSum / scale;

  /// The scale of the measure.
  double get scale => layout.canvasScale;
}
