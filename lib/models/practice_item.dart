import 'chord_progression.dart';

class PracticeItem {
  final String id; // Unique local ID (e.g., UUID or timestamp-based)
  String name; // Title of the practice item
  String description;
  ChordProgression? chordProgression; // Optional chord progression
  Map<String, int> keysPracticed; // Track reps for each of the 12 keys
  String? recordChangeTag; // CloudKit record change tag for sync
  // TODO: Consider fields for tracking (lastPracticed, priority, etc.) later
  // REMOVED: practiceAreaRecordName (now embedded in PracticeArea)

  PracticeItem({
    required this.id,
    String? name,
    this.description = '',
    this.chordProgression,
    Map<String, int>? keysPracticed,
    this.recordChangeTag,
  }) : name = _resolveName(name, chordProgression),
       keysPracticed = keysPracticed ?? _initializeKeysPracticed();

  /// Initializes keysPracticed with all 12 major keys set to 0 reps
  static Map<String, int> _initializeKeysPracticed() {
    const majorKeys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    return Map.fromIterable(majorKeys, value: (key) => 0);
  }

  /// Resolves the name based on the provided name and chord progression.
  /// If no name is provided and there's a chord progression, uses the chord progression's string representation.
  /// If no name is provided and no chord progression, throws an error.
  static String _resolveName(String? name, ChordProgression? chordProgression) {
    if (name != null && name.isNotEmpty) {
      return name;
    } else if (chordProgression != null) {
      return chordProgression.toString();
    } else {
      throw ArgumentError('Name is required if no chord progression is provided');
    }
  }

  // Since we are local-first for now, we don't need CloudKit specific methods here yet.
  // factory PracticeItem.fromCloudKitRecord(Map<String, dynamic> record) { ... }
  // Map<String, dynamic> toCloudKitRecordFields() { ... }

  // Basic copyWith for local updates if needed
  PracticeItem copyWith({
    String? id,
    String? name,
    String? description,
    ChordProgression? chordProgression,
    Map<String, int>? keysPracticed,
    String? recordChangeTag,
  }) {
    return PracticeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      chordProgression: chordProgression ?? this.chordProgression,
      keysPracticed: keysPracticed ?? Map.from(this.keysPracticed),
      recordChangeTag: recordChangeTag ?? this.recordChangeTag,
    );
  }
}
