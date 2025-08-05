import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';

enum PracticeAreaType { song, exercise }

class PracticeArea {
  final String recordName; // CloudKit record name (unique ID)
  String name;
  PracticeAreaType type; // NEW: 'song' or 'exercise'
  List<PracticeItem> practiceItems; // NEW: embedded practice items
  Song? song; // NEW: Optional song reference for song-type practice areas

  PracticeArea({
    required this.recordName,
    required this.name,
    required this.type,
    List<PracticeItem>? practiceItems,
    this.song,
  }) : practiceItems = practiceItems ?? [];

  // Factory constructor to create a PracticeArea from a CloudKit record map
  factory PracticeArea.fromCloudKitRecord(Map<String, dynamic> record) {
    // Assuming the plugin provides the fields directly, not nested under 'fields' then 'value'
    // This might need adjustment based on actual CloudKitRecord structure from the plugin
    final typeString = record['type'] as String? ?? 'exercise'; // Default to exercise for existing records
    final type = typeString == 'song' ? PracticeAreaType.song : PracticeAreaType.exercise;
    
    // Parse song data if available
    Song? song;
    if (type == PracticeAreaType.song && record['songPath'] != null) {
      song = Song(
        title: record['songTitle'] as String? ?? 'Unknown Title',
        composer: record['songComposer'] as String? ?? 'Unknown Composer',
        path: record['songPath'] as String,
      );
    }
    
    return PracticeArea(
      recordName: record['recordName'] as String,
      name: record['name'] as String, // Assuming 'name' is a direct field in the returned map
      type: type,
      song: song,
      // Note: practiceItems will be loaded separately as they're no longer stored in CloudKit for PracticeArea
    );
  }

  // Method to convert a PracticeArea to a map for saving to CloudKit
  // Adjusted to return a flat map, hoping the plugin handles type specifics.
  Map<String, dynamic> toCloudKitRecordFields() {
    final fields = <String, dynamic>{
      'name': name, // Simplified: direct value
      'type': type == PracticeAreaType.song ? 'song' : 'exercise',
      // Note: practiceItems are not stored in CloudKit for PracticeArea anymore
    };
    
    // Add song fields if this is a song-type practice area
    if (type == PracticeAreaType.song && song != null) {
      fields['songTitle'] = song!.title;
      fields['songComposer'] = song!.composer;
      fields['songPath'] = song!.path;
    }
    
    return fields;
  }

  // Helper method to add default practice items for song type areas
  void addDefaultSongItems() {
    if (type == PracticeAreaType.song) {
      practiceItems.clear();
      practiceItems.addAll([
        PracticeItem(
          id: 'default_shells_${DateTime.now().millisecondsSinceEpoch}_1',
          name: 'Shells only',
          description: 'Practice basic chord shells',
        ),
        PracticeItem(
          id: 'default_shells_melody_${DateTime.now().millisecondsSinceEpoch}_2',
          name: 'Shells only + melody',
          description: 'Practice shells with melody line',
        ),
        PracticeItem(
          id: 'default_shells_free_${DateTime.now().millisecondsSinceEpoch}_3',
          name: 'Shells + free chord',
          description: 'Practice shells with free chord voicings',
        ),
      ]);
    }
  }

  // Helper method to add a practice item
  void addPracticeItem(PracticeItem item) {
    practiceItems.add(item);
  }

  // Helper method to remove a practice item
  void removePracticeItem(String itemId) {
    practiceItems.removeWhere((item) => item.id == itemId);
  }

  // Helper method to update a practice item
  void updatePracticeItem(PracticeItem updatedItem) {
    final index = practiceItems.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      practiceItems[index] = updatedItem;
    }
  }
}
