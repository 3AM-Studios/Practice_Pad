import 'dart:math';

import 'package:flutter/material.dart';
import 'package:music_sheet/src/constants.dart';
import 'package:svg_path_parser/svg_path_parser.dart';
import 'package:xml/xml.dart';

class GlyphPaths {
  const GlyphPaths(this.allGlyphs);
  final Set<XmlElement> allGlyphs;
  static final Map<String, Path> _cachedPaths = {};

  /// Retrieves the [Path] object associated with the given [pathKey].
  Path parsePath(String pathKey) {
    if (_cachedPaths.containsKey(pathKey)) {
      return _cachedPaths[pathKey]!;
    }
    final svgPathStr = _pathKeyToPathStr(pathKey);
    final path = parseSvgPath(svgPathStr);

    // Scale the glyph to match our staff space size
    // SVG glyphs are designed for a staff space of ~250 units, need smaller scaling
    const double originalStaffSpace = 250.0;
    final double scaleFactor = (Constants.staffSpace / originalStaffSpace) * 0.7; // Make symbols 70% of calculated size
    
    // Apply both scaling and Y-axis reversal
    final transform = Matrix4.identity()
      ..scale(scaleFactor)
      ..rotateX(pi);
    
    final pathTransformed = path.transform(transform.storage);
    _cachedPaths.addEntries([MapEntry(pathKey, pathTransformed)]);

    return pathTransformed;
  }

  String _pathKeyToPathStr(String glyphName) => allGlyphs
      .firstWhere(
        (element) => element.getAttribute('glyph-name') == glyphName,
      )
      .getAttribute('d')!;
}
