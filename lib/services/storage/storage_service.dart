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
import 'package:image_painter/image_painter.dart';
import 'package:practice_pad/services/storage/cloudkit_service.dart';
import 'package:flutter_cloud_kit/flutter_cloud_kit.dart';
import 'package:flutter_cloud_kit/types/cloud_kit_asset.dart';
import 'package:practice_pad/models/pdf_result.dart';

/// Local storage service for persisting app data
class StorageService {
  static const String _practiceAreasFileName = 'practice_areas.json';
  static const String _practiceItemsFileName = 'practice_items.json';
  static const String _weeklyScheduleFileName = 'weekly_schedule.json';
  static const String _songChangesFileName = 'song_changes.json';
  static const String _chordKeysFileName = 'chord_keys.json';
  static const String _sheetMusicFileName = 'sheet_music.json';
  static const String _drawingsFileName = 'drawings.json';
  static const String _pdfDrawingsFileName = 'pdf_drawings.json';
  static const String _youtubeLinksFileName = 'youtube_links.json';
  static const String _savedLoopsFileName = 'saved_loops.json';
  static const String _booksFileName = 'books.json';
  static const String _customSongsFileName = 'custom_songs.json';
  static const String _youtubeVideosFileName = 'youtube_videos.json';

  // Static mutex for serializing save operations to prevent race conditions
  static Completer<void>? _currentSaveOperation;

  /// Serialize save operations to prevent race conditions
  static Future<T> _withSaveLock<T>(Future<T> Function() operation) async {
    // Wait for any existing save operation to complete
    if (_currentSaveOperation != null && !_currentSaveOperation!.isCompleted) {
      developer
          .log('🔒 SAVE SERIALIZATION: Waiting for previous save to complete');
      await _currentSaveOperation!.future;
    }

    // Create new operation completer
    final completer = Completer<void>();
    _currentSaveOperation = completer;

    try {
      developer
          .log('🔒 SAVE SERIALIZATION: Starting serialized save operation');
      final result = await operation();
      developer
          .log('🔒 SAVE SERIALIZATION: Save operation completed successfully');
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


  /// Load practice areas from local storage
  static Future<List<PracticeArea>> loadPracticeAreas() async {
    try {
      final file = await _getFile(_practiceAreasFileName);
      if (!await file.exists()) {
        developer
            .log('Practice areas file does not exist, returning empty list');
        return [];
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer.log('Practice areas file is empty, returning empty list');
        return [];
      }

      final List<dynamic> jsonData = json.decode(content);
      final areas =
          jsonData.map((json) => practiceAreaFromJson(json)).toList();
      developer.log('Loaded ${areas.length} practice areas from local storage');
      return areas;
    } catch (e) {
      developer.log('Error loading practice areas: $e', error: e);
      return [];
    }
  }


  /// Load practice items from local storage
  static Future<Map<String, List<PracticeItem>>> loadPracticeItems() async {
    try {
      final file = await _getFile(_practiceItemsFileName);
      if (!await file.exists()) {
        developer
            .log('Practice items file does not exist, returning empty map');
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
            (items as List).map((json) => practiceItemFromJson(json)).toList(),
          ));
      developer.log(
          'Loaded practice items for ${itemsByArea.length} areas from local storage');
      return itemsByArea;
    } catch (e) {
      developer.log('Error loading practice items: $e', error: e);
      return {};
    }
  }

  /// Save weekly schedule (practice areas assigned to days)
  static Future<void> saveWeeklySchedule(
      Map<String, List<String>> schedule) async {
    try {
      // 1. Save locally first
      final file = await _getFile(_weeklyScheduleFileName);
      await file.writeAsString(json.encode(schedule));
      developer.log('Saved weekly schedule to local storage');
      
      // 2. Sync to CloudKit
      await _syncWeeklyScheduleToCloudKit(schedule);
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
        developer.log(
            'Weekly schedule file does not exist, returning empty schedule');
        return {};
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer
            .log('Weekly schedule file is empty, returning empty schedule');
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
  static Future<void> saveSongChanges(
      String songId, Map<String, dynamic> changes) async {
    try {
      // 1. Save locally first
      final allChanges = await loadAllSongChanges();
      allChanges[songId] = changes;

      final file = await _getFile(_songChangesFileName);
      await file.writeAsString(json.encode(allChanges));
      developer.log('Saved song changes for song: $songId');
      
      // 2. Sync to CloudKit
      await _syncSongChangesToCloudKit(songId, changes);
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
  static Future<void> saveChordKeys(
      String songId, Map<String, dynamic> chordKeys) async {
    try {
      // 1. Save locally first
      final allChordKeys = await loadAllChordKeys();
      allChordKeys[songId] = chordKeys;

      final file = await _getFile(_chordKeysFileName);
      await file.writeAsString(json.encode(allChordKeys));
      developer.log('Saved chord keys for song: $songId');
      
      // 2. Sync to CloudKit
      await _syncChordKeysToCloudKit(songId, chordKeys);
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
  static Map<String, dynamic> practiceAreaToJson(PracticeArea area) {
    return {
      'recordName': area.recordName,
      'name': area.name,
      'type': area.type.toString(),
      'song': area.song?.toJson(),
      'recordChangeTag': area.recordChangeTag,
    };
  }

  /// Convert JSON to PracticeArea
  static PracticeArea practiceAreaFromJson(Map<String, dynamic> json) {
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
      recordChangeTag: json['recordChangeTag'] as String?,
    );
  }

  /// Convert PracticeItem to JSON
  static Map<String, dynamic> practiceItemToJson(PracticeItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'description': item.description,
      'chordProgression': item.chordProgression?.toJson(),
      'keysPracticed': item.keysPracticed,
      'recordChangeTag': item.recordChangeTag,
    };
  }

  /// Convert JSON to PracticeItem
  static PracticeItem practiceItemFromJson(Map<String, dynamic> json) {
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
      recordChangeTag: json['recordChangeTag'] as String?,
    );
  }

  /// Save sheet music data for a specific song
  static Future<void> saveSheetMusicForSong(
      String songId, List<Measure> measures) async {
    try {
      // 1. Save locally first
      final allSheetMusic = await loadAllSheetMusic();
      allSheetMusic[songId] =
          measures.map((measure) => measureToJson(measure)).toList();

      final file = await _getFile(_sheetMusicFileName);
      await file.writeAsString(json.encode(allSheetMusic));
      developer.log(
          'Saved sheet music for song: $songId (${measures.length} measures)');
      
      // 2. Sync to CloudKit
      await _syncSheetMusicToCloudKit(songId, measures);
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
      final measures =
          measureData.map((json) => measureFromJson(json)).toList();
      developer.log(
          'Loaded sheet music for song: $songId (${measures.length} measures)');
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
  static Map<String, dynamic> measureToJson(Measure measure) {
    // Filter out clefs and time signatures - only save modifiable symbols
    final modifiableSymbols = measure.musicalSymbols.where((symbol) {
      return symbol is! Clef &&
          symbol is! KeySignature &&
          symbol is! TimeSignature;
    }).toList();

    return {
      'musicalSymbols': modifiableSymbols
          .map((symbol) => musicalSymbolToJson(symbol))
          .toList(),
      'isNewLine': measure.isNewLine,
      // Note: chordSymbols serialization will be added later
    };
  }

  /// Convert JSON to Measure
  static Measure measureFromJson(Map<String, dynamic> json) {
    final symbolsData = json['musicalSymbols'] as List? ?? [];
    final symbols = symbolsData
        .map((symbolJson) => musicalSymbolFromJson(symbolJson))
        .toList();

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
  static Map<String, dynamic> musicalSymbolToJson(MusicalSymbol symbol) {
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
  static MusicalSymbol musicalSymbolFromJson(Map<String, dynamic> json) {
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
        final noteDuration =
            NoteDuration.values.firstWhere((d) => d.name == durationName);

        Accidental? accidental;
        final accidentalName = json['accidental'] as String?;
        if (accidentalName != null) {
          accidental =
              Accidental.values.firstWhere((a) => a.name == accidentalName);
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
        final restType =
            RestType.values.firstWhere((r) => r.name == restTypeName);

        return Rest(
          restType,
          color: color,
          margin: margin,
        );

      default:
        // For unsupported types, return a quarter rest as fallback
        developer.log(
            'Unsupported musical symbol type: $type, using Rest as fallback');
        return Rest(RestType.quarter, color: color, margin: margin);
    }
  }

  /// Save drawing data for a specific song with timestamp and atomic operations
  static Future<void> saveDrawingsForSong(
      String songId, List<Map<String, dynamic>> drawingData) async {
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

        developer.log(
            '✅ SERIALIZED SAVE: Saved ${drawingData.length} drawing elements for song: $songId with timestamp: $timestamp');
        
        // 2. Sync to CloudKit
        await _syncDrawingsToCloudKit(songId, drawingData);
      } catch (e) {
        developer.log('❌ SERIALIZED SAVE ERROR: $e', error: e);
        throw Exception('Failed to save drawings: $e');
      }
    });
  }

  /// Load drawing data for a specific song - always gets most recent timestamped data
  static Future<List<Map<String, dynamic>>> loadDrawingsForSong(
      String songId) async {
    try {
      final allDrawings = await loadAllDrawings();
      final songDrawingData = allDrawings[songId];

      if (songDrawingData == null) {
        developer.log('No drawings found for song: $songId');
        return [];
      }

      // Handle new timestamped format
      if (songDrawingData is Map<String, dynamic> &&
          songDrawingData.containsKey('timestamp')) {
        final drawingsList = songDrawingData['drawings'] as List?;
        if (drawingsList != null) {
          final drawings = drawingsList.cast<Map<String, dynamic>>();
          final timestamp = songDrawingData['timestamp'] as int?;
          developer.log(
              'Loaded ${drawings.length} drawing elements for song: $songId with timestamp: $timestamp');
          return drawings;
        }
      }

      // Handle legacy format (backward compatibility)
      if (songDrawingData is List) {
        final drawings = songDrawingData.cast<Map<String, dynamic>>();
        developer.log(
            'Loaded ${drawings.length} drawing elements for song: $songId (legacy format)');
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
  static List<PaintContent> drawingJsonToPaintContents(
      List<Map<String, dynamic>> jsonList) {
    final contents = <PaintContent>[];

    for (int i = 0; i < jsonList.length; i++) {
      final json = jsonList[i];
      try {
        final type = json['type'] as String?;

        if (type == null || type.isEmpty) {
          continue;
        }

        PaintContent? content;
        switch (type) {
          case 'SimpleLine':
            content = SimpleLine.fromJson(json);
            break;
          case 'SmoothLine':
            content = SmoothLine.fromJson(json);
            break;
          case 'StraightLine':
            content = StraightLine.fromJson(json);
            break;
          case 'Circle':
            content = Circle.fromJson(json);
            break;
          case 'Rectangle':
            content = Rectangle.fromJson(json);
            break;
          case 'Eraser':
            content = Eraser.fromJson(json);
            break;
          default:
            developer.log('Unsupported paint content type: $type');
            continue;
        }

        contents.add(content);
      } catch (e) {
        developer.log('Error deserializing paint content: $e');
        // Continue with other items even if one fails
      }
    }

    return contents;
  }

  /// Save PDF drawing data for a specific song and page with timestamp and atomic operations
  static Future<void> savePDFDrawingsForSongPage(
      String songId, int pageNumber, List<PaintInfo> paintHistory) async {
    return _withSaveLock(() async {
      try {
        // Convert PaintInfo objects to JSON
        final drawingData = paintHistory
            .map((paintInfo) => paintInfoToJson(paintInfo))
            .toList();

        // Create timestamped drawing entry
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final timestampedDrawingData = {
          'timestamp': timestamp,
          'version': 1,
          'drawings': drawingData,
          'songId': songId,
          'pageNumber': pageNumber,
        };

        final allPDFDrawings = await loadAllPDFDrawings();
        final songPageKey = '${songId}_page_$pageNumber';
        allPDFDrawings[songPageKey] = timestampedDrawingData;

        // Atomic save operation using temporary file
        final file = await _getFile(_pdfDrawingsFileName);
        final tempFile = await _getFile('$_pdfDrawingsFileName.tmp');

        try {
          // Ensure parent directory exists
          await tempFile.parent.create(recursive: true);

          // Write to temporary file first
          await tempFile.writeAsString(json.encode(allPDFDrawings));

          // Atomic rename to final file (OS-level atomic operation)
          if (await file.exists()) {
            await file.delete();
          }

          // Ensure target directory exists
          await file.parent.create(recursive: true);

          await tempFile.rename(file.path);
        } catch (renameError) {
          // Fallback: direct write if rename fails
          developer.log(
              '⚠️ Rename failed, falling back to direct write: $renameError');
          await file.writeAsString(json.encode(allPDFDrawings));

          // Clean up temp file if it exists
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }

        developer.log(
            '✅ SERIALIZED SAVE: Saved ${drawingData.length} PDF drawing elements for song: $songId page: $pageNumber with timestamp: $timestamp');
        
        // 2. Sync to CloudKit
        await _syncPDFDrawingsToCloudKit(songId, pageNumber, paintHistory);
      } catch (e) {
        developer.log('❌ SERIALIZED PDF SAVE ERROR: $e', error: e);
        throw Exception('Failed to save PDF drawings: $e');
      }
    });
  }

  /// Load PDF drawing data for a specific song and page
  static Future<List<PaintInfo>> loadPDFDrawingsForSongPage(
      String songId, int pageNumber) async {
    try {
      final allPDFDrawings = await loadAllPDFDrawings();
      final songPageKey = '${songId}_page_$pageNumber';
      final songPageDrawingData = allPDFDrawings[songPageKey];

      if (songPageDrawingData == null) {
        developer
            .log('No PDF drawings found for song: $songId page: $pageNumber');
        return [];
      }

      // Handle timestamped format
      if (songPageDrawingData is Map<String, dynamic> &&
          songPageDrawingData.containsKey('timestamp')) {
        final drawingsList = songPageDrawingData['drawings'] as List?;
        if (drawingsList != null) {
          final paintInfoList = drawingsList
              .cast<Map<String, dynamic>>()
              .map((json) => paintInfoFromJson(json))
              .toList();
          final timestamp = songPageDrawingData['timestamp'] as int?;
          developer.log(
              'Loaded ${paintInfoList.length} PDF drawing elements for song: $songId page: $pageNumber with timestamp: $timestamp');
          return paintInfoList;
        }
      }

      developer.log(
          'Invalid PDF drawing data format for song: $songId page: $pageNumber');
      return [];
    } catch (e) {
      developer.log(
          'Error loading PDF drawings for $songId page $pageNumber: $e',
          error: e);
      return [];
    }
  }

  /// Load all PDF drawing data (raw format with timestamps)
  static Future<Map<String, dynamic>> loadAllPDFDrawings() async {
    try {
      final file = await _getFile(_pdfDrawingsFileName);
      if (!await file.exists()) {
        developer.log('PDF drawings file does not exist, returning empty map');
        return {};
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer.log('PDF drawings file is empty, returning empty map');
        return {};
      }

      final Map<String, dynamic> jsonData = json.decode(content);
      developer.log('Loaded PDF drawings for ${jsonData.length} song pages');
      return jsonData;
    } catch (e) {
      developer.log('Error loading all PDF drawings: $e', error: e);
      return {};
    }
  }

  /// Convert PaintInfo to JSON
  static Map<String, dynamic> paintInfoToJson(PaintInfo paintInfo) {
    return {
      'mode': paintInfo.mode.toString(),
      'color': paintInfo.color.value,
      'strokeWidth': paintInfo.strokeWidth,
      'offsets': paintInfo.offsets
          .map((offset) =>
              offset != null ? {'dx': offset.dx, 'dy': offset.dy} : null)
          .toList(),
      'text': paintInfo.text,
      'fill': paintInfo.fill,
    };
  }

  /// Convert JSON to PaintInfo
  static PaintInfo paintInfoFromJson(Map<String, dynamic> json) {
    // Parse mode
    final modeString = json['mode'] as String;
    final mode = PaintMode.values.firstWhere(
      (e) => e.toString() == modeString,
      orElse: () => PaintMode.freeStyle,
    );

    // Parse color
    final colorValue = json['color'] as int;
    final color = Color(colorValue);

    // Parse offsets
    final offsetsData = json['offsets'] as List;
    final offsets = offsetsData.map((offsetJson) {
      if (offsetJson == null) return null;
      final offsetMap = offsetJson as Map<String, dynamic>;
      return Offset(offsetMap['dx'] as double, offsetMap['dy'] as double);
    }).toList();

    return PaintInfo(
      mode: mode,
      color: color,
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      offsets: offsets,
      text: json['text'] as String? ?? '',
      fill: json['fill'] as bool? ?? false,
    );
  }

  /// Save YouTube link data for a specific song
  static Future<void> saveYoutubeLinkForSong(
      String songId, Map<String, dynamic> youtubeData) async {
    try {
      // 1. Save locally first
      final allYoutubeLinks = await loadAllYoutubeLinks();
      allYoutubeLinks[songId] = youtubeData;

      final file = await _getFile(_youtubeLinksFileName);
      await file.writeAsString(json.encode(allYoutubeLinks));
      developer.log('Saved YouTube link for song: $songId');
      
      // 2. Sync to CloudKit
      await _syncYoutubeLinksToCloudKit(songId, youtubeData);
    } catch (e) {
      developer.log('Error saving YouTube link: $e', error: e);
      throw Exception('Failed to save YouTube link: $e');
    }
  }

  /// Load YouTube link data for a specific song
  static Future<Map<String, dynamic>> loadYoutubeLinkForSong(
      String songId) async {
    try {
      final allYoutubeLinks = await loadAllYoutubeLinks();
      return allYoutubeLinks[songId] ?? {};
    } catch (e) {
      developer.log('Error loading YouTube link for $songId: $e', error: e);
      return {};
    }
  }

  /// Load all YouTube links
  static Future<Map<String, Map<String, dynamic>>> loadAllYoutubeLinks() async {
    try {
      final file = await _getFile(_youtubeLinksFileName);
      if (!await file.exists()) {
        developer.log('YouTube links file does not exist, returning empty map');
        return {};
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer.log('YouTube links file is empty, returning empty map');
        return {};
      }

      final Map<String, dynamic> jsonData = json.decode(content);
      final youtubeLinks = jsonData.map((songId, data) => MapEntry(
            songId,
            Map<String, dynamic>.from(data as Map),
          ));
      developer.log('Loaded YouTube links for ${youtubeLinks.length} songs');
      return youtubeLinks;
    } catch (e) {
      developer.log('Error loading all YouTube links: $e', error: e);
      return {};
    }
  }

  /// Save loop data for a specific song
  static Future<void> saveSavedLoopsForSong(
      String songId, List<Map<String, dynamic>> loops) async {
    try {
      // 1. Save locally first
      final allSavedLoops = await loadAllSavedLoops();
      allSavedLoops[songId] = loops;

      final file = await _getFile(_savedLoopsFileName);
      await file.writeAsString(json.encode(allSavedLoops));
      developer.log('Saved ${loops.length} loops for song: $songId');
      
      // 2. Sync to CloudKit
      await _syncSavedLoopsToCloudKit(songId, loops);
    } catch (e) {
      developer.log('Error saving loops: $e', error: e);
      throw Exception('Failed to save loops: $e');
    }
  }

  /// Load saved loops for a specific song
  static Future<List<Map<String, dynamic>>> loadSavedLoopsForSong(
      String songId) async {
    try {
      final allSavedLoops = await loadAllSavedLoops();
      final loops = allSavedLoops[songId] ?? [];
      return List<Map<String, dynamic>>.from(loops);
    } catch (e) {
      developer.log('Error loading loops for $songId: $e', error: e);
      return [];
    }
  }

  /// Load all saved loops
  static Future<Map<String, List<dynamic>>> loadAllSavedLoops() async {
    try {
      final file = await _getFile(_savedLoopsFileName);
      if (!await file.exists()) {
        developer.log('Saved loops file does not exist, returning empty map');
        return {};
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        developer.log('Saved loops file is empty, returning empty map');
        return {};
      }

      final Map<String, dynamic> jsonData = json.decode(content);
      final savedLoops = jsonData.map((songId, loops) => MapEntry(
            songId,
            List<dynamic>.from(loops as List),
          ));
      developer.log('Loaded saved loops for ${savedLoops.length} songs');
      return savedLoops;
    } catch (e) {
      developer.log('Error loading all saved loops: $e', error: e);
      return {};
    }
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
        _pdfDrawingsFileName,
        _youtubeLinksFileName,
        _savedLoopsFileName,
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

  // =============================================================================
  // BOOKS MANAGEMENT
  // =============================================================================

  /// Save registered books to local storage
  static Future<void> saveBooks(List<Map<String, dynamic>> books) async {
    return _withSaveLock(() async {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$_booksFileName');
        
        // Use atomic save with temporary file
        final tempFile = File('${file.path}.tmp');
        await tempFile.parent.create(recursive: true);
        
        try {
          await tempFile.writeAsString(json.encode(books));
          await tempFile.rename(file.path);
          developer.log('📚 Books saved successfully: ${books.length} books');
        } catch (renameError) {
          developer.log('⚠️ Books rename failed, falling back to direct write: $renameError');
          await file.writeAsString(json.encode(books));
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
        
        // 2. Sync to CloudKit
        await _syncBooksToCloudKit(books);
      } catch (e) {
        developer.log('❌ Error saving books: $e');
        rethrow;
      }
    });
  }

  /// Load registered books from local storage
  static Future<List<Map<String, dynamic>>> loadBooks() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_booksFileName');
      
      if (!await file.exists()) {
        developer.log('📚 No books file found, returning empty list');
        return <Map<String, dynamic>>[];
      }
      
      final jsonString = await file.readAsString();
      final List<dynamic> booksJson = json.decode(jsonString);
      final books = booksJson.cast<Map<String, dynamic>>();
      
      developer.log('📚 Loaded ${books.length} books from storage');
      return books;
    } catch (e) {
      developer.log('❌ Error loading books: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Add a new book to storage
  static Future<void> addBook(Map<String, dynamic> book) async {
    try {
      final books = await loadBooks();
      books.add(book);
      await saveBooks(books);
      developer.log('📚 Added new book: ${book['name']}');
    } catch (e) {
      developer.log('❌ Error adding book: $e');
      rethrow;
    }
  }

  /// Update an existing book in storage
  static Future<void> updateBook(String bookId, Map<String, dynamic> updatedBook) async {
    try {
      final books = await loadBooks();
      final index = books.indexWhere((book) => book['id'] == bookId);
      
      if (index != -1) {
        books[index] = updatedBook;
        await saveBooks(books);
        developer.log('📚 Updated book: ${updatedBook['name']}');
      } else {
        throw Exception('Book with id $bookId not found');
      }
    } catch (e) {
      developer.log('❌ Error updating book: $e');
      rethrow;
    }
  }

  /// Delete a book from storage
  static Future<void> deleteBook(String bookId) async {
    try {
      final books = await loadBooks();
      final index = books.indexWhere((book) => book['id'] == bookId);
      
      if (index != -1) {
        final deletedBook = books.removeAt(index);
        await saveBooks(books);
        developer.log('📚 Deleted book: ${deletedBook['name']}');
      } else {
        throw Exception('Book with id $bookId not found');
      }
    } catch (e) {
      developer.log('❌ Error deleting book: $e');
      rethrow;
    }
  }


  /// Load custom songs from local storage
  static Future<List<Map<String, dynamic>>> loadCustomSongs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_customSongsFileName');
      
      if (!await file.exists()) {
        developer.log('🎵 No custom songs file found, returning empty list');
        return <Map<String, dynamic>>[];
      }

      final jsonString = await file.readAsString();
      final List<dynamic> songsJson = json.decode(jsonString);
      final songs = songsJson.cast<Map<String, dynamic>>();
      
      developer.log('🎵 Loaded ${songs.length} custom songs from storage');
      return songs;
    } catch (e) {
      developer.log('❌ Error loading custom songs: $e');
      return <Map<String, dynamic>>[];
    }
  }


  /// Delete a custom song by path
  static Future<void> deleteCustomSong(String songPath) async {
    try {
      final songs = await loadCustomSongs();
      final index = songs.indexWhere((song) => song['path'] == songPath);
      
      if (index != -1) {
        final deletedSong = songs.removeAt(index);
        await saveCustomSongs(songs);
        developer.log('🎵 Deleted custom song: ${deletedSong['title']}');
      } else {
        throw Exception('Custom song with path $songPath not found');
      }
    } catch (e) {
      developer.log('❌ Error deleting custom song: $e');
      rethrow;
    }
  }

  /// Enhanced save methods with iCloud sync integration

  /// Save custom songs with iCloud sync
  static Future<void> saveCustomSongs(List<Map<String, dynamic>> songs) async {
    return _withSaveLock(() async {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$_customSongsFileName');
        final tempFile = File('${file.path}.tmp');
        
        await tempFile.parent.create(recursive: true);
        
        try {
          await tempFile.writeAsString(json.encode(songs));
          await tempFile.rename(file.path);
          developer.log('🎵 Custom songs saved successfully: ${songs.length} songs');
        } catch (renameError) {
          await file.writeAsString(json.encode(songs));
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
        
        // 2. Sync to CloudKit
        await _syncCustomSongsToCloudKit(songs);
      } catch (e) {
        developer.log('❌ Error saving custom songs: $e');
        rethrow;
      }
    });
  }

  /// Enhanced save practice areas with CloudKit sync
  static Future<void> savePracticeAreas(List<PracticeArea> areas) async {
    try {
      // 1. Save locally first
      final file = await _getFile(_practiceAreasFileName);
      final jsonData = areas.map((area) => practiceAreaToJson(area)).toList();
      await file.writeAsString(json.encode(jsonData));
      developer.log('Saved ${areas.length} practice areas to local storage');
      
      // 2. Sync each area to CloudKit
      for (final area in areas) {
        await _syncPracticeAreaToCloudKit(area);
      }
    } catch (e) {
      developer.log('Error saving practice areas: $e', error: e);
      throw Exception('Failed to save practice areas: $e');
    }
  }

  /// Enhanced save practice items with CloudKit sync
  static Future<void> savePracticeItems(
      Map<String, List<PracticeItem>> itemsByArea) async {
    try {
      // 1. Save locally first
      final file = await _getFile(_practiceItemsFileName);
      final jsonData = itemsByArea.map((areaId, items) => MapEntry(
            areaId,
            items.map((item) => practiceItemToJson(item)).toList(),
          ));
      await file.writeAsString(json.encode(jsonData));
      developer.log(
          'Saved practice items for ${itemsByArea.length} areas to local storage');
      
      // 2. Sync each item to CloudKit
      for (final entry in itemsByArea.entries) {
        for (final item in entry.value) {
          await _syncPracticeItemToCloudKit(item, entry.key);
        }
      }
    } catch (e) {
      developer.log('Error saving practice items: $e', error: e);
      throw Exception('Failed to save practice items: $e');
    }
  }

  /// Enhanced add custom song with iCloud sync
  static Future<void> addCustomSong(Map<String, dynamic> song) async {
    try {
      final songs = await loadCustomSongs();
      songs.add(song);
      await saveCustomSongs(songs);
      developer.log('🎵 Added custom song: ${song['title']}');
    } catch (e) {
      developer.log('❌ Error adding custom song: $e');
      rethrow;
    }
  }

  /// Save labels for a specific song page using LabelPersistenceService pattern
  static Future<void> saveLabelsForPage(String songAssetPath, int page, List<dynamic> labels) async {
    return _withSaveLock(() async {
      try {
        final labelsData = labels.map((label) => label.toJson()).toList();
        final file = await _getLabelsFile(songAssetPath, page);
        
        // Atomic save with temporary file
        final tempFile = File('${file.path}.tmp');
        await tempFile.parent.create(recursive: true);
        
        try {
          await tempFile.writeAsString(json.encode(labelsData));
          await tempFile.rename(file.path);
          developer.log('✅ Saved ${labelsData.length} labels for song: $songAssetPath page: $page');
        } catch (renameError) {
          await file.writeAsString(json.encode(labelsData));
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
        
        // 2. Sync to CloudKit
        await _syncLabelsToCloudKit(songAssetPath, page, labels);
      } catch (e) {
        developer.log('❌ Error saving labels for $songAssetPath page $page: $e');
        throw Exception('Failed to save labels: $e');
      }
    });
  }

  /// Load labels for a specific song page using LabelPersistenceService pattern
  static Future<List<dynamic>> loadLabelsForPage(String songAssetPath, int page) async {
    try {
      final file = await _getLabelsFile(songAssetPath, page);
      if (!await file.exists()) {
        return [];
      }
      
      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) {
        return [];
      }
      
      final labelsData = json.decode(jsonString) as List<dynamic>;
      developer.log('Loaded ${labelsData.length} labels for song: $songAssetPath page: $page');
      return labelsData;
    } catch (e) {
      developer.log('❌ Error loading labels for $songAssetPath page $page: $e');
      return [];
    }
  }

  /// Check if labels file exists for a page
  static Future<bool> labelsExistForPage(String songAssetPath, int page) async {
    final file = await _getLabelsFile(songAssetPath, page);
    return await file.exists();
  }

  /// Delete labels file for a page
  static Future<void> deleteLabelsForPage(String songAssetPath, int page) async {
    final file = await _getLabelsFile(songAssetPath, page);
    if (await file.exists()) {
      await file.delete();
      developer.log('Deleted labels for song: $songAssetPath page: $page');
    }
  }

  /// Get file for storing labels for a specific song page
  static Future<File> _getLabelsFile(String songAssetPath, int page) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeFilename = _getSafeFilename(songAssetPath);
    return File('${directory.path}/${safeFilename}_pdf_page_${page}_labels.json');
  }

  /// Create a safe filename from asset path
  static String _getSafeFilename(String path) {
    return path
        .split('/')
        .last
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'), '_')
        .replaceAll(RegExp(r'_{2,}'), '_');
  }

  // ===================== YouTube Videos Management =====================

  /// Load list of YouTube videos
  static Future<List<Map<String, dynamic>>> loadYoutubeVideosList() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_youtubeVideosFileName');
      
      if (!await file.exists()) {
        return [];
      }
      
      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString);
      
      if (jsonData is List) {
        return List<Map<String, dynamic>>.from(jsonData);
      }
      
      return [];
    } catch (e) {
      debugPrint('Error loading YouTube videos list: $e');
      return [];
    }
  }

  /// Save list of YouTube videos
  static Future<void> saveYoutubeVideosList(List<Map<String, dynamic>> videos) async {
    return await _withSaveLock(() async {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$_youtubeVideosFileName');
        
        final jsonString = json.encode(videos);
        await file.writeAsString(jsonString);
        
        developer.log('✅ SAVE: YouTube videos list saved successfully');
        
        // 2. Sync to CloudKit
        await _syncYoutubeVideosToCloudKit(videos);
      } catch (e) {
        developer.log('❌ SAVE ERROR: Failed to save YouTube videos list: $e');
        rethrow;
      }
    });
  }

  /// Add a YouTube video to the list
  static Future<void> addYoutubeVideo(Map<String, dynamic> video) async {
    final videos = await loadYoutubeVideosList();
    videos.add(video);
    await saveYoutubeVideosList(videos);
  }

  /// Delete a YouTube video from the list
  static Future<void> deleteYoutubeVideo(String videoId) async {
    final videos = await loadYoutubeVideosList();
    videos.removeWhere((video) => video['id'] == videoId);
    await saveYoutubeVideosList(videos);
  }

  /// Update a YouTube video in the list
  static Future<void> updateYoutubeVideo(String videoId, Map<String, dynamic> updatedVideo) async {
    final videos = await loadYoutubeVideosList();
    final index = videos.indexWhere((video) => video['id'] == videoId);
    if (index != -1) {
      videos[index] = updatedVideo;
      await saveYoutubeVideosList(videos);
    }
  }

  // =============================================================================
  // CLOUDKIT CHANGE TAG MANAGEMENT
  // =============================================================================

  /// Save server change token for CloudKit sync
  static Future<void> saveServerChangeToken(String? token) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/server_change_token.txt');
      if (token != null) {
        await file.writeAsString(token);
        developer.log('☁️ Saved server change token');
      } else {
        if (await file.exists()) {
          await file.delete();
          developer.log('☁️ Deleted server change token');
        }
      }
    } catch (e) {
      developer.log('❌ Error saving server change token: $e');
    }
  }

  /// Load server change token for CloudKit sync
  static Future<String?> loadServerChangeToken() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/server_change_token.txt');
      if (await file.exists()) {
        final token = await file.readAsString();
        developer.log('☁️ Loaded server change token');
        return token.trim().isEmpty ? null : token;
      }
      return null;
    } catch (e) {
      developer.log('❌ Error loading server change token: $e');
      return null;
    }
  }

  /// Update recordChangeTag for a specific practice area
  static Future<void> updatePracticeAreaChangeTag(String recordName, String changeTag) async {
    try {
      final areas = await loadPracticeAreas();
      final index = areas.indexWhere((area) => area.recordName == recordName);
      if (index != -1) {
        // Create a new area with updated change tag
        final updatedArea = PracticeArea(
          recordName: areas[index].recordName,
          name: areas[index].name,
          type: areas[index].type,
          song: areas[index].song,
          recordChangeTag: changeTag,
        );
        areas[index] = updatedArea;
        await savePracticeAreas(areas);
        developer.log('☁️ Updated practice area change tag: $recordName');
      }
    } catch (e) {
      developer.log('❌ Error updating practice area change tag: $e');
    }
  }

  /// Update recordChangeTag for sheet music data
  static Future<void> updateSheetMusicChangeTag(String songId, String changeTag) async {
    try {
      // Store change tag in metadata using a different structure
      final changeTagsFile = await _getFile('sheet_music_change_tags.json');
      Map<String, String> changeTags = {};
      
      // Load existing change tags
      if (await changeTagsFile.exists()) {
        final content = await changeTagsFile.readAsString();
        if (content.isNotEmpty) {
          changeTags = Map<String, String>.from(json.decode(content));
        }
      }
      
      // Update the change tag
      changeTags[songId] = changeTag;
      await changeTagsFile.writeAsString(json.encode(changeTags));
      
      developer.log('☁️ Updated sheet music change tag: $songId');
    } catch (e) {
      developer.log('❌ Error updating sheet music change tag: $e');
    }
  }

  /// Get recordChangeTag for sheet music data
  static Future<String?> getSheetMusicChangeTag(String songId) async {
    try {
      final changeTagsFile = await _getFile('sheet_music_change_tags.json');
      
      if (await changeTagsFile.exists()) {
        final content = await changeTagsFile.readAsString();
        if (content.isNotEmpty) {
          final changeTags = Map<String, String>.from(json.decode(content));
          return changeTags[songId];
        }
      }
      return null;
    } catch (e) {
      developer.log('❌ Error getting sheet music change tag: $e');
      return null;
    }
  }

  // =============================================================================
  // PDF STORAGE WITH CLOUDKIT ASSETS
  // =============================================================================

  /// Save PDF file to CloudKit using CKAsset and store metadata locally
  static Future<String?> savePDFWithAsset({
    required String pdfId,
    required String filePath,
    required String title,
    required String type, // 'book' or 'song'
    String? author,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      developer.log('📄 ===== PDF UPLOAD REQUEST =====');
      developer.log('📄 PDF ID: $pdfId');
      developer.log('📄 Title: $title');
      developer.log('📄 Type: $type');
      developer.log('📄 Author: ${author ?? 'N/A'}');
      developer.log('📄 File Path: $filePath');
      
      // Validate file exists and get details
      final file = File(filePath);
      if (!await file.exists()) {
        developer.log('❌ PDF file does not exist at path: $filePath');
        throw Exception('PDF file does not exist at path: $filePath');
      }
      
      final fileSize = await file.length();
      final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(2);
      developer.log('📄 File Size: ${fileSize} bytes ($fileSizeMB MB)');
      
      // Check if this PDF already exists locally
      if (type == 'book') {
        final books = await loadBooks();
        final existingBook = books.firstWhere(
          (book) => book['id'] == pdfId,
          orElse: () => <String, dynamic>{},
        );
        if (existingBook.isNotEmpty) {
          developer.log('📄 EXISTING BOOK FOUND: Updating existing record');
          developer.log('📄   Previous Title: ${existingBook['title']}');
          developer.log('📄   Previous Author: ${existingBook['author']}');
          developer.log('📄   Previous Upload Date: ${existingBook['uploadDate']}');
        } else {
          developer.log('📄 NEW BOOK: Creating new record');
        }
      } else {
        final songPDF = await _getSongPDFMetadata(pdfId);
        if (songPDF != null && songPDF.isNotEmpty) {
          developer.log('📄 EXISTING SONG PDF FOUND: Updating existing record');
          developer.log('📄   Previous Title: ${songPDF['title']}');
        } else {
          developer.log('📄 NEW SONG PDF: Creating new record');
        }
      }
      
      // Create CloudKit asset
      final asset = CloudKitAsset(
        filePath: filePath,
        fileName: '$pdfId.pdf',
      );
      
      developer.log('📄 CloudKit Asset Details:');
      developer.log('📄   Asset File Path: ${asset.filePath}');
      developer.log('📄   Asset File Name: ${asset.fileName}');
      
      // Prepare record with metadata
      final recordName = '${type}_pdf_$pdfId';
      final uploadTimestamp = DateTime.now().millisecondsSinceEpoch;
      final record = {
        'recordName': recordName,
        'recordType': type == 'book' ? 'BookWithPDF' : 'SongPDF',
        'pdfId': pdfId,
        'title': title,
        'author': author ?? '',
        'type': type,
        'uploadDate': uploadTimestamp,
        'hasAsset': true,
        ...?additionalMetadata,
      };
      
      developer.log('📄 CloudKit Record to Upload:');
      for (final entry in record.entries) {
        developer.log('📄   ${entry.key}: ${entry.value}');
      }
      
      if (additionalMetadata != null && additionalMetadata.isNotEmpty) {
        developer.log('📄 Additional Metadata:');
        for (final entry in additionalMetadata.entries) {
          developer.log('📄   ${entry.key}: ${entry.value}');
        }
      }
      
      developer.log('📄 Initiating CloudKit upload...');
      
      // Save to CloudKit with asset
      final changeTag = await CloudKitService.saveRecordWithAssets(
        record: record,
        assets: {'pdfFile': asset},
      );
      
      if (changeTag != null) {
        developer.log('📄 CloudKit upload successful, saving local metadata...');
        
        // Save metadata locally
        final localRecord = {
          'id': pdfId,
          'title': title,
          'author': author ?? '',
          'localPath': filePath,
          'type': type,
          'recordName': recordName,
          'recordChangeTag': changeTag,
          'uploadDate': uploadTimestamp,
          'hasCloudKitAsset': true,
          'fileSizeBytes': fileSize,
          ...?additionalMetadata,
        };
        
        developer.log('📄 Local Record to Save:');
        for (final entry in localRecord.entries) {
          developer.log('📄   ${entry.key}: ${entry.value}');
        }
        
        if (type == 'book') {
          await addBook(localRecord);
          developer.log('📄 Local book record saved');
        } else {
          await _saveSongPDFMetadata(pdfId, localRecord);
          developer.log('📄 Local song PDF record saved');
        }
        
        developer.log('✅ PDF UPLOAD COMPLETE: $title');
        developer.log('📄 Change Tag: $changeTag');
        developer.log('📄 ===== PDF UPLOAD SUCCESS =====');
      } else {
        developer.log('❌ CloudKit upload returned null change tag');
      }
      
      return changeTag;
    } catch (e) {
      developer.log('❌ PDF UPLOAD FAILED: Error saving PDF with CKAsset: $e');
      developer.log('📄 ===== PDF UPLOAD FAILED =====');
      rethrow;
    }
  }

  /// Download PDF file from CloudKit CKAsset with validation and caching
  /// Returns detailed result with status information
  static Future<PDFResult> downloadPDFAssetWithStatus({
    required String pdfId,
    required String type, // 'book' or 'song'
    bool validateFile = true,
    bool useCache = true,
  }) async {
    try {
      developer.log('📄 Downloading PDF asset: $pdfId');
      
      // Check cache first if enabled
      if (useCache) {
        final cachedPath = await _getCachedPDFPath(pdfId, type);
        if (cachedPath != null) {
          developer.log('💾 Using cached PDF: $cachedPath');
          return PDFResult.success(cachedPath, 'Found in cache');
        }
      }
      
      // Check network connectivity
      if (!await CloudKitService.isAccountAvailable()) {
        return PDFResult.error('Not logged into iCloud. Please sign in to download files.');
      }
      
      final recordName = '${type}_pdf_$pdfId';
      
      // Download asset from CloudKit
      final downloadedFilePath = await CloudKitService.downloadRecordAsset(
        recordName: recordName,
        assetKey: 'pdfFile',
      );
      
      if (downloadedFilePath != null) {
        // Validate downloaded file if requested
        if (validateFile) {
          final isValid = await _validatePDFFile(downloadedFilePath);
          if (!isValid) {
            developer.log('❌ Downloaded PDF file is invalid: $downloadedFilePath');
            // Clean up invalid file
            try {
              await File(downloadedFilePath).delete();
            } catch (e) {
              developer.log('⚠️ Failed to clean up invalid file: $e');
            }
            return PDFResult.error('Downloaded file is corrupted. Please try again.');
          }
        }
        
        // Move to app-specific PDF cache directory
        final cachedPath = await _cachePDFFile(downloadedFilePath, pdfId, type);
        
        // Update local metadata with cached path
        if (type == 'book') {
          await _updateBookLocalPath(pdfId, cachedPath);
        } else {
          await _updateSongPDFLocalPath(pdfId, cachedPath);
        }
        
        developer.log('✅ PDF asset downloaded and cached: $cachedPath');
        return PDFResult.success(cachedPath, 'Downloaded successfully');
      } else {
        developer.log('❌ PDF asset download failed or returned null');
        return PDFResult.error('Failed to download from CloudKit. The file may not exist or network connection failed.');
      }
    } catch (e) {
      developer.log('❌ Error downloading PDF asset: $e');
      return PDFResult.error('Download error: ${e.toString()}');
    }
  }

  /// Download PDF file from CloudKit CKAsset with validation and caching (legacy method)
  /// For backward compatibility - use downloadPDFAssetWithStatus for better error handling
  static Future<String?> downloadPDFAsset({
    required String pdfId,
    required String type, // 'book' or 'song'
    bool validateFile = true,
    bool useCache = true,
  }) async {
    final result = await downloadPDFAssetWithStatus(
      pdfId: pdfId,
      type: type,
      validateFile: validateFile,
      useCache: useCache,
    );
    return result.path;
  }

  /// Get local PDF path or download from CloudKit if needed
  /// Returns PDFResult with path and status information
  static Future<PDFResult> getPDFWithStatus({
    required String pdfId,
    required String type,
  }) async {
    try {
      // Check if we have local path first
      String? localPath;
      
      if (type == 'book') {
        final books = await loadBooks();
        final book = books.firstWhere(
          (b) => b['id'] == pdfId,
          orElse: () => <String, dynamic>{},
        );
        localPath = book['localPath'] as String?;
      } else {
        final songPDF = await _getSongPDFMetadata(pdfId);
        localPath = songPDF?['localPath'] as String?;
      }
      
      // Check if local file exists and is valid
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          final isValid = await _validatePDFFile(localPath);
          if (isValid) {
            return PDFResult.success(localPath, 'Found locally');
          } else {
            developer.log('❌ Local PDF file is corrupted: $localPath');
          }
        }
      }
      
      // Local file doesn't exist or is invalid, attempt to download from CloudKit
      developer.log('📄 Local PDF not available, downloading from CloudKit: $pdfId');
      
      // Check if user is logged into iCloud first
      final isAccountAvailable = await CloudKitService.isAccountAvailable();
      if (!isAccountAvailable) {
        return PDFResult.error('Not logged into iCloud. Please sign in to access your files.');
      }
      
      final downloadedPath = await downloadPDFAsset(pdfId: pdfId, type: type);
      
      if (downloadedPath != null) {
        return PDFResult.success(downloadedPath, 'Downloaded from CloudKit');
      } else {
        return PDFResult.error('Failed to download PDF. Please check your internet connection and try again.');
      }
    } catch (e) {
      developer.log('❌ Error getting PDF path: $e');
      return PDFResult.error('Unexpected error: ${e.toString()}');
    }
  }

  /// Get local PDF path or download from CloudKit if needed (legacy method)
  /// For backward compatibility - use getPDFWithStatus for better error handling
  static Future<String?> getPDFPath({
    required String pdfId,
    required String type,
  }) async {
    final result = await getPDFWithStatus(pdfId: pdfId, type: type);
    return result.path;
  }

  /// Helper method to save song PDF metadata
  static Future<void> _saveSongPDFMetadata(String songId, Map<String, dynamic> metadata) async {
    try {
      final customSongs = await loadCustomSongs();
      final existingIndex = customSongs.indexWhere((song) => song['id'] == songId);
      
      if (existingIndex != -1) {
        // Update existing song with PDF metadata
        customSongs[existingIndex] = {...customSongs[existingIndex], ...metadata};
      } else {
        // Add new song PDF metadata
        customSongs.add(metadata);
      }
      
      await saveCustomSongs(customSongs);
    } catch (e) {
      developer.log('❌ Error saving song PDF metadata: $e');
      rethrow;
    }
  }

  /// Helper method to get song PDF metadata
  static Future<Map<String, dynamic>?> _getSongPDFMetadata(String songId) async {
    try {
      final customSongs = await loadCustomSongs();
      return customSongs.firstWhere(
        (song) => song['id'] == songId,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      developer.log('❌ Error getting song PDF metadata: $e');
      return null;
    }
  }

  /// Helper method to update book local path
  static Future<void> _updateBookLocalPath(String bookId, String newLocalPath) async {
    try {
      final books = await loadBooks();
      final index = books.indexWhere((book) => book['id'] == bookId);
      
      if (index != -1) {
        books[index]['localPath'] = newLocalPath;
        await saveBooks(books);
        developer.log('📚 Updated book local path: $bookId');
      }
    } catch (e) {
      developer.log('❌ Error updating book local path: $e');
    }
  }

  /// Helper method to update song PDF local path
  static Future<void> _updateSongPDFLocalPath(String songId, String newLocalPath) async {
    try {
      final customSongs = await loadCustomSongs();
      final index = customSongs.indexWhere((song) => song['id'] == songId);
      
      if (index != -1) {
        customSongs[index]['localPath'] = newLocalPath;
        await saveCustomSongs(customSongs);
        developer.log('🎵 Updated song PDF local path: $songId');
      }
    } catch (e) {
      developer.log('❌ Error updating song PDF local path: $e');
    }
  }

  /// Get cached PDF path if it exists and is valid
  static Future<String?> _getCachedPDFPath(String pdfId, String type) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/pdf_cache/$type');
      final cachedFile = File('${cacheDir.path}/$pdfId.pdf');
      
      if (await cachedFile.exists()) {
        // Validate cached file
        final isValid = await _validatePDFFile(cachedFile.path);
        if (isValid) {
          return cachedFile.path;
        } else {
          // Remove invalid cached file
          try {
            await cachedFile.delete();
            developer.log('🗑️ Removed invalid cached PDF: ${cachedFile.path}');
          } catch (e) {
            developer.log('⚠️ Failed to remove invalid cached file: $e');
          }
        }
      }
      return null;
    } catch (e) {
      developer.log('❌ Error checking cached PDF: $e');
      return null;
    }
  }

  /// Cache PDF file in app-specific directory
  static Future<String> _cachePDFFile(String downloadedPath, String pdfId, String type) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/pdf_cache/$type');
      await cacheDir.create(recursive: true);
      
      final cachedFile = File('${cacheDir.path}/$pdfId.pdf');
      
      // Copy downloaded file to cache
      await File(downloadedPath).copy(cachedFile.path);
      
      // Clean up original download file
      try {
        await File(downloadedPath).delete();
      } catch (e) {
        developer.log('⚠️ Failed to clean up original download file: $e');
      }
      
      developer.log('💾 PDF cached: ${cachedFile.path}');
      return cachedFile.path;
    } catch (e) {
      developer.log('❌ Error caching PDF file: $e');
      // Return original path if caching fails
      return downloadedPath;
    }
  }

  /// Validate that a file is a valid PDF
  static Future<bool> _validatePDFFile(String filePath) async {
    try {
      final file = File(filePath);
      
      // Check file exists and has content
      if (!await file.exists()) {
        developer.log('❌ PDF validation failed: File does not exist');
        return false;
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        developer.log('❌ PDF validation failed: File is empty');
        return false;
      }
      
      // Check minimum size (PDFs are typically at least 1KB)
      if (fileSize < 1024) {
        developer.log('❌ PDF validation failed: File too small ($fileSize bytes)');
        return false;
      }
      
      // Check PDF header
      final bytes = await file.openRead(0, 8).first;
      final header = String.fromCharCodes(bytes.take(4));
      if (header != '%PDF') {
        developer.log('❌ PDF validation failed: Invalid PDF header');
        return false;
      }
      
      developer.log('✅ PDF validation passed: $filePath ($fileSize bytes)');
      return true;
    } catch (e) {
      developer.log('❌ Error validating PDF file: $e');
      return false;
    }
  }

  /// Clean up old cached PDF files (call periodically to manage storage)
  static Future<void> cleanupPDFCache({int maxAgeHours = 72}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/pdf_cache');
      
      if (!await cacheDir.exists()) {
        return;
      }
      
      final cutoffTime = DateTime.now().subtract(Duration(hours: maxAgeHours));
      int cleanedCount = 0;
      
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffTime)) {
            try {
              await entity.delete();
              cleanedCount++;
            } catch (e) {
              developer.log('⚠️ Failed to delete cached file ${entity.path}: $e');
            }
          }
        }
      }
      
      if (cleanedCount > 0) {
        developer.log('🗑️ Cleaned up $cleanedCount old cached PDF files');
      }
    } catch (e) {
      developer.log('❌ Error cleaning up PDF cache: $e');
    }
  }

  /// Check if a PDF is available locally or needs to be downloaded
  static Future<PDFAvailability> checkPDFAvailability({
    required String pdfId,
    required String type,
  }) async {
    try {
      // Check local file first
      String? localPath;
      
      if (type == 'book') {
        final books = await loadBooks();
        final book = books.firstWhere(
          (b) => b['id'] == pdfId,
          orElse: () => <String, dynamic>{},
        );
        localPath = book['localPath'] as String?;
      } else {
        final songPDF = await _getSongPDFMetadata(pdfId);
        localPath = songPDF?['localPath'] as String?;
      }
      
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          final isValid = await _validatePDFFile(localPath);
          if (isValid) {
            return PDFAvailability.locallyAvailable;
          }
        }
      }
      
      // Check cache
      final cachedPath = await _getCachedPDFPath(pdfId, type);
      if (cachedPath != null) {
        return PDFAvailability.cached;
      }
      
      // Check if user is logged into iCloud
      if (!await CloudKitService.isAccountAvailable()) {
        return PDFAvailability.needsICloudLogin;
      }
      
      // PDF needs to be downloaded
      return PDFAvailability.needsDownload;
    } catch (e) {
      developer.log('❌ Error checking PDF availability: $e');
      return PDFAvailability.error;
    }
  }

  /// Get cache size and statistics
  static Future<Map<String, dynamic>> getPDFCacheStats() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/pdf_cache');
      
      if (!await cacheDir.exists()) {
        return {
          'totalFiles': 0,
          'totalSizeBytes': 0,
          'bookCount': 0,
          'songCount': 0,
        };
      }
      
      int totalFiles = 0;
      int totalSize = 0;
      int bookCount = 0;
      int songCount = 0;
      
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalFiles++;
          totalSize += stat.size;
          
          if (entity.path.contains('/book/')) {
            bookCount++;
          } else if (entity.path.contains('/song/')) {
            songCount++;
          }
        }
      }
      
      return {
        'totalFiles': totalFiles,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
        'bookCount': bookCount,
        'songCount': songCount,
      };
    } catch (e) {
      developer.log('❌ Error getting cache stats: $e');
      return {
        'totalFiles': 0,
        'totalSizeBytes': 0,
        'bookCount': 0,
        'songCount': 0,
        'error': e.toString(),
      };
    }
  }

  // =============================================================================
  // CLOUDKIT SYNC HELPER METHODS
  // =============================================================================

  /// Sync practice area to CloudKit
  static Future<void> _syncPracticeAreaToCloudKit(PracticeArea area) async {
    try {
      // Create CloudKit record
      final record = {
        'recordName': area.recordName,
        'recordType': 'PracticeArea',
        'name': area.name,
        'type': area.type.toString(),
        'song': area.song?.toJson(),
      };
      
      // Save to CloudKit and get change tag
      final changeTag = await CloudKitService.saveRecord(record);
      
      // Update local record with change tag
      if (changeTag != null) {
        await updatePracticeAreaChangeTag(area.recordName, changeTag);
      }
    } catch (e) {
      developer.log('❌ Error syncing practice area to CloudKit: ${area.recordName} - $e');
    }
  }

  /// Sync practice item to CloudKit
  static Future<void> _syncPracticeItemToCloudKit(PracticeItem item, String practiceAreaId) async {
    try {
      // Create CloudKit record
      final record = {
        'recordName': item.id,
        'recordType': 'PracticeItem',
        'practiceAreaId': practiceAreaId,
        'name': item.name,
        'description': item.description,
        'chordProgression': item.chordProgression?.toJson(),
        'keysPracticed': item.keysPracticed,
      };
      
      // Save to CloudKit and get change tag
      await CloudKitService.saveRecord(record);
      
      // Note: Practice items don't have individual change tag tracking in current implementation
      // This could be enhanced later if needed
    } catch (e) {
      developer.log('❌ Error syncing practice item to CloudKit: ${item.id} - $e');
    }
  }

  /// Sync sheet music to CloudKit
  static Future<void> _syncSheetMusicToCloudKit(String songId, List<Measure> measures) async {
    try {
      // Convert measures to JSON
      final measuresData = measures.map((measure) => measureToJson(measure)).toList();
      
      // Create CloudKit record
      final record = {
        'recordName': songId,
        'recordType': 'SheetMusic',
        'measuresData': json.encode(measuresData),
      };
      
      // Save to CloudKit and get change tag
      final changeTag = await CloudKitService.saveRecord(record);
      
      // Update local record with change tag
      if (changeTag != null) {
        await updateSheetMusicChangeTag(songId, changeTag);
      }
    } catch (e) {
      developer.log('❌ Error syncing sheet music to CloudKit: $songId - $e');
    }
  }

  /// Sync weekly schedule to CloudKit
  static Future<void> _syncWeeklyScheduleToCloudKit(Map<String, List<String>> schedule) async {
    try {
      final record = {
        'recordName': 'weekly_schedule',
        'recordType': 'WeeklySchedule',
        'scheduleData': json.encode(schedule),
      };
      
      await CloudKitService.saveRecord(record);
    } catch (e) {
      developer.log('❌ Error syncing weekly schedule to CloudKit: $e');
    }
  }

  /// Sync song changes to CloudKit
  static Future<void> _syncSongChangesToCloudKit(String songId, Map<String, dynamic> changes) async {
    try {
      final record = {
        'recordName': 'song_changes_$songId',
        'recordType': 'SongChanges',
        'songId': songId,
        'changesData': json.encode(changes),
      };
      
      await CloudKitService.saveRecord(record);
    } catch (e) {
      developer.log('❌ Error syncing song changes to CloudKit: $songId - $e');
    }
  }

  /// Sync chord keys to CloudKit
  static Future<void> _syncChordKeysToCloudKit(String songId, Map<String, dynamic> chordKeys) async {
    try {
      final record = {
        'recordName': 'chord_keys_$songId',
        'recordType': 'ChordKeys',
        'songId': songId,
        'chordKeysData': json.encode(chordKeys),
      };
      
      await CloudKitService.saveRecord(record);
    } catch (e) {
      developer.log('❌ Error syncing chord keys to CloudKit: $songId - $e');
    }
  }

  /// Sync drawings to CloudKit
  static Future<void> _syncDrawingsToCloudKit(String songId, List<Map<String, dynamic>> drawingData) async {
    try {
      final record = {
        'recordName': 'drawings_$songId',
        'recordType': 'Drawings',
        'songId': songId,
        'drawingsData': json.encode(drawingData),
      };
      
      await CloudKitService.saveRecord(record);
    } catch (e) {
      developer.log('❌ Error syncing drawings to CloudKit: $songId - $e');
    }
  }

  /// Sync PDF drawings to CloudKit
  static Future<void> _syncPDFDrawingsToCloudKit(String songId, int pageNumber, List<PaintInfo> paintHistory) async {
    try {
      final drawingData = paintHistory.map((paintInfo) => paintInfoToJson(paintInfo)).toList();
      
      final record = {
        'recordName': 'pdf_drawings_${songId}_page_$pageNumber',
        'recordType': 'PDFDrawings',
        'songId': songId,
        'pageNumber': pageNumber,
        'drawingsData': json.encode(drawingData),
      };
      
      await CloudKitService.saveRecord(record);
    } catch (e) {
      developer.log('❌ Error syncing PDF drawings to CloudKit: $songId page $pageNumber - $e');
    }
  }

  /// Sync YouTube links to CloudKit
  static Future<void> _syncYoutubeLinksToCloudKit(String songId, Map<String, dynamic> youtubeData) async {
    try {
      final record = {
        'recordName': 'youtube_links_$songId',
        'recordType': 'YoutubeLinks',
        'songId': songId,
        'youtubeData': json.encode(youtubeData),
      };
      
      await CloudKitService.saveRecord(record);
    } catch (e) {
      developer.log('❌ Error syncing YouTube links to CloudKit: $songId - $e');
    }
  }

  /// Sync saved loops to CloudKit
  static Future<void> _syncSavedLoopsToCloudKit(String songId, List<Map<String, dynamic>> loops) async {
    try {
      final record = {
        'recordName': 'saved_loops_$songId',
        'recordType': 'SavedLoops',
        'songId': songId,
        'loopsData': json.encode(loops),
      };
      
      await CloudKitService.saveRecord(record);
    } catch (e) {
      developer.log('❌ Error syncing saved loops to CloudKit: $songId - $e');
    }
  }

  /// Sync custom songs to CloudKit
  static Future<void> _syncCustomSongsToCloudKit(List<Map<String, dynamic>> songs) async {
    try {
      final record = {
        'recordName': 'custom_songs',
        'recordType': 'CustomSongs',
        'songsData': json.encode(songs),
      };
      
      await CloudKitService.saveRecord(record);
    } catch (e) {
      developer.log('❌ Error syncing custom songs to CloudKit: $e');
    }
  }

  /// Sync YouTube videos to CloudKit
  static Future<void> _syncYoutubeVideosToCloudKit(List<Map<String, dynamic>> videos) async {
    try {
      final record = {
        'recordName': 'youtube_videos',
        'recordType': 'YoutubeVideos',
        'videosData': json.encode(videos),
      };
      
      await CloudKitService.saveRecord(record);
    } catch (e) {
      developer.log('❌ Error syncing YouTube videos to CloudKit: $e');
    }
  }

  /// Sync labels to CloudKit
  static Future<void> _syncLabelsToCloudKit(String songAssetPath, int page, List<dynamic> labels) async {
    try {
      final record = {
        'recordName': 'labels_${_getSafeFilename(songAssetPath)}_page_$page',
        'recordType': 'Labels',
        'songAssetPath': songAssetPath,
        'page': page,
        'labelsData': json.encode(labels.map((label) => label.toJson()).toList()),
      };
      
      await CloudKitService.saveRecord(record);
    } catch (e) {
      developer.log('❌ Error syncing labels to CloudKit: $songAssetPath page $page - $e');
    }
  }

  /// Sync books to CloudKit
  static Future<void> _syncBooksToCloudKit(List<Map<String, dynamic>> books) async {
    try {
      for (final book in books) {
        final record = {
          'recordName': book['id'] ?? 'book_${DateTime.now().millisecondsSinceEpoch}',
          'recordType': 'Book',
          'directoryPath': book['path'],
          ...book,
        };
        
        await CloudKitService.saveRecord(record);
      }
    } catch (e) {
      developer.log('❌ Error syncing books to CloudKit: $e');
    }
  }
}
