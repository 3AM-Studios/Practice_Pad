import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_kit/types/cloud_kit_asset.dart';
import 'package:flutter_cloud_kit/types/database_scope.dart';
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
import 'package:http/http.dart' as http;

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
  static const String _changeTagsFileName = 'change_tags.json';

  static Completer<void>? _currentSaveOperation;

  static Future<T> _withSaveLock<T>(Future<T> Function() operation) async {
    if (_currentSaveOperation != null && !_currentSaveOperation!.isCompleted) {
      await _currentSaveOperation!.future;
    }
    final completer = Completer<void>();
    _currentSaveOperation = completer;
    try {
      return await operation();
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  static Future<File> _getFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  // =============================================================================
  // Change Tag Management
  // =============================================================================

  static Future<Map<String, String>> _loadAllChangeTags() async {
    try {
      final file = await _getFile(_changeTagsFileName);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      return Map<String, String>.from(json.decode(content));
    } catch (e) {
      return {};
    }
  }

  static Future<void> _saveAllChangeTags(Map<String, String> tags) async {
    final file = await _getFile(_changeTagsFileName);
    await file.writeAsString(json.encode(tags));
  }

  static Future<String?> getLocalChangeTag(String recordType, String recordName) async {
    final tags = await _loadAllChangeTags();
    return tags['$recordType/$recordName'];
  }

  static Future<void> saveLocalChangeTag(String recordType, String recordName, String changeTag) async {
    final tags = await _loadAllChangeTags();
    tags['$recordType/$recordName'] = changeTag;
    await _saveAllChangeTags(tags);
  }

  // =============================================================================
  // Update from Cloud Methods
  // =============================================================================

  static Future<void> updatePracticeAreaFromCloud(Map<String, dynamic> record) async {
    try {
      print('📥 Processing practice area from CloudKit:');
      print('   Record: $record');
      
      // Handle both nested and flat data formats from CloudKit
      Map<String, dynamic> dataToProcess;
      if (record.containsKey('value') && record['value'] is Map) {
        // Data is nested inside 'value' field
        dataToProcess = Map<String, dynamic>.from(record['value']);
        print('   Using nested value format');
      } else {
        // Data is flat
        dataToProcess = Map<String, dynamic>.from(record);
        print('   Using flat format');
      }
      
      final area = practiceAreaFromJson(dataToProcess);
      print('   Parsed area: ${area.recordName} - ${area.name}');
      
      final areas = await loadPracticeAreas();
      print('   Current local areas: ${areas.length}');
      print('   Looking for existing area with recordName: ${area.recordName}');
      
      final index = areas.indexWhere((a) => a.recordName == area.recordName);
      if (index != -1) {
        print('   Updating existing area at index $index');
        areas[index] = area;
      } else {
        // Double-check that we don't already have this area by name to prevent duplicates
        final duplicateIndex = areas.indexWhere((a) => a.name == area.name && a.type == area.type);
        if (duplicateIndex != -1) {
          print('   Found duplicate area by name/type at index $duplicateIndex, updating instead of adding');
          areas[duplicateIndex] = area;
        } else {
          print('   Adding new area');
          areas.add(area);
        }
      }
      
      await savePracticeAreas(areas, syncToCloud: false);
      print('✅ Successfully updated practice area: ${area.name}');
    } catch (e, stackTrace) {
      print('❌ Error updating practice area from cloud: $e');
      print('Stack trace: $stackTrace');
    }
  }

 
  static Future<void> updateBookFromCloud(Map<String, dynamic> record) async {
    try {
      final bookId = record['recordName'] as String;
      final books = await loadBooks();
      final index = books.indexWhere((book) => book['id'] == bookId);
      
      // Create book data from record (excluding asset fields)
      final bookData = <String, dynamic>{
        'id': bookId,
      };
      
      // Copy all non-asset fields from the record
      record.forEach((key, value) {
        if (key != 'recordType' && key != 'recordName' && key != 'recordChangeTag' && key != 'pdfFile') {
          bookData[key] = value;
        }
      });
      
      if (index != -1) {
        // Book exists locally, update it
        books[index] = {...books[index], ...bookData};
      } else {
        // Book doesn't exist locally, create it and download asset if present
        final pdfAsset = record['pdfFile'] as CloudKitAsset?;
        
        if (pdfAsset != null) {
          // Download the PDF asset using the new asset download helper
          final fileName = '${bookId}_book.pdf';
          final localPdfPath = await downloadAsset(
            asset: pdfAsset,
            localFileName: fileName,
            subdirectory: 'books',
          );
          
          if (localPdfPath != null) {
            bookData['fileName'] = fileName;
            developer.log('✅ Downloaded book asset: $fileName');
          } else {
            developer.log('❌ Failed to download book asset for book: $bookId');
          }
        }
        
        // Add the new book
        books.add(bookData);
      }
      
      await saveBooks(books, syncToCloud: false);
    } catch (e) {
      developer.log('Error updating book from cloud: $e');
    }
  }

  static Future<void> updateSongPdfFromCloud(Map<String, dynamic> record) async {
    try {
      print('📝 Processing song PDF from CloudKit:');
      print('   Record: $record');
      
      final songId = record['recordName'] as String;
      final pdfAsset = record['pdfFile'] as CloudKitAsset?;
      
      print('   Song ID: $songId');
      print('   PDF Asset: $pdfAsset');
      
      if (pdfAsset != null) {
        // Handle PDF asset download from CloudKit staging area
        if (pdfAsset.isForDownload && pdfAsset.fileURL != null) {
          final fileName = '${songId}_song.pdf';
          final localPdfPath = await downloadAsset(
            asset: pdfAsset,
            localFileName: fileName,
            subdirectory: 'song_pdfs',
          );
          
          if (localPdfPath != null) {
            developer.log('✅ Downloaded song PDF from CloudKit staging: $fileName');
            // You might want to trigger a reload of the PDF viewer here or 
            // notify the app that a new PDF is available
          } else {
            developer.log('❌ Failed to download song PDF from CloudKit staging for song: $songId');
          }
        } else {
          developer.log('ℹ️ Received song PDF record from cloud: $songId, asset: $pdfAsset');
        }
        
        // You might want to trigger a reload of the PDF viewer here or notify other parts of the app
        // that a PDF has been updated from the cloud
      }
    } catch (e) {
      developer.log('Error updating song PDF from cloud: $e');
    }
  }

  static Future<void> saveSongPdf(String songId, String pdfPath) async {
    try {
      developer.log('📄 Saving song PDF to CloudKit');
      developer.log('   Song ID: $songId');
      developer.log('   PDF Path: $pdfPath');
      
      // Verify the file exists before trying to upload
      final pdfFile = File(pdfPath);
      if (!await pdfFile.exists()) {
        throw Exception('PDF file does not exist: $pdfPath');
      }
      
      final fileSize = await pdfFile.length();
      developer.log('   File exists: ${pdfFile.path}');
      developer.log('   File size: $fileSize bytes');
      
      // Prepare the record fields
      final recordFields = <String, String>{
        'songId': songId,
        'lastModified': DateTime.now().toIso8601String(),
      };
      
      developer.log('   Record fields: $recordFields');

      // Prepare the asset map with the PDF file
      final pdfAsset = CloudKitAsset.forUpload(
        filePath: pdfPath,
        fileName: pdfPath.split('/').last,
        size: fileSize,
        mimeType: 'application/pdf',
      );
      
      final assets = <String, CloudKitAsset>{
        'pdfFile': pdfAsset,
      };
      
      developer.log('   Created asset: $pdfAsset');
      developer.log('   Assets map: ${assets.keys.toList()}');

      // Save the record with its PDF asset
      developer.log('   Calling CloudKitService.saveRecordWithAssets...');
      final changeTag = await CloudKitService.saveRecordWithAssets(
        recordType: 'SongPdf',
        recordName: songId,
        record: recordFields,
        assets: assets,
      );
      
      developer.log('✅ Successfully synced song PDF to CloudKit: $songId');
      developer.log('   Change tag: $changeTag');
    } catch (e, stackTrace) {
      developer.log('❌ Error syncing song PDF to CloudKit: $e');
      developer.log('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<void> updatePracticeItemFromCloud(Map<String, dynamic> record) async {
    try {
      final item = practiceItemFromJson(record);
      final practiceAreaId = record['practiceAreaId'] as String;
      final itemsByArea = await loadPracticeItems();
      
      if (!itemsByArea.containsKey(practiceAreaId)) {
        itemsByArea[practiceAreaId] = [];
      }
      
      final items = itemsByArea[practiceAreaId]!;
      final index = items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        items[index] = item;
      } else {
        items.add(item);
      }
      
      await savePracticeItems(itemsByArea, syncToCloud: false);
    } catch (e) {
      developer.log('Error updating practice item from cloud: $e');
    }
  }

  static Future<void> updateSheetMusicFromCloud(Map<String, dynamic> record) async {
    try {
      final songId = record['recordName'] as String;
      final measuresData = record['measuresData'] as List?
        ?? [];
      final measures = measuresData.map((json) => measureFromJson(json)).toList();
      await saveSheetMusicForSong(songId, measures, syncToCloud: false);
    } catch (e) {
      developer.log('Error updating sheet music from cloud: $e');
    }
  }

  static Future<void> updateWeeklyScheduleFromCloud(Map<String, dynamic> record) async {
    try {
      print('📅 Processing weekly schedule from CloudKit:');
      print('   Record: $record');
      
      // Handle both nested and flat data formats from CloudKit
      Map<String, dynamic> scheduleData;
      if (record.containsKey('value') && record['value'] is Map) {
        // Data is nested - extract scheduleData from nested value
        final nestedData = record['value'] as Map<String, dynamic>;
        if (nestedData['scheduleData'] is String) {
          // JSON-encoded as string
          scheduleData = json.decode(nestedData['scheduleData'] as String) as Map<String, dynamic>;
          print('   Parsed JSON-encoded schedule data from nested value');
        } else {
          scheduleData = nestedData['scheduleData'] as Map<String, dynamic>? ?? {};
          print('   Using direct schedule data from nested value');
        }
      } else {
        // Data is flat
        scheduleData = record['scheduleData'] as Map<String, dynamic>? ?? {};
        print('   Using flat schedule data format');
      }
      
      print('   Schedule data keys: ${scheduleData.keys.toList()}');
      
      final schedule = scheduleData.map((day, areas) => MapEntry(
        day,
        List<String>.from(areas as List),
      ));
      
      print('   Parsed schedule: $schedule');
      
      await saveWeeklySchedule(schedule, syncToCloud: false);
      print('✅ Successfully updated weekly schedule');
    } catch (e, stackTrace) {
      print('❌ Error updating weekly schedule from cloud: $e');
      print('Stack trace: $stackTrace');
    }
  }

  static Future<void> updateSongChangesFromCloud(Map<String, dynamic> record) async {
    try {
      final songId = record['recordName'] as String;
      final changesData = record['changesData'] as Map<String, dynamic>?
        ?? {};
      await saveSongChanges(songId, changesData, syncToCloud: false);
    } catch (e) {
      developer.log('Error updating song changes from cloud: $e');
    }
  }

  static Future<void> updateChordKeysFromCloud(Map<String, dynamic> record) async {
    try {
      final songId = record['recordName'] as String;
      final chordKeysData = record['chordKeysData'] as Map<String, dynamic>?
        ?? {};
      await saveChordKeys(songId, chordKeysData, syncToCloud: false);
    } catch (e) {
      developer.log('Error updating chord keys from cloud: $e');
    }
  }

  static Future<void> updateDrawingsFromCloud(Map<String, dynamic> record) async {
    try {
      final songId = record['recordName'] as String;
      final drawingsData = record['drawingsData'] as List?
        ?? [];
      final drawings = List<Map<String, dynamic>>.from(drawingsData);
      await saveDrawingsForSong(songId, drawings, syncToCloud: false);
    } catch (e) {
      developer.log('Error updating drawings from cloud: $e');
    }
  }

  static Future<void> updatePDFDrawingsFromCloud(Map<String, dynamic> record) async {
    try {
      final songId = record['songId'] as String;
      final pageNumber = record['pageNumber'] as int;
      final drawingsData = record['drawingsData'] as List?
        ?? [];
      final paintHistory = drawingsData.map((json) => paintInfoFromJson(json)).toList();
      await savePDFDrawingsForSongPage(songId, pageNumber, paintHistory, syncToCloud: false);
    } catch (e) {
      developer.log('Error updating PDF drawings from cloud: $e');
    }
  }

  static Future<void> updateYoutubeLinksFromCloud(Map<String, dynamic> record) async {
    try {
      final songId = record['songId'] as String?;
      final youtubeData = record['youtubeData'] as Map<String, dynamic>?
        ?? {};
      
      if (songId != null) {
        await saveYoutubeLinkForSong(songId, youtubeData, syncToCloud: false);
      }
    } catch (e) {
      developer.log('Error updating YouTube links from cloud: $e');
    }
  }

  static Future<void> updateSavedLoopsFromCloud(Map<String, dynamic> record) async {
    try {
      final pageId = record['recordName'] as String;
      final loopsData = record['loopsData'] as List?
        ?? [];
      final loops = List<Map<String, dynamic>>.from(loopsData);
      await saveSavedLoopsForPage(pageId, loops, syncToCloud: false);
    } catch (e) {
      developer.log('Error updating saved loops from cloud: $e');
    }
  }

  static Future<void> updateCustomSongsFromCloud(Map<String, dynamic> record) async {
    try {
      final songsData = record['songsData'] as List?
        ?? [];
      final songs = List<Map<String, dynamic>>.from(songsData);
      await saveCustomSongs(songs, syncToCloud: false);
    } catch (e) {
      developer.log('Error updating custom songs from cloud: $e');
    }
  }

  static Future<void> updateYoutubeVideosFromCloud(Map<String, dynamic> record) async {
    try {
      final videosData = record['videosData'] as List?
        ?? [];
      final videos = List<Map<String, dynamic>>.from(videosData);
      await saveYoutubeVideosList(videos, syncToCloud: false);
    } catch (e) {
      developer.log('Error updating YouTube videos from cloud: $e');
    }
  }

  static Future<void> updateLabelsFromCloud(Map<String, dynamic> record) async {
    try {
      final songAssetPath = record['songAssetPath'] as String;
      final page = record['page'] as int;
      final labelsData = record['labelsData'] as List?
        ?? [];
      await saveLabelsForPage(songAssetPath, page, labelsData, syncToCloud: false);
    } catch (e) {
      developer.log('Error updating labels from cloud: $e');
    }
  }
  // =============================================================================
  // Load/Save Methods
  // =============================================================================

  static Future<List<PracticeArea>> loadPracticeAreas() async {
    try {
      final file = await _getFile(_practiceAreasFileName);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final List<dynamic> jsonData = json.decode(content);
      return jsonData.map((json) => practiceAreaFromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> savePracticeAreas(List<PracticeArea> areas, {bool syncToCloud = true}) async {
    return _withSaveLock(() async {
      final file = await _getFile(_practiceAreasFileName);
      final jsonData = areas.map((area) => practiceAreaToJson(area)).toList();
      await file.writeAsString(json.encode(jsonData));
      if (syncToCloud) {
        for (final area in areas) {
          await _syncPracticeAreaToCloudKit(area);
        }
      }
    });
  }

  static Future<Map<String, List<PracticeItem>>> loadPracticeItems() async {
    try {
      final file = await _getFile(_practiceItemsFileName);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      final Map<String, dynamic> jsonData = json.decode(content);
      return jsonData.map((areaId, items) => MapEntry(
            areaId,
            (items as List).map((json) => practiceItemFromJson(json)).toList(),
          ));
    } catch (e) {
      return {};
    }
  }

  static Future<void> savePracticeItems(Map<String, List<PracticeItem>> itemsByArea, {bool syncToCloud = true}) async {
    return _withSaveLock(() async {
      final file = await _getFile(_practiceItemsFileName);
      final jsonData = itemsByArea.map((areaId, items) => MapEntry(
            areaId,
            items.map((item) => practiceItemToJson(item)).toList(),
          ));
      await file.writeAsString(json.encode(jsonData));
      if (syncToCloud) {
        for (final entry in itemsByArea.entries) {
          for (final item in entry.value) {
            await _syncPracticeItemToCloudKit(item, entry.key);
          }
        }
      }
    });
  }

  static Future<void> saveWeeklySchedule(Map<String, List<String>> schedule, {bool syncToCloud = true}) async {
    return _withSaveLock(() async {
      final file = await _getFile(_weeklyScheduleFileName);
      await file.writeAsString(json.encode(schedule));
      if (syncToCloud) {
        await _syncWeeklyScheduleToCloudKit(schedule);
      }
    });
  }

  static Future<Map<String, List<String>>> loadWeeklySchedule() async {
    try {
      final file = await _getFile(_weeklyScheduleFileName);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      final Map<String, dynamic> jsonData = json.decode(content);
      return jsonData.map((day, areas) => MapEntry(
            day,
            List<String>.from(areas as List),
          ));
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveSongChanges(String songId, Map<String, dynamic> changes, {bool syncToCloud = true}) async {
    final allChanges = await loadAllSongChanges();
    allChanges[songId] = changes;
    final file = await _getFile(_songChangesFileName);
    await file.writeAsString(json.encode(allChanges));
    if (syncToCloud) {
      await _syncSongChangesToCloudKit(songId, changes);
    }
  }

  static Future<Map<String, dynamic>> loadSongChanges(String songId) async {
    final allChanges = await loadAllSongChanges();
    return allChanges[songId] ?? {};
  }

  static Future<Map<String, Map<String, dynamic>>> loadAllSongChanges() async {
    try {
      final file = await _getFile(_songChangesFileName);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      final Map<String, dynamic> jsonData = json.decode(content);
      return jsonData.map((songId, changes) => MapEntry(
            songId,
            Map<String, dynamic>.from(changes as Map),
          ));
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveChordKeys(String songId, Map<String, dynamic> chordKeys, {bool syncToCloud = true}) async {
    final allChordKeys = await loadAllChordKeys();
    allChordKeys[songId] = chordKeys;
    final file = await _getFile(_chordKeysFileName);
    await file.writeAsString(json.encode(allChordKeys));
    if (syncToCloud) {
      await _syncChordKeysToCloudKit(songId, chordKeys);
    }
  }

  static Future<Map<String, dynamic>> loadChordKeys(String songId) async {
    final allChordKeys = await loadAllChordKeys();
    return allChordKeys[songId] ?? {};
  }

  static Future<Map<String, Map<String, dynamic>>> loadAllChordKeys() async {
    try {
      final file = await _getFile(_chordKeysFileName);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      final Map<String, dynamic> jsonData = json.decode(content);
      return jsonData.map((songId, keys) => MapEntry(
            songId,
            Map<String, dynamic>.from(keys as Map),
          ));
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveSheetMusicForSong(String songId, List<Measure> measures, {bool syncToCloud = true}) async {
    final allSheetMusic = await loadAllSheetMusic();
    allSheetMusic[songId] = measures.map((measure) => measureToJson(measure)).toList();
    final file = await _getFile(_sheetMusicFileName);
    await file.writeAsString(json.encode(allSheetMusic));
    if (syncToCloud) {
      await _syncSheetMusicToCloudKit(songId, measures);
    }
  }

  static Future<List<Measure>> loadSheetMusicForSong(String songId) async {
    final allSheetMusic = await loadAllSheetMusic();
    final measureData = allSheetMusic[songId] ?? [];
    return measureData.map((json) => measureFromJson(json)).toList();
  }

  static Future<Map<String, List<dynamic>>> loadAllSheetMusic() async {
    try {
      final file = await _getFile(_sheetMusicFileName);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      final Map<String, dynamic> jsonData = json.decode(content);
      return jsonData.map((songId, measures) => MapEntry(
            songId,
            List<dynamic>.from(measures as List),
          ));
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveDrawingsForSong(String songId, List<Map<String, dynamic>> drawingData, {bool syncToCloud = true}) async {
    return _withSaveLock(() async {
      final allDrawings = await loadAllDrawings();
      allDrawings[songId] = drawingData;
      final file = await _getFile(_drawingsFileName);
      await file.writeAsString(json.encode(allDrawings));
      if (syncToCloud) {
        await _syncDrawingsToCloudKit(songId, drawingData);
      }
    });
  }

  static Future<List<Map<String, dynamic>>> loadDrawingsForSong(String songId) async {
    final allDrawings = await loadAllDrawings();
    return List<Map<String, dynamic>>.from(allDrawings[songId] ?? []);
  }

  static Future<Map<String, dynamic>> loadAllDrawings() async {
    try {
      final file = await _getFile(_drawingsFileName);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      return Map<String, dynamic>.from(json.decode(content));
    } catch (e) {
      return {};
    }
  }
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

  static Future<void> savePDFDrawingsForSongPage(String songId, int pageNumber, List<PaintInfo> paintHistory, {bool syncToCloud = true}) async {
    return _withSaveLock(() async {
      final allPDFDrawings = await loadAllPDFDrawings();
      final songPageKey = '${songId}_page_$pageNumber';
      allPDFDrawings[songPageKey] = paintHistory.map((paintInfo) => paintInfoToJson(paintInfo)).toList();
      final file = await _getFile(_pdfDrawingsFileName);
      await file.writeAsString(json.encode(allPDFDrawings));
      if (syncToCloud) {
        await _syncPDFDrawingsToCloudKit(songId, pageNumber, paintHistory);
      }
    });
  }

  static Future<List<PaintInfo>> loadPDFDrawingsForSongPage(String songId, int pageNumber) async {
    final allPDFDrawings = await loadAllPDFDrawings();
    final songPageKey = '${songId}_page_$pageNumber';
    final drawingData = allPDFDrawings[songPageKey] ?? [];
    return (drawingData as List).map((json) => paintInfoFromJson(json)).toList();
  }

  static Future<Map<String, dynamic>> loadAllPDFDrawings() async {
    try {
      final file = await _getFile(_pdfDrawingsFileName);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      return Map<String, dynamic>.from(json.decode(content));
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveYoutubeLinkForSong(String songId, Map<String, dynamic> youtubeData, {bool syncToCloud = true}) async {
    final allYoutubeLinks = await loadAllYoutubeLinks();
    allYoutubeLinks[songId] = youtubeData;
    final file = await _getFile(_youtubeLinksFileName);
    await file.writeAsString(json.encode(allYoutubeLinks));
    if (syncToCloud) {
      await _syncYoutubeLinksToCloudKit(songId, youtubeData);
    }
  }

  static Future<Map<String, dynamic>> loadYoutubeLinkForSong(String songId) async {
    final allYoutubeLinks = await loadAllYoutubeLinks();
    return allYoutubeLinks[songId] ?? {};
  }

  static Future<Map<String, Map<String, dynamic>>> loadAllYoutubeLinks() async {
    try {
      final file = await _getFile(_youtubeLinksFileName);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      final Map<String, dynamic> jsonData = json.decode(content);
      return jsonData.map((songId, data) => MapEntry(
            songId,
            Map<String, dynamic>.from(data as Map),
          ));
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveSavedLoopsForPage(String pageId, List<Map<String, dynamic>> loops, {bool syncToCloud = true}) async {
    final allSavedLoops = await loadAllSavedLoops();
    allSavedLoops[pageId] = loops;
    final file = await _getFile(_savedLoopsFileName);
    await file.writeAsString(json.encode(allSavedLoops));
    if (syncToCloud) {
      await _syncSavedLoopsToCloudKit(pageId, loops);
    }
  }

  static Future<List<Map<String, dynamic>>> loadSavedLoopsForPage(String pageId) async {
    final allSavedLoops = await loadAllSavedLoops();
    return List<Map<String, dynamic>>.from(allSavedLoops[pageId] ?? []);
  }

  static Future<Map<String, List<dynamic>>> loadAllSavedLoops() async {
    try {
      final file = await _getFile(_savedLoopsFileName);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      final Map<String, dynamic> jsonData = json.decode(content);
      return jsonData.map((songId, loops) => MapEntry(
            songId,
            List<dynamic>.from(loops as List),
          ));
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveBooks(List<Map<String, dynamic>> books, {bool syncToCloud = true}) async {
    return _withSaveLock(() async {
      final file = await _getFile(_booksFileName);
      await file.writeAsString(json.encode(books));
      if (syncToCloud) {
        await _syncBooksToCloudKit(books);
      }
    });
  }

  static Future<List<Map<String, dynamic>>> loadBooks() async {
    try {
      final file = await _getFile(_booksFileName);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      return List<Map<String, dynamic>>.from(json.decode(content));
    } catch (e) {
      return [];
    }
  }

  static Future<void> addBook(Map<String, dynamic> book, {bool syncToCloud = true}) async {
    final books = await loadBooks();
    books.add(book);
    await saveBooks(books, syncToCloud: syncToCloud);
  }

  static Future<void> deleteBook(String bookId, {bool syncToCloud = true}) async {
    final books = await loadBooks();
    books.removeWhere((book) => book['id'] == bookId);
    await saveBooks(books, syncToCloud: syncToCloud);
    // Also delete from cloudkit
  }

  /// Load a specific book by ID from local storage and CloudKit
  static Future<Map<String, dynamic>?> loadBook(String bookId) async {
    try {
      // First check local storage
      final books = await loadBooks();
      final localBook = books.cast<Map<String, dynamic>?>().firstWhere(
        (book) => book?['id'] == bookId,
        orElse: () => null,
      );
      
      if (localBook != null) {
        return localBook;
      }
      
      // If not found locally, try CloudKit
      final cloudRecord = await CloudKitService.getRecord('Book_$bookId');
      if (cloudRecord != null) {
        // Convert CloudKit record to book format
        final book = <String, dynamic>{
          'id': bookId,
        };
        
        cloudRecord.forEach((key, value) {
          if (key != 'recordChangeTag' && key != 'recordName' && key != 'recordType') {
            book[key] = value;
          }
        });
        
        return book;
      }
      
      return null;
    } catch (e) {
      developer.log('Error loading book $bookId: $e');
      return null;
    }
  }

  /// Load all books from CloudKit
  static Future<List<Map<String, dynamic>>> loadBooksFromCloudKit() async {
    try {
      final cloudRecords = await CloudKitService.getAllRecords();
      final books = <Map<String, dynamic>>[];
      
      for (final record in cloudRecords) {
        if (record['recordType'] == 'Book') {
          final book = <String, dynamic>{
            'id': record['recordName']?.toString().replaceFirst('Book_', '') ?? '',
          };
          
          record.forEach((key, value) {
            if (key != 'recordChangeTag' && key != 'recordName' && key != 'recordType') {
              book[key] = value;
            }
          });
          
          books.add(book);
        }
      }
      
      return books;
    } catch (e) {
      developer.log('Error loading books from CloudKit: $e');
      return [];
    }
  }

  /// Load a specific song PDF by song ID
  static Future<Map<String, dynamic>?> loadSongPdf(String songId) async {
    try {
      // Try to get from CloudKit first
      final sanitizedKey = songId.replaceAll(RegExp(r'[/\\:*?"<>|\s]'), '_');
      final recordKey = 'SongPdf_$sanitizedKey';
      
      final cloudRecord = await CloudKitService.getRecord(recordKey);
      if (cloudRecord != null) {
        final songPdf = <String, dynamic>{
          'songId': songId,
        };
        
        cloudRecord.forEach((key, value) {
          if (key != 'recordChangeTag' && key != 'recordName' && key != 'recordType') {
            songPdf[key] = value;
          }
        });
        
        return songPdf;
      }
      
      return null;
    } catch (e) {
      developer.log('Error loading song PDF $songId: $e');
      return null;
    }
  }

  static Future<void> saveCustomSongs(List<Map<String, dynamic>> songs, {bool syncToCloud = true}) async {
    return _withSaveLock(() async {
      final file = await _getFile(_customSongsFileName);
      await file.writeAsString(json.encode(songs));
      if (syncToCloud) {
        await _syncCustomSongsToCloudKit(songs);
      }
    });
  }

  static Future<List<Map<String, dynamic>>> loadCustomSongs() async {
    try {
      final file = await _getFile(_customSongsFileName);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      return List<Map<String, dynamic>>.from(json.decode(content));
    } catch (e) {
      return [];
    }
  }

  static Future<void> addCustomSong(Map<String, dynamic> song, {bool syncToCloud = true}) async {
    final songs = await loadCustomSongs();
    songs.add(song);
    await saveCustomSongs(songs, syncToCloud: syncToCloud);
  }

  static Future<void> deleteCustomSong(String songPath, {bool syncToCloud = true}) async {
    final songs = await loadCustomSongs();
    songs.removeWhere((song) => song['path'] == songPath);
    await saveCustomSongs(songs, syncToCloud: syncToCloud);
    // Also delete from cloudkit
  }

  static Future<void> saveLabelsForPage(String songAssetPath, int page, List<dynamic> labels, {bool syncToCloud = true}) async {
    return _withSaveLock(() async {
      final file = await _getLabelsFile(songAssetPath, page);
      final labelsData = labels.map((label) => label.toJson()).toList();
      await file.writeAsString(json.encode(labelsData));
      if (syncToCloud) {
        await _syncLabelsToCloudKit(songAssetPath, page, labels);
      }
    });
  }

  static Future<List<dynamic>> loadLabelsForPage(String songAssetPath, int page) async {
    try {
      final file = await _getLabelsFile(songAssetPath, page);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      return json.decode(content) as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveYoutubeVideosList(List<Map<String, dynamic>> videos, {bool syncToCloud = true}) async {
    return _withSaveLock(() async {
      final file = await _getFile(_youtubeVideosFileName);
      await file.writeAsString(json.encode(videos));
      if (syncToCloud) {
        await _syncYoutubeVideosToCloudKit(videos);
      }
    });
  }

  static Future<List<Map<String, dynamic>>> loadYoutubeVideosList() async {
    try {
      final file = await _getFile(_youtubeVideosFileName);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      return List<Map<String, dynamic>>.from(json.decode(content));
    } catch (e) {
      return [];
    }
  }

  static Future<void> addYoutubeVideo(Map<String, dynamic> video, {bool syncToCloud = true}) async {
    final videos = await loadYoutubeVideosList();
    videos.add(video);
    await saveYoutubeVideosList(videos, syncToCloud: syncToCloud);
  }

  static Future<void> deleteYoutubeVideo(String videoId, {bool syncToCloud = true}) async {
    final videos = await loadYoutubeVideosList();
    videos.removeWhere((video) => video['id'] == videoId);
    await saveYoutubeVideosList(videos, syncToCloud: syncToCloud);
    // Also delete from cloudkit
  }

  // =============================================================================
  // JSON Conversion
  // =============================================================================

  static Map<String, dynamic> practiceAreaToJson(PracticeArea area) {
    return {
      'recordName': area.recordName,
      'name': area.name,
      'type': area.type.toString(),
      'song': area.song?.toJson(),
      'lastModified': area.lastModified.millisecondsSinceEpoch,
    };
  }

  static PracticeArea practiceAreaFromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String;
    final type = PracticeAreaType.values.firstWhere((e) => e.toString() == typeString);
    Song? song;
    if (json['song'] != null) {
      song = Song.fromJson(json['song']);
    }
    return PracticeArea(
      recordName: json['recordName'] as String,
      name: json['name'] as String,
      type: type,
      song: song,
      lastModified: DateTime.fromMillisecondsSinceEpoch(json['lastModified'] as int? ?? 0),
    );
  }

  static Map<String, dynamic> practiceItemToJson(PracticeItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'description': item.description,
      'chordProgression': item.chordProgression?.toJson(),
      'keysPracticed': item.keysPracticed,
    };
  }

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
    );
  }

  static Map<String, dynamic> measureToJson(Measure measure) {
    final modifiableSymbols = measure.musicalSymbols.where((symbol) {
      return symbol is! Clef && symbol is! KeySignature && symbol is! TimeSignature;
    }).toList();
    return {
      'musicalSymbols': modifiableSymbols.map((symbol) => musicalSymbolToJson(symbol)).toList(),
      'isNewLine': measure.isNewLine,
    };
  }

  static Measure measureFromJson(Map<String, dynamic> json) {
    final symbolsData = json['musicalSymbols'] as List? ?? [];
    final symbols = symbolsData.map((symbolJson) => musicalSymbolFromJson(symbolJson)).toList();
    if (symbols.isEmpty) {
      symbols.add(Rest(RestType.quarter));
    }
    return Measure(symbols, isNewLine: json['isNewLine'] as bool? ?? false);
  }

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
    }
    return {};
  }

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
        final noteDuration = NoteDuration.values.firstWhere((d) => d.name == durationName);
        Accidental? accidental;
        final accidentalName = json['accidental'] as String?;
        if (accidentalName != null) {
          accidental = Accidental.values.firstWhere((a) => a.name == accidentalName);
        }
        return Note(pitch, id: id, noteDuration: noteDuration, accidental: accidental, color: color, margin: margin);
      case 'Rest':
        final restTypeName = json['restType'] as String;
        final restType = RestType.values.firstWhere((r) => r.name == restTypeName);
        return Rest(restType, color: color, margin: margin);
      default:
        return Rest(RestType.quarter, color: color, margin: margin);
    }
  }

  static Map<String, dynamic> paintInfoToJson(PaintInfo paintInfo) {
    return {
      'mode': paintInfo.mode.toString(),
      'color': paintInfo.color.value,
      'strokeWidth': paintInfo.strokeWidth,
      'offsets': paintInfo.offsets.map((offset) => offset != null ? {'dx': offset.dx, 'dy': offset.dy} : null).toList(),
      'text': paintInfo.text,
      'fill': paintInfo.fill,
    };
  }

  static PaintInfo paintInfoFromJson(Map<String, dynamic> json) {
    final modeString = json['mode'] as String;
    final mode = PaintMode.values.firstWhere((e) => e.toString() == modeString, orElse: () => PaintMode.freeStyle);
    final colorValue = json['color'] as int;
    final color = Color(colorValue);
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

  // =============================================================================
  // Sync to CloudKit Methods
  // =============================================================================

  static Future<void> _syncPracticeAreaToCloudKit(PracticeArea area) async {
    try {
      final record = practiceAreaToJson(area);
      record['recordType'] = 'PracticeArea';
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('PracticeArea', area.recordName, changeTag);
      }
    } catch (e) {
      developer.log('Error syncing practice area: $e');
    }
  }

  static Future<void> _syncPracticeItemToCloudKit(PracticeItem item, String practiceAreaId) async {
    try {
      final record = practiceItemToJson(item);
      record['recordType'] = 'PracticeItem';
      record['recordName'] = item.id;
      record['practiceAreaId'] = practiceAreaId;
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('PracticeItem', item.id, changeTag);
      }
    } catch (e) {
      developer.log('Error syncing practice item: $e');
    }
  }

  static Future<void> _syncWeeklyScheduleToCloudKit(Map<String, List<String>> schedule) async {
    try {
      final record = {
        'recordType': 'WeeklySchedule',
        'recordName': 'main_schedule',
        'scheduleData': schedule,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('WeeklySchedule', 'main_schedule', changeTag);
      }
    } catch (e) {
      developer.log('Error syncing weekly schedule: $e');
    }
  }

  static Future<void> _syncSongChangesToCloudKit(String songId, Map<String, dynamic> changes) async {
    try {
      final record = {
        'recordType': 'SongChanges',
        'recordName': songId,
        'changesData': changes,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('SongChanges', songId, changeTag);
      }
    } catch (e) {
      developer.log('Error syncing song changes: $e');
    }
  }

  static Future<void> _syncChordKeysToCloudKit(String songId, Map<String, dynamic> chordKeys) async {
    try {
      final record = {
        'recordType': 'ChordKeys',
        'recordName': songId,
        'chordKeysData': chordKeys,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('ChordKeys', songId, changeTag);
      }
    } catch (e) {
      developer.log('Error syncing chord keys: $e');
    }
  }

  static Future<void> _syncSheetMusicToCloudKit(String songId, List<Measure> measures) async {
    try {
      final record = {
        'recordType': 'SheetMusic',
        'recordName': songId,
        'measuresData': measures.map((m) => measureToJson(m)).toList(),
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('SheetMusic', songId, changeTag);
      }
    } catch (e) {
      developer.log('Error syncing sheet music: $e');
    }
  }

  static Future<void> _syncDrawingsToCloudKit(String songId, List<Map<String, dynamic>> drawingData) async {
    try {
      final record = {
        'recordType': 'Drawings',
        'recordName': songId,
        'drawingsData': drawingData,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('Drawings', songId, changeTag);
      }
    } catch (e) {
      developer.log('Error syncing drawings: $e');
    }
  }

  static Future<void> _syncPDFDrawingsToCloudKit(String songId, int pageNumber, List<PaintInfo> paintHistory) async {
    try {
      final recordName = '${songId}_page_$pageNumber';
      final record = {
        'recordType': 'PDFDrawings',
        'recordName': recordName,
        'songId': songId,
        'pageNumber': pageNumber,
        'drawingsData': paintHistory.map((p) => paintInfoToJson(p)).toList(),
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('PDFDrawings', recordName, changeTag);
      }
    } catch (e) {
      developer.log('Error syncing PDF drawings: $e');
    }
  }

  static Future<void> _syncYoutubeLinksToCloudKit(String songId, Map<String, dynamic> youtubeData) async {
    try {
      // The recordName should be a unique identifier for the link itself.
      // Assuming the youtubeData map contains a unique 'videoId'.
      final recordName = youtubeData['videoId'] as String?;
      if (recordName == null) {
        developer.log('Error syncing YouTube link: videoId is missing from youtubeData');
        return;
      }

      final record = {
        'recordType': 'YoutubeLinks',
        'recordName': recordName,
        'songId': songId, // Storing songId as a field, can be null
        'youtubeData': youtubeData,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        // Use the unique videoId for tracking the change tag
        await saveLocalChangeTag('YoutubeLinks', recordName, changeTag);
      }
    } catch (e) {
      developer.log('Error syncing YouTube links: $e');
    }
  }

  static Future<void> _syncSavedLoopsToCloudKit(String songId, List<Map<String, dynamic>> loops) async {
    try {
      final record = {
        'recordType': 'SavedLoops',
        'recordName': songId,
        'loopsData': loops,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('SavedLoops', songId, changeTag);
      }
    } catch (e) {
      developer.log('Error syncing saved loops: $e');
    }
  }

static Future<void> _syncBooksToCloudKit(List<Map<String, dynamic>> books) async {
  for (final book in books) {
    try {
      // 1. Prepare the fields for the CloudKit record.
      // Exclude the 'path' field as it will be handled as an asset.
      final recordFields = <String, String>{};
      book.forEach((key, value) {
        if (key != 'path' && key != 'id' && value != null) {
          // Convert all values to String for this example.
          // Adjust as needed for your CloudKit schema (e.g., Numbers).
          recordFields[key] = value.toString();
        }
      });

      // 2. Prepare the asset map.
      final assets = <String, CloudKitAsset>{};
      final pdfPath = book['path'] as String?;

      if (pdfPath != null && pdfPath.isNotEmpty) {
        // 'pdfFile' is the field name in your CloudKit 'Book' record type for the asset.
        assets['pdfFile'] = CloudKitAsset.forUpload(filePath: pdfPath);
      }

      // 3. Get the recordName (book ID).
      final recordName = book['id'] as String;

      // 4. Call the service to save the record with its PDF asset.
      // Assuming you are using the private database.
      await CloudKitService.saveRecordWithAssets(
        recordType: 'Book',
        recordName: recordName,
        record: recordFields,
        assets: assets,
      );

      // Note: The concept of a 'changeTag' is often handled differently for asset uploads.
      // The native CloudKit API returns a full CKRecord object on success.
      // You may need to adapt your CloudKitService or change tag logic if necessary.
      developer.log('Successfully synced book with PDF asset: $recordName');

    } catch (e) {
      developer.log('Error syncing book with PDF asset: $e');
    }
  }
}

  static Future<void> _syncCustomSongsToCloudKit(List<Map<String, dynamic>> songs) async {
    try {
      final record = {
        'recordType': 'CustomSongs',
        'recordName': 'all_custom_songs',
        'songsData': songs,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('CustomSongs', 'all_custom_songs', changeTag);
      }
    } catch (e) {
      developer.log('Error syncing custom songs: $e');
    }
  }

  static Future<void> _syncYoutubeVideosToCloudKit(List<Map<String, dynamic>> videos) async {
    try {
      final record = {
        'recordType': 'YoutubeVideos',
        'recordName': 'all_youtube_videos',
        'videosData': videos,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('YoutubeVideos', 'all_youtube_videos', changeTag);
      }
    } catch (e) {
      developer.log('Error syncing YouTube videos: $e');
    }
  }

  static Future<void> _syncLabelsToCloudKit(String songAssetPath, int page, List<dynamic> labels) async {
    try {
      final recordName = '${songAssetPath}_page_$page';
      final record = {
        'recordType': 'Labels',
        'recordName': recordName,
        'songAssetPath': songAssetPath,
        'page': page,
        'labelsData': labels.map((l) => l.toJson()).toList(),
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('Labels', recordName, changeTag);
      }
    } catch (e) {
      developer.log('Error syncing labels: $e');
    }
  }

  static Future<File> _getLabelsFile(String songAssetPath, int page) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeFilename = _getSafeFilename(songAssetPath);
    return File('${directory.path}/${safeFilename}_pdf_page_${page}_labels.json');
  }

  static String _getSafeFilename(String path) {
    return path.split('/').last.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'), '_').replaceAll(RegExp(r'_{2,}'), '_');
  }

  // =============================================================================
  // CloudKit Asset Management (Real CKAsset Implementation)
  // =============================================================================

  /// Downloads a CloudKit asset from staging area to app's permanent storage
  /// This implements the real CloudKit CKAsset flow:
  /// 1. CloudKit provides a staging area fileURL (temporary)
  /// 2. We copy/move the file from staging to permanent app storage  
  /// 3. System automatically cleans up staging area files
  /// 
  /// Returns the permanent local file path if successful, null if failed
  static Future<String?> downloadCloudKitAsset({
    required CloudKitAsset asset,
    required String localFileName,
    String? subdirectory,
  }) async {
    if (!asset.isForDownload || asset.fileURL == null) {
      developer.log('❌ Asset is not configured for download or missing fileURL');
      return null;
    }

    try {
      // Get the target directory for permanent storage
      final directory = await getApplicationDocumentsDirectory();
      final targetDir = subdirectory != null 
          ? Directory('${directory.path}/$subdirectory')
          : directory;
      
      // Create subdirectory if it doesn't exist
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      
      final permanentPath = '${targetDir.path}/$localFileName';
      
      // Check if the staging file exists and copy it to permanent storage
      final stagingFile = File(asset.fileURL!);
      
      if (await stagingFile.exists()) {
        // Copy from CloudKit staging area to permanent app storage
        await stagingFile.copy(permanentPath);
        developer.log('✅ CloudKit asset copied to permanent storage: $permanentPath');
        developer.log('📂 Staging URL was: ${asset.fileURL}');
        return permanentPath;
      } else {
        developer.log('❌ CloudKit staging file not found: ${asset.fileURL}');
        return null;
      }
    } catch (e) {
      developer.log('❌ Error downloading CloudKit asset: $e');
      return null;
    }
  }

  /// Downloads a CloudKit asset using HTTP (for remote CloudKit URLs)
  /// This handles the case where CloudKit provides HTTP URLs instead of local staging URLs
  /// Some CloudKit implementations may provide HTTP URLs for large assets
  static Future<String?> downloadCloudKitAssetFromHTTP({
    required String httpUrl,
    required String localFileName,
    String? subdirectory,
    Function(int received, int total)? onProgress,
  }) async {
    try {
      // Get the target directory for permanent storage
      final directory = await getApplicationDocumentsDirectory();
      final targetDir = subdirectory != null 
          ? Directory('${directory.path}/$subdirectory')
          : directory;
      
      // Create subdirectory if it doesn't exist
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      
      final permanentPath = '${targetDir.path}/$localFileName';
      
      // Download using HTTP client
      developer.log('🔄 Starting HTTP download from: $httpUrl');
      
      final request = http.Request('GET', Uri.parse(httpUrl));
      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        final file = File(permanentPath);
        final fileSink = file.openWrite();
        
        int downloadedBytes = 0;
        final totalBytes = streamedResponse.contentLength ?? -1;
        
        await for (final chunk in streamedResponse.stream) {
          fileSink.add(chunk);
          downloadedBytes += chunk.length;
          
          // Report progress if callback provided
          onProgress?.call(downloadedBytes, totalBytes);
        }
        
        await fileSink.close();
        
        developer.log('✅ HTTP asset downloaded successfully: $permanentPath');
        developer.log('📊 Downloaded $downloadedBytes bytes');
        return permanentPath;
      } else {
        developer.log('❌ HTTP download failed with status: ${streamedResponse.statusCode}');
        return null;
      }
    } catch (e) {
      developer.log('❌ Error downloading asset via HTTP: $e');
      return null;
    }
  }

  /// Unified asset download function that handles both staging and HTTP URLs
  /// Automatically detects the URL type and uses the appropriate download method
  static Future<String?> downloadAsset({
    required CloudKitAsset asset,
    required String localFileName,
    String? subdirectory,
    Function(int received, int total)? onProgress,
  }) async {
    if (!asset.isForDownload || asset.fileURL == null) {
      developer.log('❌ Asset is not configured for download or missing fileURL');
      return null;
    }

    // Check if it's an HTTP URL or local staging path
    if (asset.fileURL!.startsWith('http://') || asset.fileURL!.startsWith('https://')) {
      // It's an HTTP URL - use HTTP download
      return downloadCloudKitAssetFromHTTP(
        httpUrl: asset.fileURL!,
        localFileName: localFileName,
        subdirectory: subdirectory,
        onProgress: onProgress,
      );
    } else {
      // It's a local staging path - use direct copy
      return downloadCloudKitAsset(
        asset: asset,
        localFileName: localFileName,
        subdirectory: subdirectory,
      );
    }
  }

  // =============================================================================
  // Asset Staging and Lifecycle Management
  // =============================================================================

  /// Checks if a local asset file still exists
  static Future<bool> assetExists(String localPath) async {
    try {
      final file = File(localPath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Moves an asset from temporary storage to permanent app storage
  /// This is useful when you have a temporary file that you want to keep permanently
  static Future<String?> moveAssetToPermanentStorage({
    required String temporaryPath,
    required String targetFileName,
    String? subdirectory,
  }) async {
    try {
      final sourceFile = File(temporaryPath);
      if (!await sourceFile.exists()) {
        developer.log('❌ Temporary asset file not found: $temporaryPath');
        return null;
      }

      // Get target directory
      final directory = await getApplicationDocumentsDirectory();
      final targetDir = subdirectory != null 
          ? Directory('${directory.path}/$subdirectory')
          : directory;

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final targetPath = '${targetDir.path}/$targetFileName';
      
      // Move the file (this is more efficient than copy + delete)
      final targetFile = await sourceFile.rename(targetPath);
      
      developer.log('✅ Asset moved to permanent storage: ${targetFile.path}');
      return targetFile.path;
    } catch (e) {
      developer.log('❌ Error moving asset to permanent storage: $e');
      return null;
    }
  }

  /// Cleans up old cached assets based on age and app storage policies
  static Future<void> cleanupOldAssets({
    Duration maxAge = const Duration(days: 30),
    String? subdirectory,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final targetDir = subdirectory != null 
          ? Directory('${directory.path}/$subdirectory')
          : directory;

      if (!await targetDir.exists()) {
        return; // Nothing to clean up
      }

      final now = DateTime.now();
      var cleanedCount = 0;
      var totalSize = 0;

      await for (final entity in targetDir.list(recursive: false)) {
        if (entity is File) {
          final stats = await entity.stat();
          final age = now.difference(stats.modified);
          
          if (age > maxAge) {
            final fileSize = stats.size;
            await entity.delete();
            cleanedCount++;
            totalSize += fileSize;
            developer.log('🗑️ Cleaned up old asset: ${entity.path}');
          }
        }
      }

      if (cleanedCount > 0) {
        developer.log('✨ Asset cleanup completed: removed $cleanedCount files (${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB)');
      }
    } catch (e) {
      developer.log('❌ Error during asset cleanup: $e');
    }
  }

  /// Gets information about asset storage usage
  static Future<Map<String, dynamic>> getAssetStorageInfo() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      var totalFiles = 0;
      var totalSize = 0;
      final subdirectories = <String, Map<String, int>>{};

      // Common asset subdirectories
      final assetDirs = ['books', 'song_pdfs', 'assets'];

      for (final subdir in assetDirs) {
        final dir = Directory('${directory.path}/$subdir');
        if (await dir.exists()) {
          var subdirFiles = 0;
          var subdirSize = 0;

          await for (final entity in dir.list(recursive: false)) {
            if (entity is File) {
              final stats = await entity.stat();
              subdirFiles++;
              subdirSize += stats.size;
            }
          }

          subdirectories[subdir] = {
            'files': subdirFiles,
            'size': subdirSize,
          };
          totalFiles += subdirFiles;
          totalSize += subdirSize;
        }
      }

      return {
        'totalFiles': totalFiles,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / 1024 / 1024),
        'subdirectories': subdirectories,
        'lastChecked': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      developer.log('❌ Error getting asset storage info: $e');
      return {
        'error': e.toString(),
        'totalFiles': 0,
        'totalSize': 0,
        'totalSizeMB': 0.0,
        'subdirectories': <String, Map<String, int>>{},
        'lastChecked': DateTime.now().toIso8601String(),
      };
    }
  }
}