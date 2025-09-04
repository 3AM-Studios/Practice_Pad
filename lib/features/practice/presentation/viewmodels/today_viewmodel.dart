import 'package:flutter/foundation.dart';
import 'package:practice_pad/features/routines/models/day_of_week.dart';
import 'package:practice_pad/features/routines/presentation/viewmodels/routines_viewmodel.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/statistics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class TodayViewModel extends ChangeNotifier {
  final RoutinesViewModel _routinesViewModel;

  List<PracticeArea> _todaysAreas = [];
  List<PracticeArea> get todaysAreas => _todaysAreas;

  // Currently selected practice items from the areas for today's practice
  final List<PracticeItem> _selectedPracticeItems = [];
  List<PracticeItem> get selectedPracticeItems => _selectedPracticeItems;

  // To track completion status for the current session
  final Set<String> _completedItemIds = {}; // Store IDs of completed items

  // To track TARGET number of cycles for each item for the current session
  final Map<String, int> _itemTargetCycleCounts = {};

  // To track COMPLETED number of cycles for each item for the current session
  final Map<String, int> _itemCompletedCycleCounts = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Daily goal in minutes
  int _dailyGoalMinutes = 10;
  int get dailyGoalMinutes => _dailyGoalMinutes;

  // Today's practice time in minutes
  int _todaysPracticeMinutes = 0;
  int get todaysPracticeMinutes => _todaysPracticeMinutes;

  TodayViewModel({required RoutinesViewModel routinesViewModel})
      : _routinesViewModel = routinesViewModel {
    developer.log(
        '[TodayViewModel] Initializing. RoutinesVM instance: ${_routinesViewModel.hashCode}',
        name: 'TodayVM');
    _loadDailyGoal();
    _loadTodaysPracticeTime();
    _loadTodaysItems();
    _routinesViewModel.addListener(_onRoutinesChanged);
  }

  void _loadTodaysItems() {
    developer.log('[TodayViewModel] _loadTodaysItems CALLED', name: 'TodayVM');
    _isLoading = true;
    // notifyListeners(); // This early notify might be okay or could cause a quick loading flicker.

    DayOfWeek currentDay = _routinesViewModel.today;
    developer.log(
        '[TodayViewModel] > _loadTodaysItems: currentDay from RoutinesVM.today = $currentDay',
        name: 'TodayVM');

    final areasFromRoutine = _routinesViewModel.routines[currentDay] ?? [];
    developer.log(
        '[TodayViewModel] > _loadTodaysItems: areas fetched from RoutinesVM for $currentDay = ${areasFromRoutine.map((e) => e.name).toList()}',
        name: 'TodayVM');
    developer.log(
        '[TodayViewModel] > _loadTodaysItems: RoutinesVM.routines has ${_routinesViewModel.routines.length} days configured',
        name: 'TodayVM');
    for (final entry in _routinesViewModel.routines.entries) {
      developer.log(
          '[TodayViewModel] > _loadTodaysItems: ${entry.key} has ${entry.value.length} areas: ${entry.value.map((e) => e.name).toList()}',
          name: 'TodayVM');
    }

    _todaysAreas = List<PracticeArea>.from(areasFromRoutine);
    _completedItemIds
        .clear(); // This might be redundant if we rely on completed cycles
    _itemTargetCycleCounts.clear(); // Clear previous target cycle counts
    _itemCompletedCycleCounts.clear(); // Clear previous completed cycle counts
    
    // Initialize default values for all practice items from all areas
    for (var area in _todaysAreas) {
      for (var item in area.practiceItems) {
        _itemTargetCycleCounts[item.id] = 1; // Default to 1 target cycle
        _itemCompletedCycleCounts[item.id] = 0; // Default to 0 completed cycles
      }
    }

    _isLoading = false;
    notifyListeners(); // Notify after all state changes for this load operation are complete.
    developer.log(
        '[TodayViewModel] > _loadTodaysItems: _todaysAreas AFTER load = ${_todaysAreas.map((e) => e.name).toList()}',
        name: 'TodayVM');
    developer.log(
        '[TodayViewModel] > _loadTodaysItems: isLoading AFTER load = $_isLoading',
        name: 'TodayVM');
  }

  void toggleItemCompletion(String itemId) {
    // This method will now increment completed cycles by 1.
    // If all cycles become complete, isItemCompleted() will reflect that.
    // If it's already fully complete and tapped again, it will reset completed to 0.
    if (isItemCompleted(itemId)) {
      _itemCompletedCycleCounts[itemId] = 0;
    } else {
      if (_itemTargetCycleCounts.containsKey(itemId) &&
          _itemCompletedCycleCounts.containsKey(itemId)) {
        int currentCompleted = _itemCompletedCycleCounts[itemId]!;
        int target = _itemTargetCycleCounts[itemId]!;
        if (currentCompleted < target) {
          _itemCompletedCycleCounts[itemId] = currentCompleted + 1;
        }
      }
    }
    notifyListeners();
  }

  bool isItemCompleted(String itemId) {
    final target = _itemTargetCycleCounts[itemId] ?? 1;
    final completed = _itemCompletedCycleCounts[itemId] ?? 0;
    return completed >= target;
  }

  int getItemTargetCycleCount(String itemId) {
    return _itemTargetCycleCounts[itemId] ?? 1; // Default to 1 if not found
  }

  void setItemTargetCycleCount(String itemId, int cycles) {
    if (_itemTargetCycleCounts.containsKey(itemId)) {
      _itemTargetCycleCounts[itemId] =
          cycles.clamp(1, 99); // Clamp between 1 and 99 cycles
      // If target is reduced below completed, adjust completed.
      if ((_itemCompletedCycleCounts[itemId] ?? 0) >
          (_itemTargetCycleCounts[itemId] ?? 1)) {
        _itemCompletedCycleCounts[itemId] = _itemTargetCycleCounts[itemId]!;
      }
      notifyListeners();
    }
  }

  void incrementItemTargetCycleCount(String itemId) {
    if (_itemTargetCycleCounts.containsKey(itemId)) {
      int currentTargetCycles = _itemTargetCycleCounts[itemId]!;
      if (currentTargetCycles < 99) {
        // Max 99 cycles
        _itemTargetCycleCounts[itemId] = currentTargetCycles + 1;
        notifyListeners();
      }
    }
  }

  void decrementItemTargetCycleCount(String itemId) {
    if (_itemTargetCycleCounts.containsKey(itemId)) {
      int currentTargetCycles = _itemTargetCycleCounts[itemId]!;
      if (currentTargetCycles > 1) {
        // Min 1 cycle
        _itemTargetCycleCounts[itemId] = currentTargetCycles - 1;
        // If target is reduced below completed, adjust completed.
        if ((_itemCompletedCycleCounts[itemId] ?? 0) >
            (_itemTargetCycleCounts[itemId] ?? 1)) {
          _itemCompletedCycleCounts[itemId] = _itemTargetCycleCounts[itemId]!;
        }
        notifyListeners();
      }
    }
  }

  // New methods for manual increment/decrement of COMPLETED cycles
  void incrementCompletedCyclesManual(String itemId) {
    if (_itemTargetCycleCounts.containsKey(itemId) &&
        _itemCompletedCycleCounts.containsKey(itemId)) {
      int currentCompleted = _itemCompletedCycleCounts[itemId]!;
      int target = _itemTargetCycleCounts[itemId]!;
      if (currentCompleted < target) {
        _itemCompletedCycleCounts[itemId] = currentCompleted + 1;
        notifyListeners();
      }
    }
  }

  void decrementCompletedCyclesManual(String itemId) {
    if (_itemCompletedCycleCounts.containsKey(itemId)) {
      int currentCompleted = _itemCompletedCycleCounts[itemId]!;
      if (currentCompleted > 0) {
        _itemCompletedCycleCounts[itemId] = currentCompleted - 1;
        notifyListeners();
      }
    }
  }

  int getItemCompletedCycleCount(String itemId) {
    return _itemCompletedCycleCounts[itemId] ?? 0;
  }

  // Method to add cycles completed, e.g., from Circle of Fifths mode
  void addCompletedCycles(String itemId, int cyclesCompletedInSession) {
    if (cyclesCompletedInSession <= 0) return;

    if (_itemTargetCycleCounts.containsKey(itemId) &&
        _itemCompletedCycleCounts.containsKey(itemId)) {
      int currentCompleted = _itemCompletedCycleCounts[itemId]!;
      int target = _itemTargetCycleCounts[itemId]!;

      currentCompleted += cyclesCompletedInSession;
      _itemCompletedCycleCounts[itemId] =
          currentCompleted.clamp(0, target); // Don't exceed target

      developer.log(
          '[TodayViewModel] addCompletedCycles: ID: $itemId, Added: $cyclesCompletedInSession, NewCompleted: ${_itemCompletedCycleCounts[itemId]}, Target: $target',
          name: 'TodayVM');
      notifyListeners();
    }
  }

  void _onRoutinesChanged() {
    developer.log(
        '[TodayViewModel] _onRoutinesChanged (listener from RoutinesVM) TRIGGERED!',
        name: 'TodayVM');
    _loadTodaysItems();
  }

  @override
  void dispose() {
    developer.log('[TodayViewModel] Disposing TodayViewModel.',
        name: 'TodayVM');
    _routinesViewModel.removeListener(_onRoutinesChanged);
    super.dispose();
  }

  // Placeholder for starting Circle of Fifths practice mode
  void startCircleOfFifthsPractice(PracticeItem item) {
    // This will be implemented in Phase 2
    print("Starting Circle of Fifths practice for: ${item.name}");
  }

  // Methods for managing selected practice items
  void selectPracticeItem(PracticeItem item) {
    if (!_selectedPracticeItems.contains(item)) {
      _selectedPracticeItems.add(item);
      notifyListeners();
    }
  }

  void deselectPracticeItem(PracticeItem item) {
    if (_selectedPracticeItems.contains(item)) {
      _selectedPracticeItems.remove(item);
      notifyListeners();
    }
  }

  void togglePracticeItemSelection(PracticeItem item) {
    if (_selectedPracticeItems.contains(item)) {
      deselectPracticeItem(item);
    } else {
      selectPracticeItem(item);
    }
  }

  bool isPracticeItemSelected(PracticeItem item) {
    return _selectedPracticeItems.contains(item);
  }

  void clearSelectedPracticeItems() {
    _selectedPracticeItems.clear();
    notifyListeners();
  }

  void selectAllItemsFromArea(PracticeArea area) {
    for (var item in area.practiceItems) {
      if (!_selectedPracticeItems.contains(item)) {
        _selectedPracticeItems.add(item);
      }
    }
    notifyListeners();
  }

  void deselectAllItemsFromArea(PracticeArea area) {
    _selectedPracticeItems.removeWhere((item) => area.practiceItems.contains(item));
    notifyListeners();
  }

  // Get practice items that are currently selected for practice  
  List<PracticeItem> get todaysItems => _selectedPracticeItems;

  // Load daily goal from SharedPreferences
  Future<void> _loadDailyGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dailyGoalMinutes = prefs.getInt('daily_goal_minutes') ?? 10;
      notifyListeners();
    } catch (e) {
      _dailyGoalMinutes = 10; // Default fallback
    }
  }

  // Save daily goal to SharedPreferences
  Future<void> _saveDailyGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('daily_goal_minutes', _dailyGoalMinutes);
    } catch (e) {
      developer.log('[TodayViewModel] Error saving daily goal: $e', name: 'TodayVM');
    }
  }

  // Load today's practice time from statistics
  Future<void> _loadTodaysPracticeTime() async {
    try {
      final todaysStats = await Statistics.getToday();
      Duration totalTime = Duration.zero;
      for (final stat in todaysStats) {
        totalTime += stat.totalTime;
      }
      final newTodaysPracticeMinutes = totalTime.inMinutes;
      
      // Only notify listeners if the practice time actually changed
      if (newTodaysPracticeMinutes != _todaysPracticeMinutes) {
        _todaysPracticeMinutes = newTodaysPracticeMinutes;
        developer.log('[TodayViewModel] Practice time changed to: $_todaysPracticeMinutes minutes', name: 'TodayVM');
        notifyListeners();
      } else {
        developer.log('[TodayViewModel] Practice time unchanged: $_todaysPracticeMinutes minutes', name: 'TodayVM');
      }
    } catch (e) {
      if (_todaysPracticeMinutes != 0) {
        _todaysPracticeMinutes = 0;
        developer.log('[TodayViewModel] Error loading today\'s practice time: $e', name: 'TodayVM');
        notifyListeners();
      }
    }
  }

  /// Public method to reload today's practice time (call after session completion)
  Future<void> reloadTodaysPracticeTime() async {
    await _loadTodaysPracticeTime();
  }

  // Increase daily goal by 2 minutes
  Future<void> increaseGoal() async {
    _dailyGoalMinutes += 2;
    await _saveDailyGoal();
    notifyListeners();
  }

  // Decrease daily goal by 2 minutes (minimum 2 minutes)
  Future<void> decreaseGoal() async {
    if (_dailyGoalMinutes > 2) {
      _dailyGoalMinutes -= 2;
      await _saveDailyGoal();
      notifyListeners();
    }
  }

  // Refresh today's practice time (call this when practice sessions complete)
  Future<void> refreshTodaysPracticeTime() async {
    await _loadTodaysPracticeTime();
  }
}
