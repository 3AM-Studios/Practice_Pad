import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:music_sheet/src/constants.dart';
import 'package:music_sheet/src/measure/measure_renderer.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/sheet_music_layout.dart';

/// The renderer for a single staff line.
///
/// This is a stateful object that holds and manages the MeasureRenderers for a line.
/// Its job is to render the staff lines and orchestrate the rendering of its measures.
class StaffRenderer {
  final List<MeasureRenderer> measureRendereres;
  final SymbolPositionCallback? symbolPositionCallback;

  StaffRenderer(
    this.measureRendereres, {
    this.symbolPositionCallback,
  });

  /// Renders the staff lines and each measure in this staff line.
  void render(Canvas canvas, Size size, {MusicalSymbol? selectedSymbol}) {
    if (measureRendereres.isNotEmpty) {
      _renderStaffLines(canvas, size);
    }
    
    for (final measureRenderer in measureRendereres) {
      measureRenderer.render(canvas, size, selectedSymbol: selectedSymbol);
    }
  }

  /// Renders the staff lines for the entire staff width.
  void _renderStaffLines(Canvas canvas, Size size) {
    if (measureRendereres.isEmpty) return;
    
    final firstMeasure = measureRendereres.first;
    final lastMeasure = measureRendereres.last;
    final staffLineCenterY = firstMeasure.staffLineCenterY;
    
    // Calculate full width - staff lines should extend to the end of the last measure
    final startX = firstMeasure.measureOriginX;
    final endX = lastMeasure.measureOriginX + lastMeasure.width;
    
    final staffLineHeights = [
      staffLineCenterY - Constants.staffSpace * 2,
      staffLineCenterY - Constants.staffSpace,
      staffLineCenterY,
      staffLineCenterY + Constants.staffSpace,
      staffLineCenterY + Constants.staffSpace * 2,
    ];
    
    final paint = Paint()
      ..color = firstMeasure.layout.lineColor
      ..strokeWidth = firstMeasure.measureMetrics.staffLineThickness;
    
    for (final height in staffLineHeights) {
      canvas.drawLine(
        Offset(startX, height),
        Offset(endX, height),
        paint,
      );
    }
  }
}