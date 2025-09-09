import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cloud_kit/types/cloud_kit_account_status.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/services/storage/storage_service.dart';
import 'package:flutter_cloud_kit/flutter_cloud_kit.dart';
import 'package:flutter_cloud_kit/types/database_scope.dart';

/// CloudKit service for syncing data to/from iCloud
class CloudKitService {
  // CloudKit instance - replace with your actual container ID
  static final FlutterCloudKit _cloudKit =
      FlutterCloudKit(containerId: 'iCloud.com.3amstudios.jazzpad');

  // List of all record types used in the app for syncing
  static const _recordTypes = [
    'PracticeArea',
    'PracticeItem',
    'Book',
    'BookWithPDF', // Books with actual PDF files in iCloud Storage
    'SongPDF', // Song PDFs stored in iCloud Storage
    'SheetMusic',
    'WeeklySchedule',
    'SongChanges',
    'ChordKeys',
    'Drawings',
    'PDFDrawings',
    'YoutubeLinks',
    'SavedLoops',
    'CustomSongs',
    'YoutubeVideos',
    'Labels',
  ];

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================
  
  /// Sanitizes a record key to be CloudKit-compatible
  /// CloudKit keys cannot contain: / \ : * ? " < > |
  static String _sanitizeRecordKey(String key) {
    return key
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(':', '_')
        .replaceAll('*', '_')
        .replaceAll('?', '_')
        .replaceAll('"', '_')
        .replaceAll('<', '_')
        .replaceAll('>', '_')
        .replaceAll('|', '_')
        .replaceAll(' ', '_')
        .replaceAll('.', '_')
        .replaceAll('-', '_');
  }

  // =============================================================================
  // CLOUDKIT ACCOUNT STATUS
  // =============================================================================
  
  /// Check if user is logged in to iCloud
  static Future<bool> isAccountAvailable() async {
    try {
      final accountStatus = await _cloudKit.getAccountStatus();
      return accountStatus == CloudKitAccountStatus.available; 
    } catch (e) {
      developer.log('❌ Error checking CloudKit account status: $e');
      return false;
    }
  }
  
  // =============================================================================
  // SAVE OPERATIONS
  // =============================================================================

  /// Save record with assets to CloudKit using CKAsset functionality
  static Future<String?> saveRecordWithAssets({
    required Map<String, dynamic> record,
    required Map<String, CloudKitAsset> assets,
  }) async {
    try {
      final recordName = record['recordName'] as String? ?? 'unknown';
      final recordType = record['recordType'] as String? ?? 'unknown';
      
      developer.log('📤 ===== CLOUDKIT UPLOAD DEBUG =====');
      developer.log('📤 Record Type: $recordType');
      developer.log('📤 Record Name: $recordName');
      developer.log('📤 Upload Time: ${DateTime.now().toIso8601String()}');
      
      // Check if this is a new record or update by trying to fetch existing
      final rawRecordKey = '${recordType}_$recordName';
      final recordKey = _sanitizeRecordKey(rawRecordKey);
      final existingRecord = await getRecord(recordKey);
      
      if (existingRecord != null) {
        developer.log('📤 UPDATE: Record exists, comparing changes...');
        _logRecordDifferences(record, existingRecord);
      } else {
        developer.log('📤 NEW RECORD: Creating new record in CloudKit');
      }
      
      // Log detailed record data
      developer.log('📤 Record Metadata:');
      for (final entry in record.entries) {
        if (entry.key != 'recordName' && entry.key != 'recordType') {
          developer.log('📤   ${entry.key}: ${entry.value}');
        }
      }
      
      // Log detailed asset information
      developer.log('📤 Assets to Upload (${assets.length}):');
      for (final entry in assets.entries) {
        final asset = entry.value;
        final assetFile = File(asset.filePath);
        
        if (await assetFile.exists()) {
          final fileSize = await assetFile.length();
          final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(2);
          developer.log('📤   Asset Key: ${entry.key}');
          developer.log('📤     File Path: ${asset.filePath}');
          developer.log('📤     File Name: ${asset.fileName ?? 'auto-generated'}');
          developer.log('📤     File Size: ${fileSize} bytes ($fileSizeMB MB)');
          developer.log('📤     File Exists: ✅');
        } else {
          developer.log('📤   Asset Key: ${entry.key}');
          developer.log('📤     File Path: ${asset.filePath}');
          developer.log('📤     File Exists: ❌ FILE NOT FOUND');
        }
      }
      
      // Validate required fields
      if (record['recordName'] == null || record['recordType'] == null) {
        throw ArgumentError('Record must have recordName and recordType');
      }
      
      // Check if user is logged in to iCloud
      if (!await isAccountAvailable()) {
        developer.log('❌ User is not logged in to iCloud');
        throw Exception('User must be logged in to iCloud to save data');
      }
      
      // Prepare record for CloudKit
      final cloudKitData = _prepareRecordForCloudKit(record);
      
      // Convert cloudKitData to Map<String, String> for flutter_cloud_kit
      final stringRecord = <String, String>{};
      for (final entry in cloudKitData.entries) {
        if (entry.value != null) {
          stringRecord[entry.key] = entry.value.toString();
        }
      }
      
      developer.log('📤 Sanitized Record Key: $recordKey');
      developer.log('📤 Calling flutter_cloud_kit.saveRecordWithAssets...');
      
      // Save to CloudKit with assets using the flutter_cloud_kit package
      await _cloudKit.saveRecordWithAssets(
        scope: CloudKitDatabaseScope.private,
        recordType: recordType,
        recordName: recordKey,
        record: stringRecord,
        assets: assets,
      );

      // Generate a change tag based on current timestamp
      final changeTag =
          'tag_${recordType.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';

      developer.log('✅ UPLOAD SUCCESS: $recordType record with assets saved to CloudKit');
      developer.log('📤 Generated Change Tag: $changeTag');
      developer.log('📤 ===== UPLOAD COMPLETE =====');
      
      return changeTag;
    } catch (e) {
      developer.log('❌ UPLOAD FAILED: Error saving record with assets to CloudKit: $e');
      developer.log('📤 ===== UPLOAD FAILED =====');
      rethrow;
    }
  }
  
  /// Log differences between new and existing records
  static void _logRecordDifferences(Map<String, dynamic> newRecord, Map<String, dynamic> existingRecord) {
    developer.log('📤 CHANGE ANALYSIS:');
    
    // Check for new fields
    final newFields = <String>[];
    final changedFields = <String>[];
    final unchangedFields = <String>[];
    
    for (final entry in newRecord.entries) {
      if (entry.key == 'recordName' || entry.key == 'recordType') continue;
      
      if (!existingRecord.containsKey(entry.key)) {
        newFields.add(entry.key);
      } else {
        final oldValue = existingRecord[entry.key];
        final newValue = entry.value;
        
        if (oldValue != newValue) {
          changedFields.add(entry.key);
          developer.log('📤   CHANGED ${entry.key}: "$oldValue" → "$newValue"');
        } else {
          unchangedFields.add(entry.key);
        }
      }
    }
    
    if (newFields.isNotEmpty) {
      developer.log('📤   NEW FIELDS: ${newFields.join(', ')}');
    }
    
    if (changedFields.isNotEmpty) {
      developer.log('📤   MODIFIED FIELDS: ${changedFields.join(', ')}');
    }
    
    if (unchangedFields.isNotEmpty) {
      developer.log('📤   UNCHANGED FIELDS: ${unchangedFields.join(', ')}');
    }
    
    // Check for removed fields
    final removedFields = existingRecord.keys
        .where((key) => key != 'recordName' && key != 'recordType' && !newRecord.containsKey(key))
        .toList();
        
    if (removedFields.isNotEmpty) {
      developer.log('📤   REMOVED FIELDS: ${removedFields.join(', ')}');
    }
  }

  /// Download asset from CloudKit record
  static Future<String?> downloadRecordAsset({
    required String recordName,
    required String assetKey,
  }) async {
    try {
      developer.log('☁️ Downloading asset from CloudKit: $recordName/$assetKey');
      
      // Check if user is logged in to iCloud
      if (!await isAccountAvailable()) {
        developer.log('❌ User is not logged in to iCloud');
        return null;
      }
      
      final sanitizedKey = _sanitizeRecordKey(recordName);
      
      // Get local documents directory for saving downloaded file
      final documentsDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${documentsDir.path}/downloads');
      await downloadDir.create(recursive: true);
      
      // Generate local file path
      final fileName = '${sanitizedKey}_${assetKey}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final localFilePath = '${downloadDir.path}/$fileName';
      
      // Download asset from CloudKit using the flutter_cloud_kit package
      final downloadedPath = await _cloudKit.downloadAsset(
        scope: CloudKitDatabaseScope.private,
        recordName: sanitizedKey,
        assetKey: assetKey,
        localFilePath: localFilePath,
      );
      
      if (downloadedPath != null) {
        developer.log('☁️ Asset downloaded successfully: $downloadedPath');
        return downloadedPath;
      } else {
        developer.log('⚠️ Asset download returned null');
        return null;
      }
    } catch (e) {
      developer.log('❌ Error downloading asset from CloudKit: $e');
      return null;
    }
  }

  /// Save single record to CloudKit (without assets)
  /// After saving, the recordChangeTag should be extracted from the response
  /// and saved locally using StorageService methods
  /// For PDFs and other assets, use saveRecordWithAssets instead
  static Future<String?> saveRecord(Map<String, dynamic> record) async {
    try {
      final recordName = record['recordName'] as String? ?? 'unknown';
      final recordType = record['recordType'] as String? ?? 'unknown';
      
      developer.log('📤 ===== CLOUDKIT RECORD UPLOAD =====');
      developer.log('📤 Record Type: $recordType');
      developer.log('📤 Record Name: $recordName');
      developer.log('📤 Upload Time: ${DateTime.now().toIso8601String()}');
      
      // Validate required fields
      if (record['recordName'] == null || record['recordType'] == null) {
        throw ArgumentError('Record must have recordName and recordType');
      }
      
      // Check if user is logged in to iCloud
      if (!await isAccountAvailable()) {
        developer.log('❌ User is not logged in to iCloud');
        throw Exception('User must be logged in to iCloud to save data');
      }
      
      // Log record data being uploaded
      developer.log('📤 Record Data:');
      for (final entry in record.entries) {
        if (entry.key != 'recordName' && entry.key != 'recordType') {
          developer.log('📤   ${entry.key}: ${entry.value}');
        }
      }
      
      // Prepare record for CloudKit - convert to JSON string
      final cloudKitData = _prepareRecordForCloudKit(record);
      final rawRecordKey = '${recordType}_$recordName';
      final recordKey = _sanitizeRecordKey(rawRecordKey);
      final recordValue = json.encode(cloudKitData);
      
      developer.log('📤 Sanitized Record Key: $recordKey');
      developer.log('📤 CloudKit JSON Size: ${recordValue.length} characters');
      
      // Save to CloudKit using key-value storage
      await _cloudKit.saveRecord(
        scope: CloudKitDatabaseScope.private,
        recordType: recordType,
        recordName: recordKey,
        record: {'value': recordValue},
      );

      // Generate a change tag based on current timestamp
      final changeTag =
          'tag_${recordType.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';

      developer.log('✅ UPLOAD SUCCESS: $recordType record saved to CloudKit');
      developer.log('📤 Generated Change Tag: $changeTag');
      developer.log('📤 ===== RECORD UPLOAD COMPLETE =====');
      
      return changeTag;
    } catch (e) {
      developer.log('❌ UPLOAD FAILED: Error saving record to CloudKit: $e');
      developer.log('📤 ===== RECORD UPLOAD FAILED =====');
      rethrow;
    }
  }

  /// Prepare record data for CloudKit by ensuring proper data types and structure
  static Map<String, dynamic> _prepareRecordForCloudKit(Map<String, dynamic> record) {
    final prepared = Map<String, dynamic>.from(record);
    
    // Add timestamp for change tracking
    prepared['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    
    // Ensure all nested objects are properly serialized
    final keysToRemove = <String>[];
    for (final entry in prepared.entries) {
      if (entry.value is Map<String, dynamic>) {
        // Already a map, keep as is
        continue;
      } else if (entry.value is List) {
        // Ensure list items are properly serialized
        prepared[entry.key] = entry.value;
      } else if (entry.value == null) {
        // Mark null values for removal
        keysToRemove.add(entry.key);
      }
    }
    
    // Remove null values as CloudKit doesn't handle them well
    for (final key in keysToRemove) {
      prepared.remove(key);
    }
    
    return prepared;
  }

  /// Get a record from CloudKit by key
  static Future<Map<String, dynamic>?> getRecord(String recordKey) async {
    try {
      if (!await isAccountAvailable()) {
        developer.log('❌ User is not logged in to iCloud');
        return null;
      }
      
      final sanitizedKey = _sanitizeRecordKey(recordKey);
      final cloudKitRecord = await _cloudKit.getRecord(
        scope: CloudKitDatabaseScope.private,
        recordName: sanitizedKey,
      );

      final recordValue = cloudKitRecord.values['value'];
      if (recordValue != null) {
        return json.decode(recordValue) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      developer.log('ℹ️ Error getting record from CloudKit (may not exist): $e');
      return null;
    }
  }

  /// Get all records from CloudKit
  static Future<Map<String, String>> getAllRecords() async {
    try {
      if (!await isAccountAvailable()) {
        developer.log('❌ User is not logged in to iCloud');
        return {};
      }
      
      final allData = <String, String>{};
      for (final recordType in _recordTypes) {
        try {
          final records = await _cloudKit.getRecordsByType(
            scope: CloudKitDatabaseScope.private,
            recordType: recordType,
          );
          for (final record in records) {
            final recordValue = record.values['value'];
            if (recordValue != null) {
              allData[record.recordName] = recordValue;
            }
          }
        } catch (e) {
          developer.log('⚠️ Error fetching records of type $recordType: $e');
        }
      }
      return allData;
    } catch (e) {
      developer.log('❌ Error getting all records from CloudKit: $e');
      return {};
    }
  }

  /// Delete a record from CloudKit
  static Future<bool> deleteRecord(String recordKey) async {
    try {
      if (!await isAccountAvailable()) {
        developer.log('❌ User is not logged in to iCloud');
        return false;
      }
      
      final sanitizedKey = _sanitizeRecordKey(recordKey);
      await _cloudKit.deleteRecord(
        scope: CloudKitDatabaseScope.private,
        recordName: sanitizedKey,
      );
      return true;
    } catch (e) {
      developer.log('❌ Error deleting record from CloudKit: $e');
      return false;
    }
  }

  // =============================================================================
  // BOOK WITH PDF OPERATIONS (using iCloud Storage for files)
  // =============================================================================

  /// Upload book metadata to CloudKit with iCloud PDF path
  /// The actual PDF file should be uploaded using ICloudFileService
  static Future<String?> saveBookWithPDF({
    required String bookId,
    required String title,
    required String iCloudPDFPath,
    String? author,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      final recordName = 'book_$bookId';
      
      // Prepare book metadata with iCloud path
      final bookRecord = {
        'recordName': recordName,
        'recordType': 'BookWithPDF',
        'bookId': bookId,
        'title': title,
        'author': author ?? '',
        'iCloudPath': iCloudPDFPath, // Path in iCloud Storage
        'uploadDate': DateTime.now().millisecondsSinceEpoch,
        ...?additionalMetadata,
      };

      // Save metadata to CloudKit
      final changeTag = await saveRecord(bookRecord);
      
      if (changeTag != null) {
        developer.log('☁️ Book metadata saved to CloudKit: $title');
      }
      
      return changeTag;
    } catch (e) {
      developer.log('❌ Error saving book metadata: $e');
      return null;
    }
  }

  /// Save song PDF metadata to CloudKit with iCloud path
  static Future<String?> saveSongWithPDF({
    required String songId,
    required String songTitle,
    required String iCloudPDFPath,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      final recordName = 'songpdf_$songId';
      
      // Prepare song PDF metadata with iCloud path
      final songPDFRecord = {
        'recordName': recordName,
        'recordType': 'SongPDF',
        'songId': songId,
        'songTitle': songTitle,
        'iCloudPath': iCloudPDFPath, // Path in iCloud Storage
        'uploadDate': DateTime.now().millisecondsSinceEpoch,
        ...?additionalMetadata,
      };

      // Save metadata to CloudKit
      final changeTag = await saveRecord(songPDFRecord);
      
      if (changeTag != null) {
        developer.log('☁️ Song PDF metadata saved to CloudKit: $songTitle');
      }
      
      return changeTag;
    } catch (e) {
      developer.log('❌ Error saving song PDF metadata: $e');
      return null;
    }
  }

  // =============================================================================
  // PROCESS INCOMING RECORDS
  // =============================================================================

  /// Process incoming CloudKit record and update local storage
  static Future<void> processIncomingRecord(Map<String, dynamic> record) async {
    try {
      final recordType = record['recordType'] as String?;
      final recordName = record['recordName'] as String?;
      
      if (recordType == null || recordName == null) {
        developer.log('❌ Invalid record: missing recordType or recordName');
        return;
      }

      developer.log('☁️ Processing incoming record: $recordName (type: $recordType)');

      switch (recordType) {
        case 'PracticeArea':
          await _processPracticeAreaRecord(record);
          break;
        case 'PracticeItem':
          await _processPracticeItemRecord(record);
          break;
        case 'Book':
          await _processBookRecord(record);
          break;
        case 'BookWithPDF':
          await _processBookWithPDFRecord(record);
          break;
        case 'SongPDF':
          await _processSongPDFRecord(record);
          break;
        case 'SheetMusic':
          await _processSheetMusicRecord(record);
          break;
        case 'WeeklySchedule':
          await _processWeeklyScheduleRecord(record);
          break;
        case 'SongChanges':
          await _processSongChangesRecord(record);
          break;
        case 'ChordKeys':
          await _processChordKeysRecord(record);
          break;
        case 'Drawings':
          await _processDrawingsRecord(record);
          break;
        case 'PDFDrawings':
          await _processPDFDrawingsRecord(record);
          break;
        case 'YoutubeLinks':
          await _processYoutubeLinksRecord(record);
          break;
        case 'SavedLoops':
          await _processSavedLoopsRecord(record);
          break;
        case 'CustomSongs':
          await _processCustomSongsRecord(record);
          break;
        case 'YoutubeVideos':
          await _processYoutubeVideosRecord(record);
          break;
        case 'Labels':
          await _processLabelsRecord(record);
          break;
        default:
          developer.log('❌ Unknown record type: $recordType');
      }
    } catch (e) {
      developer.log('❌ Error processing incoming record: $e');
    }
  }

  /// Process incoming practice area record
  static Future<void> _processPracticeAreaRecord(Map<String, dynamic> record) async {
    try {
      final recordName = record['recordName'] as String;
      final recordChangeTag = record['recordChangeTag'] as String?;
      
      // Load existing practice areas
      final areas = await StorageService.loadPracticeAreas();
      final existingIndex = areas.indexWhere((area) => area.recordName == recordName);
      
      if (existingIndex == -1) {
        // Case 1: Object doesn't exist locally - create new
        final incomingArea = StorageService.practiceAreaFromJson(record);
        areas.add(incomingArea);
        await StorageService.savePracticeAreas(areas);
        developer.log('☁️ Created new practice area: $recordName');
      } else {
        // Case 2: Object exists locally - compare change tags
        final existingArea = areas[existingIndex];
        if (existingArea.recordChangeTag != recordChangeTag && recordChangeTag != null) {
          // Incoming record is newer, update local
          final updatedArea = StorageService.practiceAreaFromJson(record);
          areas[existingIndex] = updatedArea;
          await StorageService.savePracticeAreas(areas);
          developer.log('☁️ Updated practice area: $recordName');
        } else {
          developer.log('☁️ Practice area up to date: $recordName');
        }
      }
    } catch (e) {
      developer.log('❌ Error processing practice area record: $e');
    }
  }

  /// Process incoming practice item record  
  static Future<void> _processPracticeItemRecord(Map<String, dynamic> record) async {
    try {
      final recordName = record['recordName'] as String;
      final recordChangeTag = record['recordChangeTag'] as String?;
      final practiceAreaId = record['practiceAreaId'] as String?;
      
      if (practiceAreaId == null) {
        developer.log('❌ Practice item missing practiceAreaId: $recordName');
        return;
      }

      // Load existing practice items
      final itemsByArea = await StorageService.loadPracticeItems();
      final items = itemsByArea[practiceAreaId] ?? <PracticeItem>[];
      final existingIndex = items.indexWhere((item) => item.id == recordName);
      
      if (existingIndex == -1) {
        // Case 1: Object doesn't exist locally - create new
        final incomingItem = StorageService.practiceItemFromJson(record);
        items.add(incomingItem);
        itemsByArea[practiceAreaId] = items;
        await StorageService.savePracticeItems(itemsByArea);
        developer.log('☁️ Created new practice item: $recordName');
      } else {
        // Case 2: Object exists locally - compare change tags
        final existingItem = items[existingIndex];
        if (existingItem.recordChangeTag != recordChangeTag && recordChangeTag != null) {
          // Incoming record is newer, update local
          final updatedItem = StorageService.practiceItemFromJson(record);
          items[existingIndex] = updatedItem;
          itemsByArea[practiceAreaId] = items;
          await StorageService.savePracticeItems(itemsByArea);
          developer.log('☁️ Updated practice item: $recordName');
        } else {
          developer.log('☁️ Practice item up to date: $recordName');
        }
      }
    } catch (e) {
      developer.log('❌ Error processing practice item record: $e');
    }
  }

  /// Process incoming book record
  static Future<void> _processBookRecord(Map<String, dynamic> record) async {
    try {
      final recordName = record['recordName'] as String;
      final directoryPath = record['directoryPath'] as String?;
      
      if (directoryPath != null) {
        // Store book at local directory if doesn't exist
        await StorageService.addBook(record);
        developer.log('☁️ Added book: $recordName');
      }
    } catch (e) {
      developer.log('❌ Error processing book record: $e');
    }
  }

  /// Process incoming book with PDF record using iCloud Storage
  static Future<void> _processBookWithPDFRecord(Map<String, dynamic> record) async {
    try {
      final bookId = record['bookId'] as String?;
      final title = record['title'] as String?;
      final iCloudPath = record['iCloudPath'] as String?;
      final recordChangeTag = record['recordChangeTag'] as String?;
      
      if (bookId == null || title == null || iCloudPath == null) {
        developer.log('❌ BookWithPDF record missing required fields');
        return;
      }

      developer.log('☁️ Processing book with PDF: $title');

      // Check if we already have this book locally
      final books = await StorageService.loadBooks();
      final existingBookIndex = books.indexWhere((book) => book['id'] == bookId);
      
      if (existingBookIndex == -1) {
        // New book - create book record with iCloud path
        final bookRecord = {
          'id': bookId,
          'title': title,
          'author': record['author'] ?? '',
          'iCloudPath': iCloudPath, // Store iCloud path instead of local path
          'recordName': record['recordName'],
          'recordType': 'BookWithPDF',
          'recordChangeTag': recordChangeTag,
          'uploadDate': record['uploadDate'],
        };
        
        await StorageService.addBook(bookRecord);
        developer.log('☁️ Added new book with iCloud PDF: $title');
      } else {
        // Existing book - check if we need to update
        final existingBook = books[existingBookIndex];
        final existingChangeTag = existingBook['recordChangeTag'] as String?;
        
        if (existingChangeTag != recordChangeTag && recordChangeTag != null) {
          // Update book record
          books[existingBookIndex] = {
            ...existingBook,
            'title': title,
            'author': record['author'] ?? '',
            'iCloudPath': iCloudPath,
            'recordChangeTag': recordChangeTag,
            'uploadDate': record['uploadDate'],
          };
          
          await StorageService.saveBooks(books);
          developer.log('☁️ Updated book: $title');
        } else {
          developer.log('☁️ Book with PDF up to date: $title');
        }
      }
    } catch (e) {
      developer.log('❌ Error processing book with PDF record: $e');
    }
  }

  /// Process incoming song PDF record
  static Future<void> _processSongPDFRecord(Map<String, dynamic> record) async {
    try {
      final songId = record['songId'] as String?;
      final songTitle = record['songTitle'] as String?;
      final iCloudPath = record['iCloudPath'] as String?;
      final recordChangeTag = record['recordChangeTag'] as String?;
      
      if (songId == null || songTitle == null || iCloudPath == null) {
        developer.log('❌ SongPDF record missing required fields');
        return;
      }

      developer.log('☁️ Processing song PDF: $songTitle');

      // Store song PDF metadata - you might want to add this to your StorageService
      // For now, just log that we processed it
      // In a full implementation, you'd save this to a song PDFs collection
      
      developer.log('☁️ Song PDF metadata processed: $songTitle (iCloud: $iCloudPath)');
      
      // TODO: Add StorageService method to save song PDF metadata if needed
      // await StorageService.saveSongPDFMetadata(songId, {
      //   'songId': songId,
      //   'songTitle': songTitle,
      //   'iCloudPath': iCloudPath,
      //   'recordChangeTag': recordChangeTag,
      //   'uploadDate': record['uploadDate'],
      // });
      
    } catch (e) {
      developer.log('❌ Error processing song PDF record: $e');
    }
  }

  /// Process incoming sheet music record
  static Future<void> _processSheetMusicRecord(Map<String, dynamic> record) async {
    try {
      final songId = record['recordName'] as String;
      final measuresDataString = record['measuresData'] as String?;
      final recordChangeTag = record['recordChangeTag'] as String?;
      
      if (measuresDataString == null) {
        developer.log('❌ Sheet music record missing measuresData: $songId');
        return;
      }

      // Check if local version is different
      final localChangeTag = await StorageService.getSheetMusicChangeTag(songId);
      if (localChangeTag != recordChangeTag && recordChangeTag != null) {
        // Parse and save measures
        final measuresData = json.decode(measuresDataString) as List<dynamic>;
        final measures = measuresData
            .cast<Map<String, dynamic>>()
            .map((json) => StorageService.measureFromJson(json))
            .toList();
        
        await StorageService.saveSheetMusicForSong(songId, measures);
        await StorageService.updateSheetMusicChangeTag(songId, recordChangeTag);
        
        developer.log('☁️ Updated sheet music: $songId');
      } else {
        developer.log('☁️ Sheet music up to date: $songId');
      }
    } catch (e) {
      developer.log('❌ Error processing sheet music record: $e');
    }
  }

  // =============================================================================
  // CLOUDKIT SUBSCRIPTION SETUP
  // =============================================================================

  /// Setup CloudKit database subscription to receive notifications of changes
  static Future<void> setupDatabaseSubscription() async {
    try {
      developer.log('☁️ Setting up CloudKit database subscription');
      
      // Check if subscription already exists
      if (await _subscriptionExists()) {
        developer.log('☁️ Database subscription already exists');
        return;
      }
      
      // Note: The flutter_cloud_kit package doesn't support real-time subscriptions
      // Instead, we'll implement a polling mechanism to check for changes
      // In a production app, you might want to use a more comprehensive CloudKit package
      
      developer.log('⚠️ flutter_cloud_kit package doesn\'t support real-time subscriptions');
      developer.log('☁️ Consider implementing periodic sync instead');
      
      // Save sync metadata to indicate setup is complete
      await _cloudKit.saveRecord(
        scope: CloudKitDatabaseScope.private,
        recordType: 'SyncMetadata',
        recordName: 'sync_metadata',
        record: {
          'value': json.encode({
            'setupTime': DateTime.now().millisecondsSinceEpoch,
            'lastSync': 0,
          })
        },
      );

      developer.log('☁️ CloudKit sync setup completed');
    } catch (e) {
      developer.log('❌ Error setting up CloudKit sync: $e');
      rethrow;
    }
  }

  /// Check if periodic sync is enabled (replaces subscription check)
  static Future<bool> _subscriptionExists() async {
    try {
      // For flutter_cloud_kit, we don't have real subscriptions.
      // Instead, check if we have our sync metadata record.
      // getRecord will throw if not found.
      await _cloudKit.getRecord(
        scope: CloudKitDatabaseScope.private,
        recordName: 'sync_metadata',
      );
      return true;
    } catch (e) {
      developer.log('ℹ️ Sync metadata not found, assuming subscription does not exist.');
      return false;
    }
  }

  /// Perform manual sync with CloudKit (call this periodically)
  static Future<void> performSync() async {
    await handleNotification();
  }

  /// Handle CloudKit notification by fetching database changes
  static Future<void> handleNotification() async {
    try {
      developer.log('☁️ Handling CloudKit notification - fetching database changes');
      
      // Load saved server change token
      final serverChangeToken = await StorageService.loadServerChangeToken();
      
      // Fetch database changes from CloudKit
      final result = await _fetchDatabaseChanges(serverChangeToken);
      
      if (result == null) {
        developer.log('⚠️ No changes to process');
        return;
      }
      
      final changedRecords = result['changedRecords'] as List<Map<String, dynamic>>? ?? [];
      final deletedRecordIDs = result['deletedRecordIDs'] as List<String>? ?? [];
      final newServerChangeToken = result['serverChangeToken'] as String?;
      
      // Process changed records
      for (final record in changedRecords) {
        try {
          await processIncomingRecord(record);
        } catch (e) {
          developer.log('❌ Error processing changed record ${record['recordName']}: $e');
        }
      }
      
      // Process deleted records
      for (final recordID in deletedRecordIDs) {
        try {
          await _processDeletedRecord(recordID);
        } catch (e) {
          developer.log('❌ Error processing deleted record $recordID: $e');
        }
      }
      
      // Save new server change token
      if (newServerChangeToken != null && newServerChangeToken.isNotEmpty) {
        await StorageService.saveServerChangeToken(newServerChangeToken);
      }
      
      developer.log('☁️ Successfully processed ${changedRecords.length} changed records and ${deletedRecordIDs.length} deleted records');
    } catch (e) {
      developer.log('❌ Error handling CloudKit notification: $e');
      rethrow;
    }
  }

  /// Fetch database changes from CloudKit (using polling approach)
  static Future<Map<String, dynamic>?> _fetchDatabaseChanges(String? previousToken) async {
    try {
      if (!await isAccountAvailable()) {
        developer.log('❌ User is not logged in to iCloud');
        return null;
      }
      
      // Get all records from CloudKit
      final allRecords = await getAllRecords();
      final changedRecords = <Map<String, dynamic>>[];
      final deletedRecordIDs = <String>[];
      
      // Load local sync metadata to track changes
      final localSyncData = await _loadLocalSyncMetadata();
      
      // Compare with local sync metadata to find changes
      for (final entry in allRecords.entries) {
        try {
          final recordData = json.decode(entry.value) as Map<String, dynamic>;
          final recordKey = entry.key;
          final localTimestamp = localSyncData[recordKey];
          final cloudTimestamp = recordData['timestamp'] as int? ?? 0;
          
          // If cloud timestamp is newer, it's a changed record
          if (localTimestamp == null || cloudTimestamp > localTimestamp) {
            changedRecords.add({
              'recordName': recordData['recordName'],
              'recordType': recordData['recordType'],
              'recordChangeTag': 'tag_${DateTime.now().millisecondsSinceEpoch}',
              ...recordData,
            });
            
            // Update local sync metadata
            localSyncData[recordKey] = cloudTimestamp;
          }
        } catch (e) {
          developer.log('⚠️ Error parsing record ${entry.key}: $e');
        }
      }
      
      // Check for deleted records (in local metadata but not in cloud)
      for (final localKey in localSyncData.keys.toList()) {
        if (!allRecords.containsKey(localKey)) {
          deletedRecordIDs.add(localKey);
          localSyncData.remove(localKey);
        }
      }
      
      // Save updated sync metadata
      await _saveLocalSyncMetadata(localSyncData);
      
      final newToken = 'sync_token_${DateTime.now().millisecondsSinceEpoch}';
      
      return {
        'changedRecords': changedRecords,
        'deletedRecordIDs': deletedRecordIDs,
        'serverChangeToken': newToken,
        'moreComing': false,
      };
    } catch (e) {
      developer.log('❌ Error fetching database changes: $e');
      return null;
    }
  }

  /// Load local sync metadata
  static Future<Map<String, int>> _loadLocalSyncMetadata() async {
    try {
      final metadataJson = await StorageService.loadServerChangeToken() ?? '{}';
      final metadata = json.decode(metadataJson) as Map<String, dynamic>;
      return metadata.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      developer.log('⚠️ Error loading sync metadata: $e');
      return {};
    }
  }

  /// Save local sync metadata
  static Future<void> _saveLocalSyncMetadata(Map<String, int> metadata) async {
    try {
      final metadataJson = json.encode(metadata);
      await StorageService.saveServerChangeToken(metadataJson);
    } catch (e) {
      developer.log('❌ Error saving sync metadata: $e');
    }
  }

  /// Process deleted record by removing from local storage
  static Future<void> _processDeletedRecord(String recordID) async {
    try {
      // The recordID is a sanitized composite key, e.g., "PracticeArea_My_Area_Name"
      // We need to find the local object by reconstructing this key and comparing.
      
      // Check practice areas
      final areas = await StorageService.loadPracticeAreas();
      final areaIndex = areas.indexWhere(
          (area) => _sanitizeRecordKey('PracticeArea_${area.recordName}') == recordID);
      if (areaIndex != -1) {
        final removedArea = areas.removeAt(areaIndex);
        await StorageService.savePracticeAreas(areas);
        developer.log('☁️ Deleted practice area: ${removedArea.recordName}');
        return;
      }
      
      // Check practice items
      final itemsByArea = await StorageService.loadPracticeItems();
      bool itemFound = false;
      for (final areaId in itemsByArea.keys.toList()) {
        final items = itemsByArea[areaId]!;
        final itemIndex = items.indexWhere(
            (item) => _sanitizeRecordKey('PracticeItem_${item.id}') == recordID);
        if (itemIndex != -1) {
          final removedItem = items.removeAt(itemIndex);
          itemsByArea[areaId] = items;
          await StorageService.savePracticeItems(itemsByArea);
          developer.log('☁️ Deleted practice item: ${removedItem.id}');
          itemFound = true;
          break;
        }
      }
      if (itemFound) return;

      // Check books
      final books = await StorageService.loadBooks();
      final bookIndex = books.indexWhere(
          (book) => _sanitizeRecordKey('Book_${book['id']}') == recordID);
      if (bookIndex != -1) {
        final removedBook = books.removeAt(bookIndex);
        await StorageService.saveBooks(books);
        developer.log('☁️ Deleted book: ${removedBook['id']}');
        return;
      }
      
      developer.log('☁️ Record not found locally for deletion: $recordID');
    } catch (e) {
      developer.log('❌ Error processing deleted record: $e');
    }
  }

  /// Process incoming weekly schedule record
  static Future<void> _processWeeklyScheduleRecord(Map<String, dynamic> record) async {
    try {
      final scheduleData = record['scheduleData'] as String?;
      if (scheduleData != null && scheduleData.isNotEmpty) {
        final decodedData = json.decode(scheduleData) as Map<String, dynamic>;
        final schedule = <String, List<String>>{};
        
        for (final entry in decodedData.entries) {
          if (entry.value is List) {
            schedule[entry.key] = List<String>.from(entry.value);
          } else {
            developer.log('⚠️ Invalid schedule data for key ${entry.key}: ${entry.value}');
          }
        }
        
        await StorageService.saveWeeklySchedule(schedule);
        developer.log('☁️ Updated weekly schedule');
      } else {
        developer.log('⚠️ Weekly schedule record missing or empty scheduleData');
      }
    } catch (e) {
      developer.log('❌ Error processing weekly schedule record: $e');
    }
  }

  /// Process incoming song changes record
  static Future<void> _processSongChangesRecord(Map<String, dynamic> record) async {
    try {
      final songId = record['songId'] as String?;
      final changesData = record['changesData'] as String?;
      
      if (songId != null && songId.isNotEmpty && changesData != null && changesData.isNotEmpty) {
        final decodedChanges = json.decode(changesData);
        if (decodedChanges is Map<String, dynamic>) {
          await StorageService.saveSongChanges(songId, decodedChanges);
          developer.log('☁️ Updated song changes: $songId');
        } else {
          developer.log('⚠️ Invalid song changes data format for $songId');
        }
      } else {
        developer.log('⚠️ Song changes record missing songId or changesData');
      }
    } catch (e) {
      developer.log('❌ Error processing song changes record: $e');
    }
  }

  /// Process incoming chord keys record
  static Future<void> _processChordKeysRecord(Map<String, dynamic> record) async {
    try {
      final songId = record['songId'] as String?;
      final chordKeysData = record['chordKeysData'] as String?;
      
      if (songId != null && songId.isNotEmpty && chordKeysData != null && chordKeysData.isNotEmpty) {
        final decodedKeys = json.decode(chordKeysData);
        if (decodedKeys is Map<String, dynamic>) {
          await StorageService.saveChordKeys(songId, decodedKeys);
          developer.log('☁️ Updated chord keys: $songId');
        } else {
          developer.log('⚠️ Invalid chord keys data format for $songId');
        }
      } else {
        developer.log('⚠️ Chord keys record missing songId or chordKeysData');
      }
    } catch (e) {
      developer.log('❌ Error processing chord keys record: $e');
    }
  }

  /// Process incoming drawings record
  static Future<void> _processDrawingsRecord(Map<String, dynamic> record) async {
    try {
      final songId = record['songId'] as String?;
      final drawingsData = record['drawingsData'] as String?;
      
      if (songId != null && songId.isNotEmpty && drawingsData != null && drawingsData.isNotEmpty) {
        final decodedDrawings = json.decode(drawingsData);
        if (decodedDrawings is List) {
          final drawings = decodedDrawings.cast<Map<String, dynamic>>();
          await StorageService.saveDrawingsForSong(songId, drawings);
          developer.log('☁️ Updated drawings: $songId');
        } else {
          developer.log('⚠️ Invalid drawings data format for $songId');
        }
      } else {
        developer.log('⚠️ Drawings record missing songId or drawingsData');
      }
    } catch (e) {
      developer.log('❌ Error processing drawings record: $e');
    }
  }

  /// Process incoming PDF drawings record
  static Future<void> _processPDFDrawingsRecord(Map<String, dynamic> record) async {
    try {
      final songId = record['songId'] as String?;
      final pageNumber = record['pageNumber'] as int?;
      final drawingsData = record['drawingsData'] as String?;
      
      if (songId != null && songId.isNotEmpty && pageNumber != null && 
          drawingsData != null && drawingsData.isNotEmpty) {
        final decodedDrawings = json.decode(drawingsData);
        if (decodedDrawings is List) {
          final paintHistoryData = decodedDrawings.cast<Map<String, dynamic>>();
          final paintHistory = paintHistoryData
              .map((json) => StorageService.paintInfoFromJson(json))
              .toList();
          await StorageService.savePDFDrawingsForSongPage(songId, pageNumber, paintHistory);
          developer.log('☁️ Updated PDF drawings: $songId page $pageNumber');
        } else {
          developer.log('⚠️ Invalid PDF drawings data format for $songId page $pageNumber');
        }
      } else {
        developer.log('⚠️ PDF drawings record missing required fields');
      }
    } catch (e) {
      developer.log('❌ Error processing PDF drawings record: $e');
    }
  }

  /// Process incoming YouTube links record
  static Future<void> _processYoutubeLinksRecord(Map<String, dynamic> record) async {
    try {
      final songId = record['songId'] as String?;
      final youtubeData = record['youtubeData'] as String?;
      
      if (songId != null && songId.isNotEmpty && youtubeData != null && youtubeData.isNotEmpty) {
        final decodedData = json.decode(youtubeData);
        if (decodedData is Map<String, dynamic>) {
          await StorageService.saveYoutubeLinkForSong(songId, decodedData);
          developer.log('☁️ Updated YouTube link: $songId');
        } else {
          developer.log('⚠️ Invalid YouTube data format for $songId');
        }
      } else {
        developer.log('⚠️ YouTube links record missing songId or youtubeData');
      }
    } catch (e) {
      developer.log('❌ Error processing YouTube links record: $e');
    }
  }

  /// Process incoming saved loops record
  static Future<void> _processSavedLoopsRecord(Map<String, dynamic> record) async {
    try {
      final songId = record['songId'] as String?;
      final loopsData = record['loopsData'] as String?;
      
      if (songId != null && songId.isNotEmpty && loopsData != null && loopsData.isNotEmpty) {
        final decodedLoops = json.decode(loopsData);
        if (decodedLoops is List) {
          final loops = decodedLoops.cast<Map<String, dynamic>>();
          await StorageService.saveSavedLoopsForSong(songId, loops);
          developer.log('☁️ Updated saved loops: $songId');
        } else {
          developer.log('⚠️ Invalid saved loops data format for $songId');
        }
      } else {
        developer.log('⚠️ Saved loops record missing songId or loopsData');
      }
    } catch (e) {
      developer.log('❌ Error processing saved loops record: $e');
    }
  }

  /// Process incoming custom songs record
  static Future<void> _processCustomSongsRecord(Map<String, dynamic> record) async {
    try {
      final songsData = record['songsData'] as String?;
      
      if (songsData != null && songsData.isNotEmpty) {
        final decodedSongs = json.decode(songsData);
        if (decodedSongs is List) {
          final songs = decodedSongs.cast<Map<String, dynamic>>();
          await StorageService.saveCustomSongs(songs);
          developer.log('☁️ Updated custom songs');
        } else {
          developer.log('⚠️ Invalid custom songs data format');
        }
      } else {
        developer.log('⚠️ Custom songs record missing songsData');
      }
    } catch (e) {
      developer.log('❌ Error processing custom songs record: $e');
    }
  }

  /// Process incoming YouTube videos record
  static Future<void> _processYoutubeVideosRecord(Map<String, dynamic> record) async {
    try {
      final videosData = record['videosData'] as String?;
      
      if (videosData != null && videosData.isNotEmpty) {
        final decodedVideos = json.decode(videosData);
        if (decodedVideos is List) {
          final videos = decodedVideos.cast<Map<String, dynamic>>();
          await StorageService.saveYoutubeVideosList(videos);
          developer.log('☁️ Updated YouTube videos list');
        } else {
          developer.log('⚠️ Invalid YouTube videos data format');
        }
      } else {
        developer.log('⚠️ YouTube videos record missing videosData');
      }
    } catch (e) {
      developer.log('❌ Error processing YouTube videos record: $e');
    }
  }

  /// Process incoming labels record
  static Future<void> _processLabelsRecord(Map<String, dynamic> record) async {
    try {
      final songAssetPath = record['songAssetPath'] as String?;
      final page = record['page'] as int?;
      final labelsData = record['labelsData'] as String?;
      
      if (songAssetPath != null && songAssetPath.isNotEmpty && 
          page != null && labelsData != null && labelsData.isNotEmpty) {
        final decodedLabels = json.decode(labelsData);
        if (decodedLabels is List) {
          // Convert back to proper label objects
          final labels = decodedLabels.map((data) {
            return _createLabelFromJson(data);
          }).toList();
          await StorageService.saveLabelsForPage(songAssetPath, page, labels);
          developer.log('☁️ Updated labels: $songAssetPath page $page');
        } else {
          developer.log('⚠️ Invalid labels data format for $songAssetPath page $page');
        }
      } else {
        developer.log('⚠️ Labels record missing required fields');
      }
    } catch (e) {
      developer.log('❌ Error processing labels record: $e');
    }
  }

  /// Create a label object from JSON data (mock implementation)
  /// In a real app, this would create the appropriate label type based on the data
  static dynamic _createLabelFromJson(dynamic data) {
    // This is a mock implementation - in the real app you would have:
    // if (data['type'] == 'TextLabel') return TextLabel.fromJson(data);
    // if (data['type'] == 'ShapeLabel') return ShapeLabel.fromJson(data);
    // etc.
    
    // For now, return a mock label object that has a toJson method
    return MockLabel.fromJson(data as Map<String, dynamic>);
  }
}

/// Mock label class for development - replace with actual label classes
class MockLabel {
  final Map<String, dynamic> data;
  
  MockLabel(this.data);
  
  factory MockLabel.fromJson(Map<String, dynamic> json) {
    return MockLabel(json);
  }
  
  Map<String, dynamic> toJson() {
    return data;
  }
}