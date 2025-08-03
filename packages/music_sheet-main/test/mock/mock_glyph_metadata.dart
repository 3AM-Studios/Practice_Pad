import 'package:flutter_test/flutter_test.dart';
import 'package:music_sheet/src/glyph_metadata.dart';

class MockGlyphMetadata extends Fake implements GlyphMetadata {
  MockGlyphMetadata({
    this.staffLineThickness = 0,
    this.measureUpperHeight = 0,
    this.measureLowerHeight = 0,
  });
  @override
  final double staffLineThickness;
  @override
  final double measureUpperHeight;
  @override
  final double measureLowerHeight;
}
