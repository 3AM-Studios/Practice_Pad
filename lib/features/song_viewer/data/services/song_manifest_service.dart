import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';

class SongManifestService {
  Future<List<Song>> loadSongs() async {
    final assetManifest = await _loadAssetManifest();
    final songPaths = _findSongPaths(assetManifest);

    final songs = <Song>[];
    for (final path in songPaths) {
      try {
        final xmlContent = await rootBundle.loadString(path);
        songs.add(Song.fromMusicXml(path, xmlContent));
      } catch (e) {
        print('Error parsing song at $path: $e');
        // Optionally, add a placeholder song to indicate an error
        songs.add(Song(
          title: 'Error Loading Song',
          composer: 'Invalid File',
          path: path,
        ));
      }
    }
    return songs;
  }

  Future<Map<String, dynamic>> _loadAssetManifest() async {
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    return json.decode(manifestJson);
  }

  List<String> _findSongPaths(Map<String, dynamic> assetManifest) {
    return assetManifest.keys
        .where((path) => path.startsWith('assets/songs/'))
        .where((path) => path.endsWith('.musicxml') || path.endsWith('.xml'))
        .toList();
  }
}
