import CloudKit

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

public class FlutterCloudKitPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
            let messenger = registrar.messenger()
        #else
            let messenger = registrar.messenger
        #endif
        
        let channel = FlutterMethodChannel(name: "app.fuelet.flutter_cloud_kit", binaryMessenger: messenger)
        let instance = FlutterCloudKitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    // TODO: handle ObjectiveC exceptions
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let callArguments: Dictionary<String, Any> = call.arguments as! Dictionary<String, Any>
        
        if (call.method == "getAccountStatus") {
            return GetAccountStatusHandler.handle(arguments: callArguments, result: result);
        } else if (call.method == "saveRecord") {
            return SaveRecordHandler.handle(arguments: callArguments, result: result);
        } else if (call.method == "getRecord") {
            return GetRecordHandler.handle(arguments: callArguments, result: result);
        } else if (call.method == "deleteRecord") {
            return DeleteRecordHandler.handle(arguments: callArguments, result: result);
        } else if (call.method == "getRecordsByType") {
            return GetRecordsByTypeHandler.handle(arguments: callArguments, result: result);
        } else if (call.method == "saveRecordWithAssets") {
            return SaveRecordWithAssetsHandler.handle(arguments: callArguments, result: result);
        } else if (call.method == "downloadAsset") {
            return handleDownloadAsset(arguments: callArguments, result: result);
        } else {
            return result(createFlutterError(message: "Not implemented"));
        }
    }
    
    private func handleDownloadAsset(arguments: Dictionary<String, Any>, result: @escaping FlutterResult) -> Void {
        let database: CKDatabase
        if let databaseOpt = getDatabaseFromArgs(arguments: arguments) {
            database = databaseOpt
        } else {
            return result(createFlutterError(message: "Cannot create a database for the provided scope"))
        }
        
        guard let recordName = arguments["recordName"] as? String,
              let assetKey = arguments["assetKey"] as? String,
              let localFilePath = arguments["localFilePath"] as? String else {
            return result(createFlutterError(message: "Missing required parameters for asset download"))
        }
        
        // Create record ID
        let recordID = CKRecord.ID(recordName: recordName)
        
        // Fetch the record first
        database.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                DispatchQueue.main.async {
                    result(createFlutterError(message: "Failed to fetch record: \(error.localizedDescription)"))
                }
                return
            }
            
            guard let record = record else {
                DispatchQueue.main.async {
                    result(createFlutterError(message: "Record not found: \(recordName)"))
                }
                return
            }
            
            // Get the asset from the record
            guard let asset = record[assetKey] as? CKAsset else {
                DispatchQueue.main.async {
                    result(createFlutterError(message: "Asset not found in record: \(assetKey)"))
                }
                return
            }
            
            // Get the asset file URL
            guard let assetFileURL = asset.fileURL else {
                DispatchQueue.main.async {
                    result(createFlutterError(message: "Asset file URL is nil"))
                }
                return
            }
            
            // Create destination URL
            let destinationURL = URL(fileURLWithPath: localFilePath)
            
            // Create destination directory if it doesn't exist
            let destinationDirectory = destinationURL.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                DispatchQueue.main.async {
                    result(createFlutterError(message: "Failed to create destination directory: \(error.localizedDescription)"))
                }
                return
            }
            
            // Copy the asset file to the destination
            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: localFilePath) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy the file
                try FileManager.default.copyItem(at: assetFileURL, to: destinationURL)
                
                DispatchQueue.main.async {
                    result(localFilePath)
                }
            } catch {
                DispatchQueue.main.async {
                    result(createFlutterError(message: "Failed to copy asset file: \(error.localizedDescription)"))
                }
            }
        }
    }
}
