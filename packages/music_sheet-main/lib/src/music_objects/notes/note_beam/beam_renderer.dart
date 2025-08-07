import 'package:flutter/material.dart';
import 'package:music_sheet/src/music_objects/notes/note_beam/beam_calculator.dart';
import 'package:music_sheet/src/music_objects/notes/note_beam/beam_group.dart';

/// Renders beams that connect note stems for grouped eighth notes, sixteenth notes, etc.
class BeamRenderer {
  BeamRenderer({
    required this.beamGroup,
    required this.beamMetrics,
    required this.noteXPositions,
    required this.stemTipYPositions,
    required this.color,
  });

  final BeamGroup beamGroup;
  final BeamMetrics beamMetrics;
  final List<double> noteXPositions;
  final List<double> stemTipYPositions;
  final Color color;

  /// Renders the beam(s) on the given canvas
  void render(Canvas canvas) {
    if (!beamGroup.shouldBeBeamed) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Render each beam level
    for (int level = 0; level < beamMetrics.levels; level++) {
      _renderBeamLevel(canvas, paint, level);
    }
  }

  /// Renders a single beam level (e.g., first beam for eighth notes, second beam for sixteenth notes)
  void _renderBeamLevel(Canvas canvas, Paint paint, int level) {
    final baseY = level == 0 
        ? beamMetrics.startY 
        : beamMetrics.startY + (level * beamMetrics.spacing * _getSpacingDirection());
    
    final endBaseY = level == 0
        ? beamMetrics.endY
        : beamMetrics.endY + (level * beamMetrics.spacing * _getSpacingDirection());

    // For the first level, draw a full beam connecting all notes
    if (level == 0) {
      _renderFullBeam(canvas, paint, baseY, endBaseY);
      return;
    }

    // For higher levels, we need to check which notes require this level
    _renderPartialBeams(canvas, paint, level, baseY, endBaseY);
  }

  /// Renders a full beam connecting all notes in the group
  void _renderFullBeam(Canvas canvas, Paint paint, double startY, double endY) {
    final beamPath = Path();
    
    // Extend beam slightly beyond stem positions for better visual connection
    const beamExtension = 2.0;
    final extendedStartX = beamMetrics.startX - beamExtension;
    final extendedEndX = beamMetrics.endX + beamExtension;
    
    // Top edge of the beam
    beamPath.moveTo(extendedStartX, startY);
    beamPath.lineTo(extendedEndX, endY);
    
    // Bottom edge of the beam
    beamPath.lineTo(extendedEndX, endY + beamMetrics.thickness);
    beamPath.lineTo(extendedStartX, startY + beamMetrics.thickness);
    
    beamPath.close();
    canvas.drawPath(beamPath, paint);
  }

  /// Renders partial beams for higher levels (sixteenth notes, thirty-second notes, etc.)
  void _renderPartialBeams(Canvas canvas, Paint paint, int level, double baseY, double endBaseY) {
    // Group consecutive notes that need this beam level
    final segments = _getBeamSegments(level);
    
    for (final segment in segments) {
      final segmentStartX = noteXPositions[segment.startIndex];
      final segmentEndX = noteXPositions[segment.endIndex];
      
      // Extend partial beams slightly for better visual connection
      const beamExtension = 2.0;
      final extendedStartX = segmentStartX - beamExtension;
      final extendedEndX = segmentEndX + beamExtension;
      final extendedStartY = _getYAtX(baseY, endBaseY, extendedStartX);
      final extendedEndY = _getYAtX(baseY, endBaseY, extendedEndX);
      
      final beamPath = Path();
      
      // Top edge of the beam segment
      beamPath.moveTo(extendedStartX, extendedStartY);
      beamPath.lineTo(extendedEndX, extendedEndY);
      
      // Bottom edge of the beam segment
      beamPath.lineTo(extendedEndX, extendedEndY + beamMetrics.thickness);
      beamPath.lineTo(extendedStartX, extendedStartY + beamMetrics.thickness);
      
      beamPath.close();
      canvas.drawPath(beamPath, paint);
    }
  }

  /// Gets the Y coordinate at a given X position along the beam
  double _getYAtX(double startY, double endY, double x) {
    final slope = (endY - startY) / (beamMetrics.endX - beamMetrics.startX);
    return startY + slope * (x - beamMetrics.startX);
  }

  /// Returns the direction multiplier for beam spacing (1 for stems up, -1 for stems down)
  int _getSpacingDirection() {
    // Determine stem direction from the first note
    // If stems are up, additional beams go above; if stems are down, they go below
    return _areStemsUp() ? -1 : 1;
  }

  /// Determines if stems are pointing up for this beam group
  bool _areStemsUp() {
    // Use the same logic as in BeamCalculator
    if (beamGroup.notes.isEmpty) return true;
    
    final positions = beamGroup.notes.map((note) => note.pitch.position).toList();
    final averagePosition = positions.reduce((a, b) => a + b) / positions.length;
    
    return averagePosition < 25; // Approximately middle of the staff
  }

  /// Gets beam segments for a specific beam level
  List<_BeamSegment> _getBeamSegments(int level) {
    final segments = <_BeamSegment>[];
    int segmentStart = -1;
    
    for (int i = 0; i < beamGroup.notes.length; i++) {
      final note = beamGroup.notes[i];
      final noteBeamLevel = BeamGroup.getBeamLevel(note.noteDuration);
      
      if (noteBeamLevel > level) {
        // This note needs this beam level
        if (segmentStart == -1) {
          segmentStart = i; // Start new segment
        }
      } else {
        // This note doesn't need this beam level
        if (segmentStart != -1) {
          // End current segment
          segments.add(_BeamSegment(startIndex: segmentStart, endIndex: i - 1));
          segmentStart = -1;
        }
      }
    }
    
    // Close any remaining segment
    if (segmentStart != -1) {
      segments.add(_BeamSegment(startIndex: segmentStart, endIndex: beamGroup.notes.length - 1));
    }
    
    return segments;
  }
}

/// Represents a segment of a beam that connects consecutive notes
class _BeamSegment {
  _BeamSegment({required this.startIndex, required this.endIndex});
  
  final int startIndex;
  final int endIndex;
  
  /// Returns true if this segment contains only one note (should be rendered as a partial beam)
  bool get isSingle => startIndex == endIndex;
}