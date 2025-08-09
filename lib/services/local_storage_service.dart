import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/chord_progression.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';
import 'dart:developer' as developer;

/// Local storage service for persisting app data
class LocalStorageService {
  static const String _practiceAreasFileName = 'practice_areas.json';
  static const String _practiceItemsFileName = 'practice_items.json';
  static const String _weeklyScheduleFileName = 'weekly_schedule.json';
  static const String _songChangesFileName = 'song_changes.json';
  static const String _chordKeysFileName = 'chord_keys.json';

  /// Save practice areas to local storage
  static Future<void> savePracticeAreas(List<PracticeArea> areas) async {
    try {
      final file = await _getFile(_practiceAreasFileName);
      final jsonData = areas.map((area) => _practiceAreaToJson(area)).toList();
      await file.writeAsString(json.encode(jsonData));
      developer.log('Saved ${areas.length} practice areas to local storage');
    } catch (e) {
      developer.log('Error saving practice areas: $e', error: e);
      throw Exception('Failed to save practice areas: $e');
    }
  }

  /// Load practice areas from local storage
  static Future<List<PracticeArea>> loadPracticeAreas() async {
    try {
      final file = await _getFile(_practiceAreasFileName);
      if (!await file.exists()) {
        developer.log('Practice areas file does not exist, returning empty list');
        return [];
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer.log('Practice areas file is empty, returning empty list');
        return [];
      }

      final List<dynamic> jsonData = json.decode(content);
      final areas = jsonData.map((json) => _practiceAreaFromJson(json)).toList();
      developer.log('Loaded ${areas.length} practice areas from local storage');
      return areas;
    } catch (e) {
      developer.log('Error loading practice areas: $e', error: e);
      return [];
    }
  }

  /// Save practice items to local storage
  static Future<void> savePracticeItems(Map<String, List<PracticeItem>> itemsByArea) async {
    try {
      final file = await _getFile(_practiceItemsFileName);
      final jsonData = itemsByArea.map((areaId, items) => MapEntry(
        areaId,
        items.map((item) => _practiceItemToJson(item)).toList(),
      ));
      await file.writeAsString(json.encode(jsonData));
      developer.log('Saved practice items for ${itemsByArea.length} areas to local storage');
    } catch (e) {
      developer.log('Error saving practice items: $e', error: e);
      throw Exception('Failed to save practice items: $e');
    }
  }

  /// Load practice items from local storage
  static Future<Map<String, List<PracticeItem>>> loadPracticeItems() async {
    try {
      final file = await _getFile(_practiceItemsFileName);
      if (!await file.exists()) {
        developer.log('Practice items file does not exist, returning empty map');
        return {};
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer.log('Practice items file is empty, returning empty map');
        return {};
      }

      final Map<String, dynamic> jsonData = json.decode(content);
      final itemsByArea = jsonData.map((areaId, items) => MapEntry(
        areaId,
        (items as List).map((json) => _practiceItemFromJson(json)).toList(),
      ));
      developer.log('Loaded practice items for ${itemsByArea.length} areas from local storage');
      return itemsByArea;
    } catch (e) {
      developer.log('Error loading practice items: $e', error: e);
      return {};
    }
  }

  /// Save weekly schedule (practice areas assigned to days)
  static Future<void> saveWeeklySchedule(Map<String, List<String>> schedule) async {
    try {
      final file = await _getFile(_weeklyScheduleFileName);
      await file.writeAsString(json.encode(schedule));
      developer.log('Saved weekly schedule to local storage');
    } catch (e) {
      developer.log('Error saving weekly schedule: $e', error: e);
      throw Exception('Failed to save weekly schedule: $e');
    }
  }

  /// Load weekly schedule from local storage
  static Future<Map<String, List<String>>> loadWeeklySchedule() async {
    try {
      final file = await _getFile(_weeklyScheduleFileName);
      if (!await file.exists()) {
        developer.log('Weekly schedule file does not exist, returning empty schedule');
        return {};
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer.log('Weekly schedule file is empty, returning empty schedule');
        return {};
      }

      final Map<String, dynamic> jsonData = json.decode(content);
      final schedule = jsonData.map((day, areas) => MapEntry(
        day,
        List<String>.from(areas as List),
      ));
      developer.log('Loaded weekly schedule from local storage');
      return schedule;
    } catch (e) {
      developer.log('Error loading weekly schedule: $e', error: e);
      return {};
    }
  }

  /// Save song viewer changes (notes, measures, etc.)
  static Future<void> saveSongChanges(String songId, Map<String, dynamic> changes) async {
    try {
      final allChanges = await loadAllSongChanges();
      allChanges[songId] = changes;
      
      final file = await _getFile(_songChangesFileName);
      await file.writeAsString(json.encode(allChanges));
      developer.log('Saved song changes for song: $songId');
    } catch (e) {
      developer.log('Error saving song changes: $e', error: e);
      throw Exception('Failed to save song changes: $e');
    }
  }

  /// Load song changes for a specific song
  static Future<Map<String, dynamic>> loadSongChanges(String songId) async {
    try {
      final allChanges = await loadAllSongChanges();
      return allChanges[songId] ?? {};
    } catch (e) {
      developer.log('Error loading song changes for $songId: $e', error: e);
      return {};
    }
  }

  /// Load all song changes
  static Future<Map<String, Map<String, dynamic>>> loadAllSongChanges() async {
    try {
      final file = await _getFile(_songChangesFileName);
      if (!await file.exists()) {
        developer.log('Song changes file does not exist, returning empty map');
        return {};
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer.log('Song changes file is empty, returning empty map');
        return {};
      }

      final Map<String, dynamic> jsonData = json.decode(content);
      final changes = jsonData.map((songId, changes) => MapEntry(
        songId,
        Map<String, dynamic>.from(changes as Map),
      ));
      developer.log('Loaded song changes for ${changes.length} songs');
      return changes;
    } catch (e) {
      developer.log('Error loading all song changes: $e', error: e);
      return {};
    }
  }

  /// Save non-diatonic chord keys
  static Future<void> saveChordKeys(String songId, Map<String, dynamic> chordKeys) async {
    try {
      final allChordKeys = await loadAllChordKeys();
      allChordKeys[songId] = chordKeys;
      
      final file = await _getFile(_chordKeysFileName);
      await file.writeAsString(json.encode(allChordKeys));
      developer.log('Saved chord keys for song: $songId');
    } catch (e) {
      developer.log('Error saving chord keys: $e', error: e);
      throw Exception('Failed to save chord keys: $e');
    }
  }

  /// Load chord keys for a specific song
  static Future<Map<String, dynamic>> loadChordKeys(String songId) async {
    try {
      final allChordKeys = await loadAllChordKeys();
      return allChordKeys[songId] ?? {};
    } catch (e) {
      developer.log('Error loading chord keys for $songId: $e', error: e);
      return {};
    }
  }

  /// Load all chord keys
  static Future<Map<String, Map<String, dynamic>>> loadAllChordKeys() async {
    try {
      final file = await _getFile(_chordKeysFileName);
      if (!await file.exists()) {
        developer.log('Chord keys file does not exist, returning empty map');
        return {};
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer.log('Chord keys file is empty, returning empty map');
        return {};
      }

      final Map<String, dynamic> jsonData = json.decode(content);
      final chordKeys = jsonData.map((songId, keys) => MapEntry(
        songId,
        Map<String, dynamic>.from(keys as Map),
      ));
      developer.log('Loaded chord keys for ${chordKeys.length} songs');
      return chordKeys;
    } catch (e) {
      developer.log('Error loading all chord keys: $e', error: e);
      return {};
    }
  }

  /// Helper method to get file handle
  static Future<File> _getFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  /// Convert PracticeArea to JSON
  static Map<String, dynamic> _practiceAreaToJson(PracticeArea area) {
    return {
      'recordName': area.recordName,
      'name': area.name,
      'type': area.type.toString(),
      'song': area.song?.toJson(),
    };
  }

  /// Convert JSON to PracticeArea
  static PracticeArea _practiceAreaFromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String;
    final type = PracticeAreaType.values.firstWhere(
      (e) => e.toString() == typeString,
      orElse: () => PracticeAreaType.exercise,
    );

    Song? song;
    if (json['song'] != null) {
      song = Song.fromJson(json['song']);
    }

    return PracticeArea(
      recordName: json['recordName'] as String,
      name: json['name'] as String,
      type: type,
      song: song,
    );
  }

  /// Convert PracticeItem to JSON
  static Map<String, dynamic> _practiceItemToJson(PracticeItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'description': item.description,
      'chordProgression': item.chordProgression?.toJson(),
      'keysPracticed': item.keysPracticed,
    };
  }

  /// Convert JSON to PracticeItem
  static PracticeItem _practiceItemFromJson(Map<String, dynamic> json) {
    ChordProgression? chordProgression;
    if (json['chordProgression'] != null) {
      chordProgression = ChordProgression.fromJson(json['chordProgression']);
    }

    return PracticeItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      chordProgression: chordProgression,
      keysPracticed: Map<String, int>.from(json['keysPracticed'] as Map? ?? {}),
    );
  }

  /// Clear all local storage
  static Future<void> clearAll() async {
    try {
      final files = [
        _practiceAreasFileName,
        _practiceItemsFileName,
        _weeklyScheduleFileName,
        _songChangesFileName,
        _chordKeysFileName,
      ];

      for (final fileName in files) {
        final file = await _getFile(fileName);
        if (await file.exists()) {
          await file.delete();
        }
      }
      developer.log('Cleared all local storage');
    } catch (e) {
      developer.log('Error clearing local storage: $e', error: e);
    }
  }
}