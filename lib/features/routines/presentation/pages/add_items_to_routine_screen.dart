import 'package:flutter/cupertino.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/features/routines/models/day_of_week.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:provider/provider.dart';

class AddAreasToRoutineScreen extends StatefulWidget {
  final DayOfWeek targetDay;

  const AddAreasToRoutineScreen({super.key, required this.targetDay});

  @override
  State<AddAreasToRoutineScreen> createState() =>
      _AddAreasToRoutineScreenState();
}

class _AddAreasToRoutineScreenState extends State<AddAreasToRoutineScreen> {
  final Set<PracticeArea> _selectedAreas =
      {}; // To keep track of selected areas

  @override
  Widget build(BuildContext context) {
    final editItemsViewModel = Provider.of<EditItemsViewModel>(context);
    final practiceAreas = editItemsViewModel.areas;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Add To ${dayOfWeekToFullName(widget.targetDay)}'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop(); // Dismiss screen, return no areas
          },
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child:
              const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            Navigator.of(context).pop(_selectedAreas
                .toList()); // Dismiss screen, return selected areas
          },
        ),
      ),
      child: _buildBody(practiceAreas),
    );
  }

  Widget _buildBody(List<PracticeArea> practiceAreas) {
    if (practiceAreas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.folder,
                size: 64,
                color: CupertinoColors.systemGrey,
              ),
              SizedBox(height: 16),
              Text(
                'No Practice Areas Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Create some songs or exercises first in the Items tab.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: practiceAreas.length,
      itemBuilder: (context, index) {
        final area = practiceAreas[index];
        final isSelected = _selectedAreas.contains(area);
        
        return CupertinoListTile.notched(
          title: Text(area.name),
          subtitle: Text(
            '${area.type == PracticeAreaType.song ? 'Song' : 'Exercise'} • ${area.practiceItems.length} practice items',
          ),
          leading: Icon(
            area.type == PracticeAreaType.song 
                ? CupertinoIcons.music_note_2 
                : CupertinoIcons.chart_bar_square,
            color: area.type == PracticeAreaType.song 
                ? CupertinoColors.systemBlue 
                : CupertinoColors.systemOrange,
          ),
          trailing: Icon(
            isSelected ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
            color: isSelected ? CupertinoColors.activeGreen : CupertinoColors.systemGrey,
          ),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedAreas.remove(area);
              } else {
                _selectedAreas.add(area);
              }
            });
          },
        );
      },
    );
  }

  String dayOfWeekToFullName(DayOfWeek day) {
    switch (day) {
      case DayOfWeek.monday:
        return 'Monday';
      case DayOfWeek.tuesday:
        return 'Tuesday';
      case DayOfWeek.wednesday:
        return 'Wednesday';
      case DayOfWeek.thursday:
        return 'Thursday';
      case DayOfWeek.friday:
        return 'Friday';
      case DayOfWeek.saturday:
        return 'Saturday';
      case DayOfWeek.sunday:
        return 'Sunday';
    }
  }
}
