//
//  SaveRecordWithAssetsHandler.swift
//  flutter_cloud_kit
//
//  Created by AI Assistant on 09.09.24.
//

import CloudKit
import Foundation

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

class SaveRecordWithAssetsHandler {
    static func handle(arguments: Dictionary<String, Any>, result: @escaping FlutterResult) -> Void {
        let database: CKDatabase;
        let recordType: String;
        let recordValues: Dictionary<String, String>;
        let assets: Dictionary<String, Any>;
        
        if let databaseOpt = getDatabaseFromArgs(arguments: arguments) {
            database = databaseOpt;
        } else {
            return result(createFlutterError(message: "Cannot create a database for the provided scope"));
        }
        
        if let recordTypeOpt = getRecordTypeFromArgs(arguments: arguments) {
            recordType = recordTypeOpt;
        } else {
            return result(createFlutterError(message: "Couldn't parse the required parameter 'recordType'"));
        }
        
        if let recordValuesOpt = getRecordValuesFromArgs(arguments: arguments) {
            recordValues = recordValuesOpt;
        } else {
            return result(createFlutterError(message: "Couldn't parse the required parameter 'record'"));
        }
        
        if let assetsOpt = getAssetsFromArgs(arguments: arguments) {
            assets = assetsOpt;
        } else {
            return result(createFlutterError(message: "Couldn't parse the required parameter 'assets'"));
        }
        
        let recordId = getRecordIdFromArgsOrDefault(arguments: arguments);
        let record = CKRecord(recordType: recordType, recordID: recordId);
        
        // Set string values
        for (key, value) in recordValues {
            record[key] = value as CKRecordValue;
        }
        
        // Set asset values
        for (key, assetData) in assets {
            if let assetInfo = assetData as? Dictionary<String, Any> {
                // Support both localFilePath (new format) and filePath (legacy)
                let filePath = assetInfo["localFilePath"] as? String ?? assetInfo["filePath"] as? String
                
                guard let filePath = filePath else {
                    return result(createFlutterError(message: "Asset missing filePath or localFilePath: \(key)"))
                }
                
                let fileURL = URL(fileURLWithPath: filePath);
                
                // Check if file exists
                guard FileManager.default.fileExists(atPath: filePath) else {
                    return result(createFlutterError(message: "Asset file does not exist at path: \(filePath)"));
                }
                
                let asset = CKAsset(fileURL: fileURL);
                record[key] = asset;
            }
        }
        
        database.save(record) { (record, error) in
            if let error = error {
                return result(createFlutterError(message: error.localizedDescription));
            }
            if record == nil {
                return result(createFlutterError(message: "Got nil while saving the record"));
            }
            return result(true);
        }
    }
}