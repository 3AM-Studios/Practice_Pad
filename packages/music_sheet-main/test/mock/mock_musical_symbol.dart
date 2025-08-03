import 'package:flutter_test/flutter_test.dart';
import 'package:music_sheet/src/glyph_metadata.dart';
import 'package:music_sheet/src/glyph_path.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/musical_context.dart';

import 'mock_musical_symbol_metrics.dart';

class MockMusicalSymbol extends Fake implements MusicalSymbol {
  @override
  MockMusicalSymbolMetrics setContext(
    MusicalContext context,
    GlyphMetadata metadata,
    GlyphPaths paths,
  ) =>
      MockMusicalSymbolMetrics(context: context);
}
