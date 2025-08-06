import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:music_sheet/src/glyph_metadata.dart';
import 'package:music_sheet/src/glyph_path.dart';
import 'package:music_sheet/src/mixin/debug_render_mixin.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_metrics.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol_renderer.dart';
import 'package:music_sheet/src/music_objects/notes/accidental.dart';
import 'package:music_sheet/src/music_objects/notes/legerline.dart';
import 'package:music_sheet/src/music_objects/notes/note_duration.dart';
import 'package:music_sheet/src/music_objects/notes/note_pitch.dart';
import 'package:music_sheet/src/music_objects/notes/notehead_type.dart';
import 'package:music_sheet/src/music_objects/notes/positions.dart';
import 'package:music_sheet/src/musical_context.dart';
import 'package:music_sheet/src/sheet_music_layout.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';
import 'package:music_sheet/src/utils/scale_degree_calculator.dart';
import 'package:music_sheet/src/utils/chord_note_association.dart';

/// Represents a musical note.
class Note extends MusicalSymbol with EquatableMixin {
  Note(
    this.pitch, {
    String? id,
    this.noteDuration = NoteDuration.quarter,
    this.accidental,
    this.chordSymbol,
    super.color,
    super.margin,
  }) : super(id: id);

  final Pitch pitch;
  final NoteDuration noteDuration;
  final Accidental? accidental;
  final ChordSymbol? chordSymbol;

  NoteHeadType get noteHeadType => noteDuration.noteHeadType;

  @override
  double get duration => noteDuration.duration;

  @override
  MusicalSymbolMetrics setContext(
    MusicalContext context,
    GlyphMetadata metadata,
    GlyphPaths paths,
  ) =>
      NoteMetrics(this, context, metadata, paths);

  Note copyWith({String? id, Pitch? pitch, NoteDuration? noteDuration, Accidental? accidental, ChordSymbol? chordSymbol, Color? color, EdgeInsets? margin}) {
    return Note(
      pitch ?? this.pitch,
      id: id ?? this.id,
      noteDuration: noteDuration ?? this.noteDuration,
      accidental: accidental ?? this.accidental,
      chordSymbol: chordSymbol ?? this.chordSymbol,
      color: color ?? this.color,
      margin: margin ?? this.margin,
    );
  }

  @override
  List<Object?> get props => [id, pitch, noteDuration, accidental, chordSymbol, color, margin];
}

/// Represents the INTRINSIC metrics (size, shape) of a note.
class NoteMetrics implements MusicalSymbolMetrics {
  const NoteMetrics(
    this.note,
    this.context,
    this.metadata,
    this.paths,
  );

  final Note note;
  final MusicalContext context;
  final GlyphMetadata metadata;
  final GlyphPaths paths;

  Path get noteHeadPath => paths.parsePath(note.noteHeadType.pathKey);
  Path? get accidentalPath => hasAccidental ? paths.parsePath(note.accidental!.pathKey) : null;
  Path? get flagPathOnY0 => hasFlag ? paths.parsePath(_flagPathKey!) : null;

  Rect get _noteHeadBbox => noteHeadPath.getBounds();
  Rect? get _accidentalBbox => accidentalPath?.getBounds();
  Rect? get _flagBboxOnY0 => flagPathOnY0?.getBounds();

  @override
  double get width => accidentalWidth + noteHeadWidth;
  
  double get noteHeadWidth => _noteHeadBbox.width;
  double get accidentalWidth => _accidentalBbox?.width ?? 0;

  @override
  double get lowerHeight => bbox.bottom;
  @override
  double get upperHeight => -bbox.top;

  Rect get bbox {
    var rect = _noteHeadBbox.shift(Offset(accidentalWidth, 0));
    if (_accidentalBbox != null) {
      rect = rect.expandToInclude(_accidentalBbox!);
    }
    if (hasFlag) {
      final flagBbox = _flagBboxOnY0!.shift(_flagOffset);
      rect = rect.expandToInclude(flagBbox);
    }
    if (hasStem) {
      rect = rect.expandToInclude(Rect.fromPoints(stemRootOffset, stemTipOffset));
    }
    return rect;
  }
  
  Pitch get pitch => note.pitch;
  Color get color => note.color;
  @override
  EdgeInsets get margin => note.margin;
  StavePosition get stavePosition => StavePosition(pitch, context.clefType);
  bool get hasAccidental => note.accidental != null;
  bool get hasStem => note.noteDuration.hasStem;
  bool get hasFlag => note.noteDuration.hasFlag;
  bool get isStemUp => stavePosition.defaultStemDirection.isUp;
  double get stemThickness => metadata.stemThickness;
  double get legerLineThickness => metadata.legerLineThickness;
  double get legerLineExtension => metadata.legerLineExtension;

  Offset get stemRootOffset {
    final noteHeadInitialX = accidentalWidth;
    final stemRoot = metadata.stemRootOffset(note.noteHeadType.metadataKey, isStemUp: isStemUp);
    final stemThicknessOffset = Offset(isStemUp ? -stemThickness / 2 : stemThickness / 2, 0);
    return Offset(noteHeadInitialX, 0) + stemRoot + stemThicknessOffset;
  }
  
  // --- THE FIX: Broke the circular dependency for stem/flag offsets ---

  /// Calculates the stem tip as if there were no flag.
  Offset get _stemTipWithoutFlag {
    final stemRootToStaffCenterDist = (stemRootOffset.dy + stavePosition.positionOffset.dy).abs();
    final minStemLength = metadata.minStemLength;
    final isStemCentered = stemRootToStaffCenterDist > minStemLength;

    if (isStemCentered) {
      return Offset(stemRootOffset.dx, -stavePosition.positionOffset.dy);
    }
    final stemLength = minStemLength;
    return stemRootOffset + Offset(0, isStemUp ? -stemLength : stemLength);
  }

  /// The final, public stem tip offset.
  Offset get stemTipOffset {
    if (hasFlag) {
      // If there's a flag, the stem tip is at the flag's anchor point.
      return _flagStemOffset;
    }
    // Otherwise, it's the simple stem tip.
    return _stemTipWithoutFlag;
  }

  /// The flag's position is based on the stem tip *without* a flag, breaking the recursion.
  Offset get _flagOffset => _stemTipWithoutFlag;

  /// The final position of the flag's anchor point.
  Offset get _flagStemOffset {
    if (!hasFlag) return Offset.zero;
    return metadata.flagRootOffset(_flagMetadataKey!, isStemUp: isStemUp) + _flagOffset;
  }

  // --- End of fix ---

  String? get _flagPathKey {
    if (!hasFlag) return null;
    final flagType = note.noteDuration.noteFlagType!;
    return isStemUp ? flagType.upPathKey : flagType.downPathKey;
  }
  
  String? get _flagMetadataKey {
    if (!hasFlag) return null;
    final flagType = note.noteDuration.noteFlagType!;
    return isStemUp ? flagType.upMetadataKey : flagType.downMetadataKey;
  }

  @override
  MusicalSymbolRenderer renderer(
    SheetMusicLayout layout, {
    required double staffLineCenterY,
    required double symbolX,
  }) =>
      NoteRenderer(
        this,
        layout,
        staffLineCenterY: staffLineCenterY,
        symbolX: symbolX,
        musicalSymbol: note,
      );
}

/// A class that renders a musical note symbol.
class NoteRenderer with DebugRenderMixin implements MusicalSymbolRenderer {
  NoteRenderer(
    this.noteMetrics,
    this.layout, {
    required this.staffLineCenterY,
    required this.symbolX,
    required this.musicalSymbol,
  });

  final NoteMetrics noteMetrics;
  final SheetMusicLayout layout;
  final double staffLineCenterY;
  final double symbolX;

  @override
  final MusicalSymbol musicalSymbol;

  /// The chord symbol associated with this note (for extension number display)
  ChordSymbol? _associatedChordSymbol;

  /// Sets the chord symbol associated with this note
  void setAssociatedChordSymbol(ChordSymbol? chordSymbol) {
    _associatedChordSymbol = chordSymbol;
  }

  Offset get _renderOffset => Offset(symbolX, staffLineCenterY);
  Offset get _pitchOffset => noteMetrics.stavePosition.positionOffset;

  @override
  Rect getBounds() => noteMetrics.bbox.shift(_renderOffset + _pitchOffset);

  @override
  bool isHit(Offset position) => getBounds().contains(position);

  @override
  void render(Canvas canvas) {
    _renderAccidental(canvas);
    _renderNoteHead(canvas);
    _renderStem(canvas);
    _renderFlag(canvas);
    _renderLegerLine(canvas);
    _renderScaleDegree(canvas);
    _renderChordExtension(canvas);

    if (layout.debug) {
      renderBoundingBox(canvas, getBounds());
    }
  }

  void _renderAccidental(Canvas canvas) {
    if (!noteMetrics.hasAccidental) return;
    final path = noteMetrics.accidentalPath!;
    final offset = _renderOffset + _pitchOffset;
    canvas.drawPath(path.shift(offset), Paint()..color = noteMetrics.color);
  }

  void _renderNoteHead(Canvas canvas) {
    final path = noteMetrics.noteHeadPath;
    final offset = _renderOffset + _pitchOffset + Offset(noteMetrics.accidentalWidth, 0);
    canvas.drawPath(path.shift(offset), Paint()..color = noteMetrics.color);
  }

  void _renderStem(Canvas canvas) {
    if (!noteMetrics.hasStem) return;
    final offset = _renderOffset + _pitchOffset;
    canvas.drawLine(
      noteMetrics.stemRootOffset + offset,
      noteMetrics.stemTipOffset + offset,
      Paint()
        ..color = noteMetrics.color
        ..strokeWidth = noteMetrics.stemThickness,
    );
  }

  void _renderFlag(Canvas canvas) {
    if (!noteMetrics.hasFlag) return;
    final path = noteMetrics.flagPathOnY0!;
    final offset = _renderOffset + _pitchOffset;
    canvas.drawPath(
      path.shift(noteMetrics.stemTipOffset + offset),
      Paint()..color = noteMetrics.color,
    );
  }

  void _renderLegerLine(Canvas canvas) {
    final noteHeadCenterX = symbolX + noteMetrics.accidentalWidth + (noteMetrics.noteHeadWidth / 2);
    final legerLineWidth = noteMetrics.legerLineExtension * 2 + noteMetrics.noteHeadWidth;
    
    LegerLineRenderer(
      layout.lineColor,
      noteMetrics.stavePosition,
      staffLineCenterY: staffLineCenterY,
      noteCenterX: noteHeadCenterX,
      legerLineWidth: legerLineWidth,
      legerLineThickness: noteMetrics.legerLineThickness,
    ).render(canvas);
  }

  void _renderScaleDegree(Canvas canvas) {
    final chord = (musicalSymbol as Note).chordSymbol;
    if (chord == null) return;

    final scaleDegree = getScaleDegree(noteMetrics.pitch, chord);
    final textPainter = TextPainter(
      text: TextSpan(
        text: scaleDegree,
        style: TextStyle(color: noteMetrics.color, fontSize: 24 / layout.canvasScale),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final noteHeadBounds = noteMetrics.noteHeadPath.getBounds().shift(
      _renderOffset + _pitchOffset + Offset(noteMetrics.accidentalWidth, 0)
    );
    final noteHeadCenter = noteHeadBounds.center;

    final x = noteHeadCenter.dx - textPainter.width / 2;
    final y = noteMetrics.isStemUp
        ? noteHeadBounds.bottom + (10 / layout.canvasScale)
        : noteHeadBounds.top - textPainter.height - (10 / layout.canvasScale);

    textPainter.paint(canvas, Offset(x, y));
  }

  void _renderChordExtension(Canvas canvas) {
    // Only render chord extension if we have an associated chord symbol
    if (_associatedChordSymbol == null) return;
    
    final note = musicalSymbol as Note;
    final extension = getChordExtension(note, _associatedChordSymbol!);
    if (extension.isEmpty) return;

    // Create a paint for the clay container background
    final containerPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;

    // Create a paint for the container border
    final borderPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Create text painter for the extension number
    final textPainter = TextPainter(
      text: TextSpan(
        text: extension,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 12 / layout.canvasScale,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Get note head bounds for positioning
    final noteHeadBounds = noteMetrics.noteHeadPath.getBounds().shift(
      _renderOffset + _pitchOffset + Offset(noteMetrics.accidentalWidth, 0)
    );
    final noteHeadCenter = noteHeadBounds.center;

    // Calculate container size with padding
    const padding = 4.0;
    final containerWidth = textPainter.width + (padding * 2);
    final containerHeight = textPainter.height + (padding * 2);

    // Position the container based on stem direction
    final containerX = noteHeadCenter.dx - containerWidth / 2;
    final containerY = noteMetrics.isStemUp
        ? noteHeadBounds.bottom + (8 / layout.canvasScale)
        : noteHeadBounds.top - containerHeight - (8 / layout.canvasScale);

    // Create container rectangle with rounded corners
    final containerRect = Rect.fromLTWH(containerX, containerY, containerWidth, containerHeight);
    final rrect = RRect.fromRectAndRadius(containerRect, const Radius.circular(6.0));

    // Draw the clay container background
    canvas.drawRRect(rrect, containerPaint);
    
    // Draw the border
    canvas.drawRRect(rrect, borderPaint);

    // Draw the text centered in the container
    final textX = containerX + padding;
    final textY = containerY + padding;
    textPainter.paint(canvas, Offset(textX, textY));
  }
}