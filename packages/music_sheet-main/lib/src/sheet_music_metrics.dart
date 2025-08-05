
import 'package:music_sheet/src/extension/list_extension.dart';
import 'package:music_sheet/src/glyph_metadata.dart';
import 'package:music_sheet/src/glyph_path.dart';
import 'package:music_sheet/src/measure/measure.dart';
import 'package:music_sheet/src/measure/measure_metrics.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_metrics.dart';
import 'package:music_sheet/src/music_objects/clef/clef_type.dart';
import 'package:music_sheet/src/music_objects/key_signature/keysignature_type.dart';
import 'package:music_sheet/src/music_objects/time_signature/time_signature_type.dart';
import 'package:music_sheet/src/musical_context.dart';
import 'package:music_sheet/src/staff/staff_metrics.dart';

/// Represents the metrics of a sheet music, now with efficient caching.
class SheetMusicMetrics {
  final List<Measure> measures;
  final ClefType initialClefType;
  final KeySignatureType initialKeySignatureType;
  final TimeSignatureType initialTimeSignatureType;
  final GlyphMetadata metadata;
  final GlyphPaths paths;
  final int tempo;

  /// THE FIX: The musical context is now a public, final field.
  late final MusicalContext musicalContext;
  
  // This will hold the final computed layout.
  late final List<StaffMetrics> staffsMetricses;

  SheetMusicMetrics(
    this.measures,
    // Accept the persistent cache from the state object
    Map<String, MusicalSymbolMetrics> metricsCache,
    this.initialClefType,
    this.initialKeySignatureType,
    this.initialTimeSignatureType,
    this.metadata,
    this.paths, {
    this.tempo = 120,
  }) {
    // The entire calculation now happens once upon creation.
    _calculateAllMetrics(metricsCache);
  }

  void _calculateAllMetrics(Map<String, MusicalSymbolMetrics> metricsCache) {
    final measureMetricsList = <MeasureMetrics>[];
    
    // Initialize the context and store it as a class field.
    musicalContext = MusicalContext(initialClefType, initialKeySignatureType);

    for (var i = 0; i < measures.length; i++) {
      final measure = measures[i];
      final isLastMeasure = i == measures.length - 1;
      
      final symbolMetricsList = <MusicalSymbolMetrics>[];
      for (final symbol in measure.musicalSymbols) {
        if (metricsCache.containsKey(symbol.id)) {
          symbolMetricsList.add(metricsCache[symbol.id]!);
        } else {
          // Use the class-level musicalContext now
          final newMetrics = symbol.setContext(musicalContext, metadata, paths);
          symbolMetricsList.add(newMetrics);
          metricsCache[symbol.id] = newMetrics;
        }
      }

      final measureMetrics = MeasureMetrics(
        symbolMetricsList,
        metadata,
        isNewLine: measure.isNewLine,
        isLastMeasure: isLastMeasure,
        originalMeasure: measure,
      );
      measureMetricsList.add(measureMetrics);
    }

    final staffs = <StaffMetrics>[];
    var sameStaffMeasures = <MeasureMetrics>[];
    for (final measure in measureMetricsList) {
      if (measure.isNewLine && sameStaffMeasures.isNotEmpty) {
        staffs.add(StaffMetrics(sameStaffMeasures));
        sameStaffMeasures = [measure];
      } else {
        sameStaffMeasures.add(measure);
      }
    }
    if (sameStaffMeasures.isNotEmpty) {
      staffs.add(StaffMetrics(sameStaffMeasures));
    }
    staffsMetricses = staffs;
  }

  // The rest of the getters work on the computed 'staffsMetricses' list.
  StaffMetrics get _maximumWidthStaff {
    var result = staffsMetricses.first;
    for (final staff in staffsMetricses) {
      if (staff.width > result.width) {
        result = staff;
      }
    }
    return result;
  }

  double get maximumStaffWidth => _maximumWidthStaff.width;
  double get maximumStaffHorizontalMarginSum => _maximumWidthStaff.horizontalMarginSum;
  double get staffUpperHeight => staffsMetricses.map((staff) => staff.upperHeight).max;
  double get staffLowerHeight => staffsMetricses.map((staff) => staff.lowerHeight).max;
  double get staffsHeightSum => staffsMetricses.map((staff) => staff.height).sum;
}