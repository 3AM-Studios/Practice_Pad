import Foundation
import CloudKit
import Flutter

class CloudKitHandler: NSObject {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private var currentUserRecordID: CKRecord.ID?
    
    // Record type constants
    private struct RecordTypes {
        static let weeklySchedule = "WeeklySchedule"
        static let practiceArea = "PracticeArea"
        static let practiceItem = "PracticeItem"
        static let practiceSession = "PracticeSession"
        static let songChanges = "SongChanges"
        static let chordKeys = "ChordKeys"
        static let sheetMusic = "SheetMusic"
        static let songDrawings = "SongDrawings"
        static let pdfDrawings = "PDFDrawings"
        static let youtubeLinks = "YouTubeLinks"
        static let savedLoops = "SavedLoops"
        static let youtubeVideos = "YouTubeVideos"
        static let books = "Books"
        static let customSongs = "CustomSongs"
        static let pdfLabels = "PDFLabels"
    }
    
    override init() {
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
        super.init()
    }
    
    // MARK: - Method Channel Handler
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🔄 [CLOUDKIT] Handling method: \(call.method)")
        
        switch call.method {
        case "checkAccountStatus":
            checkAccountStatus(result: result)
            
        case "saveRecord":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                return
            }
            saveRecord(args: args, result: result)
            
        case "fetchRecord":
            guard let args = call.arguments as? [String: Any],
                  let recordID = args["recordID"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "recordID is required", details: nil))
                return
            }
            fetchRecord(recordID: recordID, result: result)
            
        case "fetchRecordsByType":
            guard let args = call.arguments as? [String: Any],
                  let recordType = args["recordType"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "recordType is required", details: nil))
                return
            }
            fetchRecordsByType(recordType: recordType, result: result)
            
        case "deleteRecord":
            guard let args = call.arguments as? [String: Any],
                  let recordID = args["recordID"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "recordID is required", details: nil))
                return
            }
            deleteRecord(recordID: recordID, result: result)
            
        case "fetchAllRecords":
            fetchAllRecords(result: result)
            
        case "migrateFromFiles":
            guard let args = call.arguments as? [String: Any],
                  let fileData = args["fileData"] as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "fileData is required", details: nil))
                return
            }
            migrateFromFiles(fileData: fileData, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Account Status
    private func checkAccountStatus(result: @escaping FlutterResult) {
        container.accountStatus { (accountStatus, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [CLOUDKIT] Account status error: \(error)")
                    result(["status": "error", "error": error.localizedDescription])
                    return
                }
                
                let status: String
                switch accountStatus {
                case .available:
                    status = "available"
                case .noAccount:
                    status = "noAccount"
                case .restricted:
                    status = "restricted"
                case .couldNotDetermine:
                    status = "couldNotDetermine"
                case .temporarilyUnavailable:
                    status = "temporarilyUnavailable"
                @unknown default:
                    status = "unknown"
                }
                
                print("✅ [CLOUDKIT] Account status: \(status)")
                result(["status": status])
            }
        }
    }
    
    // MARK: - Save Record
    private func saveRecord(args: [String: Any], result: @escaping FlutterResult) {
        guard let recordType = args["recordType"] as? String,
              let fields = args["fields"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "recordType and fields are required", details: nil))
            return
        }
        
        let recordID = args["recordID"] as? String
        let record: CKRecord
        
        if let recordID = recordID {
            // Update existing record
            record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: recordID))
        } else {
            // Create new record with UUID
            record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: UUID().uuidString))
        }
        
        // Set fields
        setRecordFields(record: record, fields: fields)
        
        print("💾 [CLOUDKIT] Saving record: \(record.recordType) with ID: \(record.recordID.recordName)")
        
        privateDatabase.save(record) { (savedRecord, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [CLOUDKIT] Save error: \(error)")
                    result(FlutterError(code: "SAVE_FAILED", message: error.localizedDescription, details: nil))
                    return
                }
                
                guard let savedRecord = savedRecord else {
                    result(FlutterError(code: "NO_RECORD", message: "No record returned", details: nil))
                    return
                }
                
                print("✅ [CLOUDKIT] Record saved: \(savedRecord.recordID.recordName)")
                let recordDict = self.recordToDict(record: savedRecord)
                result(recordDict)
            }
        }
    }
    
    // MARK: - Fetch Record
    private func fetchRecord(recordID: String, result: @escaping FlutterResult) {
        let ckRecordID = CKRecord.ID(recordName: recordID)
        
        print("📥 [CLOUDKIT] Fetching record: \(recordID)")
        
        privateDatabase.fetch(withRecordID: ckRecordID) { (record, error) in
            DispatchQueue.main.async {
                if let error = error {
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        print("⚠️ [CLOUDKIT] Record not found: \(recordID)")
                        result(nil)
                    } else {
                        print("❌ [CLOUDKIT] Fetch error: \(error)")
                        result(FlutterError(code: "FETCH_FAILED", message: error.localizedDescription, details: nil))
                    }
                    return
                }
                
                guard let record = record else {
                    result(nil)
                    return
                }
                
                print("✅ [CLOUDKIT] Record fetched: \(record.recordID.recordName)")
                let recordDict = self.recordToDict(record: record)
                result(recordDict)
            }
        }
    }
    
    // MARK: - Fetch Records by Type
    private func fetchRecordsByType(recordType: String, result: @escaping FlutterResult) {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        print("📥 [CLOUDKIT] Fetching records of type: \(recordType)")
        
        privateDatabase.perform(query, inZoneWith: nil) { (records, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [CLOUDKIT] Query error: \(error)")
                    result(FlutterError(code: "QUERY_FAILED", message: error.localizedDescription, details: nil))
                    return
                }
                
                let records = records ?? []
                print("✅ [CLOUDKIT] Found \(records.count) records of type: \(recordType)")
                
                let recordDicts = records.map { self.recordToDict(record: $0) }
                result(recordDicts)
            }
        }
    }
    
    // MARK: - Delete Record
    private func deleteRecord(recordID: String, result: @escaping FlutterResult) {
        let ckRecordID = CKRecord.ID(recordName: recordID)
        
        print("🗑️ [CLOUDKIT] Deleting record: \(recordID)")
        
        privateDatabase.delete(withRecordID: ckRecordID) { (deletedRecordID, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [CLOUDKIT] Delete error: \(error)")
                    result(FlutterError(code: "DELETE_FAILED", message: error.localizedDescription, details: nil))
                    return
                }
                
                print("✅ [CLOUDKIT] Record deleted: \(recordID)")
                result(["success": true])
            }
        }
    }
    
    // MARK: - Fetch All Records
    private func fetchAllRecords(result: @escaping FlutterResult) {
        let allRecordTypes = [
            RecordTypes.weeklySchedule, RecordTypes.practiceArea, RecordTypes.practiceItem,
            RecordTypes.practiceSession, RecordTypes.songChanges, RecordTypes.chordKeys,
            RecordTypes.sheetMusic, RecordTypes.songDrawings, RecordTypes.pdfDrawings,
            RecordTypes.youtubeLinks, RecordTypes.savedLoops, RecordTypes.youtubeVideos,
            RecordTypes.books, RecordTypes.customSongs, RecordTypes.pdfLabels
        ]
        
        var allRecords: [String: [[String: Any]]] = [:]
        let dispatchGroup = DispatchGroup()
        var hasError = false
        var errorMessage = ""
        
        for recordType in allRecordTypes {
            dispatchGroup.enter()
            
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            privateDatabase.perform(query, inZoneWith: nil) { (records, error) in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    hasError = true
                    errorMessage = error.localizedDescription
                    return
                }
                
                let records = records ?? []
                let recordDicts = records.map { self.recordToDict(record: $0) }
                allRecords[recordType] = recordDicts
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if hasError {
                result(FlutterError(code: "FETCH_ALL_FAILED", message: errorMessage, details: nil))
            } else {
                print("✅ [CLOUDKIT] Fetched all records from \(allRecordTypes.count) types")
                result(allRecords)
            }
        }
    }
    
    // MARK: - Migration from Files
    private func migrateFromFiles(fileData: [String: Any], result: @escaping FlutterResult) {
        print("🔄 [CLOUDKIT] Starting migration from files")
        
        let dispatchGroup = DispatchGroup()
        var migratedRecords: [String] = []
        var errors: [String] = []
        
        // Migrate each file type to corresponding record type
        for (fileName, data) in fileData {
            dispatchGroup.enter()
            
            migrateFileToRecord(fileName: fileName, data: data) { success, recordType, error in
                defer { dispatchGroup.leave() }
                
                if success, let recordType = recordType {
                    migratedRecords.append(recordType)
                } else if let error = error {
                    errors.append("\(fileName): \(error)")
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if errors.isEmpty {
                print("✅ [CLOUDKIT] Migration completed: \(migratedRecords.count) record types migrated")
                result([
                    "success": true,
                    "migratedRecords": migratedRecords
                ])
            } else {
                print("⚠️ [CLOUDKIT] Migration completed with errors: \(errors)")
                result([
                    "success": false,
                    "migratedRecords": migratedRecords,
                    "errors": errors
                ])
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setRecordFields(record: CKRecord, fields: [String: Any]) {
        for (key, value) in fields {
            if key == "recordID" { continue } // Skip recordID as it's set separately
            
            if let stringValue = value as? String {
                record.setValue(stringValue, forKey: key)
            } else if let numberValue = value as? NSNumber {
                record.setValue(numberValue, forKey: key)
            } else if let boolValue = value as? Bool {
                record.setValue(boolValue, forKey: key)
            } else if let dateValue = value as? Date {
                record.setValue(dateValue, forKey: key)
            } else if let dictValue = value as? [String: Any],
                      let jsonData = try? JSONSerialization.data(withJSONObject: dictValue),
                      let jsonString = String(data: jsonData, encoding: .utf8) {
                record.setValue(jsonString, forKey: key)
            } else if let arrayValue = value as? [Any],
                      let jsonData = try? JSONSerialization.data(withJSONObject: arrayValue),
                      let jsonString = String(data: jsonData, encoding: .utf8) {
                record.setValue(jsonString, forKey: key)
            } else {
                // Convert to string as fallback
                record.setValue(String(describing: value), forKey: key)
            }
        }
    }
    
    private func recordToDict(record: CKRecord) -> [String: Any] {
        var dict: [String: Any] = [
            "recordID": record.recordID.recordName,
            "recordType": record.recordType,
            "modificationDate": record.modificationDate?.timeIntervalSince1970 ?? 0,
            "creationDate": record.creationDate?.timeIntervalSince1970 ?? 0
        ]
        
        for key in record.allKeys() {
            if let value = record.value(forKey: key) {
                if let stringValue = value as? String {
                    // Try to parse JSON strings back to objects
                    if stringValue.hasPrefix("{") || stringValue.hasPrefix("["),
                       let data = stringValue.data(using: .utf8),
                       let jsonObject = try? JSONSerialization.jsonObject(with: data) {
                        dict[key] = jsonObject
                    } else {
                        dict[key] = stringValue
                    }
                } else if let dateValue = value as? Date {
                    dict[key] = dateValue.timeIntervalSince1970
                } else {
                    dict[key] = value
                }
            }
        }
        
        return dict
    }
    
    private func migrateFileToRecord(fileName: String, data: Any, completion: @escaping (Bool, String?, String?) -> Void) {
        let recordType = getRecordTypeForFile(fileName: fileName)
        
        guard !recordType.isEmpty else {
            completion(false, nil, "Unknown file type: \(fileName)")
            return
        }
        
        let recordID = getRecordIDForFile(fileName: fileName)
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: recordID))
        
        // Set the data field based on file type
        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            switch recordType {
            case RecordTypes.weeklySchedule:
                record.setValue(jsonString, forKey: "scheduleData")
            case RecordTypes.songChanges:
                record.setValue(jsonString, forKey: "allChangesData")
            case RecordTypes.chordKeys:
                record.setValue(jsonString, forKey: "allChordKeysData")
            case RecordTypes.sheetMusic:
                record.setValue(jsonString, forKey: "allSheetMusicData")
            case RecordTypes.youtubeLinks:
                record.setValue(jsonString, forKey: "allLinksData")
            case RecordTypes.savedLoops:
                record.setValue(jsonString, forKey: "allLoopsData")
            case RecordTypes.youtubeVideos:
                record.setValue(jsonString, forKey: "videosListData")
            case RecordTypes.books:
                record.setValue(jsonString, forKey: "booksData")
            case RecordTypes.customSongs:
                record.setValue(jsonString, forKey: "songsData")
            default:
                record.setValue(jsonString, forKey: "data")
            }
        }
        
        privateDatabase.save(record) { (savedRecord, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, recordType, error.localizedDescription)
                } else {
                    completion(true, recordType, nil)
                }
            }
        }
    }
    
    private func getRecordTypeForFile(fileName: String) -> String {
        switch fileName {
        case "weekly_schedule.json":
            return RecordTypes.weeklySchedule
        case "practice_areas.json":
            return RecordTypes.practiceArea
        case "practice_items.json":
            return RecordTypes.practiceItem
        case "song_changes.json":
            return RecordTypes.songChanges
        case "chord_keys.json":
            return RecordTypes.chordKeys
        case "sheet_music.json":
            return RecordTypes.sheetMusic
        case "drawings.json":
            return RecordTypes.songDrawings
        case "pdf_drawings.json":
            return RecordTypes.pdfDrawings
        case "youtube_links.json":
            return RecordTypes.youtubeLinks
        case "saved_loops.json":
            return RecordTypes.savedLoops
        case "youtube_videos.json":
            return RecordTypes.youtubeVideos
        case "books.json":
            return RecordTypes.books
        case "custom_songs.json":
            return RecordTypes.customSongs
        default:
            if fileName.contains("_labels.json") {
                return RecordTypes.pdfLabels
            }
            return ""
        }
    }
    
    private func getRecordIDForFile(fileName: String) -> String {
        // Use filename (without extension) as record ID for aggregate records
        let baseFileName = (fileName as NSString).deletingPathExtension
        
        switch fileName {
        case "weekly_schedule.json", "song_changes.json", "chord_keys.json",
             "sheet_music.json", "drawings.json", "pdf_drawings.json",
             "youtube_links.json", "saved_loops.json", "youtube_videos.json",
             "books.json", "custom_songs.json":
            return baseFileName
        default:
            // For other files, use filename with UUID suffix to ensure uniqueness
            return "\(baseFileName)_\(UUID().uuidString)"
        }
    }
}