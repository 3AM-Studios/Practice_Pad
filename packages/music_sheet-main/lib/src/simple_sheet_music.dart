import 'dart:convert';
import 'dart:core';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_sheet/simple_sheet_music.dart';
import 'package:music_sheet/src/midi/midi_playback_mixin.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/sheet_music_metrics.dart';
import 'package:music_sheet/src/sheet_music_renderer.dart';
import 'package:xml/xml.dart';

import 'music_objects/key_signature/keysignature_type.dart';
import 'sheet_music_layout.dart';
import 'widgets/note_editor_popup.dart';

typedef OnTapMusicObjectCallback = void Function(
  MusicalSymbol musicObject,
  Offset offset,
);

/// The `SimpleSheetMusic` widget is used to display sheet music.
/// It takes a list of `Staff` objects, an initial clef, and other optional parameters to customize the appearance of the sheet music.
class SimpleSheetMusic extends StatefulWidget {
  const SimpleSheetMusic({
    super.key,
    required this.measures,
    this.initialClefType = ClefType.treble,
    this.initialKeySignatureType = KeySignatureType.cMajor,
    this.initialTimeSignatureType = TimeSignatureType.twoFour,
    this.height = 400.0,
    this.width = 400.0,
    this.lineColor = Colors.black,
    this.fontType = FontType.bravura,
    this.tempo = 120,
    this.enableMidi = false,
    this.soundFontType = SoundFontType.touhou,
    this.customSoundFontPath,
    this.highlightColor = Colors.red,
    this.debug = false,
    this.onTap,
    this.onSymbolAdd,
    this.onSymbolUpdate,
    this.onSymbolDelete,
    this.onChordSymbolTap,
    this.onChordSymbolLongPress,
    this.onChordSymbolLongPressEnd,
    this.onChordSymbolHover,
    this.isChordSelected,
  });

  /// The list of measures to be displayed.
  final List<Measure> measures;

  /// Receive maximum width and height so as not to break the aspect ratio of the score.
  final double height;

  /// Receive maximum width and height so as not to break the aspect ratio of the score.
  final double width;

  /// The font type to be used for rendering the sheet music.
  final FontType fontType;

  /// The initial clef  for the sheet music.
  final ClefType initialClefType;

  /// The initial keySignature for the sheet music.
  final KeySignatureType initialKeySignatureType;

  /// The initial timeSignature for the sheet music.
  final TimeSignatureType initialTimeSignatureType;

  /// The tempo in beats per minute (BPM).
  /// This affects timing and playback speed.
  final int tempo;

  /// Whether to enable MIDI playback.
  final bool enableMidi;

  /// The type of soundfont to use for MIDI playback.
  final SoundFontType soundFontType;

  /// Optional custom path to a soundfont file for MIDI playback.
  /// If provided, this will override the soundFontType.
  final String? customSoundFontPath;

  /// The color to use for highlighting the current note.
  final Color highlightColor;

  final Color lineColor;

  /// Whether to render outline boxes around music objects
  final bool debug;

  /// Callback function that is called when a musical symbol is tapped
  final OnTapMusicObjectCallback? onTap;

  final void Function(
      MusicalSymbol symbol, int measureIndex, int positionIndex)? onSymbolAdd;
  final void Function(
          MusicalSymbol symbol, int measureIndex, int positionIndex)?
      onSymbolUpdate;
  final void Function(int measureIndex, int positionIndex)? onSymbolDelete;

  /// Callback function that is called when a chord symbol is tapped
  final void Function(dynamic chordSymbol, int globalChordIndex)?
      onChordSymbolTap;

  /// Callback function that is called when a chord symbol is long pressed
  final void Function(dynamic chordSymbol, int globalChordIndex)?
      onChordSymbolLongPress;

  /// Callback function that is called when a chord symbol long press ends
  final void Function(dynamic chordSymbol, int globalChordIndex,
      LongPressEndDetails? details)? onChordSymbolLongPressEnd;

  /// Callback function that is called when hovering over a chord symbol during drag
  final void Function(dynamic chordSymbol, int globalChordIndex)?
      onChordSymbolHover;

  /// Function to get the selection state of a chord symbol
  final bool Function(int globalChordIndex)? isChordSelected;

  @override
  SimpleSheetMusicState createState() => SimpleSheetMusicState();
}

/// The state class for the SimpleSheetMusic widget.
///
/// This class manages the state of the SimpleSheetMusic widget and handles the initialization,
/// font asset loading, and building of the widget.
class SimpleSheetMusicState extends State<SimpleSheetMusic>
    with MidiPlaybackMixin {
  late final GlyphPaths glyphPath;
  late final GlyphMetadata metadata;
  late final Future<void> _fontFuture;
  SheetMusicLayout? _layout;
  List<Widget> chordSymbolOverlays = []; // Initialize as empty

  // Drag state...
  MusicalSymbol? _draggedSymbol;
  Offset? _dragPosition;
  int? _draggedSymbolMeasureIndex;
  int?
      _draggedSymbolPositionIndex; // The original index of the note in the measure
  Clef? _draggedClef;
  Rect? _pitchHighlightRect;
  MusicalSymbol? _selectedSymbol;

  bool _isAddingNewSymbol = false;

  FontType get fontType => widget.fontType;

  @override
  bool get enableMidi => widget.enableMidi;

  @override
  int get tempo => widget.tempo;

  @override
  SoundFontType get soundFontType => widget.soundFontType;

  @override
  String? get customSoundFontPath => widget.customSoundFontPath;

  @override
  Color get highlightColor => widget.highlightColor;

  @override
  List<Measure> get measures => widget.measures;

  @override
  void initState() {
    super.initState();
    _fontFuture = _loadFontAssets();
  }

  @override
  void didUpdateWidget(SimpleSheetMusic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.measures != oldWidget.measures ||
        widget.width != oldWidget.width ||
        widget.height != oldWidget.height) {
      _updateLayout();
    }
  }

  Future<void> _loadFontAssets() async {
    final fontData = await rootBundle.loadString(fontType.svgPath);
    final metadataJson = await rootBundle.loadString(fontType.metadataPath);
    glyphPath = GlyphPaths(
        XmlDocument.parse(fontData).findAllElements('glyph').toSet());
    metadata = GlyphMetadata(jsonDecode(metadataJson) as Map<String, dynamic>);
    await initializeMidi();
    _updateLayout();
  }

  void _updateLayout() {
    final metricsBuilder = SheetMusicMetrics(
      widget.measures,
      widget.initialClefType,
      widget.initialKeySignatureType,
      widget.initialTimeSignatureType,
      metadata,
      glyphPath,
      tempo: widget.tempo,
    );

    _layout = SheetMusicLayout(
      metricsBuilder,
      widget.lineColor,
      widgetWidth: widget.width,
      widgetHeight: widget.height,
      symbolPositionCallback: registerSymbolPosition,
      debug: widget.debug,
    );

    chordSymbolOverlays = _buildChordSymbolOverlays(context, _layout!);
    setState(() {});
  }

void _handleTapDown(TapDownDetails details) {
    if (_layout == null) return;
    final tapPosition = details.localPosition / _layout!.canvasScale;

    for (var staffIndex = 0;
        staffIndex < _layout!.staffRenderers.length;
        staffIndex++) {
      final staff = _layout!.staffRenderers[staffIndex];
      for (var measureIndex = 0;
          measureIndex < staff.measureRendereres.length;
          measureIndex++) {
        final measureRenderer = staff.measureRendereres[measureIndex];
        final symbol = measureRenderer.getSymbolAt(tapPosition);

        // --- SCENARIO 1: Tapped an existing Note or Rest ---
        if (symbol is Note || symbol is Rest) {
          final clef = _draggedClef ?? Clef.treble();
              
          // Immediately highlight the selected symbol and prepare for the popup
          setState(() {
            _isAddingNewSymbol = false; // We are editing, not adding
            _selectedSymbol = symbol; 
           // This will be used by MeasureRenderer to highlight the symbol
            _draggedSymbol = symbol;    // Keep this for the editor logic
            _draggedClef = clef;
            _draggedSymbolMeasureIndex = measureIndex;
            _draggedSymbolPositionIndex =
                measureRenderer.measure.musicalSymbols.indexOf(symbol);
            _dragPosition = details.localPosition;
            _pitchHighlightRect = null; // IMPORTANT: Do not highlight the whole pitch line
          });
          return; // Found our target, exit the loops
        }

        // --- SCENARIO 2: Tapped an empty space on the staff ---
        if (measureRenderer.getBounds().contains(tapPosition)) {
          final clef = _draggedClef ?? Clef.treble();
          _draggedClef = clef;
          final pitch = measureRenderer.getPitchForY(tapPosition.dy, clef);
          // Highlight the entire pitch line because we are adding/dragging a new note
          final highlightRect =
              measureRenderer.getHighlightRectForPitch(pitch, clef);
              
          setState(() {
            _isAddingNewSymbol = true; // We are adding a new note
            _draggedSymbol = Note(pitch); // Create a temporary note to show
            _selectedSymbol = null;      // Nothing is officially selected yet
            _draggedSymbolMeasureIndex = measureIndex;
            _draggedSymbolPositionIndex =
                measureRenderer.getInsertionIndexForX(tapPosition.dx);
            _dragPosition = details.localPosition;
            _pitchHighlightRect = highlightRect; // Highlight the staff line
          });
          return; // Found our target, exit the loops
        }
      }
    }
  }
  void _handlePanUpdate(DragUpdateDetails details) {
    if (_draggedSymbol == null || _layout == null || _draggedSymbol is! Note) return;
    final newDragPosition = details.localPosition;
    final clef = _draggedClef ?? Clef.treble();
    final measureRenderer = _layout!
        .staffRenderers.first.measureRendereres[_draggedSymbolMeasureIndex!];
    final newPitch = measureRenderer.getPitchForY(
        newDragPosition.dy / _layout!.canvasScale, clef);
    final newHighlightRect =
        measureRenderer.getHighlightRectForPitch(newPitch, clef);

    setState(() {
      _dragPosition = newDragPosition;
      _pitchHighlightRect = newHighlightRect;
      if ((_draggedSymbol! as Note).pitch != newPitch) {
        _draggedSymbol = Note(newPitch,
            noteDuration: (_draggedSymbol! as Note).noteDuration,
            accidental: (_draggedSymbol! as Note).accidental);
        _selectedSymbol = _draggedSymbol;
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) async {
    if (_draggedSymbol == null) return;
    _showSymbolEditorAndResetState();
  }
  void _handleTapUp(TapUpDetails details) async {
    if (_draggedSymbol == null) return;
    _showSymbolEditorAndResetState();
  }
  

  void _showSymbolEditorAndResetState() async {
    if (_draggedSymbol == null ||
        _layout == null ||
        _draggedSymbolMeasureIndex == null ||
        _dragPosition == null) {
      _resetInteractionState();
      return;
    }

    // Keep state alive while the popup is open
    final symbolToEdit = _draggedSymbol!;
    final position = _dragPosition!;
    final isAdding = _isAddingNewSymbol;
    final measureIndex = _draggedSymbolMeasureIndex!;
    final positionIndex = _draggedSymbolPositionIndex!;
    final Pitch pitchForNewNote;
    if (symbolToEdit is Note) {
      pitchForNewNote = symbolToEdit.pitch;
    } else {
      final measureRenderer =
          _layout!.staffRenderers.first.measureRendereres[measureIndex];
      final clef = _draggedClef ?? Clef.treble();
      // When adding a new note, the drag position is where the note should be.
      // When editing a rest, the drag position is where the rest was tapped.
      // We can use this to determine the pitch if we convert the rest to a note.
      pitchForNewNote =
          measureRenderer.getPitchForY(position.dy / _layout!.canvasScale, clef);
    }

    // By awaiting here, the function pauses. The state remains,
    // so the highlight is still drawn in the background.
    final result =
        await showNoteEditorPopup(context, position, symbolToEdit);

    // This code runs AFTER the popup is closed.

    if (result != null) {
      if (result.isDelete) {
        if (!isAdding) {
          widget.onSymbolDelete?.call(measureIndex, positionIndex);
        }
      } else if (result.musicalSymbol != null) {
        if (isAdding) {
          widget.onSymbolAdd
              ?.call(result.musicalSymbol!, measureIndex, positionIndex);
        } else {
          widget.onSymbolUpdate
              ?.call(result.musicalSymbol!, measureIndex, positionIndex);
        }
      }
    }

    // Now that the interaction is fully complete, reset the state.
    // This will trigger a rebuild that removes the highlight.
    _resetInteractionState();
  }

  void _resetInteractionState() {
    setState(() {
      _draggedSymbol = null;
      _draggedSymbolMeasureIndex = null;
      _draggedSymbolPositionIndex = null;
      _dragPosition = null;
      _isAddingNewSymbol = false;
      _pitchHighlightRect = null;
      _draggedClef = null;
      _selectedSymbol = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _fontFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            _layout == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentLayout = _layout!;
        final renderer = SheetMusicRenderer(
          sheetMusicLayout: currentLayout,
          draggedSymbol: _draggedSymbol,
          dragPosition: _dragPosition,
          pitchHighlightRect: _pitchHighlightRect,
          selectedSymbol: _selectedSymbol,
        );

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(
              bottom: 50.0), // Add bottom padding to the scroll view
          child: GestureDetector(
            onTapDown: _handleTapDown, 
            onTapUp: _handleTapUp,
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            behavior: HitTestBehavior.deferToChild,
            child: SizedBox(
              width: widget.width,
              height: currentLayout.totalContentHeight,
              child: Stack(
                children: [
                  // 1. The main painter, now fully aware of the drag state.
                  RepaintBoundary(
                    key: const ValueKey('sheet_music_canvas'),
                    child: CustomPaint(
                      size:
                          Size(widget.width, currentLayout.totalContentHeight),
                      painter: renderer,
                    ),
                  ),

                  // 2. The pre-built, cached list of chord symbols.
                  ...chordSymbolOverlays,

                  // 3. The highlight overlay for MIDI playback.
                  if (highlightedSymbolId != null)
                    RepaintBoundary(
                      key: const ValueKey('highlight_overlay'),
                      child: HighlightOverlay(
                        highlightedSymbolId: highlightedSymbolId!,
                        symbolPosition: getSymbolPosition(highlightedSymbolId),
                        highlightColor: currentHighlightColor,
                        canvasScale: currentLayout.canvasScale,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Add this method to build the positioned chord symbol widgets
  List<Widget> _buildChordSymbolOverlays(
      BuildContext context, SheetMusicLayout layout) {
    final overlays = <Widget>[];

    // Use the widget's current key signature
    final currentKeySignature = widget.initialKeySignatureType;

    // Track global chord index across all measures
    int globalChordIndex = 0;

    // Iterate through each staff line
    for (int staffIndex = 0;
        staffIndex < layout.staffRenderers.length;
        staffIndex++) {
      final staffRenderer = layout.staffRenderers[staffIndex];

      // Iterate through each measure in this staff
      for (int measureIndex = 0;
          measureIndex < staffRenderer.measureRendereres.length;
          measureIndex++) {
        if (staffIndex == 0 && measureIndex == 0) {
          // Skip the first measure in the first staff
          continue;
        }
        final measureRenderer = staffRenderer.measureRendereres[measureIndex];
        final measure = measureRenderer.measure;

        // Check if this is a ChordMeasure with chord symbols
        if (measure != null &&
            measure.runtimeType.toString() == 'ChordMeasure') {
          try {
            final dynamic chordMeasure = measure;
            final dynamic chordSymbols = chordMeasure.chordSymbols;

            if (chordSymbols != null &&
                chordSymbols is List &&
                chordSymbols.isNotEmpty) {
              // Convert canvas coordinates to widget coordinates
              // Same as HighlightOverlay: multiply by canvasScale
              final measureX =
                  measureRenderer.measureOriginX * layout.canvasScale;
              final measureY =
                  measureRenderer.staffLineCenterY * layout.canvasScale;
              final measureWidth = measureRenderer.width * layout.canvasScale;

              // Position chord symbols above this measure
              for (int chordIndex = 0;
                  chordIndex < chordSymbols.length;
                  chordIndex++) {
                final dynamic chordSymbol = chordSymbols[chordIndex];
                if (chordSymbol != null) {
                  // Calculate position for this chord symbol - properly centered
                  double chordX;
                  if (chordSymbols.length == 1) {
                    // Single chord: center in measure
                    chordX = measureX +
                        (measureWidth / 2) -
                        25; // Better centering - reduced offset
                  } else {
                    // Multiple chords: distribute evenly
                    final spacing = measureWidth / chordSymbols.length;
                    chordX = measureX +
                        (spacing * chordIndex) +
                        (spacing / 2) -
                        25; // Better centering
                  }

                  // Position properly above the staff (much higher and more consistent)
                  final chordY = measureY -
                      (1700 *
                          layout
                              .canvasScale); // Higher and more appropriate positioning

                  overlays.add(
                    Positioned(
                      left: chordX,
                      top: chordY,
                      child: GestureDetector(
                        onPanUpdate: widget.onChordSymbolHover != null
                            ? (details) {
                                // Handle drag updates by finding chord under current position
                                widget.onChordSymbolHover!(
                                    chordSymbol, globalChordIndex);
                              }
                            : null,
                        child: MouseRegion(
                          onEnter: widget.onChordSymbolHover != null
                              ? (_) => widget.onChordSymbolHover!(
                                  chordSymbol, globalChordIndex)
                              : null,
                          child: chordSymbol.buildWidget(
                            context: context,
                            currentKeySignature: currentKeySignature,
                            // Pass selection state for visual feedback
                            isSelected: widget.isChordSelected
                                    ?.call(globalChordIndex) ??
                                false,
                            isAnimating: false,
                            isNewMeasure: false,
                            // Connect to widget callbacks for interaction
                            onTap: widget.onChordSymbolTap != null
                                ? () => widget.onChordSymbolTap!(
                                    chordSymbol, globalChordIndex)
                                : null,
                            onLongPress: widget.onChordSymbolLongPress != null
                                ? () => widget.onChordSymbolLongPress!(
                                    chordSymbol, globalChordIndex)
                                : null,
                            onLongPressEnd: widget.onChordSymbolLongPressEnd !=
                                    null
                                ? (details) =>
                                    widget.onChordSymbolLongPressEnd!(
                                        chordSymbol, globalChordIndex, details)
                                : null,
                          ) as Widget,
                        ),
                      ),
                    ),
                  );

                  // Increment global chord index for each chord symbol
                  globalChordIndex++;
                }
              }
            }
          } catch (e) {
            print('Error building chord symbol overlay: $e');
          }
        }
      }
    }

    return overlays;
  }
}

class NotePainter extends CustomPainter {
  final Note note;

  NotePainter(this.note);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    // This is a simplified representation. A real implementation would need
    // to look up the glyph for the note head and draw it.
    canvas.drawCircle(size.center(Offset.zero), size.width / 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// A widget that draws a highlight around a musical symbol
class HighlightOverlay extends StatelessWidget {
  const HighlightOverlay({
    super.key,
    required this.highlightedSymbolId,
    required this.symbolPosition,
    required this.highlightColor,
    required this.canvasScale,
  });

  final String highlightedSymbolId;
  final Rect? symbolPosition;
  final Color highlightColor;
  final double canvasScale;

  @override
  Widget build(BuildContext context) {
    if (symbolPosition == null) {
      return const SizedBox.shrink();
    }

    // Scale the rect to match the canvas scale
    final scaledRect = Rect.fromLTRB(
      symbolPosition!.left * canvasScale,
      symbolPosition!.top * canvasScale,
      symbolPosition!.right * canvasScale,
      symbolPosition!.bottom * canvasScale,
    );

    return Positioned.fromRect(
      rect: scaledRect,
      child: CustomPaint(
        painter: HighlightPainter(highlightColor),
      ),
    );
  }
}

/// A custom painter that draws a highlight
class HighlightPainter extends CustomPainter {
  HighlightPainter(this.highlightColor);

  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Add some padding to the highlight
    final highlightRect = Rect.fromLTRB(
      -4,
      -4,
      size.width + 4,
      size.height + 4,
    );

    // Draw a rounded rectangle with a semi-transparent fill
    final paint = Paint()
      ..color = highlightColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(4)),
      paint,
    );

    // Draw a border
    final borderPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(4)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(HighlightPainter oldDelegate) {
    return oldDelegate.highlightColor != highlightColor;
  }
}

/// A custom painter that renders chord symbols above measures
class ChordSymbolOverlayPainter extends CustomPainter {
  ChordSymbolOverlayPainter({
    required this.measures,
    required this.layout,
  });

  final List<Measure> measures;
  final SheetMusicLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    // Don't apply canvas scale here since positioning is already in screen coordinates
    // canvas.scale(layout.canvasScale);

    print('ChordSymbolOverlayPainter: painting ${measures.length} measures');

    // Iterate through staff renderers and their measures
    for (final staffRenderer in layout.staffRenderers) {
      for (int i = 0;
          i < staffRenderer.measureRendereres.length && i < measures.length;
          i++) {
        final measureRenderer = staffRenderer.measureRendereres[i];
        final measure = measures[i];

        // Check if this is a ChordMeasure with chord symbols
        // Since we can't import ChordMeasure directly, we'll use runtime type checking
        if (measure.runtimeType.toString().contains('ChordMeasure')) {
          print('Found ChordMeasure at index $i');
          _renderChordSymbolsForMeasure(
            canvas,
            measure,
            measureRenderer.measureOriginX *
                layout.canvasScale, // Apply scale to positioning
            measureRenderer.staffLineCenterY *
                layout.canvasScale, // Apply scale to positioning
            measureRenderer.width * layout.canvasScale, // Apply scale to width
          );
        }
      }
    }
  }

  void _renderChordSymbolsForMeasure(
    Canvas canvas,
    Measure measure,
    double measureOriginX,
    double staffLineCenterY,
    double measureWidth,
  ) {
    try {
      // Use reflection to access chordSymbols field
      final dynamic chordMeasure = measure;
      final dynamic chordSymbols = chordMeasure.chordSymbols;

      print(
          'Rendering chord symbols for measure at X:$measureOriginX, Y:$staffLineCenterY, Width:$measureWidth');

      if (chordSymbols != null && chordSymbols is List) {
        print('Found ${chordSymbols.length} chord symbols in measure');
        for (final dynamic chordSymbol in chordSymbols) {
          // Call the render method on each chord symbol
          if (chordSymbol != null) {
            try {
              print('Rendering chord: ${chordSymbol.toString()}');
              chordSymbol.render(
                canvas,
                Size(measureWidth, 100), // Approximate size
                measureOriginX,
                staffLineCenterY,
                measureWidth,
              );
            } catch (e) {
              print('Error rendering chord symbol: $e');
            }
          }
        }
      } else {
        print('No chord symbols found in measure');
      }
    } catch (e) {
      print('Error accessing ChordMeasure: $e');
    }
  }

  @override
  bool shouldRepaint(ChordSymbolOverlayPainter oldDelegate) {
    return oldDelegate.measures != measures || oldDelegate.layout != layout;
  }
}
