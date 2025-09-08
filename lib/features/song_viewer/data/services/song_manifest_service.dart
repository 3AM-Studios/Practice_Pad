import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';
import 'package:practice_pad/services/storage/storage_service.dart';

class SongManifestService {
  Future<List<Song>> loadSongs() async {
    try {
      // Load both asset songs and custom songs
      final allSongs = <Song>[];
      
      // Load asset-based songs (existing functionality)
      final assetSongs = await _loadAssetSongs();
      allSongs.addAll(assetSongs);
      
      // Load custom songs from local storage
      final customSongs = await _loadCustomSongs();
      allSongs.addAll(customSongs);
      
      print('Successfully loaded ${allSongs.length} songs (${assetSongs.length} assets + ${customSongs.length} custom)');
      return allSongs;
    } catch (e) {
      print('Critical error in loadSongs: $e');
      return [];
    }
  }

  Future<List<Song>> _loadAssetSongs() async {
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
      return songs;
    } catch (e) {
      print('Error loading asset songs: $e');
      return [];
    }
  }

  Future<List<Song>> _loadCustomSongs() async {
    try {
      final customSongsData = await StorageService.loadCustomSongs();
      final songs = customSongsData.map((data) => Song.fromJson(data)).toList();
      print('Loaded ${songs.length} custom songs from local storage');
      return songs;
    } catch (e) {
      print('Error loading custom songs: $e');
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

  /// Save a custom song to local storage
  Future<void> saveCustomSong(Song song) async {
    if (!song.isCustom) {
      throw ArgumentError('Only custom songs can be saved');
    }
    
    try {
      await StorageService.addCustomSong(song.toJson());
      print('Saved custom song: ${song.title}');
    } catch (e) {
      print('Error saving custom song: $e');
      rethrow;
    }
  }

  /// Delete a custom song from local storage
  Future<void> deleteCustomSong(String songPath) async {
    try {
      await StorageService.deleteCustomSong(songPath);
      print('Deleted custom song with path: $songPath');
    } catch (e) {
      print('Error deleting custom song: $e');
      rethrow;
    }
  }
}
