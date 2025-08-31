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
import 'package:practice_pad/services/icloud_sync_service.dart';

/// Local storage service for persisting app data
class LocalStorageService {
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

  // iCloud Sync Integration
  static ICloudSyncService? _icloudSyncService;
  static bool _icloudSyncEnabled = false;

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
          jsonData.map((json) => _practiceAreaFromJson(json)).toList();
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
            (items as List).map((json) => _practiceItemFromJson(json)).toList(),
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
      final file = await _getFile(_weeklyScheduleFileName);
      await file.writeAsString(json.encode(schedule));
      developer.log('Saved weekly schedule to local storage');
      
      // Sync to iCloud after successful save
      await _syncFileToICloud(_weeklyScheduleFileName);
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
      final allChanges = await loadAllSongChanges();
      allChanges[songId] = changes;

      final file = await _getFile(_songChangesFileName);
      await file.writeAsString(json.encode(allChanges));
      developer.log('Saved song changes for song: $songId');
      
      // Sync to iCloud after successful save
      await _syncFileToICloud(_songChangesFileName);
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
      final allChordKeys = await loadAllChordKeys();
      allChordKeys[songId] = chordKeys;

      final file = await _getFile(_chordKeysFileName);
      await file.writeAsString(json.encode(allChordKeys));
      developer.log('Saved chord keys for song: $songId');
      
      // Sync to iCloud after successful save
      await _syncFileToICloud(_chordKeysFileName);
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
  static Future<void> saveSheetMusicForSong(
      String songId, List<Measure> measures) async {
    try {
      final allSheetMusic = await loadAllSheetMusic();
      allSheetMusic[songId] =
          measures.map((measure) => _measureToJson(measure)).toList();

      final file = await _getFile(_sheetMusicFileName);
      await file.writeAsString(json.encode(allSheetMusic));
      developer.log(
          'Saved sheet music for song: $songId (${measures.length} measures)');
      
      // Sync to iCloud after successful save
      await _syncFileToICloud(_sheetMusicFileName);
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
          measureData.map((json) => _measureFromJson(json)).toList();
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
  static Map<String, dynamic> _measureToJson(Measure measure) {
    // Filter out clefs and time signatures - only save modifiable symbols
    final modifiableSymbols = measure.musicalSymbols.where((symbol) {
      return symbol is! Clef &&
          symbol is! KeySignature &&
          symbol is! TimeSignature;
    }).toList();

    return {
      'musicalSymbols': modifiableSymbols
          .map((symbol) => _musicalSymbolToJson(symbol))
          .toList(),
      'isNewLine': measure.isNewLine,
      // Note: chordSymbols serialization will be added later
    };
  }

  /// Convert JSON to Measure
  static Measure _measureFromJson(Map<String, dynamic> json) {
    final symbolsData = json['musicalSymbols'] as List? ?? [];
    final symbols = symbolsData
        .map((symbolJson) => _musicalSymbolFromJson(symbolJson))
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
        
        // Sync to iCloud after successful save
        await _syncFileToICloud(_drawingsFileName);
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

        if (content != null) {
          contents.add(content);
        } else {}
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
            .map((paintInfo) => _paintInfoToJson(paintInfo))
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
              .map((json) => _paintInfoFromJson(json))
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
  static Map<String, dynamic> _paintInfoToJson(PaintInfo paintInfo) {
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
  static PaintInfo _paintInfoFromJson(Map<String, dynamic> json) {
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
      final allYoutubeLinks = await loadAllYoutubeLinks();
      allYoutubeLinks[songId] = youtubeData;

      final file = await _getFile(_youtubeLinksFileName);
      await file.writeAsString(json.encode(allYoutubeLinks));
      developer.log('Saved YouTube link for song: $songId');
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
      final allSavedLoops = await loadAllSavedLoops();
      allSavedLoops[songId] = loops;

      final file = await _getFile(_savedLoopsFileName);
      await file.writeAsString(json.encode(allSavedLoops));
      developer.log('Saved ${loops.length} loops for song: $songId');
      
      // Sync to iCloud after successful save
      await _syncFileToICloud(_savedLoopsFileName);
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
        
        // Sync to iCloud after deletion
        await _syncFileToICloud(_customSongsFileName);
      } else {
        throw Exception('Custom song with path $songPath not found');
      }
    } catch (e) {
      developer.log('❌ Error deleting custom song: $e');
      rethrow;
    }
  }

  // ============== iCloud Sync Integration ==============

  /// Initialize iCloud sync service
  static Future<void> initializeICloudSync() async {
    try {
      _icloudSyncService = ICloudSyncService();
      await _icloudSyncService!.initialize();
      _icloudSyncEnabled = await _icloudSyncService!.isICloudAvailable();
      
      if (_icloudSyncEnabled) {
        developer.log('☁️ iCloud sync initialized and available');
      } else {
        developer.log('⚠️ iCloud sync not available on this device');
      }
    } catch (e) {
      developer.log('❌ Failed to initialize iCloud sync: $e');
      _icloudSyncEnabled = false;
    }
  }

  /// Check if iCloud sync is enabled and available
  static bool get isICloudSyncEnabled => _icloudSyncEnabled && _icloudSyncService != null;

  /// Get iCloud sync service instance
  static ICloudSyncService? get icloudSyncService => _icloudSyncService;

  /// Enable or disable iCloud sync
  static Future<void> setICloudSyncEnabled(bool enabled) async {
    if (enabled && _icloudSyncService == null) {
      await initializeICloudSync();
    }
    _icloudSyncEnabled = enabled && _icloudSyncService != null;
    developer.log('☁️ iCloud sync ${_icloudSyncEnabled ? 'enabled' : 'disabled'}');
  }

  /// Sync a specific file to iCloud
  static Future<void> _syncFileToICloud(String fileName) async {
    if (!isICloudSyncEnabled) return;
    
    try {
      await _icloudSyncService!.syncJsonFile(fileName);
    } catch (e) {
      developer.log('⚠️ Failed to sync $fileName to iCloud: $e');
      // Don't rethrow - sync failures shouldn't break local operations
    }
  }

  /// Sync all data to iCloud
  static Future<SyncResult> syncAllToICloud() async {
    if (!isICloudSyncEnabled) {
      return SyncResult.error('iCloud sync not available or enabled');
    }
    
    return await _icloudSyncService!.syncAllData();
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
        
        // Sync to iCloud after successful save
        await _syncFileToICloud(_customSongsFileName);
      } catch (e) {
        developer.log('❌ Error saving custom songs: $e');
        rethrow;
      }
    });
  }

  /// Enhanced save practice areas with iCloud sync
  static Future<void> savePracticeAreas(List<PracticeArea> areas) async {
    try {
      final file = await _getFile(_practiceAreasFileName);
      final jsonData = areas.map((area) => _practiceAreaToJson(area)).toList();
      await file.writeAsString(json.encode(jsonData));
      developer.log('Saved ${areas.length} practice areas to local storage');
      
      // Sync to iCloud after successful save
      await _syncFileToICloud(_practiceAreasFileName);
    } catch (e) {
      developer.log('Error saving practice areas: $e', error: e);
      throw Exception('Failed to save practice areas: $e');
    }
  }

  /// Enhanced save practice items with iCloud sync
  static Future<void> savePracticeItems(
      Map<String, List<PracticeItem>> itemsByArea) async {
    try {
      final file = await _getFile(_practiceItemsFileName);
      final jsonData = itemsByArea.map((areaId, items) => MapEntry(
            areaId,
            items.map((item) => _practiceItemToJson(item)).toList(),
          ));
      await file.writeAsString(json.encode(jsonData));
      developer.log(
          'Saved practice items for ${itemsByArea.length} areas to local storage');
      
      // Sync to iCloud after successful save
      await _syncFileToICloud(_practiceItemsFileName);
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

  /// Sync PDF files to iCloud (for custom song PDFs)
  static Future<SyncResult> syncPdfToICloud(String fileName) async {
    if (!isICloudSyncEnabled) {
      return SyncResult.error('iCloud sync not available or enabled');
    }
    
    try {
      return await _icloudSyncService!.syncPdfFile(fileName);
    } catch (e) {
      developer.log('❌ Failed to sync PDF $fileName to iCloud: $e');
      return SyncResult.error('Failed to sync PDF: $e');
    }
  }

  /// Get iCloud storage usage information
  static Future<Map<String, int>> getICloudStorageUsage() async {
    if (!isICloudSyncEnabled) {
      return {
        'totalSize': 0,
        'fileCount': 0,
        'jsonSize': 0,
        'pdfSize': 0,
      };
    }
    
    return await _icloudSyncService!.getStorageUsage();
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
        
        // Sync to iCloud after successful save
        final fileName = file.path.split('/').last;
        await _syncFileToICloud(fileName);
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

  /// Dispose iCloud sync service
  static void disposeICloudSync() {
    _icloudSyncService?.dispose();
    _icloudSyncService = null;
    _icloudSyncEnabled = false;
  }
}
