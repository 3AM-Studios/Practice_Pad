import 'package:music_sheet/src/music_objects/notes/single_note/note.dart';
import 'package:music_sheet/src/music_objects/notes/note_beam/beam_group.dart';
import 'package:music_sheet/src/glyph_metadata.dart';

/// Represents the calculated positioning data for a beam
class BeamMetrics {
  BeamMetrics({
    required this.startX,
    required this.endX,
    required this.startY,
    required this.endY,
    required this.thickness,
    required this.spacing,
    required this.levels,
  });

  final double startX;
  final double endX;
  final double startY;
  final double endY;
  final double thickness;
  final double spacing;
  final int levels;

  /// Returns the slope of the beam
  double get slope => (endY - startY) / (endX - startX);

  /// Returns the Y position at a given X coordinate along the beam
  double getYAtX(double x) {
    if (startX == endX) return startY;
    return startY + slope * (x - startX);
  }
}

/// Calculates beam positioning and metrics for beam groups
class BeamCalculator {
  BeamCalculator(this.metadata);

  final GlyphMetadata metadata;

  /// Calculates beam metrics for a beam group
  BeamMetrics calculateBeamMetrics(
    BeamGroup beamGroup,
    List<double> noteXPositions,
    List<double> stemTipYPositions,
  ) {
    if (beamGroup.notes.length != noteXPositions.length ||
        beamGroup.notes.length != stemTipYPositions.length) {
      throw ArgumentError('Note count must match position arrays');
    }

    if (beamGroup.notes.length < 2) {
      throw ArgumentError('Beam group must contain at least 2 notes');
    }

    // Use much thicker beams for better visibility (multiply stem thickness by 4)
    final thickness = metadata.stemThickness * 4.0;
    // Use larger spacing between beams to clearly distinguish 16th notes from 8th notes
    final spacing = metadata.stemThickness * 5.0;
    
    // Calculate beam endpoints
    final startX = noteXPositions.first;
    final endX = noteXPositions.last;
    
    // Determine if stems are up or down based on the first note
    final stemsUp = _determineStemDirection(beamGroup.notes);
    
    // Calculate optimal beam position with slope
    final beamLine = _calculateBeamLine(
      noteXPositions, 
      stemTipYPositions, 
      stemsUp,
    );
    
    return BeamMetrics(
      startX: startX,
      endX: endX,
      startY: beamLine.startY,
      endY: beamLine.endY,
      thickness: thickness,
      spacing: spacing,
      levels: beamGroup.beamLevels,
    );
  }

  /// Determines the stem direction for the beam group
  bool _determineStemDirection(List<Note> notes) {
    // Since we're only beaming notes with the same stem direction,
    // we can just use the first note's stem direction
    if (notes.isEmpty) return true;
    
    // Use the same logic as BeamGroupAnalyzer
    // Notes on or above the middle line (B4, position 29) should have stems down
    // Notes below the middle line should have stems up
    return notes.first.pitch.position < 29; // true = stems up, false = stems down
  }

  /// Calculates the beam line with appropriate slope
  _BeamLine _calculateBeamLine(
    List<double> noteXPositions,
    List<double> stemTipYPositions,
    bool stemsUp,
  ) {
    if (noteXPositions.length != stemTipYPositions.length) {
      throw ArgumentError('Position arrays must have same length');
    }

    // Use a simple linear regression to find the best fit line
    final slope = _calculateOptimalSlope(noteXPositions, stemTipYPositions);
    
    // Constrain slope to reasonable limits for readability
    final constrainedSlope = _constrainSlope(slope);
    
    // Calculate start Y position based on the first note
    final startX = noteXPositions.first;
    final endX = noteXPositions.last;
    final startY = stemTipYPositions.first;
    final endY = startY + constrainedSlope * (endX - startX);
    
    return _BeamLine(startY: startY, endY: endY);
  }

  /// Calculates optimal slope using simple linear regression
  double _calculateOptimalSlope(List<double> xPositions, List<double> yPositions) {
    if (xPositions.length < 2) return 0.0;
    
    final n = xPositions.length;
    final sumX = xPositions.reduce((a, b) => a + b);
    final sumY = yPositions.reduce((a, b) => a + b);
    final sumXY = xPositions.asMap().entries
        .map((entry) => entry.value * yPositions[entry.key])
        .reduce((a, b) => a + b);
    final sumX2 = xPositions.map((x) => x * x).reduce((a, b) => a + b);
    
    final denominator = n * sumX2 - sumX * sumX;
    if (denominator.abs() < 0.001) return 0.0; // Avoid division by zero
    
    return (n * sumXY - sumX * sumY) / denominator;
  }

  /// Constrains beam slope to reasonable musical limits
  double _constrainSlope(double slope) {
    // Typical beam slope limits in music notation
    const maxSlope = 0.3; // Maximum upward slope
    const minSlope = -0.3; // Maximum downward slope
    
    return slope.clamp(minSlope, maxSlope);
  }

}

/// Internal helper class for beam line calculations
class _BeamLine {
  _BeamLine({required this.startY, required this.endY});
  
  final double startY;
  final double endY;
}