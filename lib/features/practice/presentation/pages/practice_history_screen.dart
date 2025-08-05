import 'package:flutter/cupertino.dart';
import 'package:practice_pad/models/statistics.dart';

/// Screen for viewing practice session history
class PracticeHistoryScreen extends StatefulWidget {
  const PracticeHistoryScreen({super.key});

  @override
  State<PracticeHistoryScreen> createState() => _PracticeHistoryScreenState();
}

class _PracticeHistoryScreenState extends State<PracticeHistoryScreen> {
  List<Statistics> _sessions = [];
  bool _isLoading = true;
  String _selectedDate = _formatDate(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allStats = await Statistics.getAll();
      final List<Statistics> sessionsForDate = [];
      
      for (final stat in allStats) {
        final sessionDateKey = '${stat.timestamp.year}-${stat.timestamp.month.toString().padLeft(2, '0')}-${stat.timestamp.day.toString().padLeft(2, '0')}';
        
        if (sessionDateKey == _selectedDate) {
          sessionsForDate.add(stat);
        }
      }
      
      // Sort sessions by timestamp (newest first)
      sessionsForDate.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      setState(() {
        _sessions = sessionsForDate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _sessions = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (BuildContext context) {
        DateTime tempDate = DateTime.now();
        
        return Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator.resolveFrom(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () => Navigator.of(context).pop(tempDate),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: DateTime.now(),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (DateTime date) {
                    tempDate = date;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = _formatDate(picked);
      });
      _loadSessions();
    }
  }

  String _formatDisplayDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateTime = DateTime(date.year, date.month, date.day);
    
    if (selectedDateTime == today) {
      return 'Today';
    } else if (selectedDateTime == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Practice History'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _selectDate,
          child: const Icon(CupertinoIcons.calendar),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Date selector
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator.resolveFrom(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: GestureDetector(
                onTap: _selectDate,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatDisplayDate(_selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      CupertinoIcons.chevron_down,
                      size: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                  ],
                ),
              ),
            ),
            
            // Sessions list
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _sessions.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.music_note_list,
                                size: 64,
                                color: CupertinoColors.systemGrey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No practice sessions found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Start practicing to see your sessions here!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: CupertinoColors.systemGrey2,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemBackground.resolveFrom(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: CupertinoColors.separator.resolveFrom(context),
                                    width: 0.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Item name and time
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Practice Item: ${session.practiceItemId}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatTime(session.timestamp),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: CupertinoColors.systemGrey.resolveFrom(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Description if available
                                    if (session.metadata.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Metadata: ${session.metadata}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: CupertinoColors.systemGrey.resolveFrom(context),
                                        ),
                                      ),
                                    ],
                                    
                                    const SizedBox(height: 12),
                                    
                                    // Practice amount
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _formatPracticeAmount(session),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: CupertinoColors.systemBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatPracticeAmount(Statistics statistics) {
    if (statistics.totalReps > 0) {
      return '${statistics.totalReps} repetition${statistics.totalReps == 1 ? '' : 's'}';
    } else if (statistics.totalTime.inSeconds > 0) {
      final timeSeconds = statistics.totalTime.inSeconds;
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
}
