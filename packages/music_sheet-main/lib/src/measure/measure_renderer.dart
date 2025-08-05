import 'package:flutter/material.dart';
import 'package:music_sheet/src/constants.dart';
import 'package:music_sheet/src/glyph_metadata.dart';
import 'package:music_sheet/src/glyph_path.dart';
import 'package:music_sheet/src/measure/measure.dart';
import 'package:music_sheet/src/measure/measure_metrics.dart';
import 'package:music_sheet/src/music_objects/clef/clef.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_metrics.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_renderer.dart';
import 'package:music_sheet/src/music_objects/notes/note_pitch.dart';
import 'package:music_sheet/src/sheet_music_layout.dart';
import 'package:music_sheet/src/musical_context.dart';

/// The renderer for a measure in sheet music.
/// This class is now stateful and manages its own layout, allowing for
/// efficient incremental updates.
class MeasureRenderer {
  // Properties needed for initial layout
  final SheetMusicLayout layout;
  double measureOriginX;
  final double staffLineCenterY;
  final Measure measure;
  final SymbolPositionCallback? symbolPositionCallback;

  // Properties needed for recalculating layout
  final MusicalContext musicalContext;
  final GlyphMetadata glyphMetadata;
  final GlyphPaths glyphPaths;

  // Internal state that gets updated
  late MeasureMetrics measureMetrics;
  List<MusicalSymbolRenderer> symbolRenderers = [];
  final Map<MusicalSymbol, Rect> _symbolBounds = {};

  final double? targetWidth;
  final double stretchFactor;

  MeasureRenderer(
    MeasureMetrics initialMeasureMetrics,
    this.layout, {
    required this.measureOriginX,
    required this.staffLineCenterY,
    required this.measure,
    required this.musicalContext,
    required this.glyphMetadata,
    required this.glyphPaths,
    this.symbolPositionCallback,
    this.targetWidth,
    this.stretchFactor = 1.0
  }) {
    // Set the initial metrics and build the renderers for the first time
    measureMetrics = initialMeasureMetrics;
    _buildRenderers();
  }

  /// The CORE METHOD for incremental updates. This recalculates the metrics
  /// and renderers for ONLY this measure.
  void recalculateMetrics(Map<String, MusicalSymbolMetrics> metricsCache) {
    // 1. Recalculate metrics for all symbols in this measure, using the cache.
    final newSymbolMetricsList = <MusicalSymbolMetrics>[];
    for (final symbol in measure.musicalSymbols) {
      if (metricsCache.containsKey(symbol.id)) {
        newSymbolMetricsList.add(metricsCache[symbol.id]!);
      } else {
        final newMetrics = symbol.setContext(musicalContext, glyphMetadata, glyphPaths);
        newSymbolMetricsList.add(newMetrics);
        metricsCache[symbol.id] = newMetrics;
      }
    }

    // 2. Create a new MeasureMetrics object for this measure
    // Note: The isLastMeasure and isNewLine flags would need to be re-evaluated
    // in a full reflow engine. For the fast path, we assume they don't change.
    measureMetrics = MeasureMetrics(
      newSymbolMetricsList,
      glyphMetadata,
      isNewLine: measureMetrics.isNewLine,
      isLastMeasure: measureMetrics.isLastMeasure,
      originalMeasure: measure,
    );

    // 3. Rebuild the list of symbol renderers based on the new metrics.
    _buildRenderers();
  }

  /// Internal helper to create the list of [MusicalSymbolRenderer] objects.
  void _buildRenderers() {
    symbolRenderers.clear();
    if (measureMetrics.symbolMetricsList.isEmpty) return;

    // REMOVE the entire if/else block for targetWidth
    
    // REPLACE with this single, natural spacing logic
    var currentX = 0.0;
    for (final symbolMetric in measureMetrics.symbolMetricsList) {
      // The space for margins and symbols is now stretched
      final margin = symbolMetric.margin;
      currentX += margin.left * stretchFactor;

      final symbolX = measureOriginX + currentX;
      final renderer = symbolMetric.renderer(
        layout,
        staffLineCenterY: staffLineCenterY,
        symbolX: symbolX,
      );
      symbolRenderers.add(renderer);

      currentX += (symbolMetric.width + margin.right) * stretchFactor;
    }
  }
  
  // The 'render' method itself remains largely the same.
  void render(Canvas canvas, Size size, {MusicalSymbol? selectedSymbol}) {
    _symbolBounds.clear(); // Clear layout info from the previous frame

    for (final symbolRenderer in symbolRenderers) {
      final bounds = symbolRenderer.getBounds();
      _symbolBounds[symbolRenderer.musicalSymbol] = bounds;

      if (symbolPositionCallback != null) {
        symbolPositionCallback!(symbolRenderer.musicalSymbol, bounds);
      }

      symbolRenderer.render(canvas);

      if (symbolRenderer.musicalSymbol == selectedSymbol) {
        final paint = Paint()
          ..color = Colors.red.withOpacity(0.5)
          ..style = PaintingStyle.fill;
        canvas.drawRect(bounds, paint);
      }
    }
    _renderBarline(canvas);
  }

  // All other public methods and getters remain the same as they operate on the
  // now-updated internal state (symbolRenderers, measureMetrics, etc.).

  Rect getBounds() {
    if (symbolRenderers.isEmpty) {
      final y = staffLineCenterY - (2 * Constants.staffSpace);
      return Rect.fromLTWH(measureOriginX, y, width, 4 * Constants.staffSpace);
    }
    final firstSymbol = symbolRenderers.first.getBounds();
    return symbolRenderers.skip(1).fold(
        firstSymbol, (prev, element) => prev.expandToInclude(element.getBounds()));
  }

  MusicalSymbol? getSymbolAt(Offset position) {
    for (final entry in _symbolBounds.entries) {
      if (entry.value.contains(position)) {
        return entry.key;
      }
    }
    return null;
  }

  int getInsertionIndexForX(double x) {
    for (var i = 0; i < symbolRenderers.length; i++) {
      final bounds = _symbolBounds[symbolRenderers[i].musicalSymbol];
      if (bounds != null && x < bounds.center.dx) {
        return i;
      }
    }
    return symbolRenderers.length;
  }
  
  Pitch getPitchForY(double y, Clef clef) {
    const centerLineY = 0.0;
    final halfStepY = Constants.staffSpace / 2;
    final stepsFromCenter = -((y - staffLineCenterY - centerLineY) / halfStepY).round();
    final centerLinePitch = clef.centerLinePitch;
    return (stepsFromCenter > 0)
        ? centerLinePitch.upN(stepsFromCenter)
        : centerLinePitch.downN(-stepsFromCenter);
  }

  Rect getHighlightRectForPitch(Pitch pitch, Clef clef) {
    final centerLinePitch = clef.centerLinePitch;
    final stepsFromCenter = pitch.difference(centerLinePitch);
    final halfStepY = Constants.staffSpace / 2;
    final y = staffLineCenterY - (stepsFromCenter * halfStepY);
    final isLine = pitch.isLineNote(clef);
    final top = isLine ? y - halfStepY / 2 : y - halfStepY;
    final bottom = isLine ? y + halfStepY / 2 : y + halfStepY;
    final left = measureOriginX;
    final right = left + width;
    return Rect.fromLTRB(left, top, right, bottom);
  }
  
  double get width => measureMetrics.width * stretchFactor;

  // Drawing helpers

  void _renderBarline(Canvas canvas) {
    final barlineX = measureOriginX + width;
    final paint = Paint()
      ..color = layout.lineColor
      ..strokeWidth = measureMetrics.staffLineThickness;

    if (measureMetrics.isLastMeasure) {
      _drawFinalBarline(canvas, barlineX);
    } else {
      canvas.drawLine(
        Offset(barlineX, staffLineCenterY - 2 * Constants.staffSpace),
        Offset(barlineX, staffLineCenterY + 2 * Constants.staffSpace),
        paint,
      );
    }
  }

  void _drawFinalBarline(Canvas canvas, double barlineX) {
    final thinPaint = Paint()
      ..color = layout.lineColor
      ..strokeWidth = measureMetrics.staffLineThickness;
    final thickPaint = Paint()
      ..color = layout.lineColor
      ..strokeWidth = measureMetrics.staffLineThickness * 3;
    
    final thinBarX = barlineX - measureMetrics.staffLineThickness * 4;
    final thickBarX = barlineX - measureMetrics.staffLineThickness * 1.5;
    final startY = staffLineCenterY - 2 * Constants.staffSpace;
    final endY = staffLineCenterY + 2 * Constants.staffSpace;
    
    // Draw thin line first, then thick line
    canvas.drawLine(Offset(thinBarX, startY), Offset(thinBarX, endY), thinPaint);
    canvas.drawLine(Offset(thickBarX, startY), Offset(thickBarX, endY), thickPaint);
  }
}