import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:practice_pad/services/practice_session_manager.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
import 'dart:async';

class HomeWidgetService {
  static const String _practiceAreasKey = 'practice_areas';
  static const String _activeSessionKey = 'active_session';
  static const String _dailyGoalKey = 'daily_goal';
  static const String _todaysPracticeKey = 'todays_practice';
  static const String _widgetActionKey = 'widget_action';
  static const String _widgetName = 'PracticePadWidget';
  
  static Timer? _actionCheckTimer;

  /// Initialize the home widget
  static Future<void> initialize() async {
    try {
      // TODO: Replace with your actual app group ID (e.g., group.your.bundle.id.practicepad)
      await HomeWidget.setAppGroupId('group.com.3amstudios.jazzpad');
    } catch (e) {
      print('Error initializing home widget: $e');
    }
  }

  /// Update the widget with current practice data
  static Future<void> updateWidget({
    required TodayViewModel todayViewModel,
    required PracticeSessionManager sessionManager,
  }) async {
    try {
      // Prepare practice areas data
      final practiceAreasData = todayViewModel.todaysAreas.map((area) {
        return {
          'name': area.name,
          'type': area.type.toString().split('.').last,
          'items': area.practiceItems.map((item) {
            return {
              'id': item.id,
              'name': item.name,
              'description': item.description,
              'isCompleted': todayViewModel.isItemCompleted(item.id),
              'completedCycles': todayViewModel.getItemCompletedCycleCount(item.id),
              'targetCycles': todayViewModel.getItemTargetCycleCount(item.id),
            };
          }).toList(),
        };
      }).toList();

      // Prepare active session data
      Map<String, dynamic>? activeSessionData;
      if (sessionManager.hasActiveSession) {
        activeSessionData = {
          'itemName': sessionManager.activePracticeItem?.name ?? 'Unknown',
          'elapsedSeconds': sessionManager.elapsedSeconds,
          'targetSeconds': sessionManager.targetSeconds,
          'isTimerRunning': sessionManager.isTimerRunning,
          'progressPercentage': sessionManager.progressPercentage,
          'timerStartTime': sessionManager.isTimerRunning ? DateTime.now().millisecondsSinceEpoch / 1000.0 : null,
        };
      }

      // Send data to widget
      await HomeWidget.saveWidgetData(_practiceAreasKey, jsonEncode(practiceAreasData));
      
      if (activeSessionData != null) {
        await HomeWidget.saveWidgetData(_activeSessionKey, jsonEncode(activeSessionData));
      } else {
        await HomeWidget.saveWidgetData(_activeSessionKey, '');
      }

      await HomeWidget.saveWidgetData(_dailyGoalKey, todayViewModel.dailyGoalMinutes.toString());
      await HomeWidget.saveWidgetData(_todaysPracticeKey, todayViewModel.todaysPracticeMinutes.toString());

      // Update the widget
      await HomeWidget.updateWidget(
        name: _widgetName,
        iOSName: _widgetName,
      );
    } catch (e) {
      print('Error updating home widget: $e');
    }
  }

  /// Clear widget data
  static Future<void> clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData(_practiceAreasKey, '');
      await HomeWidget.saveWidgetData(_activeSessionKey, '');
      await HomeWidget.saveWidgetData(_dailyGoalKey, '');
      await HomeWidget.saveWidgetData(_todaysPracticeKey, '');
      
      await HomeWidget.updateWidget(
        name: _widgetName,
        iOSName: _widgetName,
      );
    } catch (e) {
      print('Error clearing widget data: $e');
    }
  }

  /// Start monitoring widget actions - DEPRECATED: Now handled by WidgetActionHandler
  static void startMonitoringWidgetActions({
    required TodayViewModel todayViewModel,
    required PracticeSessionManager sessionManager,
  }) {
    // This method is deprecated and no longer starts monitoring
    // All widget action handling is now done through WidgetActionHandler
    print('HomeWidgetService: startMonitoringWidgetActions called but is deprecated - use WidgetActionHandler instead');
  }

  /// Stop monitoring widget actions
  static void stopMonitoringWidgetActions() {
    _actionCheckTimer?.cancel();
    _actionCheckTimer = null;
  }

  /// Check for widget actions and process them - DEPRECATED: Now handled by WidgetActionHandler
  static Future<void> _checkForWidgetActions(
    TodayViewModel todayViewModel,
    PracticeSessionManager sessionManager,
  ) async {
    // This method is deprecated and no longer processes widget actions
    // All widget action handling is now done through WidgetActionHandler
    return;
  }

  /// Handle starting a practice item from widget
  static Future<void> _handleStartPracticeItem(
    String itemId,
    String? itemName,
    TodayViewModel todayViewModel,
    PracticeSessionManager sessionManager,
  ) async {
    try {
      print('Flutter: Looking for practice item with id: $itemId');
      print('Flutter: Available areas count: ${todayViewModel.todaysAreas.length}');
      
      // Find the practice item
      for (final area in todayViewModel.todaysAreas) {
        print('Flutter: Checking area: ${area.name} with ${area.practiceItems.length} items');
        for (final item in area.practiceItems) {
          print('Flutter: Item id: ${item.id}, name: ${item.name}');
        }
        
        try {
          final item = area.practiceItems.firstWhere(
            (item) => item.id == itemId,
          );
          print('Flutter: Found matching item: ${item.name}');
          
          // Start the practice session with default values
          sessionManager.startSession(
            item: item,
            targetSeconds: 300, // 5 minutes default
          );
          print('Flutter: Started practice session for: ${item.name}');
          return;
        } catch (e) {
          // Item not found in this area, continue to next area
          print('Flutter: Item not found in area ${area.name}');
          continue;
        }
      }
      print('Flutter: Practice item with id $itemId not found in any area');
    } catch (e) {
      print('Flutter: Error starting practice item: $e');
    }
  }

  /// Handle toggling the practice session
  static Future<void> _handleToggleSession(PracticeSessionManager sessionManager) async {
    try {
      print('Flutter: Toggle session called. Has active session: ${sessionManager.hasActiveSession}');
      print('Flutter: Session manager timer running: ${sessionManager.isTimerRunning}');
      
      if (sessionManager.hasActiveSession) {
        if (sessionManager.isTimerRunning) {
          sessionManager.stopTimer();
          print('Flutter: Paused practice session');
        } else {
          sessionManager.startTimer();
          print('Flutter: Resumed practice session');
        }
      } else {
        print('Flutter: No active session to toggle');
        // Optionally could start a default session here if needed
      }
    } catch (e) {
      print('Flutter: Error toggling session: $e');
    }
  }

  /// Handle completing a practice item from widget
  static Future<void> _handleCompletePracticeItem(
    String itemId,
    TodayViewModel todayViewModel,
  ) async {
    try {
      // Find and complete the practice item
      for (final area in todayViewModel.todaysAreas) {
        try {
          final item = area.practiceItems.firstWhere(
            (item) => item.id == itemId,
          );
          todayViewModel.toggleItemCompletion(itemId);
          print('Toggled completion for: ${item.name}');
          return;
        } catch (e) {
          // Item not found in this area, continue to next area
          continue;
        }
      }
    } catch (e) {
      print('Error completing practice item: $e');
    }
  }

  /// Handle widget tap actions (legacy method for basic tap handling)
  static Future<void> handleWidgetTap(String? action) async {
    if (action == null) return;
    
    // Handle different widget tap actions
    switch (action) {
      case 'openApp':
        // The app will automatically open when widget is tapped
        break;
      case 'startSession':
        // This could trigger opening to a specific practice item
        break;
      default:
        break;
    }
  }
}