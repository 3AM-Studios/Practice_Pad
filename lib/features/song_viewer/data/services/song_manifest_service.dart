import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';

class SongManifestService {
  Future<List<Song>> loadSongs() async {
    try {
      final assetManifest = await _loadAssetManifest();
      print('Asset manifest loaded with ${assetManifest.keys.length} total assets');
      
      final songPaths = _findSongPaths(assetManifest);
      print('Found ${songPaths.length} song paths: ${songPaths.take(5).toList()}...');

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
      print('Successfully loaded ${songs.length} songs');
      return songs;
    } catch (e) {
      print('Critical error in loadSongs: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _loadAssetManifest() async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final manifest = json.decode(manifestJson);
      print('AssetManifest.json loaded successfully');
      return manifest;
    } catch (e) {
      print('Error loading AssetManifest.json: $e');
      rethrow;
    }
  }

  List<String> _findSongPaths(Map<String, dynamic> assetManifest) {
    final allPaths = assetManifest.keys.toList();
    print('All asset paths (first 10): ${allPaths.take(10).toList()}');
    
    final songPaths = assetManifest.keys
        .where((path) => path.startsWith('assets/songs/'))
        .where((path) => path.endsWith('.musicxml') || path.endsWith('.xml'))
        .toList();
    
    print('Song paths found: $songPaths');
    return songPaths;
  }
}
