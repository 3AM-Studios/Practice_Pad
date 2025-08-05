import 'package:flutter/foundation.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';
// import 'package:practice_pad/services/cloud_kit_service.dart'; // SIDELINED
import 'dart:developer' as developer; // For logging
import 'dart:math'; // For random ID generation

class EditItemsViewModel extends ChangeNotifier {
  // final CloudKitService _cloudKitService = CloudKitService.instance(); // SIDELINED

  final List<PracticeArea> _areas = [];
  List<PracticeArea> get areas => _areas;

  // NEW: Type-based getters
  List<PracticeArea> get songAreas => _areas.where((area) => area.type == PracticeAreaType.song).toList();
  List<PracticeArea> get exerciseAreas => _areas.where((area) => area.type == PracticeAreaType.exercise).toList();

  bool _isLoadingAreas = false;
  bool get isLoadingAreas => _isLoadingAreas;

  final Map<String, bool> _isLoadingItemsForArea = {}; // Key: PracticeArea.recordName
  bool isLoadingItemsForArea(String areaRecordName) =>
      _isLoadingItemsForArea[areaRecordName] ?? false;

  String? _error;
  String? get error => _error;

  // Temporary local data store
  final Random _random = Random();
  int _nextAreaId = 1;
  int _nextItemId = 1;

  String _generateLocalAreaRecordName() {
    return "local_area_${_nextAreaId++}_${_random.nextInt(99999)}";
  }

  String _generateLocalItemId() {
    return "local_item_${_nextItemId++}_${_random.nextInt(99999)}";
  }

  Future<void> fetchPracticeAreas() async {
    developer.log("ViewModel: Starting fetchPracticeAreas (LOCAL DATA)",
        name: 'EditItemsViewModel');
    _isLoadingAreas = true;
    _error = null;
    // notifyListeners(); // Avoid notifying before the simulated delay if it causes quick flashes

    await Future.delayed(
        const Duration(milliseconds: 100)); // Simulate network delay

    // REMOVED: Default data generation
    // if (_areas.isEmpty) {
    //   final area1Id = _generateLocalAreaRecordName();
    //   final area2Id = _generateLocalAreaRecordName();
    //   _areas = [
    //     PracticeArea(recordName: area1Id, name: 'Scales'),
    //     PracticeArea(recordName: area2Id, name: 'Chords'),
    //   ];
    //   _itemsByArea[area1Id] = [
    //     PracticeItem(
    //         id: _generateLocalItemId(),
    //         practiceAreaRecordName: area1Id,
    //         name: 'C Major Scale',
    //         description: '2 octaves, ascending and descending'),
    //     PracticeItem(
    //         id: _generateLocalItemId(),
    //         practiceAreaRecordName: area1Id,
    //         name: 'A Minor Pentatonic',
    //         description: 'Focus on alternate picking.'),
    //   ];
    //   _itemsByArea[area2Id] = [
    //     PracticeItem(
    //         id: _generateLocalItemId(),
    //         practiceAreaRecordName: area2Id,
    //         name: 'Basic Chord Voicings (C, G, Am, F)',
    //         description: 'Practice clean transitions.'),
    //   ];
    // }
    _isLoadingAreas = false;
    developer.log(
        "ViewModel: Fetched ${_areas.length} areas (LOCAL DATA) - No default data added.",
        name: 'EditItemsViewModel');
    notifyListeners();
  }

  Future<void> addPracticeArea(String name, PracticeAreaType type) async {
    developer.log("ViewModel: Adding practice area (LOCAL DATA): $name of type $type",
        name: 'EditItemsViewModel');
    _error = null;

    final newAreaRecordName = _generateLocalAreaRecordName();
    final newArea = PracticeArea(recordName: newAreaRecordName, name: name, type: type);
    
    // Add default items for song type areas
    if (type == PracticeAreaType.song) {
      newArea.addDefaultSongItems();
    }
    
    _areas.add(newArea);

    developer.log(
        "ViewModel: Practice area '$name' added locally with ID: $newAreaRecordName",
        name: 'EditItemsViewModel');
    notifyListeners();
  }

  Future<void> addPracticeAreaWithSong(String name, Song song) async {
    developer.log("ViewModel: Adding song practice area (LOCAL DATA): $name with song ${song.title}",
        name: 'EditItemsViewModel');
    _error = null;

    final newAreaRecordName = _generateLocalAreaRecordName();
    final newArea = PracticeArea(
      recordName: newAreaRecordName, 
      name: name, 
      type: PracticeAreaType.song,
      song: song,
    );
    
    // Add default items for song type areas
    newArea.addDefaultSongItems();
    
    _areas.add(newArea);

    developer.log(
        "ViewModel: Song practice area '$name' added locally with ID: $newAreaRecordName",
        name: 'EditItemsViewModel');
    notifyListeners();
  }

  Future<void> updatePracticeArea(PracticeArea areaToUpdate) async {
    developer.log(
        "ViewModel: Updating practice area (LOCAL DATA): ${areaToUpdate.name}",
        name: 'EditItemsViewModel');
    _error = null;
    final index =
        _areas.indexWhere((a) => a.recordName == areaToUpdate.recordName);
    if (index != -1) {
      _areas[index] = areaToUpdate;
      developer.log(
          "ViewModel: Practice area '${areaToUpdate.name}' updated locally",
          name: 'EditItemsViewModel');
    } else {
      developer.log(
          "ViewModel: Practice area not found for update (LOCAL DATA): ${areaToUpdate.recordName}",
          name: 'EditItemsViewModel');
    }
    notifyListeners();
  }

  Future<void> deletePracticeArea(String recordName) async {
    developer.log("ViewModel: Deleting practice area (LOCAL DATA): $recordName",
        name: 'EditItemsViewModel');
    _error = null;
    _areas.removeWhere((area) => area.recordName == recordName);
    developer.log("ViewModel: Practice area $recordName deleted locally",
        name: 'EditItemsViewModel');
    notifyListeners();
  }

  // --- PracticeItem Methods for LOCAL DATA ---
  Future<List<PracticeItem>> fetchPracticeItemsForArea(
      String areaRecordName) async {
    developer.log(
        "ViewModel: Fetching items for area $areaRecordName (LOCAL DATA)",
        name: 'EditItemsViewModel');

    _isLoadingItemsForArea[areaRecordName] = true;
    _error = null;

    await Future.microtask(() {
      notifyListeners();
    });

    await Future.delayed(const Duration(milliseconds: 50));

    final area = _areas.firstWhere(
      (area) => area.recordName == areaRecordName,
      orElse: () => throw Exception('Area not found'),
    );
    final items = area.practiceItems;

    _isLoadingItemsForArea[areaRecordName] = false;
    developer.log(
        "ViewModel: Fetched ${items.length} items for area $areaRecordName (LOCAL DATA)",
        name: 'EditItemsViewModel');
    notifyListeners();
    return items;
  }

  Future<void> addPracticeItem(String areaRecordName, PracticeItem item) async {
    developer.log(
        "ViewModel: Adding item '${item.name}' to area $areaRecordName (LOCAL DATA)",
        name: 'EditItemsViewModel');
    
    final newItem = item.copyWith(id: _generateLocalItemId());

    final area = _areas.firstWhere(
      (area) => area.recordName == areaRecordName,
      orElse: () => throw Exception('Area not found'),
    );
    
    area.addPracticeItem(newItem);
    
    developer.log(
        "ViewModel: Item '${newItem.name}' added locally with ID: ${newItem.id}",
        name: 'EditItemsViewModel');
    notifyListeners();
  }

  Future<void> updatePracticeItem(String areaRecordName, PracticeItem itemToUpdate) async {
    developer.log(
        "ViewModel: Updating item '${itemToUpdate.name}' in area $areaRecordName (LOCAL DATA)",
        name: 'EditItemsViewModel');
    
    final area = _areas.firstWhere(
      (area) => area.recordName == areaRecordName,
      orElse: () => throw Exception('Area not found'),
    );
    
    area.updatePracticeItem(itemToUpdate);
    
    developer.log("ViewModel: Item '${itemToUpdate.name}' updated locally",
        name: 'EditItemsViewModel');
    notifyListeners();
  }

  Future<void> deletePracticeItem(String itemId, String areaRecordName) async {
    developer.log(
        "ViewModel: Deleting item $itemId from area $areaRecordName (LOCAL DATA)",
        name: 'EditItemsViewModel');
    
    final area = _areas.firstWhere(
      (area) => area.recordName == areaRecordName,
      orElse: () => throw Exception('Area not found'),
    );
    
    area.removePracticeItem(itemId);
    
    developer.log(
        "ViewModel: Item $itemId deleted locally from area $areaRecordName",
        name: 'EditItemsViewModel');
    notifyListeners();
  }

  // NEW: Helper method to get practice area by record name
  PracticeArea? getPracticeAreaByRecordName(String recordName) {
    try {
      return _areas.firstWhere((area) => area.recordName == recordName);
    } catch (e) {
      return null;
    }
  }

  // NEW: Helper method to get all practice items across all areas (for routines)
  List<PracticeItem> getAllPracticeItems() {
    final allItems = <PracticeItem>[];
    for (final area in _areas) {
      allItems.addAll(area.practiceItems);
    }
    return allItems;
  }

  // NEW: Helper method to get practice items for a specific area type
  List<PracticeItem> getPracticeItemsByType(PracticeAreaType type) {
    final allItems = <PracticeItem>[];
    for (final area in _areas.where((area) => area.type == type)) {
      allItems.addAll(area.practiceItems);
    }
    return allItems;
  }

  // NEW: Helper method for backward compatibility - get items for area
  List<PracticeItem> getItemsForArea(String areaRecordName) {
    final area = getPracticeAreaByRecordName(areaRecordName);
    return area?.practiceItems ?? [];
  }
}
