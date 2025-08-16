import Flutter
import UIKit
import CloudKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var widgetMethodChannel: FlutterMethodChannel?
  private var widgetActionTimer: Timer?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not type FlutterViewController")
    }

    // Set up CloudKit channel
    let cloudKitChannel = FlutterMethodChannel(name: "iCloud.com.practicepad",
                                               binaryMessenger: controller.binaryMessenger)

    cloudKitChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "fetchRecords":
        self.fetchRecords(call: call, result: result)
      case "saveRecord":
        self.saveRecord(call: call, result: result)
      case "deleteRecord":
        self.deleteRecord(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    })

    // Set up Widget communication channel
    widgetMethodChannel = FlutterMethodChannel(
      name: "com.example.practicePad/widget",
      binaryMessenger: controller.binaryMessenger
    )
    
    widgetMethodChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleWidgetMethodCall(call, result: result)
    }
    
    // Start monitoring for widget actions
    startMonitoringWidgetActions()
    
    // Check for any pending widget actions on app launch
    checkPendingWidgetActions()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    // Check for widget actions when app comes to foreground
    checkPendingWidgetActions()
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    // Start monitoring when app becomes active
    startMonitoringWidgetActions()
  }
  
  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    // Stop monitoring when app becomes inactive
    stopMonitoringWidgetActions()
  }

  private func getDatabase(containerId: String) -> CKDatabase {
    let container = CKContainer(identifier: containerId)
    return container.privateCloudDatabase 
  }

  private func ckRecordToDictionary(record: CKRecord) -> [String: Any] {
    var dict: [String: Any] = [:]
    dict["recordName"] = record.recordID.recordName
    for key in record.allKeys() {
        if let value = record[key] {
            if let stringValue = value as? String {
                dict[key] = stringValue
            } else if let intValue = value as? Int64 {
                dict[key] = intValue
            } else if let doubleValue = value as? Double {
                 dict[key] = doubleValue
            } else if let dateValue = value as? Date {
                dict[key] = dateValue.timeIntervalSince1970 * 1000
            } else if value is NSNull {
            }
        }
    }
    return dict
  }

  private func fetchRecords(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let containerId = args["containerId"] as? String,
          let recordType = args["recordType"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing arguments for fetchRecords", details: nil))
      return
    }

    let database = getDatabase(containerId: containerId)
    let predicate = NSPredicate(value: true) 
    let query = CKQuery(recordType: recordType, predicate: predicate)

    database.perform(query, inZoneWith: nil) { (records, error) in
      DispatchQueue.main.async {
        if let error = error {
          NSLog("CloudKit Error fetching records: \(error.localizedDescription)")
          result(FlutterError(code: "CLOUDKIT_ERROR", message: error.localizedDescription, details: error._userInfo))
          return
        }
        guard let ckRecords = records else {
          result([]) 
          return
        }
        let resultsArray = ckRecords.map { self.ckRecordToDictionary(record: $0) }
        result(resultsArray)
      }
    }
  }

  private func saveRecord(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let containerId = args["containerId"] as? String,
          let recordType = args["recordType"] as? String,
          let fields = args["fields"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing arguments for saveRecord", details: nil))
      return
    }
    
    let recordNameString = args["recordName"] as? String 
    let database = getDatabase(containerId: containerId)
    
    let ckRecord: CKRecord // Declare ckRecord

    if let name = recordNameString, !name.isEmpty {
        // This is an update to an existing record
        let recordID = CKRecord.ID(recordName: name)
        // For updates, it's best practice to fetch the existing record first,
        // modify its fields, then save. This avoids accidentally nil-ing out fields
        // not included in the `fields` map.
        // However, for simplicity in this version, we're creating a new CKRecord instance
        // with the existing ID and overwriting fields.
        ckRecord = CKRecord(recordType: recordType, recordID: recordID) // For overwriting update
    } else {
        // This is a new record, CloudKit will generate the recordID.recordName
        ckRecord = CKRecord(recordType: recordType) 
    }

    for (key, dartValue) in fields {
        if let stringValue = dartValue as? String {
            ckRecord[key] = stringValue as CKRecordValue
        } else if let intValue = dartValue as? Int { // Dart int can be Int64 in CloudKit
            ckRecord[key] = NSNumber(value: intValue) as CKRecordValue
        } else if let doubleValue = dartValue as? Double {
            ckRecord[key] = NSNumber(value: doubleValue) as CKRecordValue
        } else if let boolValue = dartValue as? Bool {
             ckRecord[key] = NSNumber(value: boolValue) as CKRecordValue
        }
        // Add other types as needed (Date, CKReference for relations, etc.)
    }
    
    database.save(ckRecord) { (savedRecord, error) in
        DispatchQueue.main.async {
            if let error = error {
                NSLog("CloudKit Error saving record: \(error.localizedDescription)")
                // Provide more context if it's a specific CloudKit error code
                let ckError = error as? CKError
                var errorMessage = error.localizedDescription
                if let partialErrors = ckError?.partialErrorsByItemID {
                    errorMessage += " Partial errors: \(partialErrors)"
                }
                 if ckError?.code == .serverRecordChanged {
                    errorMessage += " (Server record changed - conflict resolution might be needed)"
                }
                result(FlutterError(code: "CLOUDKIT_ERROR", message: errorMessage, details: ckError?.errorUserInfo))
                return
            }
            guard let finalRecord = savedRecord else {
                result(FlutterError(code: "CLOUDKIT_ERROR", message: "Save operation did not return a record.", details: nil))
                return
            }
            result(self.ckRecordToDictionary(record: finalRecord))
        }
    }
  }

  private func deleteRecord(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let containerId = args["containerId"] as? String,
          let recordName = args["recordName"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing arguments for deleteRecord", details: nil))
      return
    }

    let database = getDatabase(containerId: containerId)
    let recordID = CKRecord.ID(recordName: recordName)

    database.delete(withRecordID: recordID) { (deletedRecordID, error) in
      DispatchQueue.main.async {
        if let error = error {
          NSLog("CloudKit Error deleting record: \(error.localizedDescription)")
          result(FlutterError(code: "CLOUDKIT_ERROR", message: error.localizedDescription, details: error._userInfo))
          return
        }
        result(nil) 
      }
    }
  }
  
  // MARK: - Widget Action Handling
  
  private func handleWidgetMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "reloadWidget":
      reloadWidget()
      result(nil)
      
    case "getWidgetAction":
      let action = getPendingWidgetAction()
      result(action)
      
    case "clearWidgetAction":
      clearWidgetAction()
      result(nil)
      
    case "updateWidgetData":
      updateWidgetDataFromFlutter(call: call, result: result)
      
    case "getAreaFilter":
      let filter = getAreaFilter()
      result(filter)
      
    case "setAreaFilter":
      setAreaFilter(call: call, result: result)
      
    case "clearAllWidgetData":
      clearAllWidgetData()
      result(nil)
      
    case "getActiveSession":
      let session = getActiveSession()
      result(session)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func startMonitoringWidgetActions() {
    stopMonitoringWidgetActions() // Ensure we don't have duplicate timers
    
    // Check for widget actions every 0.5 seconds while app is active
    widgetActionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      self?.checkPendingWidgetActions()
    }
  }
  
  private func stopMonitoringWidgetActions() {
    widgetActionTimer?.invalidate()
    widgetActionTimer = nil
  }
  
  private func checkPendingWidgetActions() {
    guard let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad") else {
      print("AppDelegate: Could not access shared UserDefaults")
      return
    }
    
    // Check if there's a pending widget action
    if let actionString = userDefaults.string(forKey: "widget_action"),
       !actionString.isEmpty {
      
      print("AppDelegate: Found pending widget action: \(actionString)")
      
      // Notify Flutter about the widget action
      DispatchQueue.main.async { [weak self] in
        self?.widgetMethodChannel?.invokeMethod("widgetActionReceived", arguments: nil)
      }
    }
  }
  
  private func getPendingWidgetAction() -> String? {
    guard let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad") else {
      return nil
    }
    
    return userDefaults.string(forKey: "widget_action")
  }
  
  private func clearWidgetAction() {
    guard let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad") else {
      return
    }
    
    userDefaults.removeObject(forKey: "widget_action")
    userDefaults.synchronize()
    print("AppDelegate: Cleared widget action")
  }
  
  private func reloadWidget() {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
      print("AppDelegate: Triggered widget reload")
    }
  }
  
  private func updateWidgetDataFromFlutter(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad") else {
      result(FlutterError(code: "APP_GROUP_ERROR", message: "Could not access shared UserDefaults", details: nil))
      return
    }
    
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments must be a dictionary", details: nil))
      return
    }
    
    // Update each piece of data if provided
    for (key, value) in args {
      if let stringValue = value as? String {
        userDefaults.set(stringValue, forKey: key)
        print("AppDelegate: Updated \(key) with string value")
      } else if value is NSNull {
        userDefaults.removeObject(forKey: key)
        print("AppDelegate: Cleared \(key)")
      }
    }
    
    userDefaults.synchronize()
    print("AppDelegate: Widget data updated from Flutter")
    result(nil)
  }
  
  private func getAreaFilter() -> String {
    guard let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad") else {
      return "all"
    }
    
    return userDefaults.string(forKey: "selected_area_filter") ?? "all"
  }
  
  private func setAreaFilter(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad") else {
      result(FlutterError(code: "APP_GROUP_ERROR", message: "Could not access shared UserDefaults", details: nil))
      return
    }
    
    guard let args = call.arguments as? [String: Any],
          let filter = args["filter"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Filter argument is required", details: nil))
      return
    }
    
    userDefaults.set(filter, forKey: "selected_area_filter")
    userDefaults.synchronize()
    print("AppDelegate: Updated area filter to: \(filter)")
    result(nil)
  }
  
  private func getActiveSession() -> String? {
    guard let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad") else {
      return nil
    }
    
    return userDefaults.string(forKey: "active_session")
  }
  
  private func clearAllWidgetData() {
    guard let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad") else {
      return
    }
    
    userDefaults.removeObject(forKey: "practice_areas")
    userDefaults.removeObject(forKey: "active_session")
    userDefaults.removeObject(forKey: "daily_goal")
    userDefaults.removeObject(forKey: "todays_practice")
    userDefaults.removeObject(forKey: "widget_action")
    userDefaults.removeObject(forKey: "selected_area_filter")
    userDefaults.synchronize()
    print("AppDelegate: Cleared all widget data")
  }
}
