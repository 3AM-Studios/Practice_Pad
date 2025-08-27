import UIKit
import Flutter
import CloudKit
import WidgetKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    private let WIDGET_CHANNEL_NAME = "com.3amstudios.jazzpad/widget"
    private let CLOUDKIT_CHANNEL_NAME = "iCloud.com.practicepad"
    private let USER_DEFAULTS_SUITE = "group.com.3amstudios.jazzpad"
    
    private var widgetMethodChannel: FlutterMethodChannel?
    private var userDefaults: UserDefaults?
    
    // Timer for polling widget actions
    private var widgetActionTimer: Timer?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not type FlutterViewController")
        }
        
        userDefaults = UserDefaults(suiteName: USER_DEFAULTS_SUITE)
        
        // --- Set up CloudKit Channel ---
        let cloudKitChannel = FlutterMethodChannel(name: CLOUDKIT_CHANNEL_NAME,
                                                   binaryMessenger: controller.binaryMessenger)
        cloudKitChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "fetchRecords": self.fetchRecords(call: call, result: result)
            case "saveRecord": self.saveRecord(call: call, result: result)
            case "deleteRecord": self.deleteRecord(call: call, result: result)
            default: result(FlutterMethodNotImplemented)
            }
        })
        
        // --- Set up iCloud Documents Sync Channel ---
        let icloudSyncChannel = FlutterMethodChannel(name: "icloud_documents_sync",
                                                    binaryMessenger: controller.binaryMessenger)
        let icloudSyncHandler = ICloudSyncHandler()
        icloudSyncChannel.setMethodCallHandler { (call, result) in
            icloudSyncHandler.handle(call, result: result)
        }

        // --- Set up Widget Channel ---
        widgetMethodChannel = FlutterMethodChannel(name: WIDGET_CHANNEL_NAME,
                                                   binaryMessenger: controller.binaryMessenger)
        widgetMethodChannel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handleWidgetMethodCall(call, result: result)
        }
        
        // Start monitoring for widget actions
        startWidgetActionMonitoring()
        
        // Check for any action that occurred while the app was closed
        checkPendingWidgetActions()

        GeneratedPluginRegistrant.register(with: self)
        
        // Additional setup for webview plugins to handle platform view registration
        if #available(iOS 11.0, *) {
            // This ensures proper webview initialization
            let _ = WKWebView()
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Handle URL scheme deep links
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("iOS: Received URL: \(url)")
        
        // Parse the URL scheme: practicepad://practice/{itemId}
        if url.scheme == "practicepad" && url.host == "practice" {
            let itemId = url.lastPathComponent
            print("iOS: Deep link to practice item: \(itemId)")
            
            // Save the deep link action for Flutter to process
            let actionData = [
                "action": "open_practice_item",
                "itemId": itemId,
                "timestamp": Date().timeIntervalSince1970
            ] as [String: Any]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: actionData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                userDefaults?.set(jsonString, forKey: "widget_action")
                print("iOS: Saved deep link action: \(jsonString)")
                
                // Notify Flutter if the app is already running
                widgetMethodChannel?.invokeMethod("widgetActionReceived", arguments: nil)
            }
            
            return true
        }
        
        return super.application(app, open: url, options: options)
    }

    // MARK: - Widget Action Handling (Polling Method)
    
    private func startWidgetActionMonitoring() {
        guard let userDefaults = self.userDefaults else { return }
        
        // Poll for widget actions every 1 second when app is active
        widgetActionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if let action = userDefaults.string(forKey: "widget_action"), !action.isEmpty {
                print("iOS Native (Timer): Detected widget action. Notifying Flutter.")
                self.widgetMethodChannel?.invokeMethod("widgetActionReceived", arguments: nil)
            }
        }
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        // Clean up the timer when app terminates
        widgetActionTimer?.invalidate()
        widgetActionTimer = nil
        super.applicationWillTerminate(application)
    }
    
    private func checkPendingWidgetActions() {
        if let action = userDefaults?.string(forKey: "widget_action"), !action.isEmpty {
            print("iOS Native: Found pending widget action on startup.")
            widgetMethodChannel?.invokeMethod("widgetActionReceived", arguments: nil)
        }
    }
    
    private func handleWidgetMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getWidgetAction":
            result(userDefaults?.string(forKey: "widget_action"))
        case "clearWidgetAction":
            userDefaults?.removeObject(forKey: "widget_action")
            result(nil)
        case "updateWidgetData":
            if let args = call.arguments as? [String: Any?] {
                args.forEach { key, value in userDefaults?.set(value, forKey: key) }
            }
            result(nil)
        case "reloadWidget":
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadTimelines(ofKind: "PracticePadWidget")
            }
            result(nil)
        case "clearAllWidgetData":
            let keys = ["practice_areas", "active_session", "daily_goal", "todays_practice", "widget_action"]
            keys.forEach { userDefaults?.removeObject(forKey: $0) }
            result(nil)
        case "getAreaFilter":
            result(userDefaults?.string(forKey: "selected_area_filter") ?? "all")
        case "setAreaFilter":
            if let args = call.arguments as? [String: Any], let filter = args["filter"] as? String {
                userDefaults?.set(filter, forKey: "selected_area_filter")
            }
            result(nil)
        case "getActiveSession":
            result(userDefaults?.string(forKey: "active_session"))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - CloudKit Methods (Your existing code)
    
    private func getDatabase(containerId: String) -> CKDatabase {
        let container = CKContainer(identifier: containerId)
        return container.privateCloudDatabase
    }

    private func ckRecordToDictionary(record: CKRecord) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["recordName"] = record.recordID.recordName
        for key in record.allKeys() {
            if let value = record[key] {
                if let stringValue = value as? String { dict[key] = stringValue }
                else if let intValue = value as? Int64 { dict[key] = intValue }
                else if let doubleValue = value as? Double { dict[key] = doubleValue }
                else if let dateValue = value as? Date { dict[key] = dateValue.timeIntervalSince1970 * 1000 }
            }
        }
        return dict
    }

    private func fetchRecords(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let containerId = args["containerId"] as? String,
              let recordType = args["recordType"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing arguments", details: nil))
            return
        }
        let database = getDatabase(containerId: containerId)
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        database.perform(query, inZoneWith: nil) { (records, error) in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "CLOUDKIT_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                let resultsArray = records?.map { self.ckRecordToDictionary(record: $0) } ?? []
                result(resultsArray)
            }
        }
    }

    private func saveRecord(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let containerId = args["containerId"] as? String,
              let recordType = args["recordType"] as? String,
              let fields = args["fields"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing arguments", details: nil))
            return
        }
        let recordName = args["recordName"] as? String
        let database = getDatabase(containerId: containerId)
        let recordID = (recordName != nil) ? CKRecord.ID(recordName: recordName!) : CKRecord.ID()
        let ckRecord = CKRecord(recordType: recordType, recordID: recordID)
        fields.forEach { key, value in ckRecord[key] = value as? CKRecordValue }
        database.save(ckRecord) { (savedRecord, error) in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "CLOUDKIT_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                result(self.ckRecordToDictionary(record: savedRecord!))
            }
        }
    }

    private func deleteRecord(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let containerId = args["containerId"] as? String,
              let recordName = args["recordName"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing arguments", details: nil))
            return
        }
        let database = getDatabase(containerId: containerId)
        let recordID = CKRecord.ID(recordName: recordName)
        database.delete(withRecordID: recordID) { (deletedRecordID, error) in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "CLOUDKIT_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                result(nil)
            }
        }
    }
}