import 'dart:math';

import 'package:music_sheet/src/extension/list_extension.dart';
import 'package:music_sheet/src/glyph_metadata.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_metrics.dart';

/// Represents the calculated metrics of a single measure in sheet music.
///
/// This is a pure data class. Its responsibility is to hold the aggregate
/// properties (like total width and height) of a measure based on the symbols
/// it contains. It is no longer responsible for creating renderers.
class MeasureMetrics {
  /// The [symbolMetricsList] is a list of [MusicalSymbolMetrics]
  /// representing the metrics of each musical symbol in the measure.
  ///
  /// The [metadata] is a [GlyphMetadata] object containing metadata for the measure.
  ///
  /// The [isNewLine] parameter indicates whether a line break should occur in this measure.
  ///
  /// The [originalMeasure] parameter is the original measure object for access to additional properties.
  const MeasureMetrics(
    this.symbolMetricsList,
    this.metadata, {
    required this.isNewLine,
    this.isLastMeasure = false,
    this.originalMeasure,
  });

  /// The list of [MusicalSymbolMetrics] for each symbol in the measure.
  final List<MusicalSymbolMetrics> symbolMetricsList;

  /// The [GlyphMetadata] object containing metadata for the measure.
  final GlyphMetadata metadata;

  /// Indicates whether a line break should occur in this measure.
  final bool isNewLine;

  /// Indicates whether this measure is the last measure in the sheet music.
  final bool isLastMeasure;

  /// Reference to the original measure object for access to additional properties.
  final dynamic originalMeasure;

  /// Gets the total width of all the musical symbols in the measure, including margins.
  double get width {
    final objectsTotalWidth = symbolMetricsList.map((symbol) => symbol.width).sum;
    final marginsTotalWidth = horizontalMarginSum;
    return objectsTotalWidth + marginsTotalWidth;
  }

  /// Gets the maximum upper height among all the musical symbols in the measure.
  double get _symbolMaximumUpperHeight =>
      symbolMetricsList.map((symbol) => symbol.upperHeight).max;

  /// Returns the height of the upper part of the measure.
  double get _measureUpperHeight => metadata.measureUpperHeight;



  /// Returns the maximum height of the measure upper part.
  double get upperHeight => max(_symbolMaximumUpperHeight, _measureUpperHeight);

  /// Gets the maximum lower height among all the musical symbols in the measure.
  double get _symbolMaximumLowerHeight =>
      symbolMetricsList.map((symbol) => symbol.lowerHeight).max;

  /// Returns the height of the lower part of the measure.
  double get _measureLowerHeight => metadata.measureLowerHeight;

  /// Returns the maximum height of the measure lower part.
  double get lowerHeight => max(_symbolMaximumLowerHeight, _measureLowerHeight);



  /// Gets the sum of the horizontal margins of all the musical symbols in the measure.
  double get horizontalMarginSum =>
      symbolMetricsList.map((symbol) => symbol.margin.horizontal).sum;

  /// Gets the thickness of the staff lines in the measure.
  double get staffLineThickness => metadata.staffLineThickness;
}