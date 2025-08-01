import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'practice_item.dart';

/// Model for storing and managing practice statistics
class Statistics {
  final String practiceItemId;
  final DateTime timestamp;
  final int totalReps;
  final Duration totalTime;
  final Map<String, dynamic> metadata;
  
  Statistics({
    required this.practiceItemId,
    required this.timestamp,
    required this.totalReps,
    required this.totalTime,
    this.metadata = const {},
  });
  
  /// Creates statistics from JSON data
  factory Statistics.fromJson(Map<String, dynamic> json) {
    return Statistics(
      practiceItemId: json['practiceItemId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      totalReps: json['totalReps'] as int,
      totalTime: Duration(microseconds: json['totalTimeMicroseconds'] as int),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
  
  /// Converts statistics to JSON
  Map<String, dynamic> toJson() {
    return {
      'practiceItemId': practiceItemId,
      'timestamp': timestamp.toIso8601String(),
      'totalReps': totalReps,
      'totalTimeMicroseconds': totalTime.inMicroseconds,
      'metadata': metadata,
    };
  }
  
  /// Gets statistics for a specific practice item
  static Future<List<Statistics>> getForPracticeItem(String practiceItemId) async {
    try {
      final file = await _getStatisticsFile();
      if (!await file.exists()) return [];
      
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      
      return jsonList
          .map((json) => Statistics.fromJson(json))
          .where((stat) => stat.practiceItemId == practiceItemId)
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Gets all statistics
  static Future<List<Statistics>> getAll() async {
    try {
      final file = await _getStatisticsFile();
      if (!await file.exists()) return [];
      
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      
      return jsonList.map((json) => Statistics.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Saves a single statistics entry
  Future<void> save() async {
    final allStats = await getAll();
    allStats.add(this);
    await _saveAll(allStats);
  }
  
  /// Adds a practice session to statistics (used by PracticeSession)
  static Future<void> addToStats(PracticeItem item, Map<String, dynamic> practiceAmount) async {
    final statistics = Statistics(
      practiceItemId: item.id,
      timestamp: DateTime.now(),
      totalReps: practiceAmount.containsKey('reps') ? practiceAmount['reps'] as int : 0,
      totalTime: practiceAmount.containsKey('time') ? Duration(seconds: practiceAmount['time'] as int) : Duration.zero,
      metadata: practiceAmount,
    );
    
    await statistics.save();
  }
  
  /// Saves multiple statistics entries
  static Future<void> saveAll(List<Statistics> statistics) async {
    await _saveAll(statistics);
  }
  
  /// Private method to save all statistics to file
  static Future<void> _saveAll(List<Statistics> statistics) async {
    final file = await _getStatisticsFile();
    final jsonList = statistics.map((stat) => stat.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
  }
  
  /// Gets the statistics file
  static Future<File> _getStatisticsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/practice_statistics.json');
  }
  
  /// Clears all statistics
  static Future<void> clearAll() async {
    final file = await _getStatisticsFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  /// Gets statistics for today
  static Future<List<Statistics>> getToday() async {
    final allStats = await getAll();
    final today = DateTime.now();
    return allStats.where((stat) {
      return stat.timestamp.year == today.year &&
             stat.timestamp.month == today.month &&
             stat.timestamp.day == today.day;
    }).toList();
  }
  
  /// Gets total practice time for a practice item
  static Future<Duration> getTotalTimeForItem(String practiceItemId) async {
    final stats = await getForPracticeItem(practiceItemId);
    Duration total = Duration.zero;
    for (final stat in stats) {
      total += stat.totalTime;
    }
    return total;
  }
  
  /// Gets total reps for a practice item
  static Future<int> getTotalRepsForItem(String practiceItemId) async {
    final stats = await getForPracticeItem(practiceItemId);
    int total = 0;
    for (final stat in stats) {
      total += stat.totalReps;
    }
    return total;
  }
  
  @override
  String toString() {
    return 'Statistics(item: $practiceItemId, reps: $totalReps, time: $totalTime)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Statistics &&
        other.practiceItemId == practiceItemId &&
        other.timestamp == timestamp;
  }
  
  @override
  int get hashCode => Object.hash(practiceItemId, timestamp);
}
