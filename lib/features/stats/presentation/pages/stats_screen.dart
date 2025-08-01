import 'package:flutter/cupertino.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextStyle captionStyle = CupertinoTheme.of(context)
        .textTheme
        .textStyle
        .copyWith(fontSize: 12, color: CupertinoColors.secondaryLabel);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Practice Stats'),
        transitionBetweenRoutes: false,
      ),
      child: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '"If you can\'t measure it, you can\'t manage it." - Peter Drucker',
              style: captionStyle, // Use the defined captionStyle
              textAlign: TextAlign.center,
            ),
          ),
          // Placeholder for Calendar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Container(
                height: 350, // Adjust as needed
                decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.separator),
                    borderRadius: BorderRadius.circular(8.0)),
                child: const Center(child: Text('Calendar Placeholder'))
                // Implement TableCalendar here later
                // TableCalendar(
                //   firstDay: DateTime.utc(2020, 1, 1),
                //   lastDay: DateTime.utc(2030, 12, 31),
                //   focusedDay: DateTime.now(),
                //   calendarStyle: CalendarStyle(
                //     todayDecoration: BoxDecoration(
                //       color: CupertinoColors.systemRed.withOpacity(0.5),
                //       shape: BoxShape.circle,
                //     ),
                //     selectedDecoration: BoxDecoration(
                //       color: CupertinoColors.systemRed,
                //       shape: BoxShape.circle,
                //     ),
                //     markerDecoration: BoxDecoration(
                //        color: CupertinoColors.activeGreen, // Example for practiced days
                //        shape: BoxShape.circle
                //     ),
                //   )
                //   // TODO: Add event loader, styling, etc.
                // ),
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _buildLegendItem(CupertinoColors.activeGreen, "Practiced"),
                _buildLegendItem(
                    CupertinoColors.systemYellow, "Partial"), // Example
              ],
            ),
          ),
          _buildStatItem(context, "Completion Rate", "--%"),
          _buildStatItem(context, "Days of practice completed", "--"),
          _buildStatItem(context, "Days of practice started", "--"),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CupertinoButton(
              child: const Text('Practice Logs'),
              onPressed: () {
                // TODO: Navigate to detailed log view
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(CupertinoIcons.circle_fill, color: color, size: 12),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String title, String value) {
    // Use the standard CupertinoListTile from flutter/cupertino.dart
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(title, style: CupertinoTheme.of(context).textTheme.textStyle),
          Text(value,
              style: CupertinoTheme.of(context)
                  .textTheme
                  .textStyle
                  .copyWith(color: CupertinoColors.secondaryLabel)),
        ],
      ),
    );
  }
}

// Removed custom CupertinoListTile definition as it's part of Flutter's Cupertino library.
