/// Represents a CloudKit CKAsset with proper separation between upload and download scenarios
/// 
/// Upload flow: CloudKitAsset.forUpload(filePath: localFile) -> CloudKit
/// Download flow: CloudKit -> CloudKitAsset.forDownload(fileURL: temporaryURL)
/// 
/// In real CloudKit:
/// - CKAsset(fileURL:) is used for uploads with local file URLs
/// - When fetched, CKAsset.fileURL contains a temporary staging URL for download
/// - Staging URLs are temporary and files are automatically cleaned up by the system
class CloudKitAsset {
  /// For uploads: Local file path to upload to CloudKit
  /// Should be null for download assets
  final String? localFilePath;
  
  /// For downloads: CloudKit staging area fileURL (temporary)
  /// This is the CKAsset.fileURL property from CloudKit
  /// Should be null for upload assets
  final String? fileURL;
  
  /// The original filename of the asset (optional, CloudKit doesn't store this automatically)
  final String? fileName;
  
  /// CloudKit record name or identifier this asset belongs to
  final String? recordIdentifier;
  
  /// Size of the asset in bytes
  final int? size;
  
  /// MIME type of the asset
  final String? mimeType;
  
  /// When this asset data was fetched (for cache management)
  final DateTime? fetchedAt;

  CloudKitAsset({
    this.localFilePath,
    this.fileURL,
    this.fileName,
    this.recordIdentifier,
    this.size,
    this.mimeType,
    this.fetchedAt,
  }) : assert(
         (localFilePath != null && fileURL == null) || 
         (localFilePath == null && fileURL != null) ||
         (localFilePath == null && fileURL == null),
         'CloudKitAsset should have either localFilePath (for upload) or fileURL (for download), not both'
       );

  /// Factory constructor for creating an upload asset from a local file
  /// This represents a local file that will be uploaded to CloudKit
  factory CloudKitAsset.forUpload({
    required String filePath,
    String? fileName,
    int? size,
    String? mimeType,
  }) {
    return CloudKitAsset(
      localFilePath: filePath,
      fileName: fileName,
      size: size,
      mimeType: mimeType,
    );
  }

  /// Factory constructor for creating a download asset from CloudKit CKAsset.fileURL
  /// This represents a CloudKit asset in the staging area, ready for download
  factory CloudKitAsset.fromStaging({
    required String fileURL,
    String? fileName,
    String? recordIdentifier,
    int? size,
    String? mimeType,
    DateTime? fetchedAt,
  }) {
    return CloudKitAsset(
      fileURL: fileURL,
      fileName: fileName,
      recordIdentifier: recordIdentifier,
      size: size,
      mimeType: mimeType,
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }

  /// Legacy constructor for backward compatibility - assumes upload scenario
  @Deprecated('Use CloudKitAsset.forUpload() or CloudKitAsset.forDownload() instead')
  factory CloudKitAsset.legacy({
    required String filePath,
    String? fileName,
  }) {
    return CloudKitAsset.forUpload(
      filePath: filePath,
      fileName: fileName,
    );
  }

  /// Whether this asset is for uploading (has local file path)
  bool get isForUpload => localFilePath != null;

  /// Whether this asset is for downloading (has CloudKit staging fileURL)
  bool get isForDownload => fileURL != null;

  /// Whether this asset data might be stale (older than 1 hour)
  bool get isStale {
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt!).inHours >= 1;
  }

  /// Get the file path - backward compatibility
  @Deprecated('Use localFilePath or fileURL explicitly')
  String get filePath => localFilePath ?? fileURL ?? '';

  /// Legacy downloadUrl getter for backward compatibility
  @Deprecated('Use fileURL instead - this represents CloudKit staging area')
  String? get downloadUrl => fileURL;

  Map<String, dynamic> toMap() {
    return {
      'localFilePath': localFilePath,
      'fileURL': fileURL,
      'fileName': fileName,
      'recordIdentifier': recordIdentifier,
      'size': size,
      'mimeType': mimeType,
      'fetchedAt': fetchedAt?.toIso8601String(),
    };
  }

  factory CloudKitAsset.fromMap(Map<String, dynamic> map) {
    return CloudKitAsset(
      localFilePath: map['localFilePath'] as String?,
      fileURL: map['fileURL'] as String?,
      fileName: map['fileName'] as String?,
      recordIdentifier: map['recordIdentifier'] as String?,
      size: map['size'] as int?,
      mimeType: map['mimeType'] as String?,
      fetchedAt: map['fetchedAt'] != null 
          ? DateTime.parse(map['fetchedAt'] as String)
          : null,
    );
  }

  /// Legacy fromMap for backward compatibility
  @Deprecated('Use CloudKitAsset.fromMap() which handles both scenarios')
  factory CloudKitAsset.fromMapLegacy(Map<String, dynamic> map) {
    final filePath = map['filePath'] as String?;
    if (filePath != null) {
      // Assume it's for upload if we have a filePath
      return CloudKitAsset.forUpload(
        filePath: filePath,
        fileName: map['fileName'] as String?,
      );
    }
    return CloudKitAsset.fromMap(map);
  }

  @override
  String toString() {
    if (isForUpload) {
      return 'CloudKitAsset.forUpload(localFilePath: $localFilePath, fileName: $fileName)';
    } else if (isForDownload) {
      return 'CloudKitAsset.fromStaging(fileURL: $fileURL, fileName: $fileName, recordId: $recordIdentifier, fetchedAt: $fetchedAt)';
    } else {
      return 'CloudKitAsset.empty()';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CloudKitAsset &&
        other.localFilePath == localFilePath &&
        other.fileURL == fileURL &&
        other.fileName == fileName &&
        other.recordIdentifier == recordIdentifier &&
        other.size == size &&
        other.mimeType == mimeType &&
        other.fetchedAt == fetchedAt;
  }

  @override
  int get hashCode => 
    localFilePath.hashCode ^ 
    fileURL.hashCode ^ 
    fileName.hashCode ^ 
    recordIdentifier.hashCode ^
    size.hashCode ^
    mimeType.hashCode ^
    fetchedAt.hashCode;
}