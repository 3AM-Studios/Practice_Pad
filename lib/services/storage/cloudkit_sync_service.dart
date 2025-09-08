import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/practice_session.dart';
import 'package:practice_pad/models/chord_progression.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';

/// Comprehensive CloudKit sync service for all app data
class CloudKitSyncService {
  static const MethodChannel _channel = MethodChannel('practice_pad_cloudkit');
  
  static CloudKitSyncService? _instance;
  
  // Record type constants matching iOS
  static const _recordTypes = {
    'weeklySchedule': 'WeeklySchedule',
    'practiceArea': 'PracticeArea',
    'practiceItem': 'PracticeItem',
    'practiceSession': 'PracticeSession',
    'songChanges': 'SongChanges',
    'chordKeys': 'ChordKeys',
    'sheetMusic': 'SheetMusic',
    'songDrawings': 'SongDrawings',
    'pdfDrawings': 'PDFDrawings',
    'youtubeLinks': 'YouTubeLinks',
    'savedLoops': 'SavedLoops',
    'youtubeVideos': 'YouTubeVideos',
    'books': 'Books',
    'customSongs': 'CustomSongs',
    'pdfLabels': 'PDFLabels',
  };

  CloudKitSyncService._();

  static CloudKitSyncService get instance {
    _instance ??= CloudKitSyncService._();
    return _instance!;
  }

  // MARK: - Account Status
  
  /// Check CloudKit account availability
  Future<CloudKitAccountStatus> checkAccountStatus() async {
    try {
      final result = await _channel.invokeMethod('checkAccountStatus');
      final status = result['status'] as String;
      
      switch (status) {
        case 'available':
          return CloudKitAccountStatus.available;
        case 'noAccount':
          return CloudKitAccountStatus.noAccount;
        case 'restricted':
          return CloudKitAccountStatus.restricted;
        case 'couldNotDetermine':
          return CloudKitAccountStatus.couldNotDetermine;
        case 'temporarilyUnavailable':
          return CloudKitAccountStatus.temporarilyUnavailable;
        default:
          return CloudKitAccountStatus.unknown;
      }
    } catch (e) {
      developer.log('Error checking CloudKit account status: $e');
      return CloudKitAccountStatus.unknown;
    }
  }

  /// Check if CloudKit is available for sync
  Future<bool> isAvailable() async {
    final status = await checkAccountStatus();
    return status == CloudKitAccountStatus.available;
  }

  // MARK: - Generic Record Operations

  /// Save a record to CloudKit
  Future<Map<String, dynamic>?> saveRecord({
    required String recordType,
    String? recordID,
    required Map<String, dynamic> fields,
  }) async {
    try {
      developer.log('💾 [CLOUDKIT] Saving $recordType record');
      
      final args = {
        'recordType': recordType,
        'fields': fields,
      };
      
      if (recordID != null) {
        args['recordID'] = recordID;
      }

      final result = await _channel.invokeMethod('saveRecord', args);
      developer.log('✅ [CLOUDKIT] Record saved successfully');
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      developer.log('❌ [CLOUDKIT] Save failed: $e');
      rethrow;
    }
  }

  /// Fetch a single record by ID
  Future<Map<String, dynamic>?> fetchRecord(String recordID) async {
    try {
      developer.log('📥 [CLOUDKIT] Fetching record: $recordID');
      
      final result = await _channel.invokeMethod('fetchRecord', {
        'recordID': recordID,
      });
      
      if (result == null) {
        developer.log('⚠️ [CLOUDKIT] Record not found: $recordID');
        return null;
      }
      
      developer.log('✅ [CLOUDKIT] Record fetched successfully');
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      developer.log('❌ [CLOUDKIT] Fetch failed: $e');
      rethrow;
    }
  }

  /// Fetch all records of a specific type
  Future<List<Map<String, dynamic>>> fetchRecordsByType(String recordType) async {
    try {
      developer.log('📥 [CLOUDKIT] Fetching records of type: $recordType');
      
      final result = await _channel.invokeMethod('fetchRecordsByType', {
        'recordType': recordType,
      });
      
      final records = (result as List).cast<Map<dynamic, dynamic>>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      
      developer.log('✅ [CLOUDKIT] Fetched ${records.length} records');
      return records;
    } catch (e) {
      developer.log('❌ [CLOUDKIT] Fetch records failed: $e');
      rethrow;
    }
  }

  /// Delete a record
  Future<bool> deleteRecord(String recordID) async {
    try {
      developer.log('🗑️ [CLOUDKIT] Deleting record: $recordID');
      
      await _channel.invokeMethod('deleteRecord', {
        'recordID': recordID,
      });
      
      developer.log('✅ [CLOUDKIT] Record deleted successfully');
      return true;
    } catch (e) {
      developer.log('❌ [CLOUDKIT] Delete failed: $e');
      rethrow;
    }
  }

  /// Fetch all records from all types
  Future<Map<String, List<Map<String, dynamic>>>> fetchAllRecords() async {
    try {
      developer.log('📥 [CLOUDKIT] Fetching all records');
      
      final result = await _channel.invokeMethod('fetchAllRecords');
      final allRecords = Map<String, dynamic>.from(result as Map);
      
      // Convert to proper type structure
      final typedRecords = <String, List<Map<String, dynamic>>>{};
      for (final entry in allRecords.entries) {
        final recordType = entry.key;
        final records = (entry.value as List).cast<Map<dynamic, dynamic>>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        typedRecords[recordType] = records;
      }
      
      developer.log('✅ [CLOUDKIT] Fetched all records from ${typedRecords.length} types');
      return typedRecords;
    } catch (e) {
      developer.log('❌ [CLOUDKIT] Fetch all records failed: $e');
      rethrow;
    }
  }

  // MARK: - Specific Data Type Operations

  /// Save weekly schedule
  Future<bool> saveWeeklySchedule(Map<String, List<String>> schedule) async {
    try {
      await saveRecord(
        recordType: _recordTypes['weeklySchedule']!,
        recordID: 'weekly_schedule',
        fields: {
          'scheduleData': json.encode(schedule),
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save weekly schedule: $e');
      return false;
    }
  }

  /// Load weekly schedule
  Future<Map<String, List<String>>> loadWeeklySchedule() async {
    try {
      final record = await fetchRecord('weekly_schedule');
      if (record == null) return {};
      
      final scheduleData = record['scheduleData'] as String?;
      if (scheduleData == null) return {};
      
      final decoded = json.decode(scheduleData) as Map<String, dynamic>;
      return decoded.map((key, value) => 
          MapEntry(key, List<String>.from(value as List)));
    } catch (e) {
      developer.log('Failed to load weekly schedule: $e');
      return {};
    }
  }

  /// Save practice area
  Future<PracticeArea?> savePracticeArea(PracticeArea area) async {
    try {
      final result = await saveRecord(
        recordType: _recordTypes['practiceArea']!,
        recordID: area.recordName.isEmpty ? null : area.recordName,
        fields: area.toCloudKitFields(),
      );
      
      if (result != null) {
        return PracticeAreaCloudKit.fromCloudKitRecord(result);
      }
      return null;
    } catch (e) {
      developer.log('Failed to save practice area: $e');
      rethrow;
    }
  }

  /// Load all practice areas
  Future<List<PracticeArea>> loadPracticeAreas() async {
    try {
      final records = await fetchRecordsByType(_recordTypes['practiceArea']!);
      return records.map((record) => PracticeAreaCloudKit.fromCloudKitRecord(record)).toList();
    } catch (e) {
      developer.log('Failed to load practice areas: $e');
      return [];
    }
  }

  /// Save practice item
  Future<PracticeItem?> savePracticeItem(PracticeItem item, String practiceAreaRecordName) async {
    try {
      final fields = item.toCloudKitFields();
      fields['practiceAreaRef'] = practiceAreaRecordName;
      
      final result = await saveRecord(
        recordType: _recordTypes['practiceItem']!,
        recordID: item.id,
        fields: fields,
      );
      
      if (result != null) {
        return PracticeItemCloudKit.fromCloudKitRecord(result);
      }
      return null;
    } catch (e) {
      developer.log('Failed to save practice item: $e');
      rethrow;
    }
  }

  /// Load practice items for a specific area
  Future<List<PracticeItem>> loadPracticeItemsForArea(String areaRecordName) async {
    try {
      final allItems = await fetchRecordsByType(_recordTypes['practiceItem']!);
      final filteredItems = allItems.where((record) => 
          record['practiceAreaRef'] == areaRecordName).toList();
      
      return filteredItems.map((record) => PracticeItemCloudKit.fromCloudKitRecord(record)).toList();
    } catch (e) {
      developer.log('Failed to load practice items for area: $e');
      return [];
    }
  }

  /// Save practice session
  Future<bool> savePracticeSession(PracticeSession session) async {
    try {
      await saveRecord(
        recordType: _recordTypes['practiceSession']!,
        fields: session.toCloudKitFields(),
      );
      return true;
    } catch (e) {
      developer.log('Failed to save practice session: $e');
      return false;
    }
  }

  /// Save song changes
  Future<bool> saveSongChanges(Map<String, Map<String, dynamic>> allChanges) async {
    try {
      await saveRecord(
        recordType: _recordTypes['songChanges']!,
        recordID: 'song_changes',
        fields: {
          'allChangesData': json.encode(allChanges),
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save song changes: $e');
      return false;
    }
  }

  /// Load song changes
  Future<Map<String, Map<String, dynamic>>> loadSongChanges() async {
    try {
      final record = await fetchRecord('song_changes');
      if (record == null) return {};
      
      final changesData = record['allChangesData'] as String?;
      if (changesData == null) return {};
      
      final decoded = json.decode(changesData) as Map<String, dynamic>;
      return decoded.map((key, value) => 
          MapEntry(key, Map<String, dynamic>.from(value as Map)));
    } catch (e) {
      developer.log('Failed to load song changes: $e');
      return {};
    }
  }

  /// Save chord keys
  Future<bool> saveChordKeys(Map<String, Map<String, dynamic>> allChordKeys) async {
    try {
      await saveRecord(
        recordType: _recordTypes['chordKeys']!,
        recordID: 'chord_keys',
        fields: {
          'allChordKeysData': json.encode(allChordKeys),
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save chord keys: $e');
      return false;
    }
  }

  /// Load chord keys
  Future<Map<String, Map<String, dynamic>>> loadChordKeys() async {
    try {
      final record = await fetchRecord('chord_keys');
      if (record == null) return {};
      
      final keysData = record['allChordKeysData'] as String?;
      if (keysData == null) return {};
      
      final decoded = json.decode(keysData) as Map<String, dynamic>;
      return decoded.map((key, value) => 
          MapEntry(key, Map<String, dynamic>.from(value as Map)));
    } catch (e) {
      developer.log('Failed to load chord keys: $e');
      return {};
    }
  }

  /// Save sheet music data
  Future<bool> saveSheetMusic(Map<String, List<dynamic>> allSheetMusic) async {
    try {
      await saveRecord(
        recordType: _recordTypes['sheetMusic']!,
        recordID: 'sheet_music',
        fields: {
          'allSheetMusicData': json.encode(allSheetMusic),
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save sheet music: $e');
      return false;
    }
  }

  /// Load sheet music data
  Future<Map<String, List<dynamic>>> loadSheetMusic() async {
    try {
      final record = await fetchRecord('sheet_music');
      if (record == null) return {};
      
      final musicData = record['allSheetMusicData'] as String?;
      if (musicData == null) return {};
      
      final decoded = json.decode(musicData) as Map<String, dynamic>;
      return decoded.map((key, value) => 
          MapEntry(key, List<dynamic>.from(value as List)));
    } catch (e) {
      developer.log('Failed to load sheet music: $e');
      return {};
    }
  }

  /// Save song drawings
  Future<bool> saveSongDrawings(String songId, Map<String, dynamic> drawingData) async {
    try {
      await saveRecord(
        recordType: _recordTypes['songDrawings']!,
        recordID: '${songId}_drawings',
        fields: {
          'songId': songId,
          'drawingData': json.encode(drawingData),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'version': 1,
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save song drawings: $e');
      return false;
    }
  }

  /// Load song drawings
  Future<Map<String, dynamic>> loadSongDrawings(String songId) async {
    try {
      final record = await fetchRecord('${songId}_drawings');
      if (record == null) return {};
      
      final drawingData = record['drawingData'] as String?;
      if (drawingData == null) return {};
      
      return Map<String, dynamic>.from(json.decode(drawingData) as Map);
    } catch (e) {
      developer.log('Failed to load song drawings: $e');
      return {};
    }
  }

  /// Save PDF drawings for a song page
  Future<bool> savePDFDrawings(String songId, int pageNumber, List<dynamic> drawingData) async {
    try {
      await saveRecord(
        recordType: _recordTypes['pdfDrawings']!,
        recordID: '${songId}_page_$pageNumber',
        fields: {
          'songId': songId,
          'pageNumber': pageNumber,
          'drawingData': json.encode(drawingData),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'version': 1,
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save PDF drawings: $e');
      return false;
    }
  }

  /// Load PDF drawings for a song page
  Future<List<dynamic>> loadPDFDrawings(String songId, int pageNumber) async {
    try {
      final record = await fetchRecord('${songId}_page_$pageNumber');
      if (record == null) return [];
      
      final drawingData = record['drawingData'] as String?;
      if (drawingData == null) return [];
      
      return List<dynamic>.from(json.decode(drawingData) as List);
    } catch (e) {
      developer.log('Failed to load PDF drawings: $e');
      return [];
    }
  }

  /// Save YouTube links
  Future<bool> saveYouTubeLinks(Map<String, Map<String, dynamic>> allLinks) async {
    try {
      await saveRecord(
        recordType: _recordTypes['youtubeLinks']!,
        recordID: 'youtube_links',
        fields: {
          'allLinksData': json.encode(allLinks),
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save YouTube links: $e');
      return false;
    }
  }

  /// Load YouTube links
  Future<Map<String, Map<String, dynamic>>> loadYouTubeLinks() async {
    try {
      final record = await fetchRecord('youtube_links');
      if (record == null) return {};
      
      final linksData = record['allLinksData'] as String?;
      if (linksData == null) return {};
      
      final decoded = json.decode(linksData) as Map<String, dynamic>;
      return decoded.map((key, value) => 
          MapEntry(key, Map<String, dynamic>.from(value as Map)));
    } catch (e) {
      developer.log('Failed to load YouTube links: $e');
      return {};
    }
  }

  /// Save saved loops
  Future<bool> saveSavedLoops(Map<String, List<dynamic>> allLoops) async {
    try {
      await saveRecord(
        recordType: _recordTypes['savedLoops']!,
        recordID: 'saved_loops',
        fields: {
          'allLoopsData': json.encode(allLoops),
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save loops: $e');
      return false;
    }
  }

  /// Load saved loops
  Future<Map<String, List<dynamic>>> loadSavedLoops() async {
    try {
      final record = await fetchRecord('saved_loops');
      if (record == null) return {};
      
      final loopsData = record['allLoopsData'] as String?;
      if (loopsData == null) return {};
      
      final decoded = json.decode(loopsData) as Map<String, dynamic>;
      return decoded.map((key, value) => 
          MapEntry(key, List<dynamic>.from(value as List)));
    } catch (e) {
      developer.log('Failed to load saved loops: $e');
      return {};
    }
  }

  /// Save YouTube videos
  Future<bool> saveYouTubeVideos(List<Map<String, dynamic>> videos) async {
    try {
      await saveRecord(
        recordType: _recordTypes['youtubeVideos']!,
        recordID: 'youtube_videos',
        fields: {
          'videosListData': json.encode(videos),
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save YouTube videos: $e');
      return false;
    }
  }

  /// Load YouTube videos
  Future<List<Map<String, dynamic>>> loadYouTubeVideos() async {
    try {
      final record = await fetchRecord('youtube_videos');
      if (record == null) return [];
      
      final videosData = record['videosListData'] as String?;
      if (videosData == null) return [];
      
      return List<Map<String, dynamic>>.from(json.decode(videosData) as List);
    } catch (e) {
      developer.log('Failed to load YouTube videos: $e');
      return [];
    }
  }

  /// Save books data
  Future<bool> saveBooks(List<Map<String, dynamic>> books) async {
    try {
      await saveRecord(
        recordType: _recordTypes['books']!,
        recordID: 'books',
        fields: {
          'booksData': json.encode(books),
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save books: $e');
      return false;
    }
  }

  /// Load books data
  Future<List<Map<String, dynamic>>> loadBooks() async {
    try {
      final record = await fetchRecord('books');
      if (record == null) return [];
      
      final booksData = record['booksData'] as String?;
      if (booksData == null) return [];
      
      return List<Map<String, dynamic>>.from(json.decode(booksData) as List);
    } catch (e) {
      developer.log('Failed to load books: $e');
      return [];
    }
  }

  /// Save custom songs
  Future<bool> saveCustomSongs(List<Map<String, dynamic>> songs) async {
    try {
      await saveRecord(
        recordType: _recordTypes['customSongs']!,
        recordID: 'custom_songs',
        fields: {
          'songsData': json.encode(songs),
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save custom songs: $e');
      return false;
    }
  }

  /// Load custom songs
  Future<List<Map<String, dynamic>>> loadCustomSongs() async {
    try {
      final record = await fetchRecord('custom_songs');
      if (record == null) return [];
      
      final songsData = record['songsData'] as String?;
      if (songsData == null) return [];
      
      return List<Map<String, dynamic>>.from(json.decode(songsData) as List);
    } catch (e) {
      developer.log('Failed to load custom songs: $e');
      return [];
    }
  }

  /// Save PDF labels for a song page
  Future<bool> savePDFLabels(String songAssetPath, int pageNumber, List<dynamic> labels) async {
    try {
      final safeFilename = _getSafeFilename(songAssetPath);
      final recordID = '${safeFilename}_pdf_page_${pageNumber}_labels';
      
      await saveRecord(
        recordType: _recordTypes['pdfLabels']!,
        recordID: recordID,
        fields: {
          'songAssetPath': songAssetPath,
          'pageNumber': pageNumber,
          'labelsData': json.encode(labels),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      return true;
    } catch (e) {
      developer.log('Failed to save PDF labels: $e');
      return false;
    }
  }

  /// Load PDF labels for a song page
  Future<List<dynamic>> loadPDFLabels(String songAssetPath, int pageNumber) async {
    try {
      final safeFilename = _getSafeFilename(songAssetPath);
      final recordID = '${safeFilename}_pdf_page_${pageNumber}_labels';
      
      final record = await fetchRecord(recordID);
      if (record == null) return [];
      
      final labelsData = record['labelsData'] as String?;
      if (labelsData == null) return [];
      
      return List<dynamic>.from(json.decode(labelsData) as List);
    } catch (e) {
      developer.log('Failed to load PDF labels: $e');
      return [];
    }
  }

  // MARK: - Migration Support

  /// Migrate data from local files to CloudKit
  Future<CloudKitMigrationResult> migrateFromFiles(Map<String, dynamic> fileData) async {
    try {
      developer.log('🔄 [CLOUDKIT] Starting migration from files');
      
      final result = await _channel.invokeMethod('migrateFromFiles', {
        'fileData': fileData,
      });
      
      final success = result['success'] as bool;
      final migratedRecords = List<String>.from(result['migratedRecords'] as List);
      final errors = result.containsKey('errors') 
          ? List<String>.from(result['errors'] as List) 
          : <String>[];
      
      return CloudKitMigrationResult(
        success: success,
        migratedRecords: migratedRecords,
        errors: errors,
      );
    } catch (e) {
      developer.log('❌ [CLOUDKIT] Migration failed: $e');
      return CloudKitMigrationResult(
        success: false,
        migratedRecords: [],
        errors: ['Migration failed: $e'],
      );
    }
  }

  // MARK: - Helper Methods

  String _getSafeFilename(String path) {
    return path
        .split('/')
        .last
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'), '_')
        .replaceAll(RegExp(r'_{2,}'), '_');
  }
}

// MARK: - Data Classes

enum CloudKitAccountStatus {
  available,
  noAccount,
  restricted,
  couldNotDetermine,
  temporarilyUnavailable,
  unknown,
}

class CloudKitMigrationResult {
  final bool success;
  final List<String> migratedRecords;
  final List<String> errors;

  CloudKitMigrationResult({
    required this.success,
    required this.migratedRecords,
    required this.errors,
  });

  @override
  String toString() {
    return 'CloudKitMigrationResult(success: $success, migrated: ${migratedRecords.length}, errors: ${errors.length})';
  }
}

// MARK: - Extensions for Models

extension PracticeAreaCloudKit on PracticeArea {
  Map<String, dynamic> toCloudKitFields() {
    return {
      'name': name,
      'type': type.toString(),
      'songTitle': song?.title,
      'songComposer': song?.composer,
      'songPath': song?.path,
    };
  }

  static PracticeArea fromCloudKitRecord(Map<String, dynamic> record) {
    final typeString = record['type'] as String? ?? 'exercise';
    final type = typeString.contains('PracticeAreaType.song') 
        ? PracticeAreaType.song 
        : typeString.contains('PracticeAreaType.chordProgression')
            ? PracticeAreaType.chordProgression
            : PracticeAreaType.exercise;
    
    // Parse song if available
    Song? song;
    if (type == PracticeAreaType.song && record['songPath'] != null) {
      song = Song(
        title: record['songTitle'] as String? ?? 'Unknown Title',
        composer: record['songComposer'] as String? ?? 'Unknown Composer',
        path: record['songPath'] as String,
      );
    }
    
    return PracticeArea(
      recordName: record['recordID'] as String,
      name: record['name'] as String,
      type: type,
      song: song,
    );
  }
}

extension PracticeItemCloudKit on PracticeItem {
  Map<String, dynamic> toCloudKitFields() {
    return {
      'name': name,
      'description': description,
      'chordProgressionData': chordProgression != null 
          ? json.encode(chordProgression!.toJson()) 
          : null,
      'keysPracticedData': json.encode(keysPracticed),
    };
  }

  static PracticeItem fromCloudKitRecord(Map<String, dynamic> record) {
    // Parse chord progression if exists
    ChordProgression? chordProgression;
    final chordProgressionData = record['chordProgressionData'] as String?;
    if (chordProgressionData != null) {
      try {
        final decoded = json.decode(chordProgressionData) as Map<String, dynamic>;
        chordProgression = ChordProgression.fromJson(decoded);
      } catch (e) {
        developer.log('Failed to parse chord progression: $e');
      }
    }
    
    // Parse keys practiced
    final keysPracticedData = record['keysPracticedData'] as String?;
    Map<String, int> keysPracticed = {};
    if (keysPracticedData != null) {
      try {
        final decoded = json.decode(keysPracticedData) as Map<String, dynamic>;
        keysPracticed = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (e) {
        developer.log('Failed to parse keys practiced: $e');
      }
    }
    
    return PracticeItem(
      id: record['recordID'] as String,
      name: record['name'] as String,
      description: record['description'] as String? ?? '',
      chordProgression: chordProgression,
      keysPracticed: keysPracticed,
    );
  }
}

extension PracticeSessionCloudKit on PracticeSession {
  Map<String, dynamic> toCloudKitFields() {
    return {
      'practiceItemId': item.id,
      'practiceAmount': json.encode(practiceAmount),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}