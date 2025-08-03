import 'package:flutter_test/flutter_test.dart';
import 'package:music_sheet/src/glyph_metadata.dart';
import 'package:music_sheet/src/glyph_path.dart';
import 'package:music_sheet/src/measure/measure.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_metrics.dart';
import 'package:music_sheet/src/musical_context.dart';

class MockMeasure extends Fake implements Measure {
  MockMeasure({this.isNewLine = false});

  @override
  final bool isNewLine;

  @override
  List<MusicalSymbolMetrics> setContext(
    MusicalContext context,
    GlyphMetadata metadata,
    GlyphPaths paths,
  ) =>
      [];

  @override
  MusicalContext updateContext(MusicalContext context) => context;
}
