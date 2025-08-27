import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  conflict,
}

class SyncResult {
  final bool success;
  final String? error;
  final List<ConflictItem> conflicts;

  const SyncResult({
    required this.success,
    this.error,
    this.conflicts = const [],
  });

  factory SyncResult.success() => const SyncResult(success: true);
  factory SyncResult.error(String error) => SyncResult(success: false, error: error);
  factory SyncResult.conflicts(List<ConflictItem> conflicts) => SyncResult(success: false, conflicts: conflicts);
}

class ConflictItem {
  final String fileName;
  final DateTime localModified;
  final DateTime icloudModified;
  final String localPath;
  final String icloudPath;

  const ConflictItem({
    required this.fileName,
    required this.localModified,
    required this.icloudModified,
    required this.localPath,
    required this.icloudPath,
  });
}

class ICloudSyncService {
  static const MethodChannel _channel = MethodChannel('icloud_documents_sync');
  
  // Cached directories for performance
  Directory? _localDirectory;
  
  // Sync status tracking
  SyncStatus _syncStatus = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncTime;
  
  // Event listeners
  final List<Function(SyncStatus)> _statusListeners = [];
  final List<Function(double)> _progressListeners = [];

  /// Get current sync status
  SyncStatus get syncStatus => _syncStatus;
  
  /// Get last error message
  String? get lastError => _lastError;
  
  /// Get last successful sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Add sync status listener
  void addStatusListener(Function(SyncStatus) listener) {
    _statusListeners.add(listener);
  }

  /// Remove sync status listener
  void removeStatusListener(Function(SyncStatus) listener) {
    _statusListeners.remove(listener);
  }

  /// Add sync progress listener
  void addProgressListener(Function(double) listener) {
    _progressListeners.add(listener);
  }

  /// Remove sync progress listener
  void removeProgressListener(Function(double) listener) {
    _progressListeners.remove(listener);
  }

  /// Notify status listeners
  void _notifyStatus(SyncStatus status) {
    _syncStatus = status;
    for (final listener in _statusListeners) {
      listener(status);
    }
  }

  /// Notify progress listeners
  void _notifyProgress(double progress) {
    for (final listener in _progressListeners) {
      listener(progress);
    }
  }

  /// Get local directory
  Future<Directory> get _getLocalDirectory async {
    _localDirectory ??= await getApplicationDocumentsDirectory();
    return _localDirectory!;
  }

  /// Initialize the sync service
  Future<void> initialize() async {
    try {
      _localDirectory = await getApplicationDocumentsDirectory();
      developer.log('ICloudSyncService initialized successfully');
    } catch (e) {
      developer.log('Failed to initialize ICloudSyncService: $e');
      rethrow;
    }
  }

  /// Check if iCloud is available
  Future<bool> isICloudAvailable() async {
    try {
      final result = await _channel.invokeMethod('isICloudAvailable');
      return result as bool;
    } catch (e) {
      developer.log('iCloud not available: $e');
      return false;
    }
  }

  /// Get iCloud account status
  Future<String> getAccountStatus() async {
    try {
      final result = await _channel.invokeMethod('getICloudAccountStatus');
      return result as String? ?? 'notAvailable';
    } catch (e) {
      developer.log('Failed to get iCloud account status: $e');
      return 'notAvailable';
    }
  }

  /// Sync a single JSON file to iCloud
  Future<SyncResult> syncJsonFile(String fileName) async {
    try {
      _notifyStatus(SyncStatus.syncing);
      
      final result = await _channel.invokeMethod('syncFileToICloud', {
        'fileName': fileName,
      });
      
      final response = Map<String, dynamic>.from(result as Map);
      
      if (response['success'] == true) {
        developer.log('Successfully synced $fileName to iCloud');
        _lastSyncTime = DateTime.now();
        _notifyStatus(SyncStatus.success);
        return SyncResult.success();
      } else {
        final error = response['error'] as String? ?? 'Unknown error';
        
        // Check if it's a conflict
        if (error.contains('Conflict detected')) {
          _notifyStatus(SyncStatus.conflict);
          // Create a conflict item (simplified for now)
          final conflict = ConflictItem(
            fileName: fileName,
            localModified: DateTime.now(),
            icloudModified: DateTime.now(),
            localPath: fileName,
            icloudPath: fileName,
          );
          return SyncResult.conflicts([conflict]);
        }
        
        _lastError = 'Failed to sync JSON $fileName: $error';
        developer.log('❌ $_lastError');
        _notifyStatus(SyncStatus.error);
        return SyncResult.error(_lastError!);
      }
    } catch (e) {
      _lastError = 'Failed to sync JSON $fileName: $e';
      developer.log('❌ $_lastError');
      _notifyStatus(SyncStatus.error);
      return SyncResult.error(_lastError!);
    }
  }

  /// Sync a PDF file to iCloud
  Future<SyncResult> syncPdfFile(String fileName) async {
    try {
      _notifyStatus(SyncStatus.syncing);
      
      final result = await _channel.invokeMethod('syncFileToICloud', {
        'fileName': fileName,
      });
      
      final response = Map<String, dynamic>.from(result as Map);
      
      if (response['success'] == true) {
        developer.log('Successfully synced PDF $fileName to iCloud');
        _lastSyncTime = DateTime.now();
        _notifyStatus(SyncStatus.success);
        return SyncResult.success();
      } else {
        final error = response['error'] as String? ?? 'Unknown error';
        _lastError = 'Failed to sync PDF $fileName: $error';
        developer.log('❌ $_lastError');
        _notifyStatus(SyncStatus.error);
        return SyncResult.error(_lastError!);
      }
    } catch (e) {
      _lastError = 'Failed to sync PDF $fileName: $e';
      developer.log('❌ $_lastError');
      _notifyStatus(SyncStatus.error);
      return SyncResult.error(_lastError!);
    }
  }

  /// Force sync a file to iCloud, ignoring conflicts
  Future<SyncResult> forceSyncFile(String fileName) async {
    try {
      _notifyStatus(SyncStatus.syncing);
      
      final result = await _channel.invokeMethod('forceSyncFileToICloud', {
        'fileName': fileName,
      });
      
      final response = Map<String, dynamic>.from(result as Map);
      
      if (response['success'] == true) {
        developer.log('Successfully force-synced $fileName to iCloud');
        _lastSyncTime = DateTime.now();
        _notifyStatus(SyncStatus.success);
        return SyncResult.success();
      } else {
        final error = response['error'] as String? ?? 'Unknown error';
        _lastError = 'Failed to force-sync $fileName: $error';
        developer.log('❌ $_lastError');
        _notifyStatus(SyncStatus.error);
        return SyncResult.error(_lastError!);
      }
    } catch (e) {
      _lastError = 'Failed to force-sync $fileName: $e';
      developer.log('❌ $_lastError');
      _notifyStatus(SyncStatus.error);
      return SyncResult.error(_lastError!);
    }
  }

  /// Download a file from iCloud to local storage
  Future<SyncResult> downloadFile(String fileName) async {
    try {
      _notifyStatus(SyncStatus.syncing);
      
      final result = await _channel.invokeMethod('downloadFileFromICloud', {
        'fileName': fileName,
      });
      
      final response = Map<String, dynamic>.from(result as Map);
      
      if (response['success'] == true) {
        developer.log('Successfully downloaded $fileName from iCloud');
        _notifyStatus(SyncStatus.success);
        return SyncResult.success();
      } else {
        final error = response['error'] as String? ?? 'Unknown error';
        _lastError = 'Failed to download $fileName: $error';
        developer.log('❌ $_lastError');
        _notifyStatus(SyncStatus.error);
        return SyncResult.error(_lastError!);
      }
    } catch (e) {
      _lastError = 'Failed to download $fileName: $e';
      developer.log('❌ $_lastError');
      _notifyStatus(SyncStatus.error);
      return SyncResult.error(_lastError!);
    }
  }

  /// Get sync status for a specific file
  Future<Map<String, dynamic>> getFileSyncStatus(String fileName) async {
    try {
      final result = await _channel.invokeMethod('getFileSyncStatus', {
        'fileName': fileName,
      });
      
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      developer.log('Failed to get sync status for $fileName: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// List all files in iCloud
  Future<List<String>> listICloudFiles() async {
    try {
      final result = await _channel.invokeMethod('listICloudFiles');
      final response = Map<String, dynamic>.from(result as Map);
      
      if (response['success'] == true) {
        final files = response['files'] as List<dynamic>? ?? [];
        return files.cast<String>();
      } else {
        developer.log('Failed to list iCloud files: ${response['error']}');
        return [];
      }
    } catch (e) {
      developer.log('Failed to list iCloud files: $e');
      return [];
    }
  }

  /// Resolve a conflict for a specific file
  Future<SyncResult> resolveConflict(String fileName, String resolution) async {
    try {
      _notifyStatus(SyncStatus.syncing);
      
      final result = await _channel.invokeMethod('resolveConflict', {
        'fileName': fileName,
        'resolution': resolution, // 'useLocal' or 'useICloud'
      });
      
      final response = Map<String, dynamic>.from(result as Map);
      
      if (response['success'] == true) {
        developer.log('Successfully resolved conflict for $fileName');
        _notifyStatus(SyncStatus.success);
        return SyncResult.success();
      } else {
        final error = response['error'] as String? ?? 'Unknown error';
        _lastError = 'Failed to resolve conflict for $fileName: $error';
        developer.log('❌ $_lastError');
        _notifyStatus(SyncStatus.error);
        return SyncResult.error(_lastError!);
      }
    } catch (e) {
      _lastError = 'Failed to resolve conflict for $fileName: $e';
      developer.log('❌ $_lastError');
      _notifyStatus(SyncStatus.error);
      return SyncResult.error(_lastError!);
    }
  }

  /// Resolve conflict by keeping the local version
  Future<SyncResult> resolveConflictWithLocal(ConflictItem conflict) async {
    developer.log('🔄 Resolving conflict with local version for: ${conflict.fileName}');
    return await resolveConflict(conflict.fileName, 'useLocal');
  }

  /// Resolve conflict by keeping the iCloud version
  Future<SyncResult> resolveConflictWithICloud(ConflictItem conflict) async {
    developer.log('🔄 Resolving conflict with iCloud version for: ${conflict.fileName}');
    return await resolveConflict(conflict.fileName, 'useICloud');
  }

  /// Delete a file from iCloud
  Future<SyncResult> deleteFile(String fileName) async {
    try {
      final result = await _channel.invokeMethod('deleteFileFromICloud', {
        'fileName': fileName,
      });
      
      final response = Map<String, dynamic>.from(result as Map);
      
      if (response['success'] == true) {
        developer.log('Successfully deleted $fileName from iCloud');
        return SyncResult.success();
      } else {
        final error = response['error'] as String? ?? 'Unknown error';
        developer.log('Failed to delete $fileName: $error');
        return SyncResult.error(error);
      }
    } catch (e) {
      developer.log('Failed to delete $fileName: $e');
      return SyncResult.error(e.toString());
    }
  }

  /// Sync all data to iCloud
  Future<SyncResult> syncAllData() async {
    try {
      _notifyStatus(SyncStatus.syncing);
      _notifyProgress(0.0);
      
      final conflicts = <ConflictItem>[];
      
      // Get the actual local directory to check which files exist
      final localDir = await _getLocalDirectory;
      
      // List of JSON files that we want to sync (if they exist)
      final potentialJsonFiles = [
        'custom_songs.json',
        'practice_sessions.json',
        'practice_areas.json',
        'practice_items.json',
        'weekly_schedule.json',
        'song_changes.json',
        'chord_keys.json',
        'sheet_music.json',
        'drawings.json',
        'pdf_drawings.json',
      ];
      
      // Filter to only include files that actually exist locally
      final existingJsonFiles = <String>[];
      for (final fileName in potentialJsonFiles) {
        final file = File('${localDir.path}/$fileName');
        if (await file.exists()) {
          existingJsonFiles.add(fileName);
          developer.log('✅ Found JSON file to sync: $fileName');
        } else {
          developer.log('⚠️ JSON file does not exist locally, skipping: $fileName');
        }
      }
      
      developer.log('📊 Found ${existingJsonFiles.length} JSON files to sync');
      
      // Sync JSON files (30% of progress)
      if (existingJsonFiles.isNotEmpty) {
        for (int i = 0; i < existingJsonFiles.length; i++) {
          final result = await syncJsonFile(existingJsonFiles[i]);
          if (!result.success) {
            conflicts.addAll(result.conflicts);
            if (result.error != null) {
              return result; // Return early on error
            }
          }
          _notifyProgress((i + 1) / existingJsonFiles.length * 0.3);
        }
      } else {
        developer.log('⚠️ No JSON files found to sync');
        _notifyProgress(0.3); // Still update progress to 30%
      }
      
      // Sync PDF files and label files (70% of progress)
      final allFilesToSync = <String>[];
      
      // Add PDF files
      try {
        final allFiles = await localDir.list().toList();
        final pdfFiles = allFiles.where((f) => f.path.endsWith('.pdf'));
        final pdfFileNames = pdfFiles.map((f) => f.path.split('/').last).toList();
        
        developer.log('📄 Found ${pdfFileNames.length} PDF files:');
        for (final pdfName in pdfFileNames) {
          developer.log('  - $pdfName');
        }
        
        allFilesToSync.addAll(pdfFileNames);
        
        // Add Roman numeral and extension label files
        final labelFiles = allFiles.where((f) => 
          f.path.endsWith('_labels.json') || 
          f.path.endsWith('_romanNumeral_labels.json') ||
          f.path.endsWith('_extension_labels.json')
        );
        final labelFileNames = labelFiles.map((f) => f.path.split('/').last).toList();
        
        developer.log('🏷️ Found ${labelFileNames.length} label files:');
        for (final labelName in labelFileNames) {
          developer.log('  - $labelName');
        }
        
        allFilesToSync.addAll(labelFileNames);
      } catch (e) {
        developer.log('Failed to list local files: $e');
      }
      
      for (int i = 0; i < allFilesToSync.length; i++) {
        final fileName = allFilesToSync[i];
        developer.log('🔄 Syncing file: $fileName (${i + 1}/${allFilesToSync.length})');
        
        SyncResult result;
        if (fileName.endsWith('.pdf')) {
          result = await syncPdfFile(fileName);
        } else {
          // Sync label files as JSON
          result = await syncJsonFile(fileName);
        }
        
        if (!result.success) {
          conflicts.addAll(result.conflicts);
          if (result.error != null && result.error!.contains('Conflict detected')) {
            // Try force sync for conflicts
            developer.log('🔄 Attempting force sync for conflicted file: $fileName');
            result = await forceSyncFile(fileName);
            if (!result.success && result.error != null) {
              return result; // Return early if force sync also failed
            }
          } else if (result.error != null) {
            return result; // Return early on non-conflict errors
          }
        }
        _notifyProgress(0.3 + ((i + 1) / allFilesToSync.length * 0.7));
      }
      
      _notifyProgress(1.0);
      
      if (conflicts.isNotEmpty) {
        _notifyStatus(SyncStatus.conflict);
        return SyncResult.conflicts(conflicts);
      } else {
        _lastSyncTime = DateTime.now();
        _notifyStatus(SyncStatus.success);
        developer.log('✅ Successfully synced all data to iCloud');
        return SyncResult.success();
      }
    } catch (e) {
      _lastError = 'Failed to sync all data: $e';
      developer.log('❌ $_lastError');
      _notifyStatus(SyncStatus.error);
      return SyncResult.error(_lastError!);
    }
  }

  /// Get storage usage information
  Future<Map<String, int>> getStorageUsage() async {
    try {
      final result = await _channel.invokeMethod('getStorageUsage');
      final response = Map<String, dynamic>.from(result as Map);
      
      if (response['success'] == true) {
        final usage = Map<String, dynamic>.from(response['usage'] as Map);
        return {
          'totalSize': usage['totalSize'] as int? ?? 0,
          'fileCount': usage['fileCount'] as int? ?? 0,
          'jsonSize': usage['jsonSize'] as int? ?? 0,
          'pdfSize': usage['pdfSize'] as int? ?? 0,
        };
      } else {
        developer.log('Failed to get storage usage: ${response['error']}');
        return {
          'totalSize': 0,
          'fileCount': 0,
          'jsonSize': 0,
          'pdfSize': 0,
        };
      }
    } catch (e) {
      developer.log('Failed to get storage usage: $e');
      return {
        'totalSize': 0,
        'fileCount': 0,
        'jsonSize': 0,
        'pdfSize': 0,
      };
    }
  }

  /// Get comprehensive diagnostic information for troubleshooting
  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    try {
      final diagnostics = <String, dynamic>{};
      
      developer.log('🔍 Starting comprehensive iCloud diagnostics...');
      
      // Basic availability
      diagnostics['isAvailable'] = await isICloudAvailable();
      diagnostics['accountStatus'] = await getAccountStatus();
      
      // Sync service status
      diagnostics['syncStatus'] = _syncStatus.toString();
      diagnostics['lastError'] = _lastError;
      diagnostics['lastSyncTime'] = _lastSyncTime?.toString();
      
      // Device and environment info
      try {
        final result = await _channel.invokeMethod('getEnvironmentInfo');
        if (result != null) {
          diagnostics['environment'] = Map<String, dynamic>.from(result as Map);
        }
      } catch (e) {
        diagnostics['environmentError'] = e.toString();
      }
      
      // Try to get storage usage (will fail if not available)
      try {
        diagnostics['storageUsage'] = await getStorageUsage();
      } catch (e) {
        diagnostics['storageUsageError'] = e.toString();
      }
      
      // Try to list files (will fail if not available)
      try {
        diagnostics['iCloudFiles'] = await listICloudFiles();
      } catch (e) {
        diagnostics['listFilesError'] = e.toString();
      }
      
      // Try a simple sync test
      try {
        // Try to sync a small test file
        developer.log('🧪 Attempting test sync...');
        final testResult = await syncJsonFile('test_diagnostic.json');
        diagnostics['testSyncResult'] = {
          'success': testResult.success,
          'error': testResult.error,
        };
      } catch (e) {
        diagnostics['testSyncError'] = e.toString();
      }
      
      developer.log('📊 Diagnostics complete: $diagnostics');
      return diagnostics;
    } catch (e) {
      developer.log('❌ Diagnostics failed: $e');
      return {'diagnosticError': e.toString()};
    }
  }

  /// List all files in the local documents directory for debugging
  Future<List<String>> listLocalFiles() async {
    try {
      final localDir = await _getLocalDirectory;
      final allFiles = await localDir.list().toList();
      final fileNames = allFiles.map((f) => f.path.split('/').last).toList();
      
      developer.log('📁 Local documents directory contains ${fileNames.length} files:');
      for (final name in fileNames) {
        developer.log('  - $name');
      }
      
      return fileNames;
    } catch (e) {
      developer.log('❌ Failed to list local files: $e');
      return [];
    }
  }

  /// Dispose the service
  void dispose() {
    _statusListeners.clear();
    _progressListeners.clear();
  }
}