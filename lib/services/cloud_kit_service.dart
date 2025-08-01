import 'package:flutter/services.dart'; // For PlatformChannel
import 'package:practice_pad/models/practice_area.dart';
import 'dart:developer' as developer;

class CloudKitService {
  final String _containerId;
  // Define a unique channel name
  static const MethodChannel _channel =
      MethodChannel('iCloud.com.practicepad'); // UPDATED CHANNEL NAME

  static const String _practiceAreaRecordType = 'PracticeAreaDefinition';

  CloudKitService._privateConstructor(this._containerId);

  static CloudKitService? _instance;

  factory CloudKitService.instance() {
    if (_instance == null) {
      throw Exception(
          "CloudKitService not initialized. Call initialize() first.");
    }
    return _instance!;
  }

  // containerId is your iCloud container ID (e.g., iCloud.com.yourcompany.YourApp)
  static Future<void> initialize(String containerId) async {
    if (_instance == null) {
      _instance = CloudKitService._privateConstructor(containerId);
      developer.log(
          "CloudKitService initialized with container: $containerId for platform channel.",
          name: 'CloudKitService.initialize');
      // You can add an initial ping to the native side if needed, e.g., to check account status.
      // For now, initialization is just setting up the Dart side service.
    } else {
      developer.log("CloudKitService already initialized.",
          name: 'CloudKitService.initialize');
    }
  }

  Future<List<PracticeArea>> fetchPracticeAreas() async {
    developer.log("Dart: Invoking fetchPracticeAreas",
        name: 'CloudKitService.fetchPracticeAreas');
    try {
      final List<dynamic>? results =
          await _channel.invokeMethod('fetchRecords', {
        'containerId': _containerId,
        'recordType': _practiceAreaRecordType,
      });

      if (results == null || results.isEmpty) {
        developer.log("Dart: No practice areas returned from native.",
            name: 'CloudKitService.fetchPracticeAreas');
        return [];
      }
      // Expecting List<Map<String, dynamic>> from native side
      final areas = results
          .map((record) =>
              PracticeArea.fromCloudKitRecord(record as Map<String, dynamic>))
          .toList();
      developer.log("Dart: Fetched ${areas.length} practice areas.",
          name: 'CloudKitService.fetchPracticeAreas');
      return areas;
    } on PlatformException catch (e) {
      developer.log(
          "Dart: PlatformException fetching practice areas: ${e.message}",
          name: 'CloudKitService.fetchPracticeAreas',
          error: e);
      throw Exception(
          "Failed to fetch practice areas (Platform Error): ${e.message}");
    } catch (e) {
      developer.log("Dart: Error fetching practice areas: $e",
          name: 'CloudKitService.fetchPracticeAreas', error: e);
      throw Exception("Failed to fetch practice areas: $e");
    }
  }

  Future<PracticeArea> savePracticeArea(PracticeArea area) async {
    final isUpdate = area.recordName.isNotEmpty;
    developer.log(
        "Dart: Invoking savePracticeArea (isUpdate: $isUpdate): ${area.name}",
        name: 'CloudKitService.savePracticeArea');
    try {
      final Map<String, dynamic> recordFields = area.toCloudKitRecordFields();

      // The native side will handle assigning a recordName if it's a new record.
      // It should return the full record (including the new recordName).
      final Map<dynamic, dynamic>? savedRecordMap =
          await _channel.invokeMethod('saveRecord', {
        'containerId': _containerId,
        'recordType': _practiceAreaRecordType,
        'recordName': isUpdate ? area.recordName : null, // Null for new records
        'fields': recordFields,
      });

      if (savedRecordMap == null) {
        throw Exception(
            "Failed to save practice area: No record data returned from native code.");
      }

      // Convert the Map<dynamic, dynamic> to Map<String, dynamic>
      final Map<String, dynamic> typedSavedRecordMap =
          Map<String, dynamic>.from(savedRecordMap);

      final savedArea = PracticeArea.fromCloudKitRecord(typedSavedRecordMap);
      developer.log(
          "Dart: Practice area saved: ${savedArea.name} (RecordName: ${savedArea.recordName})",
          name: 'CloudKitService.savePracticeArea');
      return savedArea;
    } on PlatformException catch (e) {
      developer.log(
          "Dart: PlatformException saving area '${area.name}': ${e.message}",
          name: 'CloudKitService.savePracticeArea',
          error: e);
      throw Exception(
          "Failed to save practice area '${area.name}' (Platform Error): ${e.message}");
    } catch (e) {
      developer.log("Dart: Error saving area '${area.name}': $e",
          name: 'CloudKitService.savePracticeArea', error: e);
      throw Exception("Failed to save practice area '${area.name}': $e");
    }
  }

  Future<void> deletePracticeArea(String recordName) async {
    developer.log(
        "Dart: Invoking deletePracticeArea for recordName: $recordName",
        name: 'CloudKitService.deletePracticeArea');
    if (recordName.isEmpty) {
      throw ArgumentError("recordName cannot be empty for deletion.");
    }
    try {
      await _channel.invokeMethod('deleteRecord', {
        'containerId': _containerId,
        'recordName': recordName,
      });
      developer.log("Dart: Practice area delete signal sent for $recordName",
          name: 'CloudKitService.deletePracticeArea');
    } on PlatformException catch (e) {
      developer.log(
          "Dart: PlatformException deleting area '$recordName': ${e.message}",
          name: 'CloudKitService.deletePracticeArea',
          error: e);
      throw Exception(
          "Failed to delete practice area '$recordName' (Platform Error): ${e.message}");
    } catch (e) {
      developer.log("Dart: Error deleting area '$recordName': $e",
          name: 'CloudKitService.deletePracticeArea', error: e);
      throw Exception("Failed to delete practice area '$recordName': $e");
    }
  }
  // TODO: Implement methods for PracticeItem CRUD via platform channel
}
