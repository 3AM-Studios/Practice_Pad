import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:music_sheet/src/constants.dart';
import 'package:music_sheet/src/extension/list_extension.dart';
import 'package:music_sheet/src/measure/measure_renderer.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_metrics.dart';
import 'package:music_sheet/src/sheet_music_metrics.dart';
import 'package:music_sheet/src/staff/staff_renderer.dart';

/// Callback for registering symbol positions
typedef SymbolPositionCallback = void Function(
    MusicalSymbol symbol, Rect bounds);

/// Represents the layout of the sheet music.
///
/// This is the central "orchestrator" for the visual layout. It takes the calculated
/// metrics and is responsible for building the entire tree of stateful renderer objects,
/// calculating their positions on the canvas, and handling incremental updates.
class SheetMusicLayout with ChangeNotifier {
  final SheetMusicMetrics metrics;
  final Color lineColor;
  final double widgetHeight;
  final double widgetWidth;
  final SymbolPositionCallback? symbolPositionCallback;
  final bool debug;

  /// The final, stateful list of staff renderers. This is the source of truth for drawing.
  late final List<StaffRenderer> staffRenderers;

  SheetMusicLayout(
    this.metrics,
    this.lineColor, {
    required this.widgetHeight,
    required this.widgetWidth,
    this.symbolPositionCallback,
    this.debug = false,
  }) {
    // The entire layout and renderer creation logic now lives here, in the constructor.
    // This work is done only ONCE when the layout is created.
    _buildRenderers();
  }
  void _buildRenderers() {
    final builtStaffRenderers = <StaffRenderer>[];
    var currentY = _upperPaddingOnCanvas;

    for (var i = 0; i < metrics.staffsMetricses.length; i++) {
      final staffMetrics = metrics.staffsMetricses[i];
      if (i > 0) {
        currentY += Constants.staffLineSpacing * 2;
      } else {
        currentY += Constants.staffLineSpacing;
      }

      currentY += staffMetrics.upperHeight;
      final staffLineCenterY = currentY;

      // --- NEW JUSTIFICATION LOGIC ---
      final measuresMetrics = staffMetrics.measuresMetricses;
      if (measuresMetrics.isEmpty) continue;

      // 1. Calculate the total natural width of all measures on the line
      final double naturalTotalWidth = measuresMetrics.map((m) => m.width).sum;

      // 2. Calculate the available width for measures to occupy
      final double availableWidthForMeasures =
          widgetWidth - (_kHorizontalScreenPadding);

      // 3. Calculate the stretch factor
      // Always stretch measures to use more of the available width
      double stretchFactor = 1.5; // Much more aggressive stretch for proper spacing
      if (naturalTotalWidth > 0) {
        final calculatedStretch = availableWidthForMeasures / naturalTotalWidth;
        // Use the larger of calculated stretch or minimum stretch
        stretchFactor = math.max(stretchFactor, calculatedStretch);
      }

      var currentX = _leftPaddingOnCanvas;
      final measureRenderers = <MeasureRenderer>[];

      for (final measureMetrics in measuresMetrics) {
        final measureRenderer = MeasureRenderer(
          measureMetrics,
          this,
          measureOriginX: currentX,
          staffLineCenterY: staffLineCenterY,
          measure: measureMetrics.originalMeasure,
          musicalContext: metrics.musicalContext,
          glyphMetadata: metrics.metadata,
          glyphPaths: metrics.paths,
          symbolPositionCallback: symbolPositionCallback,
          // PASS THE STRETCH FACTOR, NOT targetWidth
          stretchFactor: stretchFactor,
        );
        measureRenderers.add(measureRenderer);
        // The new origin is based on the measure's NEW stretched width
        currentX += measureRenderer.width;
      }
      // --- END OF NEW LOGIC ---

      builtStaffRenderers.add(StaffRenderer(measureRenderers));
      currentY += staffMetrics.lowerHeight;
    }
    staffRenderers = builtStaffRenderers;
  }
  // Define a constant for minimal screen padding
  static const double _kHorizontalScreenPadding = 10.0;

  // The sum of all staff heights.
  double get _staffsHeightsSum => metrics.staffsHeightSum;

  // NO SCALING: Since we're handling width distribution manually, use 1:1 scaling
  double get canvasScale => 1.0;

  // Minimal left padding
  double get _leftPaddingOnCanvas => (_kHorizontalScreenPadding / 2);

  // Public getter for available width in canvas coordinates
  double get availableWidth =>
      (widgetWidth / canvasScale) - (_leftPaddingOnCanvas * 2);

  // The top padding, calculated to center the content vertically.
  double get _upperPaddingOnCanvas {
    final totalScaledHeight = _staffsHeightsSum * canvasScale;
    final remainingVerticalSpace = widgetHeight - totalScaledHeight;
    // Prevent negative padding if content is taller than the widget height
    if (remainingVerticalSpace < 0) return 0;
    return (remainingVerticalSpace / 2) / canvasScale;
  }

  // --- End of corrected logic ---

  double get totalContentHeight {
    double baseHeight = _staffsHeightsSum * canvasScale;
    final chordSymbolHeight = 60.0;
    final numberOfStaffs = metrics.staffsMetricses.length;
    baseHeight += chordSymbolHeight * numberOfStaffs;
    baseHeight += 40.0;
    baseHeight += 100.0;
    return baseHeight;
  }

  // --- INCREMENTAL UPDATE METHODS WITH REFLOW LOGIC ---

  void addSymbolAt(int measureIndex, int positionIndex, MusicalSymbol symbol,
      Map<String, MusicalSymbolMetrics> metricsCache) {
    final measureRenderer =
        staffRenderers.first.measureRendereres[measureIndex];
    final oldWidth = measureRenderer.width;

    // THE FIX: Use the measure's OWN context, not the global one.
    final newMetrics = symbol.setContext(measureRenderer.musicalContext,
        measureRenderer.glyphMetadata, measureRenderer.glyphPaths);
    metricsCache[symbol.id] = newMetrics;

    measureRenderer.measure.musicalSymbols.insert(positionIndex, symbol);
    measureRenderer.recalculateMetrics(metricsCache);

    final newWidth = measureRenderer.width;
    _reflowLineAfterMeasure(measureIndex, newWidth - oldWidth);

    notifyListeners();
  }

  void updateSymbolAt(int measureIndex, int positionIndex,
      MusicalSymbol newSymbol, Map<String, MusicalSymbolMetrics> metricsCache) {
    final measureRenderer =
        staffRenderers.first.measureRendereres[measureIndex];
    final oldWidth = measureRenderer.width;

    // THE FIX: Use the measure's OWN context.
    final newMetrics = newSymbol.setContext(measureRenderer.musicalContext,
        measureRenderer.glyphMetadata, measureRenderer.glyphPaths);
    metricsCache[newSymbol.id] = newMetrics;

    final oldSymbolId =
        measureRenderer.measure.musicalSymbols[positionIndex].id;
    metricsCache.remove(oldSymbolId);

    measureRenderer.measure.musicalSymbols[positionIndex] = newSymbol;
    measureRenderer.recalculateMetrics(metricsCache);

    final newWidth = measureRenderer.width;
    _reflowLineAfterMeasure(measureIndex, newWidth - oldWidth);

    notifyListeners();
  }

  void deleteSymbolAt(int measureIndex, int positionIndex,
      Map<String, MusicalSymbolMetrics> metricsCache) {
    final measureRenderer =
        staffRenderers.first.measureRendereres[measureIndex];
    final oldWidth = measureRenderer.width;

    final symbolToDelete =
        measureRenderer.measure.musicalSymbols[positionIndex];
    metricsCache.remove(symbolToDelete.id);

    measureRenderer.measure.musicalSymbols.removeAt(positionIndex);
    measureRenderer.recalculateMetrics(metricsCache);

    final newWidth = measureRenderer.width;
    _reflowLineAfterMeasure(measureIndex, newWidth - oldWidth);

    notifyListeners();
  }

  /// Helper method to shift subsequent measures on the same line after a width change.
  void _reflowLineAfterMeasure(int measureIndex, double widthDelta) {
    // This simple reflow now works correctly because measureRenderer.width
    // will report its true, stretched width, and the delta will be non-zero.
    if (widthDelta.abs() < 0.01) return;

    final measureRenderers = staffRenderers.first.measureRendereres;
    for (var i = measureIndex + 1; i < measureRenderers.length; i++) {
      measureRenderers[i].measureOriginX += widthDelta;
    }
    
    // IMPORTANT: For a truly robust system, a simple shift is not enough.
    // After a symbol is added/deleted, you should ideally re-run the 
    // justification logic for the entire line to recalculate the stretchFactor
    // and reposition all subsequent measures correctly. For now, this will at least move them.
  }

  void render(Canvas canvas, Size size, {MusicalSymbol? selectedSymbol}) {
    for (final staff in staffRenderers) {
      staff.render(canvas, size, selectedSymbol: selectedSymbol);
    }
  }
}
