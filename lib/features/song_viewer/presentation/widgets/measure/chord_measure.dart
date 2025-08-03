import 'package:music_sheet/simple_sheet_music.dart' as music_sheet;
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';

/// A measure that contains both musical content and chord symbols
class ChordMeasure extends music_sheet.Measure {
  /// Creates a new instance of the [ChordMeasure] class.
  ChordMeasure(
    super.contents, {
    super.isNewLine = false,
    this.chordSymbols = const [],
  });

  /// The list of chord symbols associated with this measure
  final List<ChordSymbol> chordSymbols;
}