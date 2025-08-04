import 'dart:convert';
import 'dart:core';

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

  /// Callback function that is called when a chord symbol is tapped
  final void Function(dynamic chordSymbol, int globalChordIndex)? onChordSymbolTap;

  /// Callback function that is called when a chord symbol is long pressed
  final void Function(dynamic chordSymbol, int globalChordIndex)? onChordSymbolLongPress;

  /// Callback function that is called when a chord symbol long press ends
  final void Function(dynamic chordSymbol, int globalChordIndex, LongPressEndDetails? details)? onChordSymbolLongPressEnd;

  /// Callback function that is called when hovering over a chord symbol during drag
  final void Function(dynamic chordSymbol, int globalChordIndex)? onChordSymbolHover;

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
  late final Future<void> _future;
  SheetMusicLayout? _layout; // Remove 'late' keyword since it can be null initially
  
  // Cache key to track layout changes
  String? _lastLayoutKey;

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
    _future = _initialize();
    super.initState();
  }

  Future<void> _initialize() async {
    await load();
    await initializeMidi();
  }

  Future<void> load() async {
    final xml = await rootBundle.loadString(fontType.svgPath);
    final document = XmlDocument.parse(xml);
    final allGlyphs = document.findAllElements('glyph').toSet();
    glyphPath = GlyphPaths(allGlyphs);
    final json = await rootBundle.loadString(fontType.metadataPath);
    metadata = GlyphMetadata(jsonDecode(json) as Map<String, dynamic>);
  }

  void _handleTap(TapDownDetails details) {
    if (_layout == null || widget.onTap == null) {
      return;
    }

    // Convert the tap position to canvas coordinates
    final tapPosition = details.localPosition / _layout!.canvasScale;

    // Find the tapped symbol by testing each staff
    for (final staff in _layout!.staffRenderers) {
      final hitSymbol = staff.hitTest(tapPosition);
      if (hitSymbol != null) {
        widget.onTap!(hitSymbol.musicalSymbol, tapPosition);
        return;
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_layout == null) return;

    // Convert pan position to global chord index by finding which chord is under the position
    _findChordAtPanPosition(details.localPosition);
  }

  void _findChordAtPanPosition(Offset localPosition) {
    // This will find which chord is under the current pan position
    // and trigger hover events for drag selection
    
    // Track global chord index across all measures
    int globalChordIndex = 0;
    
    // Iterate through each staff line to find the chord under the position
    for (int staffIndex = 0; staffIndex < _layout!.staffRenderers.length; staffIndex++) {
      final staffRenderer = _layout!.staffRenderers[staffIndex];
      
      // Iterate through each measure in this staff
      for (int measureIndex = 0; measureIndex < staffRenderer.measureRendereres.length; measureIndex++) {
        if (staffIndex == 0 && measureIndex == 0) {
          // Skip the first measure in the first staff
          continue;
        }
        final measureRenderer = staffRenderer.measureRendereres[measureIndex];
        final measure = measureRenderer.measure;
        
        // Check if this is a ChordMeasure with chord symbols
        if (measure != null && measure.runtimeType.toString() == 'ChordMeasure') {
          try {
            final dynamic chordMeasure = measure;
            final dynamic chordSymbols = chordMeasure.chordSymbols;
            
            if (chordSymbols != null && chordSymbols is List && chordSymbols.isNotEmpty) {
              final measureX = measureRenderer.measureOriginX * _layout!.canvasScale;
              final measureY = measureRenderer.staffLineCenterY * _layout!.canvasScale;
              final measureWidth = measureRenderer.width * _layout!.canvasScale;
              
              // Check each chord symbol in this measure
              for (int chordIndex = 0; chordIndex < chordSymbols.length; chordIndex++) {
                final dynamic chordSymbol = chordSymbols[chordIndex];
                if (chordSymbol != null) {
                  // Calculate chord position (same logic as overlay positioning)
                  double chordX;
                  if (chordSymbols.length == 1) {
                    chordX = measureX + (measureWidth / 2) - 25;
                  } else {
                    final spacing = measureWidth / chordSymbols.length;
                    chordX = measureX + (spacing * chordIndex) + (spacing / 2) - 25;
                  }
                  
                  final chordY = measureY - (1700 * _layout!.canvasScale);
                  
                  // Check if pan position is within this chord's bounds (rough estimation)
                  final chordWidth = 50.0; // Approximate chord symbol width
                  final chordHeight = 30.0; // Approximate chord symbol height
                  
                  if (localPosition.dx >= chordX && 
                      localPosition.dx <= chordX + chordWidth &&
                      localPosition.dy >= chordY && 
                      localPosition.dy <= chordY + chordHeight) {
                    
                    // Found the chord under the pan position
                    if (widget.onChordSymbolHover != null) {
                      widget.onChordSymbolHover!(chordSymbol, globalChordIndex);
                    }
                    return;
                  }
                  
                  globalChordIndex++;
                }
              }
            }
          } catch (e) {
            print('Error finding chord at pan position: $e');
          }
        }
      }
    }
  }

  /// Generate a hash of all chord symbols to detect changes in their content
  String _generateChordSymbolHash() {
    final buffer = StringBuffer();
    
    for (final measure in widget.measures) {
      if (measure.runtimeType.toString() == 'ChordMeasure') {
        try {
          final dynamic chordMeasure = measure;
          final dynamic chordSymbols = chordMeasure.chordSymbols;
          
          if (chordSymbols != null && chordSymbols is List) {
            for (final dynamic chordSymbol in chordSymbols) {
              if (chordSymbol != null) {
                // Include key properties that affect display
                buffer.write('${chordSymbol.effectiveRootName}_');
                buffer.write('${chordSymbol.effectiveQuality}_');
                buffer.write('${chordSymbol.originalKeySignature}_');
                buffer.write('${chordSymbol.modifiedKeySignature}_');
                buffer.write('${chordSymbol.position}_');
              }
            }
          }
        } catch (e) {
          // If we can't access chord symbols, include a fallback
          buffer.write('measure_${measure.hashCode}_');
        }
      }
    }
    
    return buffer.toString().hashCode.toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        // Create layout key to detect changes - include chord symbol content hash
        final chordSymbolHash = _generateChordSymbolHash();
        final layoutKey = '${widget.measures.length}_${widget.width}_${widget.height}_${widget.initialClefType}_${widget.initialKeySignatureType}_${widget.initialTimeSignatureType}_$chordSymbolHash';
        
        // Only rebuild layout if parameters have changed
        if (_layout == null || _lastLayoutKey != layoutKey) {
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

          // Clear cache if layout changed to ensure fresh rendering
          _layout!.clearCache();
          _lastLayoutKey = layoutKey;
        }

        // Ensure layout is not null before proceeding
        final currentLayout = _layout;
        if (currentLayout == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // Create the sheet music renderer without highlighting
        final renderer = SheetMusicRenderer(currentLayout);

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: 50.0), // Add bottom padding to the scroll view
          child: GestureDetector(
            onTapDown: _handleTap,
            onPanUpdate: _handlePanUpdate,
            // Only handle taps that don't hit interactive widgets (chord symbols)
            behavior: HitTestBehavior.deferToChild,
            child: SizedBox(
              width: widget.width,
              height: currentLayout.totalContentHeight, // Use calculated content height
              child: Stack(
                children: [
                  // The sheet music is rendered once and doesn't change
                  // Wrap in RepaintBoundary for optimal scrolling performance
                  RepaintBoundary(
                    key: const ValueKey('sheet_music_canvas'),
                    child: CustomPaint(
                      size: Size(widget.width, currentLayout.totalContentHeight), // Use content height
                      painter: renderer,
                    ),
                  ),
                  // Chord symbol overlays - these need to be on top to receive touch events
                  // Individual chord symbols need to receive touch events for selection and interaction
                  ..._buildChordSymbolOverlays(context, currentLayout),
                  // The overlay that highlights the current note
                  // Wrap highlight in separate RepaintBoundary since it changes frequently
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
  List<Widget> _buildChordSymbolOverlays(BuildContext context, SheetMusicLayout layout) {
    final overlays = <Widget>[];
    
    // Use the widget's current key signature
    final currentKeySignature = widget.initialKeySignatureType;
    
    // Track global chord index across all measures
    int globalChordIndex = 0;
    
    // Iterate through each staff line
    for (int staffIndex = 0; staffIndex < layout.staffRenderers.length; staffIndex++) {
      final staffRenderer = layout.staffRenderers[staffIndex];
      
      // Iterate through each measure in this staff
      for (int measureIndex = 0; measureIndex < staffRenderer.measureRendereres.length; measureIndex++) {
        if (staffIndex == 0 &&measureIndex == 0) {
          // Skip the first measure in the first staff
          continue;
        }
        final measureRenderer = staffRenderer.measureRendereres[measureIndex];
        final measure = measureRenderer.measure;
        
        // Check if this is a ChordMeasure with chord symbols
        if (measure != null && measure.runtimeType.toString() == 'ChordMeasure') {
          try {
            final dynamic chordMeasure = measure;
            final dynamic chordSymbols = chordMeasure.chordSymbols;
            
            if (chordSymbols != null && chordSymbols is List && chordSymbols.isNotEmpty) {
              // Convert canvas coordinates to widget coordinates 
              // Same as HighlightOverlay: multiply by canvasScale
              final measureX = measureRenderer.measureOriginX * layout.canvasScale;
              final measureY = measureRenderer.staffLineCenterY * layout.canvasScale;
              final measureWidth = measureRenderer.width * layout.canvasScale;
            
              
              // Position chord symbols above this measure
              for (int chordIndex = 0; chordIndex < chordSymbols.length; chordIndex++) {
                final dynamic chordSymbol = chordSymbols[chordIndex];
                if (chordSymbol != null) {
                  // Calculate position for this chord symbol - properly centered
                  double chordX;
                  if (chordSymbols.length == 1) {
                    // Single chord: center in measure
                    chordX = measureX + (measureWidth / 2) - 25; // Better centering - reduced offset
                  } else {
                    // Multiple chords: distribute evenly
                    final spacing = measureWidth / chordSymbols.length;
                    chordX = measureX + (spacing * chordIndex) + (spacing / 2) - 25; // Better centering
                  }
                  
                  // Position properly above the staff (much higher and more consistent)
                  final chordY = measureY - (1700 * layout.canvasScale); // Higher and more appropriate positioning
                  
                  
                  overlays.add(
                    Positioned(
                      left: chordX,
                      top: chordY,
                      child: GestureDetector(
                        onPanUpdate: widget.onChordSymbolHover != null 
                          ? (details) {
                              // Handle drag updates by finding chord under current position
                              widget.onChordSymbolHover!(chordSymbol, globalChordIndex);
                            }
                          : null,
                        child: MouseRegion(
                          onEnter: widget.onChordSymbolHover != null 
                            ? (_) => widget.onChordSymbolHover!(chordSymbol, globalChordIndex)
                            : null,
                          child: chordSymbol.buildWidget(
                            context: context,
                            currentKeySignature: currentKeySignature,
                            // Pass selection state for visual feedback
                            isSelected: widget.isChordSelected?.call(globalChordIndex) ?? false,
                            isAnimating: false,
                            isNewMeasure: false,
                            // Connect to widget callbacks for interaction
                            onTap: widget.onChordSymbolTap != null 
                              ? () => widget.onChordSymbolTap!(chordSymbol, globalChordIndex)
                              : null,
                            onLongPress: widget.onChordSymbolLongPress != null 
                              ? () => widget.onChordSymbolLongPress!(chordSymbol, globalChordIndex)
                              : null,
                            onLongPressEnd: widget.onChordSymbolLongPressEnd != null 
                              ? (details) => widget.onChordSymbolLongPressEnd!(chordSymbol, globalChordIndex, details)
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
// Remove the duplicate method definition that was outside the class

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
      for (int i = 0; i < staffRenderer.measureRendereres.length && i < measures.length; i++) {
        final measureRenderer = staffRenderer.measureRendereres[i];
        final measure = measures[i];
        
        // Check if this is a ChordMeasure with chord symbols
        // Since we can't import ChordMeasure directly, we'll use runtime type checking
        if (measure.runtimeType.toString().contains('ChordMeasure')) {
          print('Found ChordMeasure at index $i');
          _renderChordSymbolsForMeasure(
            canvas,
            measure,
            measureRenderer.measureOriginX * layout.canvasScale, // Apply scale to positioning
            measureRenderer.staffLineCenterY * layout.canvasScale, // Apply scale to positioning
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
      
      print('Rendering chord symbols for measure at X:$measureOriginX, Y:$staffLineCenterY, Width:$measureWidth');
      
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
