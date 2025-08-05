import 'package:music_sheet/src/extension/list_extension.dart';
import 'package:music_sheet/src/measure/measure_metrics.dart';

/// Represents the calculated metrics of a single staff line in sheet music.
///
/// This is a pure data class, responsible only for holding the aggregate
/// properties of a staff, like its total width and height. It no longer
/// creates renderer objects.
class StaffMetrics {
  const StaffMetrics(this.measuresMetricses);

  /// The list of measure metrics for each measure in the staff.
  final List<MeasureMetrics> measuresMetricses;

  /// The height of the upper part of the staff.
  double get upperHeight =>
      measuresMetricses.map((measure) => measure.upperHeight).max;

  /// The height of the lower part of the staff.
  double get lowerHeight =>
      measuresMetricses.map((measure) => measure.lowerHeight).max;

  /// The total width of the staff, calculated from the widths of its measures.
  double get width => measuresMetricses.map((measure) => measure.width).sum;
  
  /// The sum of the horizontal margins of all symbols within this staff.
  /// Note: This is different from the old `horizontalMarginSum` which was misnamed.
  double get horizontalMarginSum =>
      measuresMetricses.map((measure) => measure.horizontalMarginSum).sum;

  /// The total height of the staff.
  double get height => upperHeight + lowerHeight;
}