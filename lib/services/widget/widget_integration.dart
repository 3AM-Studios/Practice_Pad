import 'dart:async';
import 'package:practice_pad/services/widget/widget_action_handler.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/practice_session_manager.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';

class WidgetIntegration {
  static void setupWidgetCallbacks({
    required TodayViewModel todayViewModel,
    required PracticeSessionManager sessionManager,
    required EditItemsViewModel editItemsViewModel,
    Function(String itemId)? onNavigateToPractice,
  }) {
    // Set up widget action callbacks
    WidgetActionHandler.setOnStartPracticeItem((itemId, itemName) async {
      print('WidgetIntegration: Starting practice for $itemName (ID: $itemId)');
      
      try {
        // Find the practice item in the available areas
        for (final area in todayViewModel.todaysAreas) {
          for (final item in area.practiceItems) {
            if (item.id == itemId) {
              print('WidgetIntegration: Found item ${item.name}, starting session');
              
              // Start the practice session with default settings
              sessionManager.startSession(
                item: item,
                targetSeconds: 300, // 5 minutes default
              );
              
              print('WidgetIntegration: Started practice session for ${item.name}');
              
              // Update widget data to reflect the new session
              await _updateWidgetWithCurrentData(
                todayViewModel: todayViewModel,
                sessionManager: sessionManager,
              );
              
              return;
            }
          }
        }
        
        print('WidgetIntegration: Practice item with ID $itemId not found');
      } catch (e) {
        print('WidgetIntegration: Error starting practice item: $e');
      }
    });

    WidgetActionHandler.setOnToggleSession(() async {
      print('WidgetIntegration: Toggle session action received');
      
      try {
        if (!sessionManager.hasActiveSession) {
          print('WidgetIntegration: No active session to toggle');
          return;
        }
        
        // Toggle the timer state directly in Flutter
        if (sessionManager.isTimerRunning) {
          sessionManager.stopTimer();
          print('WidgetIntegration: Stopped practice session timer');
        } else {
          sessionManager.startTimer();
          print('WidgetIntegration: Started practice session timer');
        }
        
        // Update widget data to reflect the new timer state
        await _updateWidgetWithCurrentData(
          todayViewModel: todayViewModel,
          sessionManager: sessionManager,
        );
        
        print('WidgetIntegration: Toggle session completed - Timer running: ${sessionManager.isTimerRunning}');
      } catch (e) {
        print('WidgetIntegration: Error toggling session: $e');
      }
    });

    WidgetActionHandler.setOnCompletePracticeItem((itemId) async {
      print('WidgetIntegration: Completing practice item: $itemId');
      
      try {
        // Toggle completion status
        todayViewModel.toggleItemCompletion(itemId);
        
        // Update widget data to reflect the completion
        await _updateWidgetWithCurrentData(
          todayViewModel: todayViewModel,
          sessionManager: sessionManager,
        );
        
        print('WidgetIntegration: Completed practice item $itemId');
      } catch (e) {
        print('WidgetIntegration: Error completing practice item: $e');
      }
    });

    WidgetActionHandler.setOnOpenPracticeItem((itemId) async {
      print('WidgetIntegration: Opening practice item: $itemId');
      
      try {
        if (onNavigateToPractice != null) {
          onNavigateToPractice(itemId);
          print('WidgetIntegration: Navigation callback called for item $itemId');
        } else {
          print('WidgetIntegration: No navigation callback provided');
          
          // Fallback: Start the practice session like the start button
          for (final area in todayViewModel.todaysAreas) {
            for (final item in area.practiceItems) {
              if (item.id == itemId) {
                print('WidgetIntegration: Starting practice session as fallback for ${item.name}');
                
                sessionManager.startSession(
                  item: item,
                  targetSeconds: 300, // 5 minutes default
                );
                
                await _updateWidgetWithCurrentData(
                  todayViewModel: todayViewModel,
                  sessionManager: sessionManager,
                );
                
                return;
              }
            }
          }
          print('WidgetIntegration: Practice item with ID $itemId not found');
        }
      } catch (e) {
        print('WidgetIntegration: Error opening practice item: $e');
      }
    });

    print('WidgetIntegration: Widget callbacks configured successfully');
  }

  // Update widget with current app data
  static Future<void> _updateWidgetWithCurrentData({
    required TodayViewModel todayViewModel,
    required PracticeSessionManager sessionManager,
  }) async {
    try {
      // Note: Today's practice time reload is now handled by WidgetUpdateService
      // to prevent infinite loops when session state changes
      // Prepare practice areas data
      final practiceAreas = todayViewModel.todaysAreas.map((area) {
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
      Map<String, dynamic>? activeSession;
      if (sessionManager.hasActiveSession) {
        activeSession = {
          'itemName': sessionManager.activePracticeItem?.name ?? 'Unknown',
          'elapsedSeconds': sessionManager.elapsedSeconds,
          'targetSeconds': sessionManager.targetSeconds,
          'isTimerRunning': sessionManager.isTimerRunning,
          'progressPercentage': sessionManager.progressPercentage,
          'timerStartTime': sessionManager.timerStartTime,
        };
      }

      await WidgetActionHandler.updateWidgetData(
        practiceAreas: practiceAreas,
        activeSession: activeSession,
        dailyGoal: todayViewModel.dailyGoalMinutes,
        todaysPractice: todayViewModel.todaysPracticeMinutes,
      );

      print('WidgetIntegration: Updated widget data successfully');
    } catch (e) {
      print('WidgetIntegration: Error updating widget data: $e');
    }
  }

  // Call this method to manually update widget data from the app
  static Future<void> updateWidgetData({
    required TodayViewModel todayViewModel,
    required PracticeSessionManager sessionManager,
  }) async {
    await _updateWidgetWithCurrentData(
      todayViewModel: todayViewModel,
      sessionManager: sessionManager,
    );
  }
  
  // Sync session state from widget when app becomes active
  static Future<void> syncSessionStateFromWidget({
    required PracticeSessionManager sessionManager,
  }) async {
    try {
      print('WidgetIntegration: Syncing session state from widget');
      
      final widgetSessionData = await WidgetActionHandler.getActiveSession();
      
      if (widgetSessionData == null) {
        print('WidgetIntegration: No active session in widget');
        return;
      }
      
      // Check if session manager has the same session
      if (!sessionManager.hasActiveSession) {
        print('WidgetIntegration: No active session in Flutter, widget has session - states diverged');
        return;
      }
      
      // Get widget timer running state
      final widgetIsTimerRunning = widgetSessionData['isTimerRunning'] as bool? ?? false;
      final flutterIsTimerRunning = sessionManager.isTimerRunning;
      
      print('WidgetIntegration: Widget timer running: $widgetIsTimerRunning, Flutter timer running: $flutterIsTimerRunning');
      
      // Sync elapsed time from widget (widget is the source of truth when app was backgrounded)
      final widgetElapsedSeconds = widgetSessionData['elapsedSeconds'] as int? ?? 0;
      final flutterElapsedSeconds = sessionManager.elapsedSeconds;
      
      if (widgetElapsedSeconds != flutterElapsedSeconds) {
        print('WidgetIntegration: Elapsed time differs - Widget: $widgetElapsedSeconds, Flutter: $flutterElapsedSeconds');
        print('WidgetIntegration: Syncing Flutter elapsed time to match widget');
        sessionManager.updateTimer(widgetElapsedSeconds, widgetIsTimerRunning);
      }
      
      // Sync timer state if they differ
      if (widgetIsTimerRunning != flutterIsTimerRunning) {
        print('WidgetIntegration: Timer states differ, syncing to widget state');
        
        if (widgetIsTimerRunning && !flutterIsTimerRunning) {
          sessionManager.startTimer();
          print('WidgetIntegration: Started Flutter timer to match widget');
        } else if (!widgetIsTimerRunning && flutterIsTimerRunning) {
          sessionManager.stopTimer();
          print('WidgetIntegration: Stopped Flutter timer to match widget');
        }
      } else {
        print('WidgetIntegration: Timer states are already in sync');
      }
      
    } catch (e) {
      print('WidgetIntegration: Error syncing session state: $e');
    }
  }
  
  // Monitor session state changes from widget (for background sync)
  static Future<void> startContinuousSessionStateSync({
    required PracticeSessionManager sessionManager,
  }) async {
    // Check widget session state every 2 seconds when app is active
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!sessionManager.hasActiveSession) {
        return; // No session to sync
      }
      
      try {
        final widgetSessionData = await WidgetActionHandler.getActiveSession();
        if (widgetSessionData == null) return;
        
        final widgetIsTimerRunning = widgetSessionData['isTimerRunning'] as bool? ?? false;
        final flutterIsTimerRunning = sessionManager.isTimerRunning;
        
        // Only sync if states differ (widget changed state independently)
        if (widgetIsTimerRunning != flutterIsTimerRunning) {
          print('WidgetIntegration: Widget timer state changed independently - syncing Flutter');
          
          if (widgetIsTimerRunning && !flutterIsTimerRunning) {
            sessionManager.startTimer();
            print('WidgetIntegration: Widget started timer - syncing Flutter to start');
          } else if (!widgetIsTimerRunning && flutterIsTimerRunning) {
            sessionManager.stopTimer();
            print('WidgetIntegration: Widget stopped timer - syncing Flutter to stop');
          }
        }
        
      } catch (e) {
        print('WidgetIntegration: Error in continuous sync: $e');
      }
    });
  }
}