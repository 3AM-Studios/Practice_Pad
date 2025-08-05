import 'package:flutter/foundation.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/features/routines/models/day_of_week.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'dart:developer' as developer;

class RoutinesViewModel extends ChangeNotifier {
  final EditItemsViewModel _editItemsViewModel;

  // UPDATED: Store routines as a map where key is DayOfWeek and value is a list of PracticeAreas
  final Map<DayOfWeek, List<PracticeArea>> _routines = {};
  Map<DayOfWeek, List<PracticeArea>> get routines => _routines;

  DayOfWeek _selectedDay = DayOfWeek.sunday; // Default to Sunday
  DayOfWeek get selectedDay => _selectedDay;

  // ADDED: Getter for today's DayOfWeek
  DayOfWeek get today {
    // DateTime.now().weekday returns 1 for Monday, 7 for Sunday.
    // DayOfWeek enum starts with sunday (index 0).
    int weekday = DateTime.now().weekday;
    if (weekday == 7) return DayOfWeek.sunday; // Sunday
    return DayOfWeek.values[weekday]; // Monday to Saturday (index 1 to 6)
  }

  final bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  RoutinesViewModel({required EditItemsViewModel editItemsViewModel})
      : _editItemsViewModel = editItemsViewModel {
    // Initialize routines for each day to avoid null issues later
    for (var day in DayOfWeek.values) {
      _routines[day] = [];
    }
    // Potentially load routines from a service here
  }

  // Getter to access practice areas from EditItemsViewModel
  List<PracticeArea> get practiceAreas => _editItemsViewModel.areas;

  // Getter to access items for a specific area from EditItemsViewModel
  List<PracticeItem> getItemsForArea(String areaRecordName) {
    return _editItemsViewModel.getItemsForArea(areaRecordName);
  }

  void selectDay(DayOfWeek day) {
    _selectedDay = day;
    notifyListeners();
  }

  // UPDATED: Add practice area to routine instead of practice item
  void addPracticeAreaToRoutine(DayOfWeek day, PracticeArea area) {
    // Ensure area is not already in the routine for that day to avoid duplicates
    if (!(_routines[day]?.any((a) => a.recordName == area.recordName) ?? false)) {
      _routines[day]?.add(area);
      notifyListeners();
    }
  }

  // UPDATED: Remove practice area from routine
  void removePracticeAreaFromRoutine(DayOfWeek day, PracticeArea area) {
    _routines[day]?.removeWhere((a) => a.recordName == area.recordName);
    notifyListeners();
  }

  // UPDATED: Add multiple practice areas to routine
  void addMultiplePracticeAreasToRoutine(
      DayOfWeek day, List<PracticeArea> areasToAdd) {
    final dayRoutine = _routines[day];
    if (dayRoutine == null) {
      return; // Should not happen if initialized correctly
    }

    for (var area in areasToAdd) {
      if (!dayRoutine.any((a) => a.recordName == area.recordName)) {
        dayRoutine.add(area);
      }
    }
    developer.log(
        '[RoutinesViewModel] Areas for $day after addMultiple: ${dayRoutine.map((e) => e.name).toList()}',
        name: 'RoutinesVM'); // DEBUG
    developer.log('[RoutinesViewModel] Full routines map: $_routines',
        name: 'RoutinesVM'); // DEBUG
    notifyListeners();
  }

  // UPDATED: Reorder practice areas in routine
  void reorderPracticeAreaInRoutine(DayOfWeek day, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final List<PracticeArea>? dayRoutine = _routines[day];
    if (dayRoutine != null &&
        oldIndex >= 0 &&
        oldIndex < dayRoutine.length &&
        newIndex >= 0 &&
        newIndex < dayRoutine.length) {
      final PracticeArea area = dayRoutine.removeAt(oldIndex);
      dayRoutine.insert(newIndex, area);
      notifyListeners();
    }
  }

  // UPDATED: Copy routine areas to other days
  void copyRoutineToDays(DayOfWeek sourceDay, List<DayOfWeek> targetDays) {
    final List<PracticeArea>? sourceAreas = _routines[sourceDay];
    if (sourceAreas == null) return; // Nothing to copy

    for (var targetDay in targetDays) {
      if (targetDay == sourceDay) continue; // Don't copy to itself
      // Create a new list from sourceAreas to avoid modifying the same list instance
      _routines[targetDay] = List<PracticeArea>.from(sourceAreas);
    }
    notifyListeners(); // Notify to update UI for potentially multiple days
  }

  // UPDATED: Calculate total estimated minutes for practice areas in a day
  int calculateTotalMinutesForDay(DayOfWeek day) {
    final areas = _routines[day] ?? [];
    if (areas.isEmpty) return 0;
    // Estimate 5 minutes per practice item across all areas
    return areas.fold<int>(0, (sum, area) => sum + (area.practiceItems.length * 5));
  }

  // NEW: Get all practice items for today (for practice screen)
  List<PracticeItem> getTodaysPracticeItems() {
    final todaysAreas = _routines[today] ?? [];
    final allItems = <PracticeItem>[];
    for (final area in todaysAreas) {
      allItems.addAll(area.practiceItems);
    }
    return allItems;
  }

  // NEW: Get today's practice areas
  List<PracticeArea> getTodaysPracticeAreas() {
    return _routines[today] ?? [];
  }

  // More methods will be added here for loading, saving, reordering items, etc.
}

// UPDATED: Extension on PracticeArea to include estimated duration
extension PracticeAreaDuration on PracticeArea {
  int get estimatedMinutes => practiceItems.length * 5; // 5 minutes per practice item
}
