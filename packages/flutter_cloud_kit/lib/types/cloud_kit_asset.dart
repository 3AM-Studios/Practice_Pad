class CloudKitAsset {
  final String filePath;
  final String? fileName;

  CloudKitAsset({
    required this.filePath,
    this.fileName,
  });

  Map<String, dynamic> toMap() {
    return {
      'filePath': filePath,
      'fileName': fileName,
    };
  }

  factory CloudKitAsset.fromMap(Map<String, dynamic> map) {
    return CloudKitAsset(
      filePath: map['filePath'] as String,
      fileName: map['fileName'] as String?,
    );
  }

  @override
  String toString() {
    return 'CloudKitAsset(filePath: $filePath, fileName: $fileName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CloudKitAsset &&
        other.filePath == filePath &&
        other.fileName == fileName;
  }

  @override
  int get hashCode => filePath.hashCode ^ fileName.hashCode;
}