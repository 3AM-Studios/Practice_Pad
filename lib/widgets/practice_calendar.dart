import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:practice_pad/models/statistics.dart';
import 'package:clay_containers/clay_containers.dart';

enum CalendarSize {
  small, // Compact size
  medium, // Default/current size
  large, // Expanded size
}

class PracticeCalendar extends StatefulWidget {
  final VoidCallback? onStatsPressed;
  final CalendarSize calendarSize;

  const PracticeCalendar({
    super.key,
    this.onStatsPressed,
    this.calendarSize = CalendarSize.small, // Default to medium (current size)
  });

  @override
  State<PracticeCalendar> createState() => _PracticeCalendarState();
}

class _PracticeCalendarState extends State<PracticeCalendar> {
  DateTime _focusedDay = DateTime.now();
  Set<DateTime> _completedDays = <DateTime>{};
  bool _isLoading = true;

  // Size configuration based on CalendarSize
  double get _cellSize {
    switch (widget.calendarSize) {
      case CalendarSize.small:
        return 28.0;
      case CalendarSize.medium:
        return 40.0;// Current default size
      case CalendarSize.large:
        return 48.0;
    }
  }

  double get _fontSize {
    switch (widget.calendarSize) {
      case CalendarSize.small:
        return 12.0;
      case CalendarSize.medium:
        return 17.0;// Current default
      case CalendarSize.large:
        return 16.0;
    }
  }

  double get _headerFontSize {
    switch (widget.calendarSize) {
      case CalendarSize.small:
        return 14.0;
      case CalendarSize.medium:
        return 14.0; // Current default
      case CalendarSize.large:
        return 18.0;
    }
  }

  double get _starIconSize {
    switch (widget.calendarSize) {
      case CalendarSize.small:
        return 22.0;
      case CalendarSize.medium:
        return 30.0; // Current default
      case CalendarSize.large:
        return 42.0;
    }
  }

  double get _containerPadding {
    switch (widget.calendarSize) {
      case CalendarSize.small:
        return 8.0;  // Reduced for small size
      case CalendarSize.medium:
        return 8.0; // Reduced from 16.0
      case CalendarSize.large:
        return 16.0; // Reduced from 20.0
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCompletedDays();
  }

  Future<void> _loadCompletedDays() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all practice statistics
      final allStats = await Statistics.getAll();

      // Create a set of unique days when practice was completed
      final completedDays = <DateTime>{};
      for (final stat in allStats) {
        // Normalize to date only (no time component)
        final date = DateTime(
          stat.timestamp.year,
          stat.timestamp.month,
          stat.timestamp.day,
        );
        completedDays.add(date);
      }

      setState(() {
        _completedDays = completedDays;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _completedDays = <DateTime>{};
        _isLoading = false;
      });
    }
  }

  bool _isDayCompleted(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _completedDays.contains(normalizedDay);
  }

  String _getMonthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    double dayButtonSpread = 2.12;
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return Flexible(
      child: Container(
        margin: EdgeInsets.all(_containerPadding),
        padding: EdgeInsets.all(_containerPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom header with month navigation and stats button
          Row(
            children: [
              // Left chevron
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                  });
                },
                child: Icon(
                  CupertinoIcons.chevron_left,
                  color: theme.colorScheme.onSurface,
                  size: 20,
                ),
              ),
              
              // Month title (centered)
              Expanded(
                child: Center(
                  child: Text(
                    '${_getMonthName(_focusedDay.month)} ${_focusedDay.year}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: _headerFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              // Right chevron
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                  });
                },
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: theme.colorScheme.onSurface,
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Stats button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: widget.onStatsPressed,
                child: ClayContainer(
                  color: theme.colorScheme.surface,
                  borderRadius: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      image: const DecorationImage(
                        image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: Theme.of(context).colorScheme.surface, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child:  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.chart_bar_square,
                            size: 14,
                            color: Colors.white
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Stats',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: widget.calendarSize == CalendarSize.small ? 14 : 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Calendar
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            rowHeight: _cellSize,
            daysOfWeekHeight: _cellSize * 0.8,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: false,
              headerMargin: EdgeInsets.zero,
              headerPadding: EdgeInsets.zero,
              leftChevronVisible: false,
              rightChevronVisible: false,
              titleTextStyle: TextStyle(fontSize: 0), // Hide the title
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: _fontSize * 0.85,
                fontWeight: FontWeight.w500,
              ),
              weekendStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: _fontSize * 0.85,
                fontWeight: FontWeight.w500,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              cellMargin: EdgeInsets.all(_cellSize * 0.1),
              defaultTextStyle: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: _fontSize,
              ),
              weekendTextStyle: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: _fontSize,
              ),
              todayTextStyle: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: _fontSize,
                fontWeight: FontWeight.bold,
              ),
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
              markerDecoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                if (_isDayCompleted(day)) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    child: ClayContainer(
                      color: Colors.amber,
                      borderRadius: _cellSize / 2,
                      spread: dayButtonSpread,
                      child: SizedBox(
                        width: _cellSize - 8,
                        height: _cellSize - 8,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.star_fill,
                                size: _starIconSize,
                                color: Colors.white,
                              ),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: _fontSize * 0.85,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return null;
              },
              todayBuilder: (context, day, focusedDay) {
                final isCompleted = _isDayCompleted(day);
                if (isCompleted) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    child: ClayContainer(
                      color: Colors.amber,
                      borderRadius: _cellSize / 2,
                      spread: dayButtonSpread,
                      child: Container(
                        width: _cellSize - 8,
                        height: _cellSize - 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CupertinoColors.systemGrey,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.star_fill,
                                size: _starIconSize,
                                color: Colors.white,
                              ),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: _fontSize * 0.85,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    child: ClayContainer(
                      color: theme.colorScheme.primary,
                      borderRadius: _cellSize / 2,
                      spread: dayButtonSpread,
                      child: SizedBox(
                        width: _cellSize - 8,
                        height: _cellSize - 8,
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: _fontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),

          // Legend
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.star_fill,
                size: 16,
                color: Colors.amber,
              ),
              const SizedBox(width: 4),
              Text(
                'Practice completed',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
