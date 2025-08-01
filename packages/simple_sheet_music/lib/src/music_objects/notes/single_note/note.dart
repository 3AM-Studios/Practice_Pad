import 'package:flutter/material.dart';
import 'package:simple_sheet_music/src/extension/list_extension.dart';
import 'package:simple_sheet_music/src/glyph_metadata.dart';
import 'package:simple_sheet_music/src/glyph_path.dart';
import 'package:simple_sheet_music/src/music_objects/clef/clef_type.dart';
import 'package:simple_sheet_music/src/music_objects/interface/musical_symbol.dart';
import 'package:simple_sheet_music/src/music_objects/interface/musical_symbol_metrics.dart';
import 'package:simple_sheet_music/src/music_objects/interface/musical_symbol_renderer.dart';
import 'package:simple_sheet_music/src/music_objects/notes/accidental.dart';
import 'package:simple_sheet_music/src/music_objects/notes/legerline.dart';
import 'package:simple_sheet_music/src/music_objects/notes/note_duration.dart';
import 'package:simple_sheet_music/src/music_objects/notes/note_pitch.dart';
import 'package:simple_sheet_music/src/music_objects/notes/noteflag_type.dart';
import 'package:simple_sheet_music/src/music_objects/notes/notehead_type.dart';
import 'package:simple_sheet_music/src/music_objects/notes/positions.dart';
import 'package:simple_sheet_music/src/music_objects/notes/stem_direction.dart';
import 'package:simple_sheet_music/src/musical_context.dart';
import 'package:simple_sheet_music/src/sheet_music_layout.dart';

/// Represents a musical note.
class Note implements MusicalSymbol {
  Note(
    this.pitch, {
    this.selectable = true,
    this.noteDuration = NoteDuration.quarter,
    this.accidental,
    this.margin = const EdgeInsets.all(10),
    Color color = Colors.black,
    // this.stemDirection,
  }) : _color = color;

  final bool selectable;

  @override
  final EdgeInsets margin;

  // /// The direction of the note stem.
  // final StemDirection? stemDirection;
  Color _color;

  set color(Color newColor) {
    _color = newColor;
  }

  Color get color => _color;

  /// The pitch of the note.
  final Pitch pitch;

  /// The duration of the note.
  final NoteDuration noteDuration;

  /// The accidental of the note (if any).
  final Accidental? accidental;

  /// The type of note head based on the note duration.
  NoteHeadType get noteHeadType => noteDuration.noteHeadType;

  final pitchNames = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B'
  ];

  int get halfStepIndex {
    final startPitch = pitch;
    final startName = startPitch.name[0];

    // Calculate the starting index in pitchNames, considering the accidental
    int startIndex = pitchNames.indexOf(startName);
    if (accidental == Accidental.sharp) startIndex++;
    if (accidental == Accidental.flat) startIndex--;
    return (startIndex + 12) % 12; // Ensure positive index
  }

  Note moveSemitones(int semitones,
      {bool keepOctave = false, bool flat = false}) {
    if (semitones == 0) return this;

    final startPitch = pitch;
    final startOctave = int.parse(startPitch.name[1]);

    // Calculate the starting index in pitchNames, considering the accidental
    int startIndex = this.halfStepIndex;

    // Calculate the new index and octave
    int newIndex = (startIndex + semitones) % 12;
    int newOctave = startOctave;
    if (!keepOctave) {
      int octaveChange = ((startIndex + semitones) / 12).floor();
      newOctave = startOctave + octaveChange;
    }

    // Determine the new pitch and accidental
    String newPitchName = pitchNames[newIndex];
    Accidental? newAccidental;
    if (newPitchName.length > 1) {
      if (flat) {
        newPitchName = pitchNames[newIndex + 1][0];
        newAccidental = Accidental.flat;
      } else {
        newAccidental = Accidental.sharp;
        newPitchName = newPitchName[0];
      }
    }

    final newPitchFullName = newPitchName + newOctave.toString();
    final newPitch = Pitch.values.firstWhere((p) => p.name == newPitchFullName);

    return Note(newPitch, accidental: newAccidental);
  }

  String get noteText {
    var pitch = this.pitch.name.substring(0, this.pitch.name.length - 1);

    return this.accidental != null ? pitch + this.accidental!.symbol : pitch;
  }

  @override
  MusicalSymbolMetrics setContext(
    MusicalContext context,
    GlyphMetadata metadata,
    GlyphPaths paths,
  ) =>
      NoteMetrics(this, context, metadata, paths);
}

/// Represents the metrics (size, position, etc.) of a single note in sheet music.
class NoteMetrics implements MusicalSymbolMetrics {
  const NoteMetrics(
    this.note,
    this.context,
    this.metadata,
    this.paths,
  );

  // The musical context in which the note appears.
  final MusicalContext context;

  // The metadata of the note's glyph.
  final GlyphMetadata metadata;

  // The paths of the note's glyph.
  final GlyphPaths paths;

  // The note object associated with these metrics.
  final Note note;

  @override
  double get lowerHeight => bbox.bottom;

  // The width of the note head.
  double get noteHeadWidth => _noteHeadBbox.width;

  // The bounding box of the note.
  Rect get bbox => Rect.fromLTRB(_left, _top, _right, _bottom);

  double get _left =>
      [_noteHeadBbox.left, (_accidentalBbox?.left ?? _noteHeadBbox.left)].min;

  double get _top => [
        _noteHeadBbox.top,
        hasStem ? stemTipOffset.dy : double.infinity,
        (_flagBbox?.top ?? double.infinity),
        (_accidentalBbox?.top ?? double.infinity),
      ].min;

  double get _right => [
        _noteHeadBbox.right,
        (_flagBbox?.right ?? double.negativeInfinity),
        (_accidentalBbox?.right ?? double.negativeInfinity),
      ].max;

  double get _bottom => [
        _noteHeadBbox.bottom,
        hasStem ? stemTipOffset.dy : double.negativeInfinity,
        (_flagBbox?.bottom ?? double.negativeInfinity),
        (_accidentalBbox?.bottom ?? double.negativeInfinity),
      ].max;

  @override
  EdgeInsets get margin => note.margin;

  // The pitch of the note.
  Pitch get pitch => note.pitch;

  // The thickness of the leger lines.
  double get legerLineThickness => metadata.legerLineThickness;

  // The extension of the leger lines.
  double get legerLineExtension => metadata.legerLineExtension;

  // The color of the note.
  Color get color => note.color;

  @override
  MusicalSymbolRenderer renderer(
    SheetMusicLayout layout, {
    required double staffLineCenterY,
    required double symbolX,
  }) {
    return NoteRenderer(
      this,
      layout,
      staffLineCenterY: staffLineCenterY,
      symbolX: symbolX,
    );
  }

  @override
  double get upperHeight => -bbox.top;

  @override
  double get width => bbox.width;

  // The bounding box of the note head.
  Rect get _noteHeadBbox => noteHeadPath.getBounds();
  Rect get noteHeadBbox => _noteHeadBbox;

  Rect globalHeadBBox(BuildContext context) {
    // Use the provided context if available, otherwise use the stored context
    BuildContext effectiveContext = context;

    final RenderBox renderBox =
        effectiveContext.findRenderObject() as RenderBox;
    final localBounds = noteHeadPath.getBounds();
    final topLeft = renderBox.localToGlobal(localBounds.topLeft);
    final bottomRight = renderBox.localToGlobal(localBounds.bottomRight);
    return Rect.fromPoints(topLeft, bottomRight);
  }

  // The default offset of the note.
  Offset get _defaultOffset => Offset.zero;

  // The path of the note head.
  Path get noteHeadPath => paths
      .parsePath(note.noteHeadType.pathKey)
      .shift(_defaultOffset + _positionOffset + Offset(accidentalWidth, 0));

  // The left x-coordinate of the note head.
  double get noteHeadLeftX => _noteHeadBbox.left;
  // The width of the accidental (if any).
  double get accidentalWidth => _accidentalBbox?.width ?? 0;

  // The bounding box of the accidental (if any).
  Rect? get _accidentalBbox {
    if (!hasAccidental) {
      return null;
    }
    return accidentalPath!.getBounds();
  }

  // The offset of the note's position.
  Offset get _positionOffset => stavePosition.positionOffset;

  // The accidental of the note (if any).
  Accidental? get _accidental => note.accidental;

  // Whether the note has an accidental.
  bool get hasAccidental => _accidental != null;

  // The path of the accidental (if any).
  Path? get accidentalPath {
    if (!hasAccidental) {
      return null;
    }
    return paths
        .parsePath(_accidental!.pathKey)
        .shift(_defaultOffset + _positionOffset);
  }

  // The stave position of the note.
  StavePosition get stavePosition => StavePosition(pitch, _clefType);

  // The clef type of the note.
  ClefType get _clefType => context.clefType;

  // The minimum length of the stem.
  double get _minStemLength => metadata.minStemLength;

  // The distance from the stem root to the center of the staff.
  double get _stemRootToStaffCenterDist => stemRootOffset.dy.abs();

  // Whether the stem is centered.
  bool get _isStemCentered => _stemRootToStaffCenterDist > _minStemLength;

  // The length of the stem.
  double get _stemLength =>
      _isStemCentered ? _stemRootToStaffCenterDist : _minStemLength;

  // The thickness of the stem.
  double get stemThickness => metadata.stemThickness;

  // The initial x-coordinate of the note head.
  double get _noteHeadInitialX => _noteHeadBbox.left;

  // The offset of the stem root.
  Offset get stemRootOffset =>
      Offset(_noteHeadInitialX, 0) +
      metadata.stemRootOffset(_noteHeadType.metadataKey, isStemUp: _isStemUp) +
      _stemThicknessOffset +
      _positionOffset;

  // The offset of the stem thickness.
  Offset get _stemThicknessOffset =>
      Offset(_isStemUp ? -stemThickness / 2 : stemThickness / 2, 0);

  // The offset of the stem tip.
  Offset get stemTipOffset {
    if (hasFlag) {
      return _flagStemOffset! + Offset(stemThickness / 2, 0);
    }
    if (_isStemCentered) {
      return Offset(stemRootOffset.dx, 0);
    }
    return stemRootOffset + Offset(0, _isStemUp ? -_stemLength : _stemLength);
  }

  // The offset of the flag.
  Offset get _flagOffset {
    if (_isStemCentered) {
      return Offset(
        stemRootOffset.dx - stemThickness / 2,
        -(_isStemUp ? _flagBboxOnY0!.top : _flagBboxOnY0!.bottom),
      );
    }
    return stemRootOffset + Offset(0, _isStemUp ? -_stemLength : _stemLength);
  }

  // Whether the note has a stem.
  bool get hasStem => note.noteDuration.hasStem;

  // Whether the stem is up.
  // bool get _isStemUp => note.stemDirection?.isUp ?? _defaultStemDirection.isUp;
  bool get _isStemUp => _defaultStemDirection.isUp;

  // The default stem direction based on the stave position.
  StemDirection get _defaultStemDirection => stavePosition.defaultStemDirection;

  // The type of the note head.
  NoteHeadType get _noteHeadType => note.noteHeadType;

  // Whether the note has a flag.
  bool get hasFlag => note.noteDuration.hasFlag;

  // The type of the note flag.
  NoteFlagType? get _noteFlagType => note.noteDuration.noteFlagType;

  // The metadata key of the flag.
  String? get _flagMetadataKey {
    if (!hasFlag) {
      return null;
    }
    return _isStemUp
        ? _noteFlagType!.upMetadataKey
        : _noteFlagType!.downMetadataKey;
  }

  // The path key of the flag.
  String? get _flagPathKey {
    if (!hasFlag) {
      return null;
    }
    return _isStemUp ? _noteFlagType!.upPathKey : _noteFlagType!.downPathKey;
  }

  // The offset of the flag stem.
  Offset? get _flagStemOffset {
    if (!hasFlag) {
      return null;
    }
    return metadata.flagRootOffset(_flagMetadataKey!, isStemUp: _isStemUp) +
        _flagOffset;
  }

  // The path of the flag on the y=0 line.
  Path? get _flagPathOnY0 {
    if (!hasFlag) {
      return null;
    }
    return paths.parsePath(_flagPathKey!);
  }

  // The bounding box of the flag on the y=0 line.
  Rect? get _flagBboxOnY0 {
    if (!hasFlag) {
      return null;
    }
    return _flagPathOnY0!.getBounds();
  }

  // The path of the flag.
  Path? get flagPath {
    if (!hasFlag) {
      return null;
    }
    return _flagPathOnY0!.shift(_flagOffset);
  }

  // The bounding box of the flag.
  Rect? get _flagBbox => flagPath?.getBounds();
}

/// A class that renders a musical note symbol.
class NoteRenderer implements MusicalSymbolRenderer {
  const NoteRenderer(
    this.note,
    this.layout, {
    required this.staffLineCenterY,
    required this.symbolX,
  });

  final SheetMusicLayout layout;
  final double staffLineCenterY;
  final double symbolX;
  final NoteMetrics note;

  /// Returns the scale of the canvas.
  double get canvasScale => layout.canvasScale;

  @override
  bool isHit(Offset position) => _renderArea.contains(position);

  @override
  void render(Canvas canvas) {
    _renderNoteHead(canvas);
    _renderFlag(canvas);
    _renderAccidental(canvas);
    _renderStem(canvas);
    _renderLegerLine(canvas);
  }

  void _renderNoteHead(Canvas canvas) {
    canvas.drawPath(noteHeadRenderPath, Paint()..color = note.color);
  }

  void _renderAccidental(Canvas canvas) {
    if (!note.hasAccidental) {
      return;
    }
    canvas.drawPath(
      renderAccidentalPath!,
      Paint()
        ..color = note.note.color
        ..strokeWidth = 2,
    );
  }

  /// Returns the path of the accidental, shifted by the render offset.
  Path? get renderAccidentalPath => note.accidentalPath?.shift(_renderOffset);

  void _renderStem(Canvas canvas) {
    if (!note.hasStem) {
      return;
    }
    canvas.drawLine(
      note.stemRootOffset + _renderOffset,
      note.stemTipOffset + _renderOffset,
      Paint()
        ..color = note.color
        ..strokeWidth = note.stemThickness,
    );
  }

  /// Returns the path of the note head, shifted by the render offset.
  Path get noteHeadRenderPath => note.noteHeadPath.shift(_renderOffset);

  void _renderFlag(Canvas canvas) {
    if (!note.hasFlag) {
      return;
    }
    canvas.drawPath(
      note.flagPath!.shift(_renderOffset),
      Paint()..color = note.color,
    );
  }

  /// Returns the render offset, which is the sum of the symbol X position and the staff line center Y position.
  Offset get _renderOffset => Offset(symbolX, staffLineCenterY) + _marginOffset;
  Offset get renderOffset => _renderOffset;

  /// Returns the margin offset, which is the left margin of the note divided by the canvas scale.
  Offset get _marginOffset => Offset(note.margin.left / canvasScale, 0);
  Offset get marginOffset => _marginOffset;

  /// Returns the render area of the note, shifted by the render offset.
  Rect get _renderArea => note.bbox.shift(_renderOffset);

  Rect get renderArea => _renderArea;

  /// Returns the width of the leger line, which is twice the leger line extension plus the note head width.
  double get _legerLineWidth => note.legerLineExtension * 2 + _noteHeadWidth;

  /// Returns the thickness of the leger line.
  double get _legerLineThickness => note.legerLineThickness;

  /// Renders the leger line.
  void _renderLegerLine(Canvas canvas) => LegerLineRenderer(
        layout.lineColor,
        _notePosition,
        staffLineCenterY: staffLineCenterY,
        noteCenterX: _noteHeadCenterX,
        legerLineWidth: _legerLineWidth,
        legerLineThickness: _legerLineThickness,
      ).render(canvas);

  /// Returns the position of the note on the stave.
  StavePosition get _notePosition => note.stavePosition;

  /// Returns the width of the note head.
  double get _noteHeadWidth => note.noteHeadWidth;

  /// Returns the left X position of the note head.
  double get _noteHeadLeftX => _renderOffset.dx + note.noteHeadLeftX;
  double get noteHeadLeftX => _renderOffset.dx + note.noteHeadLeftX;

  /// Returns the center X position of the note head.
  double get _noteHeadCenterX => _noteHeadLeftX + note.noteHeadWidth / 2;
}
