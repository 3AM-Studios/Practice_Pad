import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/chord_progression.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';
import 'package:music_sheet/index.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'dart:developer' as developer;

/// Local storage service for persisting app data
class LocalStorageService {
  static const String _practiceAreasFileName = 'practice_areas.json';
  static const String _practiceItemsFileName = 'practice_items.json';
  static const String _weeklyScheduleFileName = 'weekly_schedule.json';
  static const String _songChangesFileName = 'song_changes.json';
  static const String _chordKeysFileName = 'chord_keys.json';
  static const String _sheetMusicFileName = 'sheet_music.json';
  static const String _drawingsFileName = 'drawings.json';

  // Static mutex for serializing save operations to prevent race conditions
  static final Completer<void>? _saveMutex = null;
  static Completer<void>? _currentSaveOperation;

  /// Serialize save operations to prevent race conditions
  static Future<T> _withSaveLock<T>(Future<T> Function() operation) async {
    // Wait for any existing save operation to complete
    if (_currentSaveOperation != null && !_currentSaveOperation!.isCompleted) {
      developer.log('🔒 SAVE SERIALIZATION: Waiting for previous save to complete');
      await _currentSaveOperation!.future;
    }
    
    // Create new operation completer
    final completer = Completer<void>();
    _currentSaveOperation = completer;
    
    try {
      developer.log('🔒 SAVE SERIALIZATION: Starting serialized save operation');
      final result = await operation();
      developer.log('🔒 SAVE SERIALIZATION: Save operation completed successfully');
      return result;
    } catch (e) {
      developer.log('🔒 SAVE SERIALIZATION: Save operation failed: $e');
      rethrow;
    } finally {
      // Mark operation as complete
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

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

  /// Save sheet music data for a specific song
  static Future<void> saveSheetMusicForSong(String songId, List<Measure> measures) async {
    try {
      final allSheetMusic = await loadAllSheetMusic();
      allSheetMusic[songId] = measures.map((measure) => _measureToJson(measure)).toList();
      
      final file = await _getFile(_sheetMusicFileName);
      await file.writeAsString(json.encode(allSheetMusic));
      developer.log('Saved sheet music for song: $songId (${measures.length} measures)');
    } catch (e) {
      developer.log('Error saving sheet music: $e', error: e);
      throw Exception('Failed to save sheet music: $e');
    }
  }

  /// Load sheet music data for a specific song
  static Future<List<Measure>> loadSheetMusicForSong(String songId) async {
    try {
      final allSheetMusic = await loadAllSheetMusic();
      final measureData = allSheetMusic[songId] ?? [];
      final measures = measureData.map((json) => _measureFromJson(json)).toList();
      developer.log('Loaded sheet music for song: $songId (${measures.length} measures)');
      return measures;
    } catch (e) {
      developer.log('Error loading sheet music for $songId: $e', error: e);
      return [];
    }
  }

  /// Load all sheet music data
  static Future<Map<String, List<dynamic>>> loadAllSheetMusic() async {
    try {
      final file = await _getFile(_sheetMusicFileName);
      if (!await file.exists()) {
        developer.log('Sheet music file does not exist, returning empty map');
        return {};
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer.log('Sheet music file is empty, returning empty map');
        return {};
      }

      final Map<String, dynamic> jsonData = json.decode(content);
      final sheetMusic = jsonData.map((songId, measures) => MapEntry(
        songId,
        List<dynamic>.from(measures as List),
      ));
      developer.log('Loaded sheet music for ${sheetMusic.length} songs');
      return sheetMusic;
    } catch (e) {
      developer.log('Error loading all sheet music: $e', error: e);
      return {};
    }
  }

  /// Convert Measure to JSON (excluding clefs and time signatures)
  static Map<String, dynamic> _measureToJson(Measure measure) {
    // Filter out clefs and time signatures - only save modifiable symbols
    final modifiableSymbols = measure.musicalSymbols.where((symbol) {
      return symbol is! Clef && symbol is! KeySignature && symbol is! TimeSignature;
    }).toList();

    return {
      'musicalSymbols': modifiableSymbols.map((symbol) => _musicalSymbolToJson(symbol)).toList(),
      'isNewLine': measure.isNewLine,
      // Note: chordSymbols serialization will be added later
    };
  }

  /// Convert JSON to Measure
  static Measure _measureFromJson(Map<String, dynamic> json) {
    final symbolsData = json['musicalSymbols'] as List? ?? [];
    final symbols = symbolsData.map((symbolJson) => _musicalSymbolFromJson(symbolJson)).toList();
    
    // If no symbols, add a quarter rest as default
    if (symbols.isEmpty) {
      symbols.add(Rest(RestType.quarter));
    }

    return Measure(
      symbols,
      isNewLine: json['isNewLine'] as bool? ?? false,
      // Note: chordSymbols deserialization will be added later
    );
  }

  /// Convert MusicalSymbol to JSON
  static Map<String, dynamic> _musicalSymbolToJson(MusicalSymbol symbol) {
    if (symbol is Note) {
      return {
        'type': 'Note',
        'id': symbol.id,
        'pitch': symbol.pitch.name,
        'noteDuration': symbol.noteDuration.name,
        'accidental': symbol.accidental?.name,
        'color': symbol.color.value,
        'margin': {
          'left': symbol.margin.left,
          'top': symbol.margin.top,
          'right': symbol.margin.right,
          'bottom': symbol.margin.bottom,
        },
      };
    } else if (symbol is Rest) {
      return {
        'type': 'Rest',
        'id': symbol.id,
        'restType': symbol.restType.name,
        'color': symbol.color.value,
        'margin': {
          'left': symbol.margin.left,
          'top': symbol.margin.top,
          'right': symbol.margin.right,
          'bottom': symbol.margin.bottom,
        },
      };
    } else {
      // For other symbol types, store basic info but they won't be fully reconstructed
      return {
        'type': symbol.runtimeType.toString(),
        'id': symbol.id,
        'color': symbol.color.value,
        'margin': {
          'left': symbol.margin.left,
          'top': symbol.margin.top,
          'right': symbol.margin.right,
          'bottom': symbol.margin.bottom,
        },
      };
    }
  }

  /// Convert JSON to MusicalSymbol
  static MusicalSymbol _musicalSymbolFromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final id = json['id'] as String?;
    final colorValue = json['color'] as int? ?? Colors.black.value;
    final color = Color(colorValue);
    
    final marginData = json['margin'] as Map<String, dynamic>? ?? {};
    final margin = EdgeInsets.fromLTRB(
      (marginData['left'] as num?)?.toDouble() ?? 2.0,
      (marginData['top'] as num?)?.toDouble() ?? 0.0,
      (marginData['right'] as num?)?.toDouble() ?? 2.0,
      (marginData['bottom'] as num?)?.toDouble() ?? 0.0,
    );

    switch (type) {
      case 'Note':
        final pitchName = json['pitch'] as String;
        final pitch = Pitch.values.firstWhere((p) => p.name == pitchName);
        
        final durationName = json['noteDuration'] as String;
        final noteDuration = NoteDuration.values.firstWhere((d) => d.name == durationName);
        
        Accidental? accidental;
        final accidentalName = json['accidental'] as String?;
        if (accidentalName != null) {
          accidental = Accidental.values.firstWhere((a) => a.name == accidentalName);
        }

        return Note(
          pitch,
          id: id,
          noteDuration: noteDuration,
          accidental: accidental,
          color: color,
          margin: margin,
        );
        
      case 'Rest':
        final restTypeName = json['restType'] as String;
        final restType = RestType.values.firstWhere((r) => r.name == restTypeName);
        
        return Rest(
          restType,
          color: color,
          margin: margin,
        );
        
      default:
        // For unsupported types, return a quarter rest as fallback
        developer.log('Unsupported musical symbol type: $type, using Rest as fallback');
        return Rest(RestType.quarter, color: color, margin: margin);
    }
  }

  /// Save drawing data for a specific song with timestamp and atomic operations
  static Future<void> saveDrawingsForSong(String songId, List<Map<String, dynamic>> drawingData) async {
    return _withSaveLock(() async {
      try {
        // Create timestamped drawing entry
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final timestampedDrawingData = {
          'timestamp': timestamp,
          'version': 1,
          'drawings': drawingData,
          'songId': songId,
        };
        
        final allDrawings = await loadAllDrawings();
        allDrawings[songId] = timestampedDrawingData;
        
        // Atomic save operation using temporary file
        final file = await _getFile(_drawingsFileName);
        final tempFile = await _getFile('$_drawingsFileName.tmp');
        
        // Write to temporary file first
        await tempFile.writeAsString(json.encode(allDrawings));
        
        // Atomic rename to final file (OS-level atomic operation)
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
        
        developer.log('✅ SERIALIZED SAVE: Saved ${drawingData.length} drawing elements for song: $songId with timestamp: $timestamp');
      } catch (e) {
        developer.log('❌ SERIALIZED SAVE ERROR: $e', error: e);
        throw Exception('Failed to save drawings: $e');
      }
    });
  }

  /// Load drawing data for a specific song - always gets most recent timestamped data
  static Future<List<Map<String, dynamic>>> loadDrawingsForSong(String songId) async {
    try {
      final allDrawings = await loadAllDrawings();
      final songDrawingData = allDrawings[songId];
      
      if (songDrawingData == null) {
        developer.log('No drawings found for song: $songId');
        return [];
      }
      
      // Handle new timestamped format
      if (songDrawingData is Map<String, dynamic> && songDrawingData.containsKey('timestamp')) {
        final drawingsList = songDrawingData['drawings'] as List?;
        if (drawingsList != null) {
          final drawings = drawingsList.cast<Map<String, dynamic>>();
          final timestamp = songDrawingData['timestamp'] as int?;
          developer.log('Loaded ${drawings.length} drawing elements for song: $songId with timestamp: $timestamp');
          return drawings;
        }
      }
      
      // Handle legacy format (backward compatibility)  
      if (songDrawingData is List) {
        final drawings = songDrawingData.cast<Map<String, dynamic>>();
        developer.log('Loaded ${drawings.length} drawing elements for song: $songId (legacy format)');
        return drawings;
      }
      
      developer.log('Invalid drawing data format for song: $songId');
      return [];
    } catch (e) {
      developer.log('Error loading drawings for $songId: $e', error: e);
      return [];
    }
  }

  /// Load all drawing data (raw format with timestamps)
  static Future<Map<String, dynamic>> loadAllDrawings() async {
    try {
      final file = await _getFile(_drawingsFileName);
      if (!await file.exists()) {
        developer.log('Drawings file does not exist, returning empty map');
        return {};
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer.log('Drawings file is empty, returning empty map');
        return {};
      }

      final Map<String, dynamic> jsonData = json.decode(content);
      developer.log('Loaded drawings for ${jsonData.length} songs');
      return jsonData;
    } catch (e) {
      developer.log('Error loading all drawings: $e', error: e);
      return {};
    }
  }

  /// Convert drawing JSON to PaintContent objects
  static List<PaintContent> drawingJsonToPaintContents(List<Map<String, dynamic>> jsonList) {
    print('🎨 LOCAL_STORAGE: drawingJsonToPaintContents called with ${jsonList.length} items');
    final contents = <PaintContent>[];
    
    for (int i = 0; i < jsonList.length; i++) {
      final json = jsonList[i];
      try {
        print('🎨 LOCAL_STORAGE: Processing item $i: $json');
        final type = json['type'] as String?;
        print('🎨 LOCAL_STORAGE: Item $i type: $type');
        
        if (type == null || type.isEmpty) {
          print('🎨 LOCAL_STORAGE: Item $i skipped - null or empty type');
          continue;
        }
        
        PaintContent? content;
        switch (type) {
          case 'SimpleLine':
            print('🎨 LOCAL_STORAGE: Creating SimpleLine from JSON');
            content = SimpleLine.fromJson(json);
            break;
          case 'SmoothLine':
            print('🎨 LOCAL_STORAGE: Creating SmoothLine from JSON');
            content = SmoothLine.fromJson(json);
            break;
          case 'StraightLine':
            print('🎨 LOCAL_STORAGE: Creating StraightLine from JSON');
            content = StraightLine.fromJson(json);
            break;
          case 'Circle':
            print('🎨 LOCAL_STORAGE: Creating Circle from JSON');
            content = Circle.fromJson(json);
            break;
          case 'Rectangle':
            print('🎨 LOCAL_STORAGE: Creating Rectangle from JSON');
            content = Rectangle.fromJson(json);
            break;
          case 'Eraser':
            print('🎨 LOCAL_STORAGE: Creating Eraser from JSON');
            content = Eraser.fromJson(json);
            break;
          default:
            print('🎨 LOCAL_STORAGE: Unsupported paint content type: $type');
            developer.log('Unsupported paint content type: $type');
            continue;
        }
        
        if (content != null) {
          print('🎨 LOCAL_STORAGE: Successfully created content $i: ${content.runtimeType}');
          contents.add(content);
        } else {
          print('🎨 LOCAL_STORAGE: Failed to create content $i - content is null');
        }
      } catch (e) {
        print('🎨 LOCAL_STORAGE: Error deserializing item $i: $e');
        developer.log('Error deserializing paint content: $e');
        // Continue with other items even if one fails
      }
    }
    
    print('🎨 LOCAL_STORAGE: drawingJsonToPaintContents returning ${contents.length} contents');
    return contents;
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
        _sheetMusicFileName,
        _drawingsFileName,
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