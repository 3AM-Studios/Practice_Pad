import 'dart:convert';
import 'package:flutter/services.dart';

class WidgetActionHandler {
  static const MethodChannel _channel = MethodChannel('com.3amstudios.jazzpad/widget');
  
  // Initialize the handler and set up listeners
  static Future<void> initialize() async {
    try {
      // Listen for widget updates
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Check for any pending widget actions on app start
      await _checkPendingWidgetActions();
      
      print('WidgetActionHandler: Initialized successfully');
    } catch (e) {
      print('WidgetActionHandler: Error during initialization: $e');
    }
  }
  
  // Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'widgetActionReceived':
        await _processWidgetAction();
        break;
      case 'reloadWidget':
        await updateWidgetData();
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }
  
  // Check for pending widget actions
  static Future<void> _checkPendingWidgetActions() async {
    try {
      // Use platform channel to get widget action from App Group UserDefaults
      final actionString = await _channel.invokeMethod<String>('getWidgetAction');
      
      if (actionString != null && actionString.isNotEmpty) {
        print('WidgetActionHandler: Found pending action: $actionString');
        await _processActionString(actionString);
        // Clear the action after processing
        await _channel.invokeMethod('clearWidgetAction');
      }
    } catch (e) {
      print('WidgetActionHandler: Error checking pending actions: $e');
    }
  }
  
  // Process widget action from App Group UserDefaults via platform channel
  static Future<void> _processWidgetAction() async {
    try {
      // Use platform channel to get widget action from App Group UserDefaults
      final actionString = await _channel.invokeMethod<String>('getWidgetAction');
      
      if (actionString == null || actionString.isEmpty) {
        print('WidgetActionHandler: No widget action found');
        return;
      }
      
      print('WidgetActionHandler: Processing action: $actionString');
      await _processActionString(actionString);
      
      // Clear the action after processing
      await _channel.invokeMethod('clearWidgetAction');
      
    } catch (e) {
      print('WidgetActionHandler: Error processing widget action: $e');
      // Don't rethrow - handle gracefully
    }
  }
  
  // Process the action string with better error handling
  static Future<void> _processActionString(String actionString) async {
    try {
      // Validate JSON format
      if (!actionString.trim().startsWith('{') || !actionString.trim().endsWith('}')) {
        print('WidgetActionHandler: Invalid JSON format: $actionString');
        return;
      }
      
      final Map<String, dynamic> actionData = json.decode(actionString);
      
      final String? action = actionData['action'] as String?;
      final double? timestamp = (actionData['timestamp'] as num?)?.toDouble();
      
      if (action == null) {
        print('WidgetActionHandler: No action specified in widget data');
        return;
      }
      
      // Check if action is too old (more than 30 seconds)
      if (timestamp != null) {
        final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
        final age = now - timestamp;
        if (age > 30) {
          print('WidgetActionHandler: Action too old ($age seconds), ignoring');
          return;
        }
      }
      
      print('WidgetActionHandler: Processing action: $action');
      
      switch (action) {
        case 'start_practice_item':
          await _handleStartPracticeItem(actionData);
          break;
        case 'open_practice_item':
          await _handleOpenPracticeItem(actionData);
          break;
        case 'toggle_session':
          await _handleToggleSession(actionData);
          break;
        case 'complete_practice_item':
          await _handleCompletePracticeItem(actionData);
          break;
        default:
          print('WidgetActionHandler: Unknown action: $action');
      }
      
    } catch (e) {
      print('WidgetActionHandler: Error parsing widget action: $e');
    }
  }
  
  // Handle open practice item action (from deep link)
  static Future<void> _handleOpenPracticeItem(Map<String, dynamic> actionData) async {
    try {
      final String? itemId = actionData['itemId'] as String?;
      final double? timestamp = (actionData['timestamp'] as num?)?.toDouble();
      
      if (itemId == null || itemId.isEmpty) {
        print('WidgetActionHandler: Missing itemId for open_practice_item');
        return;
      }
      
      print('WidgetActionHandler: Opening practice item: $itemId');
      
      // Call the registered callback for opening practice item (navigation)
      if (_onOpenPracticeItem != null) {
        await _onOpenPracticeItem!(itemId);
      } else {
        print('WidgetActionHandler: No callback registered for open_practice_item');
      }
    } catch (e) {
      print('WidgetActionHandler: Error handling open_practice_item: $e');
    }
  }

  // Handle start practice item action
  static Future<void> _handleStartPracticeItem(Map<String, dynamic> actionData) async {
    try {
      final String? itemId = actionData['itemId'] as String?;
      final String? itemName = actionData['itemName'] as String?;
      final double? timestamp = (actionData['timestamp'] as num?)?.toDouble();
      
      if (itemId == null || itemId.isEmpty) {
        print('WidgetActionHandler: Missing itemId for start_practice_item');
        return;
      }
      
      if (itemName == null || itemName.isEmpty) {
        print('WidgetActionHandler: Missing itemName for start_practice_item');
        return;
      }
      
      print('WidgetActionHandler: Starting practice item: $itemName (ID: $itemId)');
      
      // Call the registered callback
      if (_onStartPracticeItem != null) {
        await _onStartPracticeItem!(itemId, itemName);
      } else {
        print('WidgetActionHandler: No callback registered for start_practice_item');
      }
    } catch (e) {
      print('WidgetActionHandler: Error handling start_practice_item: $e');
    }
  }
  
  // Handle toggle session action
  static Future<void> _handleToggleSession(Map<String, dynamic> actionData) async {
    try {
      final double? timestamp = (actionData['timestamp'] as num?)?.toDouble();
      
      print('WidgetActionHandler: Toggling practice session');
      
      // Call the registered callback
      if (_onToggleSession != null) {
        await _onToggleSession!();
      } else {
        print('WidgetActionHandler: No callback registered for toggle_session');
      }
    } catch (e) {
      print('WidgetActionHandler: Error handling toggle_session: $e');
    }
  }
  
  // Handle complete practice item action
  static Future<void> _handleCompletePracticeItem(Map<String, dynamic> actionData) async {
    try {
      final String? itemId = actionData['itemId'] as String?;
      final double? timestamp = (actionData['timestamp'] as num?)?.toDouble();
      
      if (itemId == null || itemId.isEmpty) {
        print('WidgetActionHandler: Missing itemId for complete_practice_item');
        return;
      }
      
      print('WidgetActionHandler: Completing practice item: $itemId');
      
      // Call the registered callback
      if (_onCompletePracticeItem != null) {
        await _onCompletePracticeItem!(itemId);
      } else {
        print('WidgetActionHandler: No callback registered for complete_practice_item');
      }
    } catch (e) {
      print('WidgetActionHandler: Error handling complete_practice_item: $e');
    }
  }
  
  // Update widget data using App Group UserDefaults via platform channel
  static Future<void> updateWidgetData({
    List<Map<String, dynamic>>? practiceAreas,
    Map<String, dynamic>? activeSession,
    int? dailyGoal,
    int? todaysPractice,
  }) async {
    try {
      // Create data map for platform channel
      Map<String, dynamic> updateData = {};
      
      if (practiceAreas != null) {
        updateData['practice_areas'] = json.encode(practiceAreas);
        print('WidgetActionHandler: Updated practice areas');
      }
      
      if (activeSession != null) {
        updateData['active_session'] = json.encode(activeSession);
        print('WidgetActionHandler: Updated active session');
      } else {
        // Clear active session when activeSession is null (no active session)
        updateData['active_session'] = '';
        print('WidgetActionHandler: Cleared active session');
      }
      
      if (dailyGoal != null) {
        updateData['daily_goal'] = dailyGoal.toString();
        print('WidgetActionHandler: Updated daily goal: $dailyGoal');
      }
      
      if (todaysPractice != null) {
        updateData['todays_practice'] = todaysPractice.toString();
        print('WidgetActionHandler: Updated todays practice: $todaysPractice');
      }
      
      // Send data to iOS via platform channel if there's data to update
      if (updateData.isNotEmpty) {
        await _channel.invokeMethod('updateWidgetData', updateData);
      }
      
      // Trigger widget reload on iOS
      try {
        await _channel.invokeMethod('reloadWidget');
        print('WidgetActionHandler: Triggered widget reload');
      } catch (e) {
        print('WidgetActionHandler: Error triggering widget reload: $e');
      }
      
    } catch (e) {
      print('WidgetActionHandler: Error updating widget data: $e');
    }
  }
  
  // Get current area filter
  static Future<String> getSelectedAreaFilter() async {
    try {
      final result = await _channel.invokeMethod<String>('getAreaFilter');
      return result ?? 'all';
    } catch (e) {
      print('WidgetActionHandler: Error getting area filter: $e');
      return 'all';
    }
  }
  
  // Set area filter
  static Future<void> setSelectedAreaFilter(String filter) async {
    try {
      await _channel.invokeMethod('setAreaFilter', {'filter': filter});
      
      // Trigger widget reload
      await _channel.invokeMethod('reloadWidget');
      print('WidgetActionHandler: Updated area filter to: $filter');
    } catch (e) {
      print('WidgetActionHandler: Error setting area filter: $e');
    }
  }
  
  // Clear all widget data
  static Future<void> clearAllWidgetData() async {
    try {
      await _channel.invokeMethod('clearAllWidgetData');
      print('WidgetActionHandler: Cleared all widget data');
    } catch (e) {
      print('WidgetActionHandler: Error clearing widget data: $e');
    }
  }
  
  // Callbacks for app-specific handling
  static Future<void> Function(String itemId, String itemName)? _onStartPracticeItem;
  static Future<void> Function(String itemId)? _onOpenPracticeItem;
  static Future<void> Function()? _onToggleSession;
  static Future<void> Function(String itemId)? _onCompletePracticeItem;
  
  // Set callback for start practice item
  static void setOnStartPracticeItem(Future<void> Function(String itemId, String itemName) callback) {
    _onStartPracticeItem = callback;
    print('WidgetActionHandler: Registered start practice item callback');
  }

  // Set callback for open practice item (navigation)
  static void setOnOpenPracticeItem(Future<void> Function(String itemId) callback) {
    _onOpenPracticeItem = callback;
    print('WidgetActionHandler: Registered open practice item callback');
  }
  
  // Set callback for toggle session
  static void setOnToggleSession(Future<void> Function() callback) {
    _onToggleSession = callback;
    print('WidgetActionHandler: Registered toggle session callback');
  }
  
  // Set callback for complete practice item
  static void setOnCompletePracticeItem(Future<void> Function(String itemId) callback) {
    _onCompletePracticeItem = callback;
    print('WidgetActionHandler: Registered complete practice item callback');
  }
  
  // Get current active session from App Group UserDefaults
  static Future<Map<String, dynamic>?> getActiveSession() async {
    try {
      final sessionString = await _channel.invokeMethod<String>('getActiveSession');
      
      if (sessionString == null || sessionString.isEmpty) {
        return null;
      }
      
      final Map<String, dynamic> sessionData = json.decode(sessionString);
      print('WidgetActionHandler: Retrieved active session: $sessionData');
      return sessionData;
      
    } catch (e) {
      print('WidgetActionHandler: Error getting active session: $e');
      return null;
    }
  }
}