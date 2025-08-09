import 'package:flutter/foundation.dart';

@immutable
class Song {
  const Song({
    required this.title,
    required this.composer,
    required this.path,
  });

  factory Song.fromMusicXml(String path, String xmlContent) {
    // This is a simplified parser. For robust use, a proper XML library is better.
    final titleMatch =
        RegExp(r'<work-title>(.*?)</work-title>').firstMatch(xmlContent);
    final composerMatch = RegExp(r'<creator type="composer">(.*?)</creator>')
        .firstMatch(xmlContent);

    return Song(
      title: titleMatch?.group(1) ?? 'Unknown Title',
      composer: composerMatch?.group(1) ?? 'Unknown Composer',
      path: path,
    );
  }

  final String title;
  final String composer;
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          composer == other.composer &&
          path == other.path;

  @override
  int get hashCode => title.hashCode ^ composer.hashCode ^ path.hashCode;

  /// Convert Song to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'composer': composer,
      'path': path,
    };
  }

  /// Create Song from JSON
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      title: json['title'] as String,
      composer: json['composer'] as String,
      path: json['path'] as String,
    );
  }
}
