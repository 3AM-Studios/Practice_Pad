/// Result class for PDF operations with detailed status information
class PDFResult {
  final String? path;
  final String message;
  final PDFStatus status;
  
  const PDFResult._({
    this.path,
    required this.message,
    required this.status,
  });
  
  /// Create a successful result
  factory PDFResult.success(String path, String message) {
    return PDFResult._(
      path: path,
      message: message,
      status: PDFStatus.success,
    );
  }
  
  /// Create an error result
  factory PDFResult.error(String message) {
    return PDFResult._(
      path: null,
      message: message,
      status: PDFStatus.error,
    );
  }
  
  /// Create a downloading result
  factory PDFResult.downloading(String message) {
    return PDFResult._(
      path: null,
      message: message,
      status: PDFStatus.downloading,
    );
  }
  
  /// Whether the operation was successful
  bool get isSuccess => status == PDFStatus.success;
  
  /// Whether there was an error
  bool get isError => status == PDFStatus.error;
  
  /// Whether the PDF is being downloaded
  bool get isDownloading => status == PDFStatus.downloading;
  
  @override
  String toString() {
    return 'PDFResult(status: $status, path: $path, message: $message)';
  }
}

/// Status of PDF operations
enum PDFStatus {
  success,
  error,
  downloading,
}

/// Extension to get user-friendly status names
extension PDFStatusExtension on PDFStatus {
  String get displayName {
    switch (this) {
      case PDFStatus.success:
        return 'Available';
      case PDFStatus.error:
        return 'Error';
      case PDFStatus.downloading:
        return 'Downloading';
    }
  }
}

/// Availability status for PDF files
enum PDFAvailability {
  locallyAvailable,
  cached,
  needsDownload,
  needsICloudLogin,
  error,
}

/// Extension to get user-friendly availability messages
extension PDFAvailabilityExtension on PDFAvailability {
  String get displayName {
    switch (this) {
      case PDFAvailability.locallyAvailable:
        return 'Ready to view';
      case PDFAvailability.cached:
        return 'Cached locally';
      case PDFAvailability.needsDownload:
        return 'Needs download';
      case PDFAvailability.needsICloudLogin:
        return 'Sign in to iCloud';
      case PDFAvailability.error:
        return 'Error';
    }
  }
  
  String get userMessage {
    switch (this) {
      case PDFAvailability.locallyAvailable:
        return 'This file is ready to view';
      case PDFAvailability.cached:
        return 'This file is cached locally and ready to view';
      case PDFAvailability.needsDownload:
        return 'This file needs to be downloaded from iCloud';
      case PDFAvailability.needsICloudLogin:
        return 'Please sign in to iCloud to access this file';
      case PDFAvailability.error:
        return 'There was an error checking this file';
    }
  }
  
  bool get isReadyToView {
    return this == PDFAvailability.locallyAvailable || this == PDFAvailability.cached;
  }
}