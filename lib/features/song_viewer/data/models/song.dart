import 'package:flutter/foundation.dart';

@immutable
class Song {
  const Song({
    required this.title,
    required this.composer,
    required this.path,
    this.isPdfOnly = false,
    this.isCustom = false,
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
      isPdfOnly: false,
      isCustom: false,
    );
  }

  /// Create a PDF-only song for custom songs
  factory Song.createPdfOnly({
    required String title,
    required String composer,
  }) {
    // Generate a unique path for custom songs
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final path = 'custom://pdf_only/$safeName-$timestamp';
    
    return Song(
      title: title,
      composer: composer,
      path: path,
      isPdfOnly: true,
      isCustom: true,
    );
  }

  final String title;
  final String composer;
  final String path;
  final bool isPdfOnly;
  final bool isCustom;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          composer == other.composer &&
          path == other.path &&
          isPdfOnly == other.isPdfOnly &&
          isCustom == other.isCustom;

  @override
  int get hashCode => 
      title.hashCode ^ 
      composer.hashCode ^ 
      path.hashCode ^ 
      isPdfOnly.hashCode ^ 
      isCustom.hashCode;

  /// Convert Song to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'composer': composer,
      'path': path,
      'isPdfOnly': isPdfOnly,
      'isCustom': isCustom,
    };
  }

  /// Create Song from JSON
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      title: json['title'] as String,
      composer: json['composer'] as String,
      path: json['path'] as String,
      isPdfOnly: json['isPdfOnly'] as bool? ?? false,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }
}
