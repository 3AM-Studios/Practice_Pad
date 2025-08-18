import 'package:flutter/material.dart';
import 'package:music_sheet/src/constants.dart';
import 'package:music_sheet/src/glyph_metadata.dart';
import 'package:music_sheet/src/glyph_path.dart';
import 'package:music_sheet/src/measure/measure.dart';
import 'package:music_sheet/src/measure/measure_metrics.dart';
import 'package:music_sheet/src/music_objects/clef/clef.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_metrics.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_renderer.dart';
import 'package:music_sheet/src/music_objects/notes/note_pitch.dart';
import 'package:music_sheet/src/music_objects/notes/single_note/note.dart';
import 'package:music_sheet/src/sheet_music_layout.dart';
import 'package:music_sheet/src/musical_context.dart';
import 'package:music_sheet/src/utils/chord_note_association.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';
import 'package:music_sheet/src/music_objects/notes/note_beam/beam_group.dart';
import 'package:music_sheet/src/music_objects/notes/note_beam/beam_calculator.dart';
import 'package:music_sheet/src/music_objects/notes/note_beam/beam_renderer.dart';

/// The renderer for a measure in sheet music.
/// This class is now stateful and manages its own layout, allowing for
/// efficient incremental updates.
class MeasureRenderer {
  // Properties needed for initial layout
  final SheetMusicLayout layout;
  double measureOriginX;
  final double staffLineCenterY;
  final Measure measure;
  final SymbolPositionCallback? symbolPositionCallback;

  // Properties needed for recalculating layout
  final MusicalContext musicalContext;
  final GlyphMetadata glyphMetadata;
  final GlyphPaths glyphPaths;

  // Internal state that gets updated
  late MeasureMetrics measureMetrics;
  List<MusicalSymbolRenderer> symbolRenderers = [];
  final Map<MusicalSymbol, Rect> _symbolBounds = {};
  List<BeamRenderer> beamRenderers = [];
  final Map<Note, Offset> _beamedNoteCustomStems = {};

  final double stretchFactor;
  final double measurePadding;

  MeasureRenderer(
    MeasureMetrics initialMeasureMetrics,
    this.layout, {
    required this.measureOriginX,
    required this.staffLineCenterY,
    required this.measure,
    required this.musicalContext,
    required this.glyphMetadata,
    required this.glyphPaths,
    this.symbolPositionCallback,
    this.stretchFactor = 1,
    this.measurePadding = 6.0
  }) {
    // Set the initial metrics and build the renderers for the first time
    measureMetrics = initialMeasureMetrics;
    _buildRenderers();
  }

  /// The CORE METHOD for incremental updates. This recalculates the metrics
  /// and renderers for ONLY this measure.
  void recalculateMetrics(Map<String, MusicalSymbolMetrics> metricsCache) {
    // 1. Recalculate metrics for all symbols in this measure, using the cache.
    final newSymbolMetricsList = <MusicalSymbolMetrics>[];
    for (final symbol in measure.musicalSymbols) {
      if (metricsCache.containsKey(symbol.id)) {
        newSymbolMetricsList.add(metricsCache[symbol.id]!);
      } else {
        final newMetrics = symbol.setContext(musicalContext, glyphMetadata, glyphPaths);
        newSymbolMetricsList.add(newMetrics);
        metricsCache[symbol.id] = newMetrics;
      }
    }

    // 2. Create a new MeasureMetrics object for this measure
    // Note: The isLastMeasure and isNewLine flags would need to be re-evaluated
    // in a full reflow engine. For the fast path, we assume they don't change.
    measureMetrics = MeasureMetrics(
      newSymbolMetricsList,
      glyphMetadata,
      isNewLine: measureMetrics.isNewLine,
      isLastMeasure: measureMetrics.isLastMeasure,
      originalMeasure: measure,
    );

    // 3. Rebuild the list of symbol renderers based on the new metrics.
    _buildRenderers();
  }

  /// Gets chord symbols for this measure if it's a ChordMeasure
  List<ChordSymbol> get chordSymbols {
    try {
      // Use dynamic casting to access chordSymbols if it's a ChordMeasure
      final dynamic chordMeasure = measure;
      if (chordMeasure.runtimeType.toString().contains('ChordMeasure')) {
        return chordMeasure.chordSymbols ?? <ChordSymbol>[];
      }
    } catch (e) {
      // If casting fails, return empty list
    }
    return <ChordSymbol>[];
  }

  /// Internal helper to create the list of [MusicalSymbolRenderer] objects.
  void _buildRenderers() {
    symbolRenderers.clear();
    beamRenderers.clear();
    _beamedNoteCustomStems.clear();
    if (measureMetrics.symbolMetricsList.isEmpty) return;

    // Get chord symbols for this measure
    final measureChordSymbols = chordSymbols;

    var currentX = measurePadding * stretchFactor; // Start with left padding
    int noteIndex = 0; // Track note index for chord association
    final notePositions = <double>[];
    final noteMetricsList = <NoteMetrics>[];
    final notes = <Note>[];
    
    // First pass: collect note information and create beam groups
    for (int i = 0; i < measureMetrics.symbolMetricsList.length; i++) {
      final symbolMetric = measureMetrics.symbolMetricsList[i];
      final margin = symbolMetric.margin;
      currentX += margin.left * stretchFactor;
      final symbolX = measureOriginX + currentX;
      
      if (symbolMetric is NoteMetrics) {
        notePositions.add(symbolX);
        noteMetricsList.add(symbolMetric);
        notes.add(symbolMetric.note);
        noteIndex++;
      }
      currentX += (symbolMetric.width + margin.right) * stretchFactor;
    }
    
    // Create beam groups and calculate adjusted stem positions
    // Pass the full list of musical symbols so beams are broken by rests
    _createBeamRenderers(measure.musicalSymbols, notes, notePositions, noteMetricsList);
    
    // Second pass: create renderers with adjusted stem positions for beamed notes
    currentX = measurePadding * stretchFactor; // Start with left padding
    noteIndex = 0;
    for (int i = 0; i < measureMetrics.symbolMetricsList.length; i++) {
      final symbolMetric = measureMetrics.symbolMetricsList[i];
      final margin = symbolMetric.margin;
      currentX += margin.left * stretchFactor;
      final symbolX = measureOriginX + currentX;
      
      // Check if this symbol is a Note and associate with chord symbol  
      ChordSymbol? associatedChord;
      if (symbolMetric is NoteMetrics) {
        associatedChord = getChordSymbolForNote(
          noteIndex,
          measure.musicalSymbols,
          measureChordSymbols,
        );
        noteIndex++;
      }
      
      final renderer = symbolMetric.renderer(
        layout,
        staffLineCenterY: staffLineCenterY,
        symbolX: symbolX,
      );
      
      // If this is a note renderer, set the associated chord symbol and custom stem tip if applicable
      if (renderer is NoteRenderer) {
        if (associatedChord != null) {
          renderer.setAssociatedChordSymbol(associatedChord);
        }
        
        // Check if this note has a custom stem tip position (beamed note)
        final note = (symbolMetric as NoteMetrics).note;
        if (_beamedNoteCustomStems.containsKey(note)) {
          renderer.setCustomStemTipOffset(_beamedNoteCustomStems[note]!);
        }
      }
      symbolRenderers.add(renderer);

      // Apply stretch factor to symbol width and right margin
      currentX += (symbolMetric.width + margin.right) * stretchFactor;
    }
  }

  /// Creates beam renderers for grouped notes
  void _createBeamRenderers(List<MusicalSymbol> musicalSymbols, List<Note> notes, List<double> notePositions, List<NoteMetrics> noteMetricsList) {
    if (notes.isEmpty) return;
    
    // Create beam groups using the full musical symbol sequence to respect rests
    final beamGroups = BeamGroupAnalyzer.createBeamGroupsFromSymbols(musicalSymbols);
    
    final beamCalculator = BeamCalculator(glyphMetadata);
    
    for (final beamGroup in beamGroups) {
      if (!beamGroup.shouldBeBeamed) continue;
      
      // Find the indices of notes in this beam group
      final groupIndices = <int>[];
      for (final note in beamGroup.notes) {
        final index = notes.indexOf(note);
        if (index >= 0) groupIndices.add(index);
      }
      
      if (groupIndices.length < 2) continue;
      
      // Get positions and stem tips for the beam group
      // Use stem position instead of note head center for proper beam connection
      final groupNotePositions = groupIndices.map((i) {
        final noteMetrics = noteMetricsList[i];
        return notePositions[i] + noteMetrics.stemRootOffset.dx;
      }).toList();
      
      // Use the original stem tip positions to calculate beam slope
      final originalGroupStemTipYPositions = groupIndices.map((i) {
        final noteMetrics = noteMetricsList[i];
        return staffLineCenterY + noteMetrics.stemTipOffset.dy + noteMetrics.stavePosition.positionOffset.dy;
      }).toList();
      
      // Calculate beam metrics with original positions to get proper slope
      final preliminaryBeamMetrics = beamCalculator.calculateBeamMetrics(
        beamGroup,
        groupNotePositions,
        originalGroupStemTipYPositions,
      );
      
      // Now calculate where each stem should end to connect to this sloped beam
      final adjustedGroupStemTipYPositions = groupNotePositions.map((x) {
        return preliminaryBeamMetrics.getYAtX(x);
      }).toList();
      
      // Set custom stem tip positions for all notes in this beam group
      for (int i = 0; i < groupIndices.length; i++) {
        final noteIndex = groupIndices[i];
        final noteMetrics = noteMetricsList[noteIndex];
        final adjustedStemTipY = adjustedGroupStemTipYPositions[i];
        
        // Calculate the custom stem tip offset relative to note position
        final customStemTipOffset = Offset(
          noteMetrics.stemRootOffset.dx,
          adjustedStemTipY - staffLineCenterY - noteMetrics.stavePosition.positionOffset.dy,
        );
        
        // Store this information for later use when creating note renderers
        _beamedNoteCustomStems[notes[noteIndex]] = customStemTipOffset;
      }
      
      // Use the preliminary beam metrics (which already have the right slope)
      final beamMetrics = preliminaryBeamMetrics;
      
      // Create beam renderer
      final beamRenderer = BeamRenderer(
        beamGroup: beamGroup,
        beamMetrics: beamMetrics,
        noteXPositions: groupNotePositions,
        stemTipYPositions: adjustedGroupStemTipYPositions,
        color: layout.lineColor,
      );
      
      beamRenderers.add(beamRenderer);
    }
  }

  
  // The 'render' method itself remains largely the same.
  void render(Canvas canvas, Size size, {MusicalSymbol? selectedSymbol}) {
    _symbolBounds.clear(); // Clear layout info from the previous frame

    // Render symbols but hide flags for beamed notes
    for (final symbolRenderer in symbolRenderers) {
      final bounds = symbolRenderer.getBounds();
      _symbolBounds[symbolRenderer.musicalSymbol] = bounds;

      if (symbolPositionCallback != null) {
        symbolPositionCallback!(symbolRenderer.musicalSymbol, bounds);
      }

      // Check if this note should have its flag hidden (it's part of a beam)
      bool shouldHideFlag = false;
      if (symbolRenderer is NoteRenderer) {
        shouldHideFlag = _isNoteBeamed(symbolRenderer.noteMetrics.note);
      }

      // Render the symbol (with flag conditionally hidden)
      if (shouldHideFlag && symbolRenderer is NoteRenderer) {
        _renderNoteWithoutFlag(canvas, symbolRenderer);
      } else {
        symbolRenderer.render(canvas);
      }

      if (symbolRenderer.musicalSymbol == selectedSymbol) {
        final paint = Paint()
          ..color = Colors.red.withOpacity(0.5)
          ..style = PaintingStyle.fill;
        canvas.drawRect(bounds, paint);
      }
    }

    // Render beams
    for (final beamRenderer in beamRenderers) {
      beamRenderer.render(canvas);
    }
    
    _renderBarline(canvas);
  }

  /// Checks if a note is part of a beam group
  bool _isNoteBeamed(Note note) {
    for (final beamRenderer in beamRenderers) {
      if (beamRenderer.beamGroup.notes.contains(note)) {
        return true;
      }
    }
    return false;
  }

  /// Renders a note without its flag (for beamed notes)
  void _renderNoteWithoutFlag(Canvas canvas, NoteRenderer noteRenderer) {
    // Access the note renderer's private methods through a custom render
    noteRenderer.renderWithoutFlag(canvas);
  }

  // All other public methods and getters remain the same as they operate on the
  // now-updated internal state (symbolRenderers, measureMetrics, etc.).

  Rect getBounds() {
    // The measure bounds should always be the full measure width, not just the union of symbol bounds
    // This ensures that empty spaces in the measure are clickable for adding new notes
    // Extended Y bounds to include ledger line notes like middle C (±4 staff spaces)
    final y = staffLineCenterY - (4 * Constants.staffSpace);
    return Rect.fromLTWH(measureOriginX, y, width, 8 * Constants.staffSpace);
  }

  MusicalSymbol? getSymbolAt(Offset position) {
    for (final entry in _symbolBounds.entries) {
      if (entry.value.contains(position)) {
        return entry.key;
      }
    }
    return null;
  }

  int getInsertionIndexForX(double x) {
    for (var i = 0; i < symbolRenderers.length; i++) {
      final bounds = _symbolBounds[symbolRenderers[i].musicalSymbol];
      if (bounds != null && x < bounds.center.dx) {
        return i;
      }
    }
    return symbolRenderers.length;
  }
  
  Pitch getPitchForY(double y, Clef clef) {
    const centerLineY = 0.0;
    final halfStepY = Constants.staffSpace / 2;
    final stepsFromCenter = -((y - staffLineCenterY - centerLineY) / halfStepY).round();
    final centerLinePitch = clef.centerLinePitch;
    return (stepsFromCenter > 0)
        ? centerLinePitch.upN(stepsFromCenter)
        : centerLinePitch.downN(-stepsFromCenter);
  }

  Rect getHighlightRectForPitch(Pitch pitch, Clef clef) {
    final centerLinePitch = clef.centerLinePitch;
    final stepsFromCenter = pitch.difference(centerLinePitch);
    final halfStepY = Constants.staffSpace / 2;
    final y = staffLineCenterY - (stepsFromCenter * halfStepY);
    final isLine = pitch.isLineNote(clef);
    final top = isLine ? y - halfStepY / 2 : y - halfStepY;
    final bottom = isLine ? y + halfStepY / 2 : y + halfStepY;
    final left = measureOriginX;
    final right = left + width;
    return Rect.fromLTRB(left, top, right, bottom);
  }
  
  double get width => (measureMetrics.width + (2 * measurePadding)) * stretchFactor;

  // Drawing helpers

  void _renderBarline(Canvas canvas) {
    final barlineX = measureOriginX + width;
    final paint = Paint()
      ..color = layout.lineColor
      ..strokeWidth = measureMetrics.staffLineThickness;

    if (measureMetrics.isLastMeasure) {
      _drawFinalBarline(canvas, barlineX);
    } else {
      canvas.drawLine(
        Offset(barlineX, staffLineCenterY - 2 * Constants.staffSpace),
        Offset(barlineX, staffLineCenterY + 2 * Constants.staffSpace),
        paint,
      );
    }
  }

  void _drawFinalBarline(Canvas canvas, double barlineX) {
    final thinPaint = Paint()
      ..color = layout.lineColor
      ..strokeWidth = measureMetrics.staffLineThickness;
    final thickPaint = Paint()
      ..color = layout.lineColor
      ..strokeWidth = measureMetrics.staffLineThickness * 3;
    
    final thinBarX = barlineX - measureMetrics.staffLineThickness * 4;
    final thickBarX = barlineX - measureMetrics.staffLineThickness * 1.5;
    final startY = staffLineCenterY - 2 * Constants.staffSpace;
    final endY = staffLineCenterY + 2 * Constants.staffSpace;
    
    // Draw thin line first, then thick line
    canvas.drawLine(Offset(thinBarX, startY), Offset(thinBarX, endY), thinPaint);
    canvas.drawLine(Offset(thickBarX, startY), Offset(thickBarX, endY), thickPaint);
  }
}