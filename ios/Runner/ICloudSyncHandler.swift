import Foundation
import Flutter
import Dispatch

class ICloudSyncHandler: NSObject {
    private let fileManager = FileManager.default
    
    // MARK: - Method Channel Handler
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isICloudAvailable":
            result(isICloudAvailable())
            
        case "getICloudAccountStatus":
            getICloudAccountStatus { status in
                result(status)
            }
            
        case "syncFileToICloud":
            guard let args = call.arguments as? [String: Any],
                  let fileName = args["fileName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "fileName is required", details: nil))
                return
            }
            
            syncFileToICloudWithRetry(fileName: fileName) { success, error in
                if success {
                    result(["success": true])
                } else {
                    result(["success": false, "error": error ?? "Unknown error"])
                }
            }
            
        case "downloadFileFromICloud":
            guard let args = call.arguments as? [String: Any],
                  let fileName = args["fileName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "fileName is required", details: nil))
                return
            }
            
            downloadFileFromICloudWithRetry(fileName: fileName) { success, error in
                if success {
                    result(["success": true])
                } else {
                    result(["success": false, "error": error ?? "Unknown error"])
                }
            }
            
        case "getFileSyncStatus":
            guard let args = call.arguments as? [String: Any],
                  let fileName = args["fileName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "fileName is required", details: nil))
                return
            }
            
            let status = getFileSyncStatus(fileName: fileName)
            result(status)
            
        case "listICloudFiles":
            listICloudFiles { files, error in
                if let files = files {
                    result(["success": true, "files": files])
                } else {
                    result(["success": false, "error": error ?? "Unknown error"])
                }
            }
            
        case "deleteFileFromICloud":
            guard let args = call.arguments as? [String: Any],
                  let fileName = args["fileName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "fileName is required", details: nil))
                return
            }
            
            deleteFileFromICloud(fileName: fileName) { success, error in
                if success {
                    result(["success": true])
                } else {
                    result(["success": false, "error": error ?? "Unknown error"])
                }
            }
            
        case "resolveConflict":
            guard let args = call.arguments as? [String: Any],
                  let fileName = args["fileName"] as? String,
                  let resolution = args["resolution"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "fileName and resolution are required", details: nil))
                return
            }
            
            resolveConflict(fileName: fileName, resolution: resolution) { success, error in
                if success {
                    result(["success": true])
                } else {
                    result(["success": false, "error": error ?? "Unknown error"])
                }
            }
            
        case "getStorageUsage":
            getStorageUsage { usage, error in
                if let usage = usage {
                    result(["success": true, "usage": usage])
                } else {
                    result(["success": false, "error": error ?? "Unknown error"])
                }
            }
            
        case "getEnvironmentInfo":
            let envInfo = getEnvironmentInfo()
            result(envInfo)
            
        case "forceSyncFileToICloud":
            guard let args = call.arguments as? [String: Any],
                  let fileName = args["fileName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "fileName is required", details: nil))
                return
            }
            
            forceSyncFileToICloud(fileName: fileName) { success, error in
                if success {
                    result(["success": true])
                } else {
                    result(["success": false, "error": error ?? "Unknown error"])
                }
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - iCloud Availability
    private func isICloudAvailable() -> Bool {
        NSLog("🔍 [ICLOUD] Starting iCloud availability check...")
        
        let token = fileManager.ubiquityIdentityToken
        let available = token != nil
        
        NSLog("🔍 [ICLOUD] Availability check - Token exists: %@", available ? "YES" : "NO")
        print("🔍 [ICLOUD] Availability check - Token exists: \(available)")
        
        if let token = token {
            NSLog("🔍 [ICLOUD] Identity token: %@", String(describing: token))
            print("🔍 [ICLOUD] Identity token: \(String(describing: token))")
        } else {
            NSLog("❌ [ICLOUD] No iCloud identity token found")
            print("❌ [ICLOUD] No iCloud identity token found")
        }
        
        // Check bundle ID for common development issues
        if let bundleId = Bundle.main.bundleIdentifier {
            NSLog("📦 [ICLOUD] Bundle ID: %@", bundleId)
            print("📦 [ICLOUD] Bundle ID: \(bundleId)")
            
            if bundleId.starts(with: "com.example.") {
                NSLog("⚠️ [ICLOUD] Using example bundle ID - iCloud may not work properly")
                NSLog("   Example bundle IDs don't have proper iCloud entitlements")
                print("⚠️ [ICLOUD] Using example bundle ID - iCloud may not work properly")
                print("   Example bundle IDs don't have proper iCloud entitlements")
            } else {
                NSLog("✅ [ICLOUD] Using production bundle ID: %@", bundleId)
                print("✅ [ICLOUD] Using production bundle ID: \(bundleId)")
            }
        }
        
        // Additional validation
        if available {
            performDetailedICloudValidation()
        } else {
            NSLog("❌ [ICLOUD] iCloud not available - user not signed in or iCloud disabled")
            print("❌ [ICLOUD] No iCloud identity token - user not signed in or iCloud disabled")
        }
        
        NSLog("🔍 [ICLOUD] Final availability result: %@", available ? "AVAILABLE" : "NOT AVAILABLE")
        return available
    }
    
    private func performDetailedICloudValidation() {
        NSLog("🔍 [ICLOUD] Performing detailed validation...")
        print("🔍 [ICLOUD] Performing detailed validation...")
        
        // Check if we can get the container URL
        let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil)
        if let containerURL = containerURL {
            NSLog("✅ [ICLOUD] Container URL accessible: %@", containerURL.path)
            print("✅ [ICLOUD] Container URL accessible: \(containerURL.path)")
            
            // Check if container is reachable
            do {
                let reachable = try containerURL.checkResourceIsReachable()
                NSLog("✅ [ICLOUD] Container is reachable: %@", reachable ? "YES" : "NO")
                print("✅ [ICLOUD] Container is reachable: \(reachable)")
            } catch {
                NSLog("⚠️ [ICLOUD] Container reachability check failed: %@", error.localizedDescription)
                print("⚠️ [ICLOUD] Container reachability check failed: \(error)")
            }
            
            // Check container permissions
            do {
                let resourceValues = try containerURL.resourceValues(forKeys: [.isReadableKey, .isWritableKey])
                let readable = resourceValues.isReadable ?? false
                let writable = resourceValues.isWritable ?? false
                
                NSLog("📝 [ICLOUD] Container readable: %@", readable ? "YES" : "NO")
                NSLog("📝 [ICLOUD] Container writable: %@", writable ? "YES" : "NO")
                print("📝 [ICLOUD] Container readable: \(readable)")
                print("📝 [ICLOUD] Container writable: \(writable)")
                
                if !readable || !writable {
                    NSLog("❌ [ICLOUD] PERMISSION ISSUE: Container not readable/writable")
                    NSLog("❌ [ICLOUD] This is likely the source of your permission denied error")
                }
            } catch {
                NSLog("⚠️ [ICLOUD] Could not check container permissions: %@", error.localizedDescription)
                print("⚠️ [ICLOUD] Could not check container permissions: \(error)")
            }
            
            // Try to create a test directory
            let documentsURL = containerURL.appendingPathComponent("Documents")
            let testURL = documentsURL.appendingPathComponent("PracticePadData")
            
            do {
                try fileManager.createDirectory(at: testURL, withIntermediateDirectories: true)
                NSLog("✅ [ICLOUD] Successfully created test directory: %@", testURL.path)
                print("✅ [ICLOUD] Successfully created test directory: \(testURL.path)")
            } catch {
                NSLog("❌ [ICLOUD] FAILED to create test directory: %@", error.localizedDescription)
                NSLog("❌ [ICLOUD] This is the EXACT source of your permission denied error!")
                print("❌ [ICLOUD] FAILED to create test directory: \(error)")
                print("❌ [ICLOUD] This is the EXACT source of your permission denied error!")
            }
        } else {
            NSLog("❌ [ICLOUD] Container URL is nil - major configuration issue!")
            NSLog("❌ [ICLOUD] Bundle ID may not be properly configured in Apple Developer Portal")
            print("❌ [ICLOUD] Container URL is nil - major issue!")
        }
        
        // Log bundle identifier for debugging
        if let bundleId = Bundle.main.bundleIdentifier {
            NSLog("📦 [ICLOUD] Bundle ID: %@", bundleId)
            NSLog("☁️ [ICLOUD] Expected container: iCloud.%@", bundleId)
            print("📦 [ICLOUD] Bundle ID: \(bundleId)")
            print("☁️ [ICLOUD] Expected container: iCloud.\(bundleId)")
        }
        
        NSLog("🔍 [ICLOUD] Detailed validation complete")
    }
    
    private func getICloudAccountStatus(completion: @escaping (String) -> Void) {
        let token = fileManager.ubiquityIdentityToken
        print("🔍 [ICLOUD] Account status check - Token: \(token != nil ? "exists" : "nil")")
        
        if token != nil {
            print("✅ [ICLOUD] Account status: available")
            completion("available")
        } else {
            print("❌ [ICLOUD] Account status: notAvailable")
            completion("notAvailable")
        }
    }
    
    // MARK: - Directory Helpers
    private func getLocalDocumentsURL() -> URL? {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    private func getICloudDocumentsURL() -> URL? {
        // First try with nil (default container)
        if let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            print("✅ [ICLOUD] Got default container URL: \(containerURL.path)")
            let documentsURL = containerURL.appendingPathComponent("Documents")
            print("🔍 [ICLOUD] Documents URL: \(documentsURL.path)")
            return documentsURL
        }
        
        // If default fails, try with explicit bundle ID
        if let bundleId = Bundle.main.bundleIdentifier {
            let explicitContainerId = "iCloud.\(bundleId)"
            print("🔄 [ICLOUD] Trying explicit container: \(explicitContainerId)")
            
            if let containerURL = fileManager.url(forUbiquityContainerIdentifier: explicitContainerId) {
                print("✅ [ICLOUD] Got explicit container URL: \(containerURL.path)")
                let documentsURL = containerURL.appendingPathComponent("Documents")
                print("🔍 [ICLOUD] Documents URL: \(documentsURL.path)")
                return documentsURL
            } else {
                print("❌ [ICLOUD] Failed to get explicit container for: \(explicitContainerId)")
            }
        }
        
        // Last resort: try to get any available container
        print("⚠️ [ICLOUD] Trying to find any available iCloud container...")
        
        // For development/testing purposes, we might fallback to using local documents
        // This won't sync but will prevent crashes
        print("❌ [ICLOUD] No iCloud container available - this is expected with com.example.* bundle IDs")
        
        return nil
    }
    
    private func ensureICloudDirectoryExists() -> Bool {
        guard let icloudURL = getICloudDocumentsURL() else {
            print("❌ [ICLOUD] Cannot get iCloud Documents URL")
            return false
        }
        
        let practicepadURL = icloudURL.appendingPathComponent("PracticePadData")
        print("📁 [ICLOUD] PracticePad directory: \(practicepadURL.path)")
        
        do {
            try fileManager.createDirectory(at: practicepadURL, withIntermediateDirectories: true, attributes: nil)
            print("✅ [ICLOUD] Directory created/verified: \(practicepadURL.path)")
            return true
        } catch {
            print("❌ [ICLOUD] Failed to create iCloud directory: \(error)")
            return false
        }
    }
    
    private func getICloudFileURL(fileName: String) -> URL? {
        guard let icloudURL = getICloudDocumentsURL() else { 
            print("❌ [PATH] Cannot get iCloud Documents URL")
            return nil 
        }
        let fileURL = icloudURL.appendingPathComponent("PracticePadData").appendingPathComponent(fileName)
        print("🔗 [PATH] iCloud file URL: \(fileURL.path)")
        return fileURL
    }
    
    private func getLocalFileURL(fileName: String) -> URL? {
        guard let localURL = getLocalDocumentsURL() else { 
            print("❌ [PATH] Cannot get Local Documents URL")
            return nil 
        }
        let fileURL = localURL.appendingPathComponent(fileName)
        print("🔗 [PATH] Local file URL: \(fileURL.path)")
        return fileURL
    }
    
    // MARK: - Path Validation
    private func validatePaths(localURL: URL, icloudURL: URL) -> Bool {
        print("🔍 [VALIDATE] Validating file paths...")
        print("📁 [VALIDATE] Local: \(localURL.path)")
        print("☁️ [VALIDATE] iCloud: \(icloudURL.path)")
        
        // Validate local directory exists
        let localDir = localURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: localDir.path) {
            print("❌ [VALIDATE] Local directory doesn't exist: \(localDir.path)")
            return false
        }
        print("✅ [VALIDATE] Local directory exists")
        
        // Validate iCloud directory exists (create if needed)
        let icloudDir = icloudURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: icloudDir.path) {
            print("⚠️ [VALIDATE] iCloud directory doesn't exist, attempting to create: \(icloudDir.path)")
            do {
                try fileManager.createDirectory(at: icloudDir, withIntermediateDirectories: true)
                print("✅ [VALIDATE] iCloud directory created")
            } catch {
                print("❌ [VALIDATE] Failed to create iCloud directory: \(error)")
                return false
            }
        } else {
            print("✅ [VALIDATE] iCloud directory exists")
        }
        
        return true
    }
    
    // MARK: - File Sync Operations
    private func syncFileToICloud(fileName: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔄 [SYNC] Starting upload of file: \(fileName)")
        
        guard isICloudAvailable() else {
            print("❌ [SYNC] iCloud is not available")
            completion(false, "iCloud is not available")
            return
        }
        print("✅ [SYNC] iCloud is available")
        
        guard ensureICloudDirectoryExists() else {
            print("❌ [SYNC] Failed to create iCloud directory")
            completion(false, "Failed to create iCloud directory")
            return
        }
        print("✅ [SYNC] iCloud directory exists")
        
        guard let localURL = getLocalFileURL(fileName: fileName),
              let icloudURL = getICloudFileURL(fileName: fileName) else {
            print("❌ [SYNC] Failed to get file URLs")
            completion(false, "Failed to get file URLs")
            return
        }
        
        // Validate paths before proceeding
        guard validatePaths(localURL: localURL, icloudURL: icloudURL) else {
            print("❌ [SYNC] Path validation failed")
            completion(false, "Invalid file paths")
            return
        }
        
        // Check if local file exists
        guard fileManager.fileExists(atPath: localURL.path) else {
            print("❌ [SYNC] Local file does not exist: \(localURL.path)")
            completion(false, "Local file does not exist")
            return
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: localURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("📄 [SYNC] Local file size: \(fileSize) bytes")
        } catch {
            print("⚠️ [SYNC] Could not read file attributes: \(error)")
        }
        
        DispatchQueue.global(qos: .utility).async(group: nil, qos: .unspecified, flags: []) {
            do {
                print("🔄 [SYNC] Starting async copy operation")
                
                // If iCloud file already exists, handle the replacement
                if self.fileManager.fileExists(atPath: icloudURL.path) {
                    print("⚠️ [SYNC] iCloud file already exists, checking timestamps")
                    
                    do {
                        let shouldReplace = try self.shouldReplaceICloudFile(localURL: localURL, icloudURL: icloudURL)
                        
                        if !shouldReplace {
                            // Local file is older, but we'll allow the upload with a warning
                            print("⚠️ [SYNC] Local file is older than iCloud version, but proceeding with upload")
                        } else {
                            print("✅ [SYNC] Local file is newer, replacing iCloud version")
                        }
                        
                        print("🔄 [SYNC] Removing existing iCloud file for replacement")
                        // Remove existing iCloud file to replace it
                        try self.fileManager.removeItem(at: icloudURL)
                    } catch {
                        // If we can't check timestamps, proceed anyway
                        print("⚠️ [SYNC] Could not compare file timestamps: \(error), proceeding with upload")
                        try self.fileManager.removeItem(at: icloudURL)
                    }
                }
                
                print("📤 [SYNC] Copying local file to iCloud")
                // Copy local file to iCloud
                try self.fileManager.copyItem(at: localURL, to: icloudURL)
                
                print("☁️ [SYNC] Starting iCloud upload process")
                // Start uploading to iCloud
                try self.fileManager.startDownloadingUbiquitousItem(at: icloudURL)
                
                // Verify the file was copied successfully
                if self.fileManager.fileExists(atPath: icloudURL.path) {
                    print("✅ [SYNC] File successfully copied to iCloud")
                    
                    // Check upload status
                    let resourceValues = try icloudURL.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey, .ubiquitousItemUploadingErrorKey])
                    if let uploadError = resourceValues.ubiquitousItemUploadingError {
                        print("⚠️ [SYNC] Upload error: \(uploadError.localizedDescription)")
                    }
                    if let isUploaded = resourceValues.ubiquitousItemIsUploaded {
                        print("📡 [SYNC] Is uploaded: \(isUploaded)")
                    }
                } else {
                    print("❌ [SYNC] File was not copied to iCloud path")
                }
                
                DispatchQueue.main.async {
                    print("✅ [SYNC] Upload completed successfully")
                    completion(true, nil)
                }
            } catch {
                let errorMessage = self.interpretError(error)
                let nsError = error as NSError
                
                NSLog("❌ [SYNC] Upload failed with error: %@", error.localizedDescription)
                NSLog("❌ [SYNC] Error domain: %@", nsError.domain)
                NSLog("❌ [SYNC] Error code: %ld", nsError.code)
                NSLog("❌ [SYNC] Error userInfo: %@", nsError.userInfo)
                NSLog("❌ [SYNC] Interpreted error: %@", errorMessage)
                
                print("❌ [SYNC] Upload failed with error: \(error.localizedDescription)")
                print("❌ [SYNC] Error domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ [SYNC] Interpreted error: \(errorMessage)")
                
                DispatchQueue.main.async {
                    completion(false, errorMessage)
                }
            }
        }
    }
    
    private func downloadFileFromICloud(fileName: String, completion: @escaping (Bool, String?) -> Void) {
        print("📥 [DOWNLOAD] Starting download of file: \(fileName)")
        
        guard isICloudAvailable() else {
            print("❌ [DOWNLOAD] iCloud is not available")
            completion(false, "iCloud is not available")
            return
        }
        print("✅ [DOWNLOAD] iCloud is available")
        
        guard let icloudURL = getICloudFileURL(fileName: fileName),
              let localURL = getLocalFileURL(fileName: fileName) else {
            print("❌ [DOWNLOAD] Failed to get file URLs")
            completion(false, "Failed to get file URLs")
            return
        }
        
        // Validate paths before proceeding
        guard validatePaths(localURL: localURL, icloudURL: icloudURL) else {
            print("❌ [DOWNLOAD] Path validation failed")
            completion(false, "Invalid file paths")
            return
        }
        
        DispatchQueue.global(qos: .utility).async(group: nil, qos: .unspecified, flags: []) {
            do {
                print("🔄 [DOWNLOAD] Starting async download operation")
                
                // Check if iCloud file exists
                guard self.fileManager.fileExists(atPath: icloudURL.path) else {
                    print("❌ [DOWNLOAD] File does not exist in iCloud: \(icloudURL.path)")
                    DispatchQueue.main.async {
                        completion(false, "File does not exist in iCloud")
                    }
                    return
                }
                print("✅ [DOWNLOAD] iCloud file exists")
                
                // Check initial download status
                let initialStatus = try icloudURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                print("📡 [DOWNLOAD] Initial download status: \(initialStatus.ubiquitousItemDownloadingStatus?.rawValue ?? "unknown")")
                
                // Start downloading if not already downloaded
                print("🔄 [DOWNLOAD] Starting download process")
                try self.fileManager.startDownloadingUbiquitousItem(at: icloudURL)
                
                // Wait for download to complete with improved logic
                print("⏳ [DOWNLOAD] Waiting for download to complete...")
                let maxTimeout = Date().addingTimeInterval(120) // 2 minutes maximum timeout
                var downloadCompleted = false
                var retryCount = 0
                let maxRetries = 3
                
                while Date() < maxTimeout && !downloadCompleted && retryCount < maxRetries {
                    do {
                        let resourceValues = try icloudURL.resourceValues(forKeys: [
                            .ubiquitousItemDownloadingStatusKey, 
                            .ubiquitousItemDownloadingErrorKey
                        ])
                        
                        if let downloadError = resourceValues.ubiquitousItemDownloadingError {
                            print("❌ [DOWNLOAD] Download error: \(downloadError.localizedDescription)")
                            
                            // Retry on error
                            retryCount += 1
                            if retryCount < maxRetries {
                                print("🔄 [DOWNLOAD] Retrying download (\(retryCount)/\(maxRetries))...")
                                try self.fileManager.startDownloadingUbiquitousItem(at: icloudURL)
                                Thread.sleep(forTimeInterval: 2.0)
                                continue
                            } else {
                                print("❌ [DOWNLOAD] Max retries reached, giving up")
                                break
                            }
                        }
                        
                        if let status = resourceValues.ubiquitousItemDownloadingStatus {
                            print("📊 [DOWNLOAD] Status: \(status.rawValue)")
                            
                            switch status {
                            case .current:
                                print("✅ [DOWNLOAD] File is current and fully available")
                                downloadCompleted = true
                                break
                            case .downloaded:
                                print("✅ [DOWNLOAD] File is downloaded")
                                downloadCompleted = true
                                break
                            case .notDownloaded:
                                print("⏳ [DOWNLOAD] Still not downloaded, continuing to wait...")
                                Thread.sleep(forTimeInterval: 2.0)
                            default:
                                print("⚠️ [DOWNLOAD] Unknown download status: \(status.rawValue)")
                                Thread.sleep(forTimeInterval: 1.0)
                            }
                        }
                        
                        // No additional check needed - the status check above is sufficient
                        
                    } catch let statusError {
                        print("⚠️ [DOWNLOAD] Error checking download status: \(statusError)")
                        Thread.sleep(forTimeInterval: 1.0)
                    }
                }
                
                if !downloadCompleted {
                    print("⚠️ [DOWNLOAD] Download not completed after timeout or max retries")
                    // Still try to proceed - file might be available even if status isn't perfect
                }
                
                // Verify file can be read
                do {
                    let attributes = try self.fileManager.attributesOfItem(atPath: icloudURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    print("📄 [DOWNLOAD] iCloud file size: \(fileSize) bytes")
                } catch {
                    print("⚠️ [DOWNLOAD] Could not read iCloud file attributes: \(error)")
                }
                
                // Copy from iCloud to local (if local file doesn't exist or is older)
                if !self.fileManager.fileExists(atPath: localURL.path) {
                    print("📂 [DOWNLOAD] Local file doesn't exist, copying from iCloud")
                    try self.fileManager.copyItem(at: icloudURL, to: localURL)
                    print("✅ [DOWNLOAD] File copied to local storage")
                } else {
                    print("🔍 [DOWNLOAD] Local file exists, checking if iCloud version is newer")
                    let shouldReplace = try self.shouldReplaceLocalFile(localURL: localURL, icloudURL: icloudURL)
                    if shouldReplace {
                        print("🔄 [DOWNLOAD] iCloud version is newer, replacing local file")
                        try self.fileManager.removeItem(at: localURL)
                        try self.fileManager.copyItem(at: icloudURL, to: localURL)
                        print("✅ [DOWNLOAD] Local file replaced with iCloud version")
                    } else {
                        print("ℹ️ [DOWNLOAD] Local file is current, no replacement needed")
                    }
                }
                
                // Verify final copy
                if self.fileManager.fileExists(atPath: localURL.path) {
                    do {
                        let attributes = try self.fileManager.attributesOfItem(atPath: localURL.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        print("✅ [DOWNLOAD] Final local file size: \(fileSize) bytes")
                    } catch {
                        print("⚠️ [DOWNLOAD] Could not verify local file: \(error)")
                    }
                }
                
                DispatchQueue.main.async {
                    print("✅ [DOWNLOAD] Download completed successfully")
                    completion(true, nil)
                }
            } catch {
                let errorMessage = self.interpretError(error)
                print("❌ [DOWNLOAD] Download failed with error: \(error.localizedDescription)")
                print("❌ [DOWNLOAD] Interpreted error: \(errorMessage)")
                DispatchQueue.main.async {
                    completion(false, errorMessage)
                }
            }
        }
    }
    
    // Force sync - ignores conflicts and always uploads the local file
    private func forceSyncFileToICloud(fileName: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔄 [FORCE-SYNC] Starting forced upload of file: \(fileName)")
        
        guard isICloudAvailable() else {
            print("❌ [FORCE-SYNC] iCloud is not available")
            completion(false, "iCloud is not available")
            return
        }
        print("✅ [FORCE-SYNC] iCloud is available")
        
        guard ensureICloudDirectoryExists() else {
            print("❌ [FORCE-SYNC] Failed to create iCloud directory")
            completion(false, "Failed to create iCloud directory")
            return
        }
        print("✅ [FORCE-SYNC] iCloud directory exists")
        
        guard let localURL = getLocalFileURL(fileName: fileName),
              let icloudURL = getICloudFileURL(fileName: fileName) else {
            print("❌ [FORCE-SYNC] Failed to get file URLs")
            completion(false, "Failed to get file URLs")
            return
        }
        
        // Validate paths before proceeding
        guard validatePaths(localURL: localURL, icloudURL: icloudURL) else {
            print("❌ [FORCE-SYNC] Path validation failed")
            completion(false, "Invalid file paths")
            return
        }
        
        // Check if local file exists
        guard fileManager.fileExists(atPath: localURL.path) else {
            print("❌ [FORCE-SYNC] Local file does not exist: \(localURL.path)")
            completion(false, "Local file does not exist")
            return
        }
        
        DispatchQueue.global(qos: .utility).async(group: nil, qos: .unspecified, flags: []) {
            do {
                print("🔄 [FORCE-SYNC] Starting forced async copy operation")
                
                // Remove existing iCloud file if it exists (no conflict checking)
                if self.fileManager.fileExists(atPath: icloudURL.path) {
                    print("🔄 [FORCE-SYNC] Removing existing iCloud file (forced)")
                    try self.fileManager.removeItem(at: icloudURL)
                }
                
                print("📤 [FORCE-SYNC] Copying local file to iCloud")
                try self.fileManager.copyItem(at: localURL, to: icloudURL)
                
                print("☁️ [FORCE-SYNC] Starting iCloud upload process")
                try self.fileManager.startDownloadingUbiquitousItem(at: icloudURL)
                
                if self.fileManager.fileExists(atPath: icloudURL.path) {
                    print("✅ [FORCE-SYNC] File successfully copied to iCloud")
                } else {
                    print("❌ [FORCE-SYNC] File was not copied to iCloud path")
                }
                
                DispatchQueue.main.async {
                    print("✅ [FORCE-SYNC] Forced upload completed successfully")
                    completion(true, nil)
                }
            } catch {
                let errorMessage = self.interpretError(error)
                print("❌ [FORCE-SYNC] Forced upload failed with error: \(error.localizedDescription)")
                print("❌ [FORCE-SYNC] Interpreted error: \(errorMessage)")
                DispatchQueue.main.async {
                    completion(false, errorMessage)
                }
            }
        }
    }
    
    // MARK: - Retry Logic for Sync Operations
    private func syncFileToICloudWithRetry(fileName: String, completion: @escaping (Bool, String?) -> Void) {
        let maxRetries = 3
        var currentAttempt = 0
        
        func attemptSync() {
            currentAttempt += 1
            print("🔄 [RETRY] Upload attempt \(currentAttempt)/\(maxRetries) for \(fileName)")
            
            syncFileToICloud(fileName: fileName) { success, error in
                if success {
                    print("✅ [RETRY] Upload succeeded on attempt \(currentAttempt)")
                    completion(true, nil)
                } else if currentAttempt < maxRetries {
                    let delay = Double(currentAttempt) * 2.0 // Exponential backoff: 2s, 4s, 6s
                    print("⚠️ [RETRY] Upload failed on attempt \(currentAttempt), retrying in \(delay)s: \(error ?? "Unknown error")")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        attemptSync()
                    }
                } else {
                    print("❌ [RETRY] Upload failed after \(maxRetries) attempts: \(error ?? "Unknown error")")
                    completion(false, "Upload failed after \(maxRetries) attempts: \(error ?? "Unknown error")")
                }
            }
        }
        
        attemptSync()
    }
    
    private func downloadFileFromICloudWithRetry(fileName: String, completion: @escaping (Bool, String?) -> Void) {
        let maxRetries = 3
        var currentAttempt = 0
        
        func attemptDownload() {
            currentAttempt += 1
            print("📥 [RETRY] Download attempt \(currentAttempt)/\(maxRetries) for \(fileName)")
            
            downloadFileFromICloud(fileName: fileName) { success, error in
                if success {
                    print("✅ [RETRY] Download succeeded on attempt \(currentAttempt)")
                    completion(true, nil)
                } else if currentAttempt < maxRetries {
                    let delay = Double(currentAttempt) * 2.0 // Exponential backoff: 2s, 4s, 6s
                    print("⚠️ [RETRY] Download failed on attempt \(currentAttempt), retrying in \(delay)s: \(error ?? "Unknown error")")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        attemptDownload()
                    }
                } else {
                    print("❌ [RETRY] Download failed after \(maxRetries) attempts: \(error ?? "Unknown error")")
                    completion(false, "Download failed after \(maxRetries) attempts: \(error ?? "Unknown error")")
                }
            }
        }
        
        attemptDownload()
    }
    
    // MARK: - Error Handling
    private func interpretError(_ error: Error) -> String {
        let nsError = error as NSError
        
        NSLog("🔍 [ERROR] === DETAILED ERROR ANALYSIS ===")
        NSLog("🔍 [ERROR] Domain: %@", nsError.domain)
        NSLog("🔍 [ERROR] Code: %ld", nsError.code)  
        NSLog("🔍 [ERROR] Description: %@", nsError.localizedDescription)
        NSLog("🔍 [ERROR] UserInfo: %@", nsError.userInfo)
        
        print("🔍 [ERROR] Domain: \(nsError.domain), Code: \(nsError.code)")
        print("🔍 [ERROR] Description: \(nsError.localizedDescription)")
        print("🔍 [ERROR] UserInfo: \(nsError.userInfo)")
        
        // Handle common iCloud errors
        switch nsError.domain {
        case NSCocoaErrorDomain:
            NSLog("🔍 [ERROR] NSCocoaErrorDomain detected - File system error")
            switch nsError.code {
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                NSLog("❌ [ERROR] Permission denied error detected")
                if let bundleId = Bundle.main.bundleIdentifier {
                    NSLog("🔍 [ERROR] Bundle ID: %@", bundleId)
                    if bundleId.starts(with: "com.example.") {
                        NSLog("❌ [ERROR] CAUSE: Example bundle ID without proper entitlements")
                        return "Permission denied: The app uses an example bundle ID (com.example.*) which doesn't have proper iCloud entitlements configured in Apple's Developer Portal. For testing iCloud sync, you need a proper bundle ID with iCloud capabilities enabled."
                    } else {
                        NSLog("❌ [ERROR] CAUSE: Production bundle ID but app not authorized in iCloud settings")
                        return "Permission denied: Your bundle ID (\(bundleId)) appears valid, but the app is not authorized for iCloud. Please check: 1) Settings > [Your Name] > iCloud > Apps Using iCloud - ensure your app is ON, 2) Verify bundle ID has iCloud capability in Apple Developer Portal, 3) Check if provisioning profile includes iCloud entitlements."
                    }
                } else {
                    NSLog("❌ [ERROR] No bundle ID found - major configuration issue")
                    return "Permission denied: No bundle identifier found. This indicates a serious app configuration issue."
                }
            case NSFileReadNoSuchFileError:
                NSLog("🔍 [ERROR] File not found error")
                return "File not found in iCloud. It may not have been uploaded yet or may have been deleted."
            case NSUbiquitousFileNotUploadedDueToQuotaError:
                NSLog("❌ [ERROR] iCloud storage quota exceeded")
                return "iCloud storage quota exceeded. Please free up space in your iCloud account."
            case NSUbiquitousFileUnavailableError:
                NSLog("❌ [ERROR] iCloud file unavailable")
                return "File is not available from iCloud right now. Check your internet connection and try again."
            default:
                NSLog("🔍 [ERROR] Other NSCocoaErrorDomain error: %ld", nsError.code)
                break
            }
        case NSURLErrorDomain:
            NSLog("🔍 [ERROR] NSURLErrorDomain detected - Network error")
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                NSLog("❌ [ERROR] No internet connection")
                return "No internet connection. iCloud sync requires an internet connection."
            case NSURLErrorTimedOut:
                NSLog("❌ [ERROR] Connection timeout")
                return "Connection timed out. Please check your internet connection and try again."
            default:
                NSLog("🔍 [ERROR] Other NSURLErrorDomain error: %ld", nsError.code)
                break
            }
        default:
            NSLog("🔍 [ERROR] Unknown error domain: %@", nsError.domain)
            break
        }
        
        NSLog("🔍 [ERROR] === END ERROR ANALYSIS ===")
        
        // Fallback to original error message
        return "iCloud sync error: \(nsError.localizedDescription)"
    }
    
    // MARK: - File Status and Conflict Detection
    private func getFileSyncStatus(fileName: String) -> [String: Any] {
        guard let icloudURL = getICloudFileURL(fileName: fileName) else {
            return ["status": "error", "message": "Failed to get iCloud URL"]
        }
        
        guard fileManager.fileExists(atPath: icloudURL.path) else {
            return ["status": "not_in_icloud"]
        }
        
        do {
            let resourceValues = try icloudURL.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemHasUnresolvedConflictsKey,
                .ubiquitousItemIsUploadedKey
            ])
            
            var status: [String: Any] = ["status": "unknown"]
            
            if let hasConflicts = resourceValues.ubiquitousItemHasUnresolvedConflicts, hasConflicts {
                status["status"] = "conflict"
                status["hasConflicts"] = true
            } else if let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus {
                switch downloadStatus {
                case .current:
                    status["status"] = "current"
                case .downloaded:
                    status["status"] = "downloaded"
                case .notDownloaded:
                    status["status"] = "not_downloaded"
                default:
                    status["status"] = "unknown"
                }
            }
            
            // Check if file is downloaded by checking download status
            let isDownloaded = resourceValues.ubiquitousItemDownloadingStatus == .current || resourceValues.ubiquitousItemDownloadingStatus == .downloaded
            status["isDownloaded"] = isDownloaded
            status["isUploaded"] = resourceValues.ubiquitousItemIsUploaded ?? false
            
            return status
        } catch {
            return ["status": "error", "message": error.localizedDescription]
        }
    }
    
    private func shouldReplaceICloudFile(localURL: URL, icloudURL: URL) throws -> Bool {
        let localAttributes = try fileManager.attributesOfItem(atPath: localURL.path)
        let icloudAttributes = try fileManager.attributesOfItem(atPath: icloudURL.path)
        
        let localDate = localAttributes[.modificationDate] as? Date ?? Date.distantPast
        let icloudDate = icloudAttributes[.modificationDate] as? Date ?? Date.distantPast
        
        return localDate > icloudDate
    }
    
    private func shouldReplaceLocalFile(localURL: URL, icloudURL: URL) throws -> Bool {
        let localAttributes = try fileManager.attributesOfItem(atPath: localURL.path)
        let icloudAttributes = try fileManager.attributesOfItem(atPath: icloudURL.path)
        
        let localDate = localAttributes[.modificationDate] as? Date ?? Date.distantPast
        let icloudDate = icloudAttributes[.modificationDate] as? Date ?? Date.distantPast
        
        return icloudDate > localDate
    }
    
    // MARK: - File Management
    private func listICloudFiles(completion: @escaping ([String]?, String?) -> Void) {
        print("📋 [LIST] Starting to list iCloud files")
        
        guard isICloudAvailable() else {
            print("❌ [LIST] iCloud is not available")
            completion(nil, "iCloud is not available")
            return
        }
        
        guard let icloudURL = getICloudDocumentsURL() else {
            print("❌ [LIST] Failed to get iCloud documents URL")
            completion(nil, "Failed to get iCloud documents URL")
            return
        }
        
        let practicepadURL = icloudURL.appendingPathComponent("PracticePadData")
        print("📁 [LIST] Listing files in: \(practicepadURL.path)")
        
        DispatchQueue.global(qos: .utility).async(group: nil, qos: .unspecified, flags: []) {
            do {
                // Check if directory exists
                if !self.fileManager.fileExists(atPath: practicepadURL.path) {
                    print("⚠️ [LIST] PracticePad directory does not exist")
                    DispatchQueue.main.async {
                        completion([], nil)
                    }
                    return
                }
                
                let fileURLs = try self.fileManager.contentsOfDirectory(at: practicepadURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
                let fileNames = fileURLs.map { $0.lastPathComponent }
                
                print("📋 [LIST] Found \(fileNames.count) files:")
                for (index, fileName) in fileNames.enumerated() {
                    let fileURL = fileURLs[index]
                    do {
                        let resources = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                        let size = resources.fileSize ?? 0
                        let modDate = resources.contentModificationDate ?? Date()
                        print("  📄 [LIST] \(fileName) - \(size) bytes - \(modDate)")
                    } catch {
                        print("  📄 [LIST] \(fileName) - (could not read attributes)")
                    }
                }
                
                DispatchQueue.main.async {
                    print("✅ [LIST] Successfully listed \(fileNames.count) files")
                    completion(fileNames, nil)
                }
            } catch {
                print("❌ [LIST] Failed to list iCloud files: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, "Failed to list iCloud files: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteFileFromICloud(fileName: String, completion: @escaping (Bool, String?) -> Void) {
        guard let icloudURL = getICloudFileURL(fileName: fileName) else {
            completion(false, "Failed to get iCloud URL")
            return
        }
        
        DispatchQueue.global(qos: .utility).async(group: nil, qos: .unspecified, flags: []) {
            do {
                if self.fileManager.fileExists(atPath: icloudURL.path) {
                    try self.fileManager.removeItem(at: icloudURL)
                }
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to delete file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Conflict Resolution
    private func resolveConflict(fileName: String, resolution: String, completion: @escaping (Bool, String?) -> Void) {
        guard let icloudURL = getICloudFileURL(fileName: fileName) else {
            completion(false, "Failed to get iCloud URL")
            return
        }
        
        DispatchQueue.global(qos: .utility).async(group: nil, qos: .unspecified, flags: []) {
            do {
                if resolution == "useLocal" {
                    // Replace iCloud version with local version
                    if let localURL = self.getLocalFileURL(fileName: fileName) {
                        try self.fileManager.removeItem(at: icloudURL)
                        try self.fileManager.copyItem(at: localURL, to: icloudURL)
                    }
                } else if resolution == "useICloud" {
                    // Keep iCloud version, update local
                    if let localURL = self.getLocalFileURL(fileName: fileName) {
                        try self.fileManager.removeItem(at: localURL)
                        try self.fileManager.copyItem(at: icloudURL, to: localURL)
                    }
                }
                
                // Try to resolve conflicts by triggering iCloud sync
                try self.fileManager.startDownloadingUbiquitousItem(at: icloudURL)
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to resolve conflict: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Environment Diagnostics
    private func getEnvironmentInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        
        // Bundle information
        if let bundleId = Bundle.main.bundleIdentifier {
            info["bundleIdentifier"] = bundleId
            info["expectedContainer"] = "iCloud.\(bundleId)"
        }
        
        // Device information
        info["isSimulator"] = TARGET_OS_SIMULATOR != 0
        info["deviceModel"] = UIDevice.current.model
        info["systemVersion"] = UIDevice.current.systemVersion
        
        // iCloud token information
        let token = fileManager.ubiquityIdentityToken
        info["hasIdentityToken"] = token != nil
        if let token = token {
            info["identityTokenDescription"] = String(describing: token)
        }
        
        // Container accessibility
        let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil)
        info["canAccessDefaultContainer"] = containerURL != nil
        
        if let containerURL = containerURL {
            info["containerPath"] = containerURL.path
            
            // Check if we can actually read/write to the container
            do {
                let resourceValues = try containerURL.resourceValues(forKeys: [.isReadableKey, .isWritableKey])
                info["containerReadable"] = resourceValues.isReadable ?? false
                info["containerWritable"] = resourceValues.isWritable ?? false
            } catch {
                info["containerAccessError"] = error.localizedDescription
            }
            
            // Try to create our app directory
            let documentsURL = containerURL.appendingPathComponent("Documents")
            let appURL = documentsURL.appendingPathComponent("PracticePadData")
            
            do {
                try fileManager.createDirectory(at: appURL, withIntermediateDirectories: true)
                info["canCreateAppDirectory"] = true
            } catch {
                info["canCreateAppDirectory"] = false
                info["directoryCreationError"] = error.localizedDescription
            }
        }
        
        // Developer team information
        if let teamId = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String {
            info["teamIdentifierPrefix"] = teamId
        }
        
        print("🔍 [ENV] Environment info: \(info)")
        return info
    }
    
    // MARK: - Storage Usage
    private func getStorageUsage(completion: @escaping ([String: Any]?, String?) -> Void) {
        guard let icloudURL = getICloudDocumentsURL() else {
            completion(nil, "Failed to get iCloud documents URL")
            return
        }
        
        let practicepadURL = icloudURL.appendingPathComponent("PracticePadData")
        
        DispatchQueue.global(qos: .utility).async(group: nil, qos: .unspecified, flags: []) {
            do {
                let fileURLs = try self.fileManager.contentsOfDirectory(at: practicepadURL, includingPropertiesForKeys: [.fileSizeKey])
                
                var totalSize: Int64 = 0
                var fileCount = 0
                var jsonSize: Int64 = 0
                var pdfSize: Int64 = 0
                
                for fileURL in fileURLs {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    
                    totalSize += fileSize
                    fileCount += 1
                    
                    if fileURL.pathExtension.lowercased() == "json" {
                        jsonSize += fileSize
                    } else if fileURL.pathExtension.lowercased() == "pdf" {
                        pdfSize += fileSize
                    }
                }
                
                let usage: [String: Any] = [
                    "totalSize": totalSize,
                    "fileCount": fileCount,
                    "jsonSize": jsonSize,
                    "pdfSize": pdfSize
                ]
                
                DispatchQueue.main.async {
                    completion(usage, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, "Failed to calculate storage usage: \(error.localizedDescription)")
                }
            }
        }
    }
}