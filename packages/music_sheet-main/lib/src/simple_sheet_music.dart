import 'dart:convert';
import 'dart:core';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_sheet/index.dart';
import 'package:music_sheet/simple_sheet_music.dart';
import 'package:music_sheet/src/midi/midi_playback_mixin.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/sheet_music_metrics.dart';
import 'package:music_sheet/src/sheet_music_renderer.dart';
import 'package:music_sheet/src/utils/interaction_overlay_painter.dart';
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
  final Map<String, MusicalSymbolMetrics> _metricsCache = {};
  // MusicalSymbol? _draggedSymbol;
  // Offset? _dragPosition;
  //Rect? _pitchHighlightRect;
  int? _draggedSymbolMeasureIndex;

  final ValueNotifier<InteractionState?> _interactionNotifier =
      ValueNotifier<InteractionState?>(null);

  int?
      _draggedSymbolPositionIndex; // The original index of the note in the measure
  Clef? _draggedClef;
  
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
      _metricsCache, // Pass the cache here
      widget.initialClefType,
      widget.initialKeySignatureType,
      widget.initialTimeSignatureType,
      metadata,
      glyphPath,
      tempo: widget.tempo,
    );

    // Get actual screen width instead of widget.width which may be incorrect
    final actualWidth = MediaQuery.of(context).size.width;

    _layout = SheetMusicLayout(
      metricsBuilder,
      widget.lineColor,
      widgetWidth: actualWidth,
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

  for (var staffIndex = 0; staffIndex < _layout!.staffRenderers.length; staffIndex++) {
    final staff = _layout!.staffRenderers[staffIndex];
    for (var measureIndex = 0; measureIndex < staff.measureRendereres.length; measureIndex++) {
      final measureRenderer = staff.measureRendereres[measureIndex];

      // Use hit-testing to find if an existing symbol was tapped
      final symbol = measureRenderer.getSymbolAt(tapPosition);

      // --- SCENARIO 1: Tapped an existing symbol ---
      if (symbol != null) {
        // Prepare the state needed AFTER the gesture ends
        _isAddingNewSymbol = false;
        _draggedClef = Clef.treble(); // Replace with logic to find the current clef if needed
        _draggedSymbolMeasureIndex = measureIndex;
        _draggedSymbolPositionIndex =
            measureRenderer.measure.musicalSymbols.indexWhere((s) => s.id == symbol.id);

        // Update the persistent selection and trigger one rebuild to show it.
        // This is acceptable as it only happens once on tap down.
        setState(() {
          _selectedSymbol = symbol;
        });
        final pitch = measureRenderer.getPitchForY(tapPosition.dy, _draggedClef!);
        final highlightRect = measureRenderer.getHighlightRectForPitch(pitch, _draggedClef!);
        // Update the notifier to draw the dynamic overlay. This is fast and does NOT cause a rebuild.
        _interactionNotifier.value = InteractionState(
          draggedSymbol: symbol,
          dragPosition: details.localPosition,
          pitchHighlightRect: highlightRect, // No line highlight when editing an existing note
        );
        return; // Found our target, exit all loops
      }

      // --- SCENARIO 2: Tapped an empty space ---
      if (measureRenderer.getBounds().contains(tapPosition)) {
        // Prepare the state needed AFTER the gesture ends
        _isAddingNewSymbol = true;
        _draggedClef = Clef.treble(); // Replace with logic to find the current clef
        _draggedSymbolMeasureIndex = measureIndex;
        _draggedSymbolPositionIndex = measureRenderer.getInsertionIndexForX(tapPosition.dx);
        
        // Clear any previous persistent selection without a full rebuild if possible
        if (_selectedSymbol != null) {
          setState(() {
            _selectedSymbol = null;
          });
        }

        // Create temporary objects for the dynamic overlay
        final pitch = measureRenderer.getPitchForY(tapPosition.dy, _draggedClef!);
        final tempNote = Note(pitch); // A new temporary note for dragging
        print(_draggedClef);
        final newHighlightRect = measureRenderer.getHighlightRectForPitch(pitch, _draggedClef!);
        // Update the notifier to draw the dynamic overlay.
        _interactionNotifier.value = InteractionState(
          draggedSymbol: tempNote,
          dragPosition: details.localPosition,
          pitchHighlightRect: newHighlightRect,
        );
        return; // Found our target, exit all loops
      }
    }
  }
}


void _handlePanUpdate(DragUpdateDetails details) {
  final currentState = _interactionNotifier.value;
  // Ensure there's an active interaction and we are dragging a note
  if (currentState == null || currentState.draggedSymbol is! Note || _layout == null) {
    return;
  }

  // Retrieve the state we set in _handleTapDown
  final clef = _draggedClef ?? Clef.treble();
  final measureRenderer =
      _layout!.staffRenderers.first.measureRendereres[_draggedSymbolMeasureIndex!];

  // Calculate new state based on the current drag position
  final newDragPosition = details.localPosition;
  final scaledY = newDragPosition.dy / _layout!.canvasScale;
  final newPitch = measureRenderer.getPitchForY(scaledY, clef);
  final newHighlightRect = measureRenderer.getHighlightRectForPitch(newPitch, clef);

  Note updatedSymbol = currentState.draggedSymbol as Note;

  // If the pitch has changed, create a new temporary Note object for the overlay.
  // CRITICAL: We pass the original ID to the new copy to maintain identity.
  if (updatedSymbol.pitch != newPitch) {
    updatedSymbol = updatedSymbol.copyWith(pitch: newPitch);
  }

  // Update the notifier with the new state. This is the only thing we do here.
  // It's extremely fast and will only trigger the lightweight overlay painter.
  _interactionNotifier.value = InteractionState(
    draggedSymbol: updatedSymbol,
    dragPosition: newDragPosition,
    pitchHighlightRect: newHighlightRect,
  );
}

void _handlePanEnd(DragEndDetails details) {
  // Get the final state of the interaction from the notifier.
  final interaction = _interactionNotifier.value;

  // If there's no active interaction, do nothing.
  if (interaction == null) return;

  // Pass the required information to the editor function.
  _showSymbolEditorAndResetState(
    symbolToEdit: interaction.draggedSymbol!,
    position: interaction.dragPosition!,
  );
}

void _handleTapUp(TapUpDetails details) {
  // The logic is identical for tap up.
  final interaction = _interactionNotifier.value;
  if (interaction == null) return;

  _showSymbolEditorAndResetState(
    symbolToEdit: interaction.draggedSymbol!,
    position: interaction.dragPosition!,
  );
}

// Note the new parameters: {required MusicalSymbol symbolToEdit, required Offset position}
void _showSymbolEditorAndResetState({
  required MusicalSymbol symbolToEdit,
  required Offset position,
}) async {
  // The null check for the notifier already happened in the functions that call this one.
  // We can safely use the parameters.

  // Keep other state we need from the class member variables.
  final isAdding = _isAddingNewSymbol;
  final measureIndex = _draggedSymbolMeasureIndex!;
  final positionIndex = _draggedSymbolPositionIndex!;
  
  // By awaiting here, the function pauses.
  final result = await showNoteEditorPopup(context, position, symbolToEdit);

  // This code runs AFTER the popup is closed.
if (result != null) {
  if (result.isDelete) {
    if (!isAdding) {
      widget.onSymbolDelete?.call(measureIndex, positionIndex);
    }
  } else if (result.musicalSymbol != null) {
    if (isAdding) {
      widget.onSymbolAdd?.call(result.musicalSymbol!, measureIndex, positionIndex);
    } else {
      widget.onSymbolUpdate?.call(result.musicalSymbol!, measureIndex, positionIndex);
    }
  }
}

  // Now that the interaction is fully complete, reset all state.
  _resetInteractionState();
}

void _resetInteractionState() {
  // 1. Clear the dynamic interaction state. This removes the overlay.
  _interactionNotifier.value = null;

  // 2. Clear the persistent state and trigger a rebuild to remove
  //    the selection highlight and prepare for the next interaction.
  setState(() {
    _draggedSymbolMeasureIndex = null;
    _draggedSymbolPositionIndex = null;
    _draggedClef = null;
    _selectedSymbol = null;
    _isAddingNewSymbol = false;
    // No need to reset _draggedSymbol or _dragPosition, as they've been removed.
  });
}


  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _fontFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || _layout == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentLayout = _layout!;
      
      // The main renderer is now much simpler. It is only responsible for drawing the
      // static score. It no longer knows anything about dragging.
      // It ONLY depends on the layout and the final selected symbol.
      final staticSheetMusicRenderer = SheetMusicRenderer(
        sheetMusicLayout: currentLayout,
        selectedSymbol: _selectedSymbol,
      );

      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 50.0),
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          behavior: HitTestBehavior.deferToChild,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: currentLayout.totalContentHeight,
            // The Stack is how we layer our static and dynamic painters.
            child: Stack(
              children: [
                // ===== LAYER 1: The Static Background Painter =====
                // This draws the entire score. It will only repaint when _selectedSymbol
                // changes, NOT during a drag. The RepaintBoundary helps isolate it.
                RepaintBoundary(
                  key: const ValueKey('sheet_music_canvas'),
                  child: CustomPaint(
                    size: Size(MediaQuery.of(context).size.width, currentLayout.totalContentHeight),
                    painter: staticSheetMusicRenderer,
                  ),
                ),

                // ===== LAYER 2: Other Overlays (Unchanged) =====
                // Your existing logic for chord symbols and MIDI highlights remains the same.

                ...chordSymbolOverlays,

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

                // ===== LAYER 3: The NEW Dynamic Interaction Painter =====
                // This is the key to our performance gain. ValueListenableBuilder listens
                // to our notifier and ONLY rebuilds its child (the lightweight CustomPaint)
                // when the interaction state changes.
                ValueListenableBuilder<InteractionState?>(
                  valueListenable: _interactionNotifier,
                  builder: (context, interactionState, child) {
                    // If there is no active interaction, we draw nothing.
                    if (interactionState == null) {
                      return const SizedBox.shrink();
                    }

                    // If there IS an interaction, we draw our fast overlay.
                    return CustomPaint(
                      size: Size(MediaQuery.of(context).size.width, currentLayout.totalContentHeight),
                      painter: InteractionOverlayPainter(
                        interactionState: interactionState,
                        canvasScale: currentLayout.canvasScale,
                      ),
                    );
                  },
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

    // Track global chord index across all measures - need to account for ALL measures in the source data
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
        final measureRenderer = staffRenderer.measureRendereres[measureIndex];
        final measure = measureRenderer.measure;
        
        // Always count chords from all measures (including skipped ones) to maintain correct indexing
        if (measure.runtimeType.toString() == 'ChordMeasure') {
          try {
            final dynamic chordMeasure = measure;
            final dynamic chordSymbols = chordMeasure.chordSymbols;
            
            if (chordSymbols != null && chordSymbols is List && chordSymbols.isNotEmpty) {
              if (staffIndex == 0 && measureIndex == 0) {
                // Skip rendering the first measure but still increment the index for consistency
                globalChordIndex += chordSymbols.length;
                continue;
              }
            }
          } catch (e) {
            // If there's an error accessing chord symbols, continue
          }
        }
        
        if (staffIndex == 0 && measureIndex == 0) {
          // Skip the first measure in the first staff (already handled above)
          continue;
        }

        // Check if this is a ChordMeasure with chord symbols
        if (measure.runtimeType.toString() == 'ChordMeasure') {
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
                  // Capture the current globalChordIndex value for this chord symbol
                  final int currentGlobalIndex = globalChordIndex;
                  
                  // Determine if this chord is the start of a reharmonized sequence
                  bool isStartOfReharmonizedSequence = false;
                  if (chordSymbol.modifiedKeySignature != null) {
                    // Check if previous chord has different or no modifiedKeySignature
                    if (chordIndex == 0) {
                      // First chord in measure - need to check previous measure
                      isStartOfReharmonizedSequence = true; // Assume start for now
                    } else {
                      // Check previous chord in same measure
                      final previousChord = chordSymbols[chordIndex - 1];
                      isStartOfReharmonizedSequence = previousChord.modifiedKeySignature == null ||
                          previousChord.modifiedKeySignature != chordSymbol.modifiedKeySignature;
                    }
                  }
                  
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
                      (140 *
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
                                    chordSymbol, currentGlobalIndex);
                              }
                            : null,
                        child: MouseRegion(
                          onEnter: widget.onChordSymbolHover != null
                              ? (_) => widget.onChordSymbolHover!(
                                  chordSymbol, currentGlobalIndex)
                              : null,
                          child: chordSymbol.buildWidget(
                            context: context,
                            currentKeySignature: currentKeySignature,
                            // Pass selection state for visual feedback
                            isSelected: widget.isChordSelected
                                    ?.call(currentGlobalIndex) ??
                                false,
                            isAnimating: false,
                            isNewMeasure: false,
                            isStartOfReharmonizedSequence: isStartOfReharmonizedSequence,
                            // Connect to widget callbacks for interaction
                            onTap: widget.onChordSymbolTap != null
                                ? () => widget.onChordSymbolTap!(
                                    chordSymbol, currentGlobalIndex)
                                : null,
                            onLongPress: widget.onChordSymbolLongPress != null
                                ? () => widget.onChordSymbolLongPress!(
                                    chordSymbol, currentGlobalIndex)
                                : null,
                            onLongPressEnd: widget.onChordSymbolLongPressEnd !=
                                    null
                                ? (details) =>
                                    widget.onChordSymbolLongPressEnd!(
                                        chordSymbol, currentGlobalIndex, details)
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

class InteractionState {
  final MusicalSymbol? draggedSymbol;
  final Offset? dragPosition;
  final Rect? pitchHighlightRect;
  // Add any other state that changes during a drag/tap

  const InteractionState({
    this.draggedSymbol,
    this.dragPosition,
    this.pitchHighlightRect,
  });
}
