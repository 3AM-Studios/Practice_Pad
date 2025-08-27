import Foundation

enum ICloudError: Error, LocalizedError {
    case notAvailable
    case accountNotSignedIn
    case networkUnavailable
    case quotaExceeded
    case fileNotFound(String)
    case conflictDetected(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case permissionDenied
    case invalidFileName(String)
    case directoryCreationFailed
    case timeout
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "iCloud is not available on this device"
        case .accountNotSignedIn:
            return "User is not signed in to iCloud"
        case .networkUnavailable:
            return "Network connection is not available"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .fileNotFound(let fileName):
            return "File '\(fileName)' not found"
        case .conflictDetected(let fileName):
            return "Conflict detected for file '\(fileName)'"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .permissionDenied:
            return "Permission denied to access iCloud"
        case .invalidFileName(let fileName):
            return "Invalid file name: '\(fileName)'"
        case .directoryCreationFailed:
            return "Failed to create iCloud directory"
        case .timeout:
            return "Operation timed out"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .notAvailable:
            return "iCloud Documents is not enabled or supported"
        case .accountNotSignedIn:
            return "Go to Settings > [Your Name] > iCloud to sign in"
        case .networkUnavailable:
            return "Check your internet connection"
        case .quotaExceeded:
            return "Free up space in iCloud or upgrade storage"
        case .fileNotFound(_):
            return "The requested file may have been deleted or moved"
        case .conflictDetected(_):
            return "Multiple versions of the file exist"
        case .uploadFailed(_), .downloadFailed(_):
            return "Check your network connection and try again"
        case .permissionDenied:
            return "Enable iCloud Documents for this app in Settings"
        case .invalidFileName(_):
            return "File name contains invalid characters"
        case .directoryCreationFailed:
            return "Unable to create required directories in iCloud"
        case .timeout:
            return "The operation took too long to complete"
        case .unknown(_):
            return "An unexpected error occurred"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notAvailable, .accountNotSignedIn:
            return "Sign in to iCloud in Settings and enable iCloud Documents"
        case .networkUnavailable:
            return "Connect to Wi-Fi or cellular data and try again"
        case .quotaExceeded:
            return "Manage your iCloud storage in Settings"
        case .fileNotFound(_):
            return "Verify the file exists and try again"
        case .conflictDetected(_):
            return "Choose which version to keep"
        case .uploadFailed(_), .downloadFailed(_):
            return "Check your connection and retry"
        case .permissionDenied:
            return "Enable iCloud Documents in app settings"
        case .invalidFileName(_):
            return "Use a different file name"
        case .directoryCreationFailed:
            return "Check iCloud storage space and permissions"
        case .timeout:
            return "Try again with a better network connection"
        case .unknown(_):
            return "Restart the app and try again"
        }
    }
}

enum SyncStatus: String, CaseIterable {
    case idle = "idle"
    case syncing = "syncing"
    case success = "success"
    case error = "error"
    case conflict = "conflict"
    case notInICloud = "not_in_icloud"
    case current = "current"
    case downloading = "downloading"
    case uploading = "uploading"
    case notDownloaded = "not_downloaded"
}

struct ICloudFileStatus {
    let fileName: String
    let status: SyncStatus
    let isDownloaded: Bool
    let isUploaded: Bool
    let hasConflicts: Bool
    let lastModified: Date?
    let size: Int64?
    let error: ICloudError?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "fileName": fileName,
            "status": status.rawValue,
            "isDownloaded": isDownloaded,
            "isUploaded": isUploaded,
            "hasConflicts": hasConflicts
        ]
        
        if let lastModified = lastModified {
            dict["lastModified"] = Int64(lastModified.timeIntervalSince1970 * 1000) // milliseconds
        }
        
        if let size = size {
            dict["size"] = size
        }
        
        if let error = error {
            dict["error"] = error.localizedDescription
            dict["errorReason"] = error.failureReason
            dict["errorSuggestion"] = error.recoverySuggestion
        }
        
        return dict
    }
}

extension FileManager {
    func iCloudAccountStatus() -> String {
        if ubiquityIdentityToken != nil {
            return "available"
        } else {
            return "notAvailable"
        }
    }
    
    func isICloudEnabled() -> Bool {
        return ubiquityIdentityToken != nil
    }
}