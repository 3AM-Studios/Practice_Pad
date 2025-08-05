import 'package:flutter/material.dart';
import 'package:music_sheet/src/glyph_metadata.dart';
import 'package:music_sheet/src/glyph_path.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_metrics.dart';
import 'package:music_sheet/src/musical_context.dart';
import 'package:music_sheet/src/utils/id_generator.dart';

/// An abstract class representing a musical symbol in sheet music.
///
/// This class serves as the base class for all musical symbols in the
/// application. It provides common properties and methods that are shared
/// among different types of musical symbols.
abstract class MusicalSymbol {
  /// Creates a new instance of [MusicalSymbol].
  ///
  /// The [margin] parameter specifies the margin around the musical symbol.
  /// The [color] parameter specifies the color of the musical symbol.
  MusicalSymbol({
    String? id, // 2. Add the optional 'id' parameter to the constructor.
    this.color = Colors.black,
    this.margin = const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0.0),
    // 3. Use the initializer list to set the id.
  }) : id = id ?? IdGenerator.generateId('symbol');

  /// A unique identifier for this symbol.
  /// This is used for highlighting and MIDI playback.
  final String id;

  /// The color of the musical symbol.
  final Color color;

  /// The margin around the musical symbol.
  final EdgeInsets margin;

  /// The duration of the musical symbol in beats (where a quarter note is 1.0 beats).
  /// For non-note symbols (like clefs, key signatures, etc.), this should be 0.
  double get duration;

  /// Sets the musical context for this symbol and returns its metrics.
  ///
  /// The [context] parameter specifies the musical context in which the
  /// symbol is being rendered. The [metadata] parameter provides additional
  /// metadata about the symbol. The [paths] parameter contains the glyph paths
  /// for the symbol.
  ///
  /// Returns the metrics for the musical symbol.
  MusicalSymbolMetrics setContext(
    MusicalContext context,
    GlyphMetadata metadata,
    GlyphPaths paths,
  );
}
