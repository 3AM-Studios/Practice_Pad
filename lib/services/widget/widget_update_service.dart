import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/practice_session_manager.dart';
import 'package:practice_pad/services/widget/widget_action_handler.dart';

class WidgetUpdateService {
  static WidgetUpdateService? _instance;
  static WidgetUpdateService get instance => _instance ??= WidgetUpdateService._internal();
  
  WidgetUpdateService._internal();

  TodayViewModel? _todayViewModel;
  PracticeSessionManager? _sessionManager;
  
  // State tracking to prevent infinite loops
  bool _isUpdating = false;
  bool _lastHasActiveSession = false;

  /// Initialize the service with the view models
  void initialize({
    required TodayViewModel todayViewModel,
    required PracticeSessionManager sessionManager,
  }) {
    _todayViewModel = todayViewModel;
    _sessionManager = sessionManager;
    
    // Add listeners to update widget when data changes
    _todayViewModel?.addListener(_updateWidget);
    _sessionManager?.addListener(_updateWidget);
    
    // Widget action monitoring is now handled by WidgetActionHandler 
    // and WidgetIntegration - no need to start monitoring here
    
    // Initial widget update
    _updateWidget();
  }

  /// Update the widget with current data
  void _updateWidget() async {
    if (_todayViewModel == null || _sessionManager == null) return;
    
    // Prevent recursive calls
    if (_isUpdating) return;
    
    _isUpdating = true;
    
    try {
      final currentHasActiveSession = _sessionManager!.hasActiveSession;
      
      // Only reload today's practice time when a session actually just ended
      if (_lastHasActiveSession && !currentHasActiveSession) {
        print('WidgetUpdateService: Session ended, reloading today\'s practice time');
        await _todayViewModel!.reloadTodaysPracticeTime();
      }
      
      // Update the last session state
      _lastHasActiveSession = currentHasActiveSession;
      
      _updateWidgetData();
    } finally {
      _isUpdating = false;
    }
  }
  
  /// Update widget data using the new WidgetActionHandler
  void _updateWidgetData() async {
    if (_todayViewModel == null || _sessionManager == null) return;
    
    try {
      // Debug: Check what areas we have
      print('WidgetUpdateService: TodayViewModel has ${_todayViewModel!.todaysAreas.length} areas');
      for (final area in _todayViewModel!.todaysAreas) {
        print('WidgetUpdateService: Area: ${area.name} with ${area.practiceItems.length} items');
      }
      
      // Don't update widget if we're still loading and have no areas
      // This prevents showing old cached data when the app is initializing
      if (_todayViewModel!.isLoading && _todayViewModel!.todaysAreas.isEmpty) {
        print('WidgetUpdateService: TodayViewModel is still loading and has no areas, skipping widget update');
        return;
      }
      
      // Prepare practice areas data
      final practiceAreas = _todayViewModel!.todaysAreas.map((area) {
        return {
          'name': area.name,
          'type': area.type.toString().split('.').last,
          'items': area.practiceItems.map((item) {
            return {
              'id': item.id,
              'name': item.name,
              'description': item.description,
              'isCompleted': _todayViewModel!.isItemCompleted(item.id),
              'completedCycles': _todayViewModel!.getItemCompletedCycleCount(item.id),
              'targetCycles': _todayViewModel!.getItemTargetCycleCount(item.id),
            };
          }).toList(),
        };
      }).toList();

      // Prepare active session data
      Map<String, dynamic>? activeSession;
      if (_sessionManager!.hasActiveSession) {
        activeSession = {
          'itemName': _sessionManager!.activePracticeItem?.name ?? 'Unknown',
          'elapsedSeconds': _sessionManager!.elapsedSeconds,
          'targetSeconds': _sessionManager!.targetSeconds,
          'isTimerRunning': _sessionManager!.isTimerRunning,
          'progressPercentage': _sessionManager!.progressPercentage,
          'timerStartTime': _sessionManager!.timerStartTime,
        };
      }

      print('WidgetUpdateService: Sending ${practiceAreas.length} practice areas to widget');
      print('WidgetUpdateService: Practice areas data: $practiceAreas');
      
      await WidgetActionHandler.updateWidgetData(
        practiceAreas: practiceAreas,
        activeSession: activeSession,
        dailyGoal: _todayViewModel!.dailyGoalMinutes,
        todaysPractice: _todayViewModel!.todaysPracticeMinutes,
      );
    } catch (e) {
      print('WidgetUpdateService: Error updating widget data: $e');
    }
  }

  /// Manually trigger a widget update
  void updateWidget() {
    _updateWidget();
  }

  /// Dispose of listeners
  void dispose() {
    _todayViewModel?.removeListener(_updateWidget);
    _sessionManager?.removeListener(_updateWidget);
    // Widget action monitoring is now handled by WidgetActionHandler - no cleanup needed here
  }
}