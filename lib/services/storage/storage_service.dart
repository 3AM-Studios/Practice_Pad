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
import 'package:image_painter/image_painter.dart' as image_painter;
import 'package:practice_pad/services/storage/cloudkit_service.dart';
import 'package:http/http.dart' as http;
import 'package:practice_pad/features/song_viewer/presentation/viewers/pdf_viewer/models/label_base.dart';
import 'package:practice_pad/features/song_viewer/presentation/viewers/pdf_viewer/models/extension_label.dart';
import 'package:practice_pad/features/song_viewer/presentation/viewers/pdf_viewer/models/roman_numeral_label.dart';

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
      // Use originalBookId if available (new format), otherwise fallback to recordName (old format)
      final bookId = record['originalBookId']?.toString() ?? record['recordName']?.toString() ?? '';
      final books = await loadBooks();
      final index = books.indexWhere((book) => book['id'] == bookId);
      
      // Create book data from record (excluding asset fields)
      final bookData = <String, dynamic>{
        'id': bookId,
      };
      
      // Copy all non-asset fields from the record
      record.forEach((key, value) {
        if (key != 'recordType' && key != 'recordName' && key != 'recordChangeTag' && 
            key != 'pdfFile' && key != 'fileName' && key != 'originalBookId') {
          // Convert integers to strings if needed for consistency
          bookData[key] = value is int ? value.toString() : value;
        }
      });
      
      if (index != -1) {
        // Book exists locally, update it
        books[index] = {...books[index], ...bookData};
      } else {
        // Book doesn't exist locally, create it and download asset if present
        final pdfAsset = record['pdfFile'] as CloudKitAsset? ?? record['fileName'] as CloudKitAsset?;
        
        if (pdfAsset != null) {
          // Download the PDF asset using the CloudKit asset download helper
          final fileName = '${bookId}_book.pdf';
          final localPdfPath = await downloadCloudKitAsset(
            asset: pdfAsset,
            localFileName: fileName,
            subdirectory: 'books',
          );
          
          if (localPdfPath != null) {
            bookData['path'] = localPdfPath; // Store the local path
            bookData['fileName'] = fileName;
            print('✅ Downloaded book PDF asset: $fileName to $localPdfPath');
          } else {
            print('❌ Failed to download book PDF asset for book: $bookId');
          }
        }
        
        // Add the new book
        books.add(bookData);
      }
      
      await saveBooks(books, syncToCloud: false);
    } catch (e) {
      print('Error updating book from cloud: $e');
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
            print('✅ Downloaded song PDF from CloudKit staging: $fileName');
            // You might want to trigger a reload of the PDF viewer here or 
            // notify the app that a new PDF is available
          } else {
            print('❌ Failed to download song PDF from CloudKit staging for song: $songId');
          }
        } else {
          print('ℹ️ Received song PDF record from cloud: $songId, asset: $pdfAsset');
        }
        
        // You might want to trigger a reload of the PDF viewer here or notify other parts of the app
        // that a PDF has been updated from the cloud
      }
    } catch (e) {
      print('Error updating song PDF from cloud: $e');
    }
  }

  static Future<void> saveSongPdf(String songId, String pdfPath) async {
    try {
      print('📄 Saving song PDF to CloudKit');
      print('   Song ID: $songId');
      print('   PDF Path: $pdfPath');
      
      // Verify the file exists before trying to upload
      final pdfFile = File(pdfPath);
      if (!await pdfFile.exists()) {
        throw Exception('PDF file does not exist: $pdfPath');
      }
      
      final fileSize = await pdfFile.length();
      print('   File exists: ${pdfFile.path}');
      print('   File size: $fileSize bytes');
      
      // Prepare the record fields
      final recordFields = <String, String>{
        'songId': songId,
        'lastModified': DateTime.now().toIso8601String(),
      };
      
      print('   Record fields: $recordFields');

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
      
      print('   Created asset: $pdfAsset');
      print('   Assets map: ${assets.keys.toList()}');

      // Save the record with its PDF asset
      print('   Calling CloudKitService.saveRecordWithAssets...');
      final changeTag = await CloudKitService.saveRecordWithAssets(
        recordType: 'SongPdf',
        recordName: songId,
        record: recordFields,
        assets: assets,
      );
      
      print('✅ Successfully synced song PDF to CloudKit: $songId');
      print('   Change tag: $changeTag');
    } catch (e, stackTrace) {
      print('❌ Error syncing song PDF to CloudKit: $e');
      print('   Stack trace: $stackTrace');
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
      print('Error updating practice item from cloud: $e');
    }
  }

  static Future<void> updateSheetMusicFromCloud(Map<String, dynamic> record) async {
    try {
      // Use originalSongId if available, otherwise fall back to recordName for backward compatibility
      final songId = record['originalSongId'] as String? ?? record['recordName'] as String;
      final measuresData = record['measuresData'] as List?
        ?? [];
      final measures = measuresData.map((json) => measureFromJson(json)).toList();
      await saveSheetMusicForSong(songId, measures, syncToCloud: false);
    } catch (e) {
      print('Error updating sheet music from cloud: $e');
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
      final songId = record['originalSongId'] as String? ?? record['recordName'] as String;
      final changesData = record['changesData'] as Map<String, dynamic>?
        ?? {};
      await saveSongChanges(songId, changesData, syncToCloud: false);
    } catch (e) {
      print('Error updating song changes from cloud: $e');
    }
  }

  static Future<void> updateChordKeysFromCloud(Map<String, dynamic> record) async {
    try {
      final songId = record['originalSongId'] as String? ?? record['recordName'] as String;
      final chordKeysData = json.decode(record['chordKeysData']) as Map<String, dynamic>?
        ?? {};
      await saveChordKeys(songId, chordKeysData, syncToCloud: false);
    } catch (e) {
      print('Error updating chord keys from cloud: $e');
    }
  }

  static Future<void> updateDrawingsFromCloud(Map<String, dynamic> record) async {
    try {
      final songId = record['originalSongId'] as String? ?? record['recordName'] as String;
      final drawingsData = record['drawingsData'] as List?
        ?? [];
      final drawings = List<Map<String, dynamic>>.from(drawingsData);
      await saveDrawingsForSong(songId, drawings, syncToCloud: false);
    } catch (e) {
      print('Error updating drawings from cloud: $e');
    }
  }

  static Future<void> updatePDFDrawingsFromCloud(Map<String, dynamic> record) async {
    try {
      // Parse songId and pageNumber from recordName
      // Format: PDFDrawings_{songId}_page_{pageNumber}
      final recordName = record['recordName'] as String;
      print('📝 Processing PDFDrawings record: $recordName');
      
      // Remove the "PDFDrawings_" prefix
      final withoutPrefix = recordName.replaceFirst('PDFDrawings_', '');
      
      // Find the last occurrence of "_page_" to split correctly
      final pageIndex = withoutPrefix.lastIndexOf('_page_');
      if (pageIndex == -1) {
        print('❌ Invalid PDFDrawings record name format: $recordName');
        return;
      }
      
      final extractedSongId = withoutPrefix.substring(0, pageIndex);
      final pageNumberStr = withoutPrefix.substring(pageIndex + '_page_'.length);
      final pageNumber = int.tryParse(pageNumberStr);
      
      if (pageNumber == null) {
        print('❌ Invalid page number in record name: $recordName');
        return;
      }
      
      // Transform songId to match PDF viewer's _getSafeFilename format
      // CloudKit: "assets_songs_a_lovely_way_to_spend_an_evening_musicxml"  
      // PDF viewer expects: "assets_songs_a-lovely-way-to-spend-an-evening.musicxml"
      String songId;
      if (extractedSongId.contains('_songs_')) {
        // Convert back to PDF viewer's safe filename format
        // CloudKit format: assets_songs_a_lovely_way_to_spend_an_evening_musicxml
        // Original path: assets/songs/a-lovely-way-to-spend-an-evening.musicxml
        // PDF viewer result: assets_songs_a-lovely-way-to-spend-an-evening.musicxml
        
        // Step 1: Convert underscores back to path structure
        final pathLike = extractedSongId.replaceAll('_', '/');
        // Result: assets/songs/a/lovely/way/to/spend/an/evening/musicxml
        
        // Step 2: Try to reconstruct the original filename
        // We know the pattern: assets/songs/{filename}.musicxml
        final parts = pathLike.split('/');
        if (parts.length >= 3 && parts[0] == 'assets' && parts[1] == 'songs') {
          // Take everything after assets/songs/ and reconstruct with hyphens and .musicxml
          final filenameParts = parts.sublist(2);
          final baseName = filenameParts.take(filenameParts.length - 1).join('-'); // All but 'musicxml'
          final originalFilename = '$baseName.musicxml';
          
          // Apply PDF viewer's _getSafeFilename transformation
          songId = 'assets/songs/$originalFilename'
            .replaceAll('/', '_')
            .replaceAll('\\', '_')
            .replaceAll(':', '_')
            .replaceAll('*', '_')
            .replaceAll('?', '_')
            .replaceAll('"', '_')
            .replaceAll('<', '_')
            .replaceAll('>', '_')
            .replaceAll('|', '_');
        } else {
          songId = extractedSongId; // Fallback to original
        }
      } else {
        songId = extractedSongId; // Fallback to original
      }
      
      print('   Extracted songId: $extractedSongId → Transformed: $songId, pageNumber: $pageNumber');
      
      final drawingsData = record['drawingsData'] as List?
        ?? [];
      final paintHistory = drawingsData.map((json) => paintInfoFromJson(json)).toList();
      await savePDFDrawingsForSongPage(songId, pageNumber, paintHistory, syncToCloud: false);
      
      print('✅ Successfully updated PDF drawings for $songId page $pageNumber');
    } catch (e) {
      print('❌ Error updating PDF drawings from cloud: $e');
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
      print('Error updating YouTube links from cloud: $e');
    }
  }

  static Future<void> updateSavedLoopsFromCloud(Map<String, dynamic> record) async {
    try {
      final pageId = record['originalSongId'] as String? ?? record['recordName'] as String;
      final loopsData = record['loopsData'] as List?
        ?? [];
      final loops = List<Map<String, dynamic>>.from(loopsData);
      await saveSavedLoopsForPage(pageId, loops, syncToCloud: false);
    } catch (e) {
      print('Error updating saved loops from cloud: $e');
    }
  }

  static Future<void> updateCustomSongsFromCloud(Map<String, dynamic> record) async {
    try {
      final songsData = record['songsData'] as List?
        ?? [];
      final songs = List<Map<String, dynamic>>.from(songsData);
      await saveCustomSongs(songs, syncToCloud: false);
    } catch (e) {
      print('Error updating custom songs from cloud: $e');
    }
  }

  static Future<void> updateYoutubeVideosFromCloud(Map<String, dynamic> record) async {
    try {
      print('🎥📥 YOUTUBE_VIDEOS_UPDATE_DEBUG: Received record: $record');
      
      final videosData = record['videosData'];
      print('🎥📥 YOUTUBE_VIDEOS_UPDATE_DEBUG: videosData type: ${videosData.runtimeType}');
      print('🎥📥 YOUTUBE_VIDEOS_UPDATE_DEBUG: videosData value: $videosData');
      
      List<Map<String, dynamic>> videos;
      
      if (videosData is List) {
        print('🎥📥 YOUTUBE_VIDEOS_UPDATE_DEBUG: videosData is already a List');
        videos = List<Map<String, dynamic>>.from(videosData);
      } else if (videosData is String) {
        print('🎥📥 YOUTUBE_VIDEOS_UPDATE_DEBUG: videosData is a String, attempting to decode JSON');
        try {
          final decoded = json.decode(videosData);
          if (decoded is List) {
            videos = List<Map<String, dynamic>>.from(decoded);
          } else {
            print('🎥❌ YOUTUBE_VIDEOS_UPDATE_DEBUG: Decoded data is not a List: ${decoded.runtimeType}');
            videos = [];
          }
        } catch (e) {
          print('🎥❌ YOUTUBE_VIDEOS_UPDATE_DEBUG: Failed to decode JSON string: $e');
          videos = [];
        }
      } else {
        print('🎥❌ YOUTUBE_VIDEOS_UPDATE_DEBUG: videosData is unexpected type: ${videosData.runtimeType}');
        videos = [];
      }
      
      print('🎥📥 YOUTUBE_VIDEOS_UPDATE_DEBUG: Final parsed videos count: ${videos.length}');
      if (videos.isNotEmpty) {
        print('🎥📥 YOUTUBE_VIDEOS_UPDATE_DEBUG: Sample video: ${videos.first}');
      }
      
      await saveYoutubeVideosList(videos, syncToCloud: false);
      print('🎥✅ YOUTUBE_VIDEOS_UPDATE_DEBUG: Successfully saved videos locally');
    } catch (e) {
      print('🎥❌ YOUTUBE_VIDEOS_UPDATE_DEBUG: Error updating YouTube videos from cloud: $e');
    }
  }

  static Future<void> updateLabelsFromCloud(Map<String, dynamic> record) async {
    try {
      print('🏷️📥 LABEL_DOWNLOAD_DEBUG: Receiving labels from CloudKit (DOWNLOAD scenario)');
      print('🏷️📥 LABEL_DOWNLOAD_DEBUG: Raw record keys: ${record.keys.toList()}');
      print('🏷️📥 LABEL_DOWNLOAD_DEBUG: page value type: ${record['page'].runtimeType}');
      print('🏷️📥 LABEL_DOWNLOAD_DEBUG: labelsData value type: ${record['labelsData'].runtimeType}');
      print('🏷️📥 LABEL_DOWNLOAD_DEBUG: songPath value type: ${record['songPath'] .runtimeType}');
      final songPath = record['songPath'] as String;
      
      // Handle page field - CloudKit stores it as String, convert to int
      final pageValue = record['page'];
      final page = int.parse(pageValue.toString());
      
      final labelsData = record['labelsData'];
      //print('🏷️📥 LABEL_DOWNLOAD_DEBUG: rawLabelsData type: ${rawLabelsData.runtimeType}');
      
      
      
      // Convert dynamic label data to Label objects
      final labels = <Label>[];
      for (int i = 0; i < labelsData.length; i++) {
        final labelMap = labelsData[i];
        
        try {
          
          if (labelMap != null) {
            print('🏷️📥 LABEL_DOWNLOAD_DEBUG: Label $i keys: ${labelMap.keys.toList()}');
            final labelType = labelMap['labelType'] as String?;
            
            Label? label;
            if (labelType == 'extension' || labelType == null) {
              // Handle old format without labelType (assume extension)
              label = ExtensionLabel.fromJson(labelMap);
            } else if (labelType == 'romanNumeral') {
              label = RomanNumeralLabel.fromJson(labelMap);
            }
            
            if (label != null) {
              labels.add(label);
            }
          } 
        } catch (e) {
          print('🏷️📥 LABEL_DOWNLOAD_DEBUG: Error processing label $i: $e');
        }
      }
      
      print('🏷️📥 LABEL_DOWNLOAD_DEBUG: Converted ${labels.length} labels from CloudKit data');
      print('🏷️📥 LABEL_DOWNLOAD_DEBUG: Saving to local storage with syncToCloud=false to prevent upload loop');
      
      await saveLabelsForPage(songPath, page, labels, syncToCloud: false);
      
      print('🏷️📥 LABEL_DOWNLOAD_DEBUG: Successfully downloaded and saved ${labels.length} labels from CloudKit');
    } catch (e) {
      print('🏷️📥 LABEL_DOWNLOAD_DEBUG: Error updating labels from cloud: $e');
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
            print('Unsupported paint content type: $type');
            continue;
        }

        contents.add(content);
      } catch (e) {
        print('Error deserializing paint content: $e');
        // Continue with other items even if one fails
      }
    }

    return contents;
  }

  static Future<void> savePDFDrawingsForSongPage(String songId, int pageNumber, List<image_painter.PaintInfo> paintHistory, {bool syncToCloud = true}) async {
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

  static Future<List<image_painter.PaintInfo>> loadPDFDrawingsForSongPage(String songId, int pageNumber) async {
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
      
      // If not found locally, try CloudKit with sanitized record name
      final sanitizedRecordName = _sanitizeForCloudKit(bookId);
      final cloudRecord = await CloudKitService.getRecord(sanitizedRecordName);
      if (cloudRecord != null) {
        // Convert CloudKit record to book format
        final book = <String, dynamic>{
          'id': bookId,
        };
        
        // Copy non-asset and non-internal fields
        cloudRecord.forEach((key, value) {
          if (key != 'recordChangeTag' && key != 'recordName' && key != 'recordType' && 
              key != 'pdfFile' && key != 'fileName' && key != 'originalBookId') {
            book[key] = value;
          }
        });
        
        // Handle PDF asset if present (could be either 'pdfFile' or 'fileName')
        final pdfAsset = cloudRecord['pdfFile'] as CloudKitAsset? ?? cloudRecord['fileName'] as CloudKitAsset?;
        if (pdfAsset != null) {
          // Download the PDF asset using the CloudKit asset download helper
          final fileName = '${bookId}_book.pdf';
          final localPdfPath = await downloadCloudKitAsset(
            asset: pdfAsset,
            localFileName: fileName,
            subdirectory: 'books',
          );
          
          if (localPdfPath != null) {
            book['path'] = localPdfPath; // Store the local path
            book['fileName'] = fileName;
            print('✅ Downloaded book PDF asset for single book load: $fileName to $localPdfPath');
          } else {
            print('❌ Failed to download book PDF asset for single book load: $bookId');
          }
        }
        
        return book;
      }
      
      return null;
    } catch (e) {
      print('Error loading book $bookId: $e');
      return null;
    }
  }

  /// Load all books from CloudKit
  static Future<List<Map<String, dynamic>>> loadBooksFromCloudKit() async {
    try {
      print('📚 BOOK_DEBUG: Starting loadBooksFromCloudKit');
      final cloudRecords = await CloudKitService.getAllRecords();
      print('📚 BOOK_DEBUG: Got ${cloudRecords.length} total records from CloudKit');
      final books = <Map<String, dynamic>>[];
      
      for (final record in cloudRecords) {
        if (record['recordType'] == 'Book') {
          print('📚 BOOK_DEBUG: Processing Book record: ${record['recordName']}');
          print('📚 BOOK_DEBUG: Record keys: ${record.keys.toList()}');
          print('📚 BOOK_DEBUG: Record types: ${record.map((key, value) => MapEntry(key, value.runtimeType.toString()))}');
          
          // Use originalBookId if available (new format), otherwise extract from recordName (old format)
          final bookId = record['originalBookId']?.toString() ?? 
                        record['recordName']?.toString().replaceFirst('Book_', '') ?? '';
          
          print('📚 BOOK_DEBUG: Extracted bookId: $bookId');
          
          final book = <String, dynamic>{
            'id': bookId,
          };
          
          // Copy non-asset and non-internal fields
          record.forEach((key, value) {
            if (key != 'recordChangeTag' && key != 'recordName' && key != 'recordType' && 
                key != 'pdfFile' && key != 'fileName' && key != 'originalBookId') {
              // Convert integers to strings if needed for consistency
              book[key] = value is int ? value.toString() : value;
            }
          });
          
          // Handle PDF asset if present (could be either 'pdfFile' or 'fileName')
          final pdfAsset = record['pdfFile'] as CloudKitAsset? ?? record['fileName'] as CloudKitAsset?;
          if (pdfAsset != null) {
            // Download the PDF asset using the CloudKit asset download helper
            final fileName = '${bookId}_book.pdf';
            final localPdfPath = await downloadCloudKitAsset(
              asset: pdfAsset,
              localFileName: fileName,
              subdirectory: 'books',
            );
            
            if (localPdfPath != null) {
              book['path'] = localPdfPath; // Store the local path
              book['fileName'] = fileName;
              print('✅ Downloaded book PDF asset during load: $fileName to $localPdfPath');
            } else {
              print('❌ Failed to download book PDF asset during load for book: $bookId');
            }
          }
          
          books.add(book);
        }
      }
      
      return books;
    } catch (e) {
      print('Error loading books from CloudKit: $e');
      return [];
    }
  }

  /// Load a specific song PDF by song ID
  static Future<Map<String, dynamic>?> loadSongPdf(String songId) async {
    try {
      print('🔍🔍 PDF_DEBUG_123: loadSongPdf called with songId: "$songId"');
      // Try to get from CloudKit first
      final sanitizedKey = songId.replaceAll(RegExp(r'[/\\:*?"<>|\s]'), '_');
      print('🔍🔍 PDF_DEBUG_123: Sanitized key: "$sanitizedKey"');
      final recordKey = 'SongPdf_$sanitizedKey';
      print('🔍🔍 PDF_DEBUG_123: Looking for CloudKit record: "$recordKey"');
      
      final cloudRecord = await CloudKitService.getRecord(recordKey);
      print('🔍🔍 PDF_DEBUG_123: CloudKit record result: $cloudRecord');
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
      print('Error loading song PDF $songId: $e');
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

  /// Save labels for page - accepts either our Label objects or image_painter Label objects
  static Future<void> saveLabelsForPage(String songPath, int page, List<dynamic> labels, {bool syncToCloud = true}) async {
    return _withSaveLock(() async {
      print('🏷️💾 LABEL_SAVE_DEBUG: Starting saveLabelsForPage');
      print('🏷️💾 LABEL_SAVE_DEBUG: songPath: $songPath');
      print('🏷️💾 LABEL_SAVE_DEBUG: page: $page');
      print('🏷️💾 LABEL_SAVE_DEBUG: labels count: ${labels.length}');
      print('🏷️💾 LABEL_SAVE_DEBUG: syncToCloud: $syncToCloud');
      
      final file = await _getLabelsFile(songPath, page);
      
      // Convert labels to JSON - handle both our Label objects and image_painter Label objects
      final labelsData = <Map<String, dynamic>>[];
      for (int i = 0; i < labels.length; i++) {
        final label = labels[i];
        print('🏷️💾 LABEL_SAVE_DEBUG: Processing label $i: ${label.runtimeType}');
        
        if (label is Label) {
          // Our custom Label objects
          final labelJson = label.toJson();
          labelsData.add(labelJson);
          print('🏷️💾 LABEL_SAVE_DEBUG: Added custom Label: $labelJson');
        } else if (label is image_painter.Label) {
          // image_painter Label objects - convert to our format
          final labelJson = _convertImagePainterLabelToJson(label);
          labelsData.add(labelJson);
          print('🏷️💾 LABEL_SAVE_DEBUG: Added image_painter Label: $labelJson');
        } else {
          print('🏷️💾 LABEL_SAVE_DEBUG: Unknown label type: ${label.runtimeType}');
        }
      }
      
      print('🏷️💾 LABEL_SAVE_DEBUG: Final labelsData count: ${labelsData.length}');
      
      await file.writeAsString(json.encode(labelsData));
      if (syncToCloud) {
        print('🏷️☁️ LABEL_SYNC_DEBUG: Preparing to sync to CloudKit');
        
        // CRITICAL: Prevent local data from overwriting more complete CloudKit data
        try {
          final existingCloudData = await _checkCloudKitForExistingLabels(songPath, page);
          
          if (labels.isEmpty && existingCloudData > 0) {
            print('🏷️🛡️ LABEL_PROTECTION: Local labels are empty but CloudKit has $existingCloudData labels');
            print('🏷️🛡️ LABEL_PROTECTION: BLOCKING empty sync to prevent data loss!');
            print('🏷️🛡️ LABEL_PROTECTION: This prevents empty local state from overwriting valuable CloudKit data');
            return; // Exit early, don't sync empty data over existing CloudKit data
          } else if (labels.length < existingCloudData && existingCloudData > 5) {
            // Also prevent syncing significantly fewer labels over many labels (possible partial load)
            print('🏷️🛡️ LABEL_PROTECTION: Local has ${labels.length} labels but CloudKit has $existingCloudData labels');
            print('🏷️🛡️ LABEL_PROTECTION: BLOCKING potentially incomplete sync to prevent data loss!');
            print('🏷️🛡️ LABEL_PROTECTION: This prevents partial local state from overwriting more complete CloudKit data');
            return; // Exit early to prevent data loss
          } else if (existingCloudData == 0) {
            print('🏷️🛡️ LABEL_PROTECTION: CloudKit is empty - allowing local sync (${labels.length} labels)');
          } else {
            print('🏷️🛡️ LABEL_PROTECTION: Local has ${labels.length} labels, CloudKit has $existingCloudData - allowing sync');
          }
        } catch (e) {
          print('🏷️🛡️ LABEL_PROTECTION: Could not check CloudKit data: $e - allowing sync to proceed');
          // If we can't check CloudKit, allow the sync to proceed to avoid blocking legitimate operations
        }
        
        // Convert to our Label objects for CloudKit sync - only convert image_painter labels
        final imagePainterLabels = <image_painter.Label>[];
        final ourLabels = <Label>[];
        
        for (int i = 0; i < labels.length; i++) {
          final label = labels[i];
          if (label is Label) {
            // Already our custom Label objects
            ourLabels.add(label);
            print('🏷️☁️ LABEL_SYNC_DEBUG: Added custom Label $i to sync list');
          } else if (label is image_painter.Label) {
            // Convert image_painter Label objects
            imagePainterLabels.add(label);
            print('🏷️☁️ LABEL_SYNC_DEBUG: Added image_painter Label $i to conversion list');
          }
        }
        
        // Convert image_painter labels to our format
        if (imagePainterLabels.isNotEmpty) {
          final converted = _convertImagePainterLabelsToOurLabels(imagePainterLabels);
          ourLabels.addAll(converted);
          print('🏷️☁️ LABEL_SYNC_DEBUG: Converted ${imagePainterLabels.length} image_painter labels to ${converted.length} custom labels');
        }
        
        print('🏷️☁️ LABEL_SYNC_DEBUG: Total labels for CloudKit sync: ${ourLabels.length}');
        
        // Validate labels before syncing
        if (ourLabels.isEmpty) {
          print('🏷️⚠️ LABEL_VALIDATION_WARNING: No labels to sync to CloudKit');
        } else {
          // Validate each label has required data
          bool allLabelsValid = true;
          for (int i = 0; i < ourLabels.length; i++) {
            final label = ourLabels[i];
            try {
              final testJson = label.toJson();
              if (testJson['id'] == null || testJson['position'] == null) {
                print('🏷️❌ LABEL_VALIDATION_ERROR: Label $i missing required fields: $testJson');
                allLabelsValid = false;
              }
            } catch (e) {
              print('🏷️❌ LABEL_VALIDATION_ERROR: Label $i failed toJson: $e');
              allLabelsValid = false;
            }
          }
          
          if (allLabelsValid) {
            print('🏷️✅ LABEL_VALIDATION_SUCCESS: All labels are valid for CloudKit sync');
          } else {
            print('🏷️❌ LABEL_VALIDATION_FAILED: Some labels are invalid, but proceeding with sync');
          }
        }
        
        await _syncLabelsToCloudKit(songPath, page, ourLabels);
      } else {
        print('🏷️💾 LABEL_SAVE_DEBUG: Skipping CloudKit sync (syncToCloud = false)');
      }
    });
  }

  /// Convert image_painter Label to our JSON format
  static Map<String, dynamic> _convertImagePainterLabelToJson(image_painter.Label imagePainterLabel) {
    if (imagePainterLabel is image_painter.ExtensionLabel) {
      return {
        'id': imagePainterLabel.id,
        'position': {'dx': imagePainterLabel.position.dx, 'dy': imagePainterLabel.position.dy},
        'displayValue': imagePainterLabel.number,
        'size': 25.0,
        'color': 0xFF2196F3,
        'labelType': 'extension',
        'isSelected': false,
        'accidental': '♮', // Default for image_painter labels
        'number': imagePainterLabel.number,
      };
    } else if (imagePainterLabel is image_painter.RomanNumeralLabel) {
      return {
        'id': imagePainterLabel.id,
        'position': {'dx': imagePainterLabel.position.dx, 'dy': imagePainterLabel.position.dy},
        'displayValue': imagePainterLabel.romanNumeral,
        'size': 25.0,
        'color': 0xFF2196F3,
        'labelType': 'romanNumeral',
        'isSelected': false,
        'romanNumeral': imagePainterLabel.romanNumeral,
      };
    }
    // Fallback
    return {
      'id': imagePainterLabel.id,
      'position': {'dx': imagePainterLabel.position.dx, 'dy': imagePainterLabel.position.dy},
      'displayValue': '1',
      'size': 25.0,
      'color': 0xFF2196F3,
      'labelType': 'extension',
      'isSelected': false,
      'accidental': '♮',
      'number': '1',
    };
  }

  /// Convert image_painter Labels to our Label objects
  static List<Label> _convertImagePainterLabelsToOurLabels(List<image_painter.Label> imagePainterLabels) {
    final ourLabels = <Label>[];
    for (final imagePainterLabel in imagePainterLabels) {
      if (imagePainterLabel is image_painter.ExtensionLabel) {
        ourLabels.add(ExtensionLabel(
          id: imagePainterLabel.id,
          position: imagePainterLabel.position,
          accidental: '♮', // Default
          number: imagePainterLabel.number,
        ));
      } else if (imagePainterLabel is image_painter.RomanNumeralLabel) {
        ourLabels.add(RomanNumeralLabel(
          id: imagePainterLabel.id,
          position: imagePainterLabel.position,
          romanNumeral: imagePainterLabel.romanNumeral,
        ));
      }
    }
    return ourLabels;
  }

  static Future<List<dynamic>> loadLabelsForPage(String songPath, int page) async {
    try {
      final file = await _getLabelsFile(songPath, page);
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

  static Map<String, dynamic> paintInfoToJson(image_painter.PaintInfo paintInfo) {
    return {
      'mode': paintInfo.mode.toString(),
      'color': paintInfo.color.value,
      'strokeWidth': paintInfo.strokeWidth,
      'offsets': paintInfo.offsets.map((offset) => offset != null ? {'dx': offset.dx, 'dy': offset.dy} : null).toList(),
      'text': paintInfo.text,
      'fill': paintInfo.fill,
    };
  }

  static image_painter.PaintInfo paintInfoFromJson(Map<String, dynamic> json) {
    final modeString = json['mode'] as String;
    final mode = image_painter.PaintMode.values.firstWhere((e) => e.toString() == modeString, orElse: () => image_painter.PaintMode.freeStyle);
    final colorValue = json['color'] as int;
    final color = Color(colorValue);
    final offsetsData = json['offsets'] as List;
    final offsets = offsetsData.map((offsetJson) {
      if (offsetJson == null) return null;
      final offsetMap = offsetJson as Map<String, dynamic>;
      return Offset(offsetMap['dx'] as double, offsetMap['dy'] as double);
    }).toList();
    return image_painter.PaintInfo(
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
      print('Error syncing practice area: $e');
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
      print('Error syncing practice item: $e');
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
      print('Error syncing weekly schedule: $e');
    }
  }

  static Future<void> _syncSongChangesToCloudKit(String songId, Map<String, dynamic> changes) async {
    try {
      final sanitizedRecordName = _sanitizeForCloudKit(songId);
      final record = {
        'recordType': 'SongChanges',
        'recordName': sanitizedRecordName,
        'originalSongId': songId,
        'changesData': changes,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('SongChanges', sanitizedRecordName, changeTag);
      }
    } catch (e) {
      print('Error syncing song changes: $e');
    }
  }

  static Future<void> _syncChordKeysToCloudKit(String songId, Map<String, dynamic> chordKeys) async {
    try {
      final sanitizedRecordName = _sanitizeForCloudKit(songId);
      final record = {
        'recordType': 'ChordKeys',
        'recordName': sanitizedRecordName,
        'originalSongId': songId,
        'chordKeysData': chordKeys,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('ChordKeys', sanitizedRecordName, changeTag);
      }
    } catch (e) {
      print('Error syncing chord keys: $e');
    }
  }

  static Future<void> _syncSheetMusicToCloudKit(String songId, List<Measure> measures) async {
    try {
      final sanitizedRecordName = _sanitizeForCloudKit(songId);
      final record = {
        'recordType': 'SheetMusic',
        'recordName': sanitizedRecordName,
        'originalSongId': songId, // Store original for retrieval
        'measuresData': measures.map((m) => measureToJson(m)).toList(),
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('SheetMusic', sanitizedRecordName, changeTag);
      }
    } catch (e) {
      print('Error syncing sheet music: $e');
    }
  }

  static Future<void> _syncDrawingsToCloudKit(String songId, List<Map<String, dynamic>> drawingData) async {
    try {
      final sanitizedRecordName = _sanitizeForCloudKit(songId);
      final record = {
        'recordType': 'Drawings',
        'recordName': sanitizedRecordName,
        'originalSongId': songId,
        'drawingsData': drawingData,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('Drawings', sanitizedRecordName, changeTag);
      }
    } catch (e) {
      print('Error syncing drawings: $e');
    }
  }

  static Future<void> _syncPDFDrawingsToCloudKit(String songId, int pageNumber, List<image_painter.PaintInfo> paintHistory) async {
    try {
      final originalRecordName = '${songId}_page_$pageNumber';
      final recordName = _sanitizeForCloudKit(originalRecordName);
      
      final drawingsData = paintHistory.map((p) => paintInfoToJson(p)).toList();
      
      final record = {
        'recordType': 'PDFDrawings',
        'recordName': recordName,
        'originalRecordName': originalRecordName,
        'songId': songId,
        'pageNumber': pageNumber,
        'drawingsData': drawingsData,
      };
      
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('PDFDrawings', recordName, changeTag);
      }
    } catch (e) {
      print('Error syncing PDF drawings: $e');
    }
  }

  static Future<void> _syncYoutubeLinksToCloudKit(String songId, Map<String, dynamic> youtubeData) async {
    try {
      // Try to get videoId from youtubeData, or extract from URL if missing
      String? originalVideoId = youtubeData['videoId'] as String?;
      
      // If videoId is missing or empty, try to extract from URL
      if (originalVideoId == null || originalVideoId.isEmpty) {
        final url = youtubeData['url'] as String?;
        if (url != null && url.isNotEmpty) {
          originalVideoId = _extractVideoIdFromUrl(url);
          if (originalVideoId != null) {
            print('YouTube link: Extracted videoId from URL: $originalVideoId');
          } else {
            // Fallback to using songId if URL parsing fails
            originalVideoId = 'song_${_sanitizeForCloudKit(songId)}';
            print('YouTube link: Could not extract videoId from URL, using fallback: $originalVideoId');
          }
        } else {
          print('Error syncing YouTube link: both videoId and url are missing from youtubeData');
          return;
        }
      }

      // Sanitize the video ID for CloudKit (YouTube IDs can contain hyphens)
      final sanitizedRecordName = _sanitizeForCloudKit(originalVideoId);

      final record = {
        'recordType': 'YoutubeLinks',
        'recordName': sanitizedRecordName,
        'originalVideoId': originalVideoId, // Store original video ID
        'songId': songId, // Storing songId as a field, can be null
        'youtubeData': youtubeData,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        // Use the sanitized recordName for tracking the change tag
        await saveLocalChangeTag('YoutubeLinks', sanitizedRecordName, changeTag);
      }
    } catch (e) {
      print('Error syncing YouTube links: $e');
    }
  }

  static Future<void> _syncSavedLoopsToCloudKit(String songId, List<Map<String, dynamic>> loops) async {
    try {
      final sanitizedRecordName = _sanitizeForCloudKit(songId);
      final record = {
        'recordType': 'SavedLoops',
        'recordName': sanitizedRecordName,
        'originalSongId': songId,
        'loopsData': loops,
      };
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('SavedLoops', sanitizedRecordName, changeTag);
      }
    } catch (e) {
      print('Error syncing saved loops: $e');
    }
  }

static Future<void> _syncBooksToCloudKit(List<Map<String, dynamic>> books) async {
  for (final book in books) {
    try {
      print('📚 Syncing book to CloudKit');
      // Get the original book ID and sanitize it for CloudKit
      final originalBookId = book['id'] as String;
      final sanitizedRecordName = _sanitizeForCloudKit(originalBookId);
      print('   Book ID: $originalBookId');
      print('   Record Name: $sanitizedRecordName');
      
      // 1. Prepare the fields for the CloudKit record.
      // Exclude the 'path' field as it will be handled as an asset.
      final recordFields = <String, String>{};
      book.forEach((key, value) {
        if (key != 'path' && key != 'id' && value != null) {
          // Convert all values to String for CloudKit
          recordFields[key] = value.toString();
        }
      });
      
      // Add the original book ID for retrieval
      recordFields['originalBookId'] = originalBookId;
      print('   Record fields: $recordFields');

      // 2. Prepare the asset map.
      final assets = <String, CloudKitAsset>{};
      final pdfPath = book['path'] as String?;
      print('   PDF Path: $pdfPath');

      if (pdfPath != null && pdfPath.isNotEmpty) {
        // Verify the file exists before trying to upload
        final pdfFile = File(pdfPath);
        if (await pdfFile.exists()) {
          final fileSize = await pdfFile.length();
          // Create CloudKitAsset with full parameters like SongPdf does
          assets['pdfFile'] = CloudKitAsset.forUpload(
            filePath: pdfPath,
            fileName: pdfPath.split('/').last,
            size: fileSize,
            mimeType: 'application/pdf',
          );
          print('📚 Book asset prepared: ${pdfPath.split('/').last} (${fileSize} bytes)');
        } else {
          print('❌ Book PDF file not found: $pdfPath');
        }
      }

      print('   Assets map: ${assets.keys.toList()}');

      // 3. Call the service to save the record with its PDF asset.
      print('   Calling CloudKitService.saveRecordWithAssets...');
      final changeTag = await CloudKitService.saveRecordWithAssets(
        recordType: 'Book',
        recordName: sanitizedRecordName,
        record: recordFields,
        assets: assets,
      );

      // Save local change tag for sync tracking
      if (changeTag != null) {
        await saveLocalChangeTag('Book', sanitizedRecordName, changeTag);
      }

      print('✅ Successfully synced book with PDF asset: $sanitizedRecordName (original: $originalBookId)');
      print('   Change tag: $changeTag');

    } catch (e, stackTrace) {
      print('❌ Error syncing book with PDF asset: $e');
      print('   Stack trace: $stackTrace');
      rethrow;
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
      print('Error syncing custom songs: $e');
    }
  }

  static Future<void> _syncYoutubeVideosToCloudKit(List<Map<String, dynamic>> videos) async {
    try {
      print('🎥📤 YOUTUBE_VIDEOS_SYNC_DEBUG: Syncing ${videos.length} videos to CloudKit');
      print('🎥📤 YOUTUBE_VIDEOS_SYNC_DEBUG: Sample video data: ${videos.isNotEmpty ? videos.first : 'none'}');
      
      final record = {
        'recordType': 'YoutubeVideos',
        'recordName': 'all_youtube_videos',
        'videosData': videos,
      };
      
      print('🎥📤 YOUTUBE_VIDEOS_SYNC_DEBUG: Record to save: $record');
      
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('YoutubeVideos', 'all_youtube_videos', changeTag);
        print('🎥📤 YOUTUBE_VIDEOS_SYNC_DEBUG: Successfully saved with change tag: $changeTag');
      }
    } catch (e) {
      print('🎥❌ YOUTUBE_VIDEOS_SYNC_DEBUG: Error syncing YouTube videos: $e');
    }
  }

  static Future<void> _syncLabelsToCloudKit(String songPath, int page, List<Label> labels) async {
    try {
      print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: Starting CloudKit sync');
      print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: songPath: $songPath');
      print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: page: $page');
      print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: labels count: ${labels.length}');
      
      final originalRecordName = '${songPath}_page_$page';
      final sanitizedRecordName = _sanitizeForCloudKit(originalRecordName);
      
      print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: originalRecordName: $originalRecordName');
      print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: sanitizedRecordName: $sanitizedRecordName');
      
      // Convert labels to JSON and log each one
      final labelsDataForCloudKit = <Map<String, dynamic>>[];
      for (int i = 0; i < labels.length; i++) {
        final labelJson = labels[i].toJson();
        labelsDataForCloudKit.add(labelJson);
        print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: Label $i JSON: $labelJson');
      }
      
      print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: Total labelsDataForCloudKit: ${labelsDataForCloudKit.length} items');
      
      final record = {
        'recordType': 'Labels',
        'recordName': sanitizedRecordName,
        'originalRecordName': originalRecordName, // Store original record name
        'songPath': songPath,
        'page': page,
        'labelsData': labelsDataForCloudKit,
      };
      
      print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: Complete record being sent to CloudKit: $record');
      
      final changeTag = await CloudKitService.saveRecord(record);
      if (changeTag != null) {
        await saveLocalChangeTag('Labels', sanitizedRecordName, changeTag);
        print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: Successfully synced to CloudKit with changeTag: $changeTag');
      } else {
        print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: CloudKit sync failed - no changeTag returned');
      }
    } catch (e) {
      print('🏷️☁️ CLOUDKIT_SYNC_DEBUG: Error syncing labels: $e');
    }
  }

  static Future<File> _getLabelsFile(String songPath, int page) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeFilename = _getSafeFilename(songPath);
    return File('${directory.path}/${safeFilename}_pdf_page_${page}_labels.json');
  }

  static String _getSafeFilename(String path) {
    return path.split('/').last.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'), '_').replaceAll(RegExp(r'_{2,}'), '_');
  }

  /// Check if CloudKit has existing label data for a song page to prevent accidental overwrites
  /// Returns the number of labels found in CloudKit, or 0 if none/error
  static Future<int> _checkCloudKitForExistingLabels(String songPath, int page) async {
    try {
      final originalRecordName = '${songPath}_page_$page';
      final sanitizedRecordName = _sanitizeForCloudKit(originalRecordName);
      
      print('🏷️🔍 LABEL_CHECK_DEBUG: Checking CloudKit for existing labels');
      print('🏷️🔍 LABEL_CHECK_DEBUG: sanitizedRecordName: $sanitizedRecordName');
      
      // CloudKit records are stored with recordType prefix, so construct full record key
      final fullRecordKey = 'Labels_$sanitizedRecordName';
      print('🏷️🔍 LABEL_CHECK_DEBUG: fullRecordKey: $fullRecordKey');
      
      // Try to fetch the record from CloudKit using the full record key
      final cloudKitRecord = await CloudKitService.getRecord(fullRecordKey);
      
      if (cloudKitRecord != null) {
        final labelsData = cloudKitRecord['labelsData'] as List? ?? [];
        print('🏷️🔍 LABEL_CHECK_DEBUG: Found CloudKit record with ${labelsData.length} labels');
        return labelsData.length;
      } else {
        print('🏷️🔍 LABEL_CHECK_DEBUG: No CloudKit record found');
        return 0;
      }
    } catch (e) {
      print('🏷️🔍 LABEL_CHECK_DEBUG: Error checking CloudKit: $e');
      return 0; // Return 0 on error to allow sync (fail-safe)
    }
  }

  /// Sanitize record names for CloudKit compatibility
  /// Converts invalid CloudKit characters to underscores
  static String _sanitizeForCloudKit(String recordName) {
    return recordName.replaceAll(RegExp(r'[/\:*?"<>| .\-]'), '_');
  }

  /// Extracts YouTube video ID from a YouTube URL
  static String? _extractVideoIdFromUrl(String url) {
    if (url.isEmpty) return null;
    
    // Remove whitespace
    url = url.trim();
    
    // Handle different YouTube URL formats
    final RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    
    final match = regExp.firstMatch(url);
    return match?.group(1);
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
    if (asset.fileURL == null) {
      print('❌ Asset is not configured for download or missing fileURL');
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
      String filePath = asset.fileURL!;
      if (filePath.startsWith('file://')) {
        filePath = filePath.substring(7); // Remove 'file://' prefix
      }
      final stagingFile = File(filePath);
      
      if (await stagingFile.exists()) {
        // Copy from CloudKit staging area to permanent app storage
        await stagingFile.copy(permanentPath);
        print('✅ CloudKit asset copied to permanent storage: $permanentPath');
        print('📂 Staging URL was: ${asset.fileURL}');
        return permanentPath;
      } else {
        print('❌ CloudKit staging file not found: ${asset.fileURL}');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading CloudKit asset: $e');
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
      print('🔄 Starting HTTP download from: $httpUrl');
      
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
        
        print('✅ HTTP asset downloaded successfully: $permanentPath');
        print('📊 Downloaded $downloadedBytes bytes');
        return permanentPath;
      } else {
        print('❌ HTTP download failed with status: ${streamedResponse.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading asset via HTTP: $e');
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
    if (asset.fileURL == null) {
      print('❌ Asset missing fileURL');
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
        print('❌ Temporary asset file not found: $temporaryPath');
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
      
      print('✅ Asset moved to permanent storage: ${targetFile.path}');
      return targetFile.path;
    } catch (e) {
      print('❌ Error moving asset to permanent storage: $e');
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
            print('🗑️ Cleaned up old asset: ${entity.path}');
          }
        }
      }

      if (cleanedCount > 0) {
        print('✨ Asset cleanup completed: removed $cleanedCount files (${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB)');
      }
    } catch (e) {
      print('❌ Error during asset cleanup: $e');
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
      print('❌ Error getting asset storage info: $e');
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