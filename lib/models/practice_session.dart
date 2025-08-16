import 'practice_item.dart';
import 'statistics.dart';

/// Represents a practice session for a specific practice item.
/// 
/// A practice session tracks the time spent practicing. Legacy support
/// for repetition-based sessions is maintained for historical data.
/// 
/// Example usage:
/// ```dart
/// // Practice session with time (primary method)
/// final session = PracticeSession(
///   item: practiceItem,
///   practiceAmount: {'time': 300}, // 5 minutes in seconds
/// );
/// 
/// // Legacy repetition-based support (for historical data)
/// final legacySession = PracticeSession(
///   item: practiceItem,
///   practiceAmount: {'reps': 10},
/// );
/// ```
class PracticeSession {
  /// The practice item being practiced
  final PracticeItem item;
  
  /// Map containing practice amount data
  /// Expected keys:
  /// - 'reps': int (number of repetitions)
  /// - 'time': int (time in seconds)
  final Map<String, dynamic> practiceAmount;
  
  /// Timestamp when the practice session was created
  final DateTime timestamp;

  PracticeSession({
    required this.item,
    required this.practiceAmount,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now() {
    _validatePracticeAmount();
  }

  /// Validates that practiceAmount contains valid data
  void _validatePracticeAmount() {
    if (practiceAmount.isEmpty) {
      throw ArgumentError('practiceAmount cannot be empty');
    }
    
    final hasReps = practiceAmount.containsKey('reps');
    final hasTime = practiceAmount.containsKey('time');
    
    if (!hasReps && !hasTime) {
      throw ArgumentError('practiceAmount must contain either "reps" or "time"');
    }
    
    if (hasReps && hasTime) {
      throw ArgumentError('practiceAmount cannot contain both "reps" and "time"');
    }
    
    if (hasReps) {
      final reps = practiceAmount['reps'];
      if (reps is! int || reps <= 0) {
        throw ArgumentError('reps must be a positive integer');
      }
    }
    
    if (hasTime) {
      final time = practiceAmount['time'];
      if (time is! int || time <= 0) {
        throw ArgumentError('time must be a positive integer (seconds)');
      }
    }
  }

  /// Returns a human-readable description of the practice amount
  String get practiceDescription {
    if (practiceAmount.containsKey('reps')) {
      final reps = practiceAmount['reps'] as int;
      return '$reps repetition${reps == 1 ? '' : 's'}';
    } else if (practiceAmount.containsKey('time')) {
      final timeSeconds = practiceAmount['time'] as int;
      final minutes = timeSeconds ~/ 60;
      final seconds = timeSeconds % 60;
      
      if (minutes > 0) {
        return '${minutes}m ${seconds}s';
      } else {
        return '${seconds}s';
      }
    }
    
    return 'Unknown practice amount';
  }

  /// Returns true if this is a repetition-based session
  bool get isRepsBased => practiceAmount.containsKey('reps');

  /// Returns true if this is a time-based session
  bool get isTimeBased => practiceAmount.containsKey('time');

  /// Gets the number of repetitions (if this is a reps-based session)
  int? get reps => practiceAmount['reps'] as int?;

  /// Gets the time in seconds (if this is a time-based session)
  int? get timeSeconds => practiceAmount['time'] as int?;

  /// Saves this practice session to the statistics storage
  Future<void> addToStatistics() async {
    await Statistics.addToStats(item, practiceAmount);
  }

  /// Converts this practice session to a Map for serialization
  Map<String, dynamic> toMap() {
    return {
      'item': {
        'id': item.id,
        'name': item.name,
        'description': item.description,
      },
      'practiceAmount': practiceAmount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Creates a PracticeSession from a Map (for deserialization)
  factory PracticeSession.fromMap(Map<String, dynamic> map) {
    final itemMap = map['item'] as Map<String, dynamic>;
    final item = PracticeItem(
      id: itemMap['id'] as String,
      name: itemMap['name'] as String,
      description: itemMap['description'] as String,
    );

    return PracticeSession(
      item: item,
      practiceAmount: Map<String, dynamic>.from(map['practiceAmount'] as Map),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is PracticeSession &&
        other.item.id == item.id &&
        other.practiceAmount.toString() == practiceAmount.toString() &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return item.id.hashCode ^ 
           practiceAmount.toString().hashCode ^ 
           timestamp.hashCode;
  }

  @override
  String toString() {
    return 'PracticeSession(item: ${item.name}, amount: $practiceDescription, timestamp: $timestamp)';
  }
}
