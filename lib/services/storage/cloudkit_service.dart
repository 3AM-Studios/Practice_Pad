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
  static final FlutterCloudKit _cloudKit =
      FlutterCloudKit(containerId: 'iCloud.com.3amstudios.jazzpad');

  static const _recordTypes = [
    'PracticeArea',
    'PracticeItem', 
    'Book',
    'SongPdf', // Note: changed from SongPDF to SongPdf to match your CloudKit records
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
  

  static String _sanitizeRecordKey(String key) {
    return key.replaceAll(RegExp(r'[/\:*?"<>| .\-]'), '_');
  }

  static Future<bool> isAccountAvailable() async {
    try {
      final accountStatus = await _cloudKit.getAccountStatus();
      return accountStatus == CloudKitAccountStatus.available;
    } catch (e) {
      developer.log('❌ Error checking CloudKit account status: $e');
      return false;
    }
  }

  static Future<String?> saveRecord(Map<String, dynamic> record) async {
    try {
      final recordType = record['recordType'] as String;
      final recordName = record['recordName'] as String;

      if (!await isAccountAvailable()) {
        throw Exception('User must be logged in to iCloud to save data');
      }

      final recordKey = _sanitizeRecordKey('${recordType}_$recordName');
      
      // Filter out reserved CloudKit field names
      final filteredRecord = Map<String, dynamic>.from(record);
      filteredRecord.removeWhere((key, value) => 
        key == 'recordType' || 
        key == 'recordName' || 
        key == 'recordChangeTag'
      );
      
      final recordToSave = Map<String, String>.from(filteredRecord.map((key, value) {
        if (value is Map || value is List) {
          return MapEntry(key, json.encode(value));
        }
        return MapEntry(key, value.toString());
      }));

      await _cloudKit.saveRecord(
        scope: CloudKitDatabaseScope.private,
        recordType: recordType,
        recordName: recordKey,
        record: recordToSave,
      );

      developer.log('✅ Record saved to CloudKit: $recordKey');
      // Return a timestamp-based change tag for local tracking
      return 'local_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      developer.log('❌ Error saving record to CloudKit: $e');
      rethrow;
    }
  }
 /// Saves a record with associated file assets to a CloudKit database.
  ///
  /// - [recordType]: The name of the record type in your schema (e.g., 'Book').
  /// - [recordName]: The unique ID for this record.
  /// - [record]: A map of string-based fields for the record (e.g., {'title': 'The Real Book'}).
  /// - [assets]: A map where keys are asset field names (e.g., 'pdfFile')
  ///   and values are [CloudKitAsset] objects pointing to the local file.
  ///
  /// Returns the server 'changeTag' upon success, which can be used for caching.
  static Future<String?> saveRecordWithAssets({
    required String recordType,
    required String recordName,
    Map<String, String> record = const {},
    Map<String, CloudKitAsset> assets = const {},
  }) async {
    try {
      if (!await isAccountAvailable()) {
        throw Exception('User must be logged in to iCloud to save data');
      }

      // Sanitize the record name to create a unique, safe key for CloudKit.
      final recordKey = _sanitizeRecordKey('${recordType}_$recordName');

      // Filter out reserved CloudKit field names and create a mutable copy
      final filteredRecord = Map<String, String>.from(record);
      filteredRecord.removeWhere((key, value) => 
        key == 'recordType' || 
        key == 'recordName' || 
        key == 'recordChangeTag'
      );
      
      final recordToSave = Map<String, String>.from(filteredRecord);

      // Call the existing CloudKit method to upload the record and its assets.
      await _cloudKit.saveRecordWithAssets(
        scope: CloudKitDatabaseScope.private,
        recordType: recordType,
        recordName: recordKey,
        record: recordToSave,
        assets: assets,
      );

      developer.log('✅ Record with assets saved to CloudKit: $recordKey');
      // Return a timestamp-based change tag for local tracking
      return 'local_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      developer.log('❌ Error saving record with assets to CloudKit: $e');
      // Rethrow the error to be handled by the calling function in StorageService.
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>?> getRecord(String recordKey) async {
    try {
      if (!await isAccountAvailable()) return null;

      final sanitizedKey = _sanitizeRecordKey(recordKey);
      final cloudKitRecord = await _cloudKit.getRecord(
        scope: CloudKitDatabaseScope.private,
        recordName: sanitizedKey,
      );

      final recordData = <String, dynamic>{};
      cloudKitRecord.values.forEach((key, value) {
        try {
          // Try to decode as JSON first
          recordData[key] = json.decode(value);
        } catch (_) {
          // If it's not JSON, check if it might be an asset
          if (_isAssetField(key, value)) {
            recordData[key] = _parseCloudKitAsset(value, key, cloudKitRecord.recordName);
          } else {
            recordData[key] = value;
          }
        }
      });
      return recordData;
    } catch (e) {
      return null;
    }
  }

  /// Checks if a field represents a CloudKit asset
  static bool _isAssetField(String key, String value) {
    // Asset fields typically end with 'File' or contain asset indicators
    return key.toLowerCase().contains('file') || 
           key.toLowerCase().contains('asset') ||
           value.contains('file://') || 
           value.contains('.tmp/') ||
           value.contains('CloudKit');
  }

  /// Parses a CloudKit asset from the raw value
  static CloudKitAsset _parseCloudKitAsset(String rawValue, String fieldName, String recordName) {
    try {
      // In real CloudKit, assets come back as file URLs in staging area
      // The format might be: file:///path/to/staging/area/filename
      // Or it could be a structured response with metadata
      
      if (rawValue.startsWith('file://')) {
        // Direct file URL from staging area
        return CloudKitAsset.fromStaging(
          fileURL: rawValue,
          recordIdentifier: recordName,
          fetchedAt: DateTime.now(),
        );
      } else {
        // Try to parse as JSON in case it has metadata
        try {
          final assetData = json.decode(rawValue) as Map<String, dynamic>;
          return CloudKitAsset.fromStaging(
            fileURL: assetData['fileURL'] as String? ?? assetData['url'] as String,
            fileName: assetData['fileName'] as String?,
            recordIdentifier: recordName,
            size: assetData['size'] as int?,
            mimeType: assetData['mimeType'] as String?,
            fetchedAt: DateTime.now(),
          );
        } catch (_) {
          // Fallback: treat the entire value as a file URL
          return CloudKitAsset.fromStaging(
            fileURL: rawValue,
            recordIdentifier: recordName,
            fetchedAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      developer.log('❌ Error parsing CloudKit asset: $e');
      // Return empty asset as fallback
      return CloudKitAsset.fromStaging(
        fileURL: '',
        recordIdentifier: recordName,
        fetchedAt: DateTime.now(),
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getAllRecords() async {
    if (!await isAccountAvailable()) return [];

    final allRecords = <Map<String, dynamic>>[];
    for (final recordType in _recordTypes) {
      try {
        print('🔍 Fetching records of type: $recordType');
        final records = await _cloudKit.getRecordsByType(
          scope: CloudKitDatabaseScope.private,
          recordType: recordType,
        );
        print('   Found ${records.length} $recordType records');
        for (final record in records) {
          print('   Processing record: ${record.recordName}');
          final recordData = <String, dynamic>{};
          record.values.forEach((key, value) {
            try {
              // Try to decode as JSON first
              recordData[key] = json.decode(value);
            } catch (_) {
              // If it's not JSON, check if it might be an asset
              if (_isAssetField(key, value)) {
                recordData[key] = _parseCloudKitAsset(value, key, record.recordName);
              } else {
                recordData[key] = value;
              }
            }
          });
          recordData['recordName'] = record.recordName;
          recordData['recordType'] = record.recordType;
          allRecords.add(recordData);
        }
      } catch (e) {
        final errorMessage = e.toString();
        if (errorMessage.contains('Did not find record type')) {
          print('ℹ️ Record type $recordType does not exist in CloudKit schema - skipping');
        } else if (errorMessage.contains('not marked sortable') || errorMessage.contains('not marked queryable')) {
          print('⚠️ Schema configuration issue for $recordType: $e');
          print('   This can be fixed in CloudKit Console by updating field indexes');
        } else {
          print('⚠️ Error fetching records of type $recordType: $e');
        }
      }
    }
    return allRecords;
  }

  static Future<void> setupDatabaseSubscription() async {
    // This is a mock subscription using polling, as flutter_cloud_kit does not support real-time subscriptions.
    // We save a metadata record to indicate that the sync is set up.
    try {
      if (await _subscriptionExists()) {
        developer.log('☁️ Database subscription already exists');
        return;
      }
      await _cloudKit.saveRecord(
        scope: CloudKitDatabaseScope.private,
        recordType: 'SyncMetadata',
        recordName: 'sync_metadata',
        record: {
          'value': json.encode({
            'setupTime': DateTime.now().millisecondsSinceEpoch,
          })
        },
      );
      developer.log('☁️ CloudKit sync setup completed');
    } catch (e) {
      developer.log('❌ Error setting up CloudKit sync: $e');
    }
  }

  static Future<bool> _subscriptionExists() async {
    try {
      await _cloudKit.getRecord(
        scope: CloudKitDatabaseScope.private,
        recordName: 'sync_metadata',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> handleNotification() async {
    print('📥 Starting CloudKit sync...');
    final changedRecords = await _fetchDatabaseChanges();
    print('📥 Found ${changedRecords.length} changed records to process');
    
    for (final record in changedRecords) {
      final recordType = record['recordType'];
      final recordName = record['recordName'];
      print('📥 Processing $recordType: $recordName');
      await processIncomingRecord(record);
    }
    
    print('✅ CloudKit sync completed');
  }

  static Future<List<Map<String, dynamic>>> _fetchDatabaseChanges() async {
    print('📥 Fetching all records from CloudKit...');
    final allCloudRecords = await getAllRecords();
    print('📥 Retrieved ${allCloudRecords.length} total records from CloudKit');
    
    final changedRecords = <Map<String, dynamic>>[];
    final recordTypeCounts = <String, int>{};

    for (final cloudRecord in allCloudRecords) {
      final recordType = cloudRecord['recordType'] as String?;
      final recordName = cloudRecord['recordName'] as String?;
      final cloudChangeTag = cloudRecord['recordChangeTag'] as String?;

      if (recordType == null || recordName == null) {
        print('⚠️ Skipping record with missing type/name: $cloudRecord');
        continue;
      }
      
      // Count records by type
      recordTypeCounts[recordType] = (recordTypeCounts[recordType] ?? 0) + 1;

      final localChangeTag = await StorageService.getLocalChangeTag(recordType, recordName);
      
      print('🔍 Checking $recordType/$recordName:');
      print('   Cloud tag: $cloudChangeTag');
      print('   Local tag: $localChangeTag');

      // Handle null change tags - if either is null, consider it a change that needs syncing
      bool needsSync = false;
      if (cloudChangeTag == null && localChangeTag == null) {
        // Both null - this is a fresh sync, sync everything
        needsSync = true;
        print('🆕 Both tags null - fresh sync, will sync this record');
      } else if (cloudChangeTag != localChangeTag) {
        // Tags differ - normal change detection
        needsSync = true;
        print('✅ Change detected - will sync this record');
      } else {
        print('⚔️ No change - skipping');
      }
      
      if (needsSync) {
        changedRecords.add(cloudRecord);
      }
    }
    
    print('📊 Record counts by type: $recordTypeCounts');
    print('📥 Found ${changedRecords.length} records that need syncing');
    return changedRecords;
  }

  static Future<void> processIncomingRecord(Map<String, dynamic> record) async {
    final recordType = record['recordType'] as String?;
    if (recordType == null) return;

    // Process each record type with the appropriate update function
    try {
      print('🔍 Record type to process: "$recordType"');
      print('   Record name: "${record['recordName']}"');
      print('   Record keys: ${record.keys.toList()}');
      
      switch (recordType) {
        case 'PracticeArea':
          await StorageService.updatePracticeAreaFromCloud(record);
          break;
        case 'PracticeItem':
          await StorageService.updatePracticeItemFromCloud(record);
          break;
        case 'Book':
          await StorageService.updateBookFromCloud(record);
          break;
        case 'SongPdf':
          print('📝 Processing SongPdf record');
          await StorageService.updateSongPdfFromCloud(record);
          break;
        case 'SheetMusic':
          await StorageService.updateSheetMusicFromCloud(record);
          break;
        case 'WeeklySchedule':
          await StorageService.updateWeeklyScheduleFromCloud(record);
          break;
        case 'SongChanges':
          await StorageService.updateSongChangesFromCloud(record);
          break;
        case 'ChordKeys':
          await StorageService.updateChordKeysFromCloud(record);
          break;
        case 'Drawings':
          await StorageService.updateDrawingsFromCloud(record);
          break;
        case 'PDFDrawings':
          await StorageService.updatePDFDrawingsFromCloud(record);
          break;
        case 'YoutubeLinks':
          await StorageService.updateYoutubeLinksFromCloud(record);
          break;
        case 'SavedLoops':
          await StorageService.updateSavedLoopsFromCloud(record);
          break;
        case 'CustomSongs':
          await StorageService.updateCustomSongsFromCloud(record);
          break;
        case 'YoutubeVideos':
          await StorageService.updateYoutubeVideosFromCloud(record);
          break;
        case 'Labels':
          await StorageService.updateLabelsFromCloud(record);
          break;
        default:
          print('⚠️ Unknown record type: "$recordType" - adding debug info');
          print('   Available cases: PracticeArea, PracticeItem, Book, SongPdf, SheetMusic, WeeklySchedule, etc.');
          print('   Actual record type: "$recordType" (length: ${recordType.length})');
      }
    } catch (e) {
      developer.log('❌ Error processing incoming record of type $recordType: $e');
    }

    // Save the change tag after successful processing
    final recordName = record['recordName'] as String?;
    final changeTag = record['recordChangeTag'] as String?;
    if (recordName != null && changeTag != null) {
      await StorageService.saveLocalChangeTag(recordType, recordName, changeTag);
    }
  }
}