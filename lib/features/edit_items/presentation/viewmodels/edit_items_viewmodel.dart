import 'package:flutter/foundation.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';
import 'package:practice_pad/services/storage/local_storage_service.dart';
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
  List<PracticeArea> get chordProgressionAreas => _areas.where((area) => area.type == PracticeAreaType.chordProgression).toList();
  
  // Get all exercise-type areas (includes both exercises and chord progressions)
  List<PracticeArea> get allExerciseAreas => _areas.where((area) => 
    area.type == PracticeAreaType.exercise || area.type == PracticeAreaType.chordProgression).toList();
  
  // Get the main Chord Progressions practice area (always exists)
  PracticeArea get chordProgressionsArea {
    var chordProgressionArea = _areas.firstWhere(
      (area) => area.type == PracticeAreaType.chordProgression && area.name == 'Chord Progressions',
      orElse: () => _createDefaultChordProgressionsArea(),
    );
    return chordProgressionArea;
  }
  
  PracticeArea _createDefaultChordProgressionsArea() {
    final area = PracticeArea(
      recordName: 'chord_progressions_default',
      name: 'Chord Progressions',
      type: PracticeAreaType.chordProgression,
    );
    _areas.add(area);
    return area;
  }
  
  void _ensureChordProgressionsAreaExists() {
    final exists = _areas.any(
      (area) => area.type == PracticeAreaType.chordProgression && area.name == 'Chord Progressions'
    );
    if (!exists) {
      _createDefaultChordProgressionsArea();
    }
  }

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

  /// Auto-save all data to local storage
  Future<void> _autoSave() async {
    try {
      // Save practice areas
      await LocalStorageService.savePracticeAreas(_areas);
      
      // Prepare items by area map
      final itemsByArea = <String, List<PracticeItem>>{};
      for (final area in _areas) {
        itemsByArea[area.recordName] = area.practiceItems;
      }
      
      // Save practice items
      await LocalStorageService.savePracticeItems(itemsByArea);
      
      developer.log('Auto-saved all data to local storage');
    } catch (e) {
      developer.log('Error in auto-save: $e', error: e);
    }
  }

  /// Reload all data from storage (useful after iCloud sync)
  Future<void> reloadFromStorage() async {
    developer.log("ViewModel: Reloading all data from storage", name: 'EditItemsViewModel');
    await fetchPracticeAreas();
  }

  Future<void> fetchPracticeAreas() async {
    developer.log("ViewModel: Starting fetchPracticeAreas (LOCAL STORAGE)",
        name: 'EditItemsViewModel');
    _isLoadingAreas = true;
    _error = null;
    notifyListeners();

    try {
      // Load practice areas from local storage
      final loadedAreas = await LocalStorageService.loadPracticeAreas();
      _areas.clear();
      _areas.addAll(loadedAreas);
      
      // Load practice items for each area
      final loadedItems = await LocalStorageService.loadPracticeItems();
      
      // Ensure each area has its practice items populated
      for (final area in _areas) {
        final items = loadedItems[area.recordName] ?? [];
        area.practiceItems.clear();
        area.practiceItems.addAll(items);
      }

      // Ensure Chord Progressions area always exists
      _ensureChordProgressionsAreaExists();
      
      _isLoadingAreas = false;
      developer.log(
          "ViewModel: Loaded ${_areas.length} areas from local storage - Chord Progressions area ensured.",
          name: 'EditItemsViewModel');
      notifyListeners();
    } catch (e) {
      _isLoadingAreas = false;
      _error = 'Failed to load practice areas: $e';
      developer.log("ViewModel: Error loading practice areas: $e", error: e);
      
      // Ensure Chord Progressions area exists even on error
      _ensureChordProgressionsAreaExists();
      notifyListeners();
    }
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
    
    // Auto-save to local storage
    await _autoSave();
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
    
    // Auto-save to local storage
    await _autoSave();
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
      
      // Auto-save to local storage
      await _autoSave();
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
    
    // Auto-save to local storage
    await _autoSave();
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
    
    // Auto-save to local storage
    await _autoSave();
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
    
    // Auto-save to local storage
    await _autoSave();
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
    
    // Auto-save to local storage
    await _autoSave();
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
