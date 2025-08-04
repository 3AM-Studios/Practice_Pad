import 'dart:math';

import 'package:flutter/material.dart';
import 'package:music_sheet/src/constants.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/sheet_music_metrics.dart';
import 'package:music_sheet/src/staff/staff_renderer.dart';

/// Callback for registering symbol positions
typedef SymbolPositionCallback = void Function(MusicalSymbol symbol, Rect bounds);

/// Represents the layout of the sheet music.
class SheetMusicLayout {
  SheetMusicLayout(
    this.metrics,
    this.lineColor, {
    required this.widgetHeight,
    required this.widgetWidth,
    this.symbolPositionCallback,
    this.debug = false,

  });

  /// The height of the widget.
  final double widgetHeight;

  /// The width of the widget.
  final double widgetWidth;

  /// The metrics for the sheet music.
  final SheetMusicMetrics metrics;

  /// The color of the lines in the sheet music.
  final Color lineColor;

  /// Whether to render outline around music objects.
  final bool debug;
  
  /// Callback for registering the position of symbols
  final SymbolPositionCallback? symbolPositionCallback;

  /// Cached staff renderers for performance optimization
  List<StaffRenderer>? _cachedStaffRenderers;

  /// The maximum width of a staff.
  double get _maximumStaffWidth => metrics.maximumStaffWidth;

  /// The sum of the horizontal margins of all the staffs.
  double get _maximumStaffHorizontalMarginSum =>
      metrics.maximumStaffHorizontalMarginSum;

  /// The horizontal padding of the sheet music.
  double get _horizontalPadding =>
      widgetWidth -
      (_maximumStaffWidth * canvasScale + _maximumStaffHorizontalMarginSum);

  /// The horizontal padding on the canvas.
  double get _horizontalPaddingOnCanvas => _horizontalPadding / canvasScale;

  /// The left padding on the canvas.
  double get _leftPaddingOnCanvas => _horizontalPaddingOnCanvas / 2;

  /// The vertical padding of the sheet music.
  double get _verticalPadding => widgetHeight - _staffsHeightsSum * canvasScale;

  /// The vertical padding on the canvas.
  double get _verticalPaddingOnCanvas => _verticalPadding / canvasScale;

  /// The upper padding on the canvas.
  double get _upperPaddingOnCanvas => _verticalPaddingOnCanvas / 2;

  /// The list of staff renderers.
  /// Uses caching for performance optimization.
List<StaffRenderer> get staffRenderers {
  // Return cached renderers if available
  if (_cachedStaffRenderers != null) {
    return _cachedStaffRenderers!;
  }
  
  // Generate and cache staff renderers
  var currentY = _upperPaddingOnCanvas;
  _cachedStaffRenderers = metrics.staffsMetricses.asMap().entries.map((entry) {
    final staffMetrics = entry.value;
    
    // Add extra spacing only when the first measure in this staff starts a new line
    // Add extra spacing for all lines after the first
    if (entry.key > 0 && entry.value.measuresMetricses.any((m) => m.isNewLine)) {
      currentY += Constants.staffLineSpacing * 2; // Double the spacing, or use a custom multiplier
    } else {
      currentY += Constants.staffLineSpacing;
    }
    
    currentY += staffMetrics.upperHeight;
    final staffRenderer = staffMetrics.renderer(
      this,
      staffLineCenterY: currentY,
      leftPadding: _leftPaddingOnCanvas,
      symbolPositionCallback: symbolPositionCallback,
    );
    currentY += staffMetrics.lowerHeight;
    return staffRenderer;
  }).toList();
  
  return _cachedStaffRenderers!;
}
  /// The sum of the heights of all the staffs.
  double get _staffsHeightsSum => metrics.staffsHeightSum;

  /// The scale factor for the width of the sheet music.
  double get _widthScale =>
      (widgetWidth - _maximumStaffHorizontalMarginSum) / _maximumStaffWidth;

  /// The scale factor for the height of the sheet music.
  double get _heightScale => widgetHeight / _staffsHeightsSum;

  /// The scale factor for the canvas.
  double get canvasScale => min(_widthScale, _heightScale);

  /// Calculate the total content height including chord symbols and padding
  double get totalContentHeight {
    // Base height: staff heights + vertical padding
    double baseHeight = _staffsHeightsSum * canvasScale;
    
    // Add extra space for chord symbols above each staff
    final chordSymbolHeight = 60.0; // Space for chord symbols
    final numberOfStaffs = metrics.staffsMetricses.length;
    baseHeight += chordSymbolHeight * numberOfStaffs;
    
    // Add some top and bottom padding
    baseHeight += 40.0; // Top padding
    baseHeight += 100.0; // Bottom padding - increased for better scrolling visibility
    
    return baseHeight;
  }

  /// Renders the sheet music on the canvas.
  void render(Canvas canvas, Size size, {MusicalSymbol? symbolToExclude, MusicalSymbol? selectedSymbol}) {
    for (final staff in staffRenderers) {
      staff.render(canvas, size, symbolToExclude: symbolToExclude, selectedSymbol: selectedSymbol);
    }
  }

  /// Clear the cached staff renderers to force regeneration.
  /// Call this when layout parameters change.
  void clearCache() {
    _cachedStaffRenderers = null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SheetMusicLayout) return false;
    
    return other.widgetHeight == widgetHeight &&
           other.widgetWidth == widgetWidth &&
           other.lineColor == lineColor &&
           other.debug == debug &&
           other.metrics == metrics;
  }

  @override
  int get hashCode {
    return Object.hash(
      widgetHeight,
      widgetWidth,
      lineColor,
      debug,
      metrics,
    );
  }
}
