import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/features/routines/models/day_of_week.dart';
import 'package:practice_pad/features/routines/presentation/pages/add_areas_to_routine_screen.dart';
import 'package:practice_pad/features/routines/presentation/viewmodels/routines_viewmodel.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:provider/provider.dart';

class EditRoutinesScreen extends StatefulWidget {
  const EditRoutinesScreen({super.key});

  @override
  _EditRoutinesScreenState createState() => _EditRoutinesScreenState();
}

class _EditRoutinesScreenState extends State<EditRoutinesScreen> {
  Future<void> _navigateToAddAreaScreen(
      BuildContext context, RoutinesViewModel routinesViewModel) async {
    final List<PracticeArea>? selectedAreas =
        await Navigator.of(context).push<List<PracticeArea>>(
      CupertinoPageRoute(
        builder: (_) =>
            AddAreasToRoutineScreen(targetDay: routinesViewModel.selectedDay),
        fullscreenDialog: true,
      ),
    );

    if (selectedAreas != null && selectedAreas.isNotEmpty) {
      routinesViewModel.addMultiplePracticeAreasToRoutine(
          routinesViewModel.selectedDay, selectedAreas);
    }
  }

  Future<void> _showCopyRoutineDialog(
      BuildContext context, RoutinesViewModel viewModel) async {
    final DayOfWeek sourceDay = viewModel.selectedDay;
    final List<PracticeArea>? sourceAreas = viewModel.routines[sourceDay];

    if (sourceAreas == null || sourceAreas.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('No Areas to Copy'),
          content: Text(
              'The routine for ${_dayOfWeekToFullName(sourceDay)} is empty.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Copy Routine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Copy the routine from ${_dayOfWeekToFullName(sourceDay)} to which day?'),
            const SizedBox(height: 16),
            ...DayOfWeek.values
                .where((day) => day != sourceDay)
                .map((targetDay) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: CupertinoButton(
                        padding: const EdgeInsets.all(12),
                        color: CupertinoColors.activeBlue,
                        borderRadius: BorderRadius.circular(8),
                        child: Text(_dayOfWeekToFullName(targetDay)),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          viewModel.copyRoutineToDays(sourceDay, [targetDay]);
                          _showCopyConfirmation(context, sourceDay, targetDay);
                        },
                      ),
                    ))
                ,
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  void _showCopyConfirmation(
      BuildContext context, DayOfWeek sourceDay, DayOfWeek targetDay) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Routine Copied'),
        content: Text(
            'The routine from ${_dayOfWeekToFullName(sourceDay)} has been copied to ${_dayOfWeekToFullName(targetDay)}.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoutinesViewModel>(
      builder: (context, routinesViewModel, child) {
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Edit Routines'),
            transitionBetweenRoutes: false,
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text('Back'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.add),
              onPressed: () {
                _navigateToAddAreaScreen(context, routinesViewModel);
              },
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Day of week selector
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: CupertinoSlidingSegmentedControl<DayOfWeek>(
                    groupValue: routinesViewModel.selectedDay,
                    children: const {
                      DayOfWeek.monday: Text('Mon'),
                      DayOfWeek.tuesday: Text('Tue'),
                      DayOfWeek.wednesday: Text('Wed'),
                      DayOfWeek.thursday: Text('Thu'),
                      DayOfWeek.friday: Text('Fri'),
                      DayOfWeek.saturday: Text('Sat'),
                      DayOfWeek.sunday: Text('Sun'),
                    },
                    onValueChanged: (DayOfWeek? value) {
                      if (value != null) {
                        routinesViewModel.selectDay(value);
                      }
                    },
                  ),
                ),
                // Copy routine button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: CupertinoColors.systemGrey5,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.doc_on_doc,
                              color: CupertinoColors.systemBlue),
                          SizedBox(width: 8),
                          Text('Copy This Routine to Another Day',
                              style:
                                  TextStyle(color: CupertinoColors.systemBlue)),
                        ],
                      ),
                      onPressed: () =>
                          _showCopyRoutineDialog(context, routinesViewModel),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Practice areas list
                Expanded(
                  child: Consumer<EditItemsViewModel>(
                    builder: (context, editItemsViewModel, child) {
                      final List<PracticeArea>? practiceAreas =
                          routinesViewModel.routines[routinesViewModel.selectedDay];

                      if (practiceAreas == null || practiceAreas.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.music_note_list,
                                size: 64,
                                color: CupertinoColors.systemGrey3,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No practice areas assigned for ${_dayOfWeekToFullName(routinesViewModel.selectedDay)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: CupertinoColors.systemGrey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              CupertinoButton.filled(
                                child: const Text('Add Practice Areas'),
                                onPressed: () => _navigateToAddAreaScreen(context, routinesViewModel),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: practiceAreas.length,
                        itemBuilder: (context, index) {
                          final practiceArea = practiceAreas[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: CupertinoListTile(
                              title: Text(practiceArea.name),
                              subtitle: Text(
                                '${practiceArea.practiceItems.length} practice items',
                                style: const TextStyle(
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                              trailing: CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: const Icon(
                                  CupertinoIcons.delete,
                                  color: CupertinoColors.destructiveRed,
                                ),
                                onPressed: () {
                                  routinesViewModel.removePracticeAreaFromRoutine(
                                      routinesViewModel.selectedDay, practiceArea);
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _dayOfWeekToFullName(DayOfWeek day) {
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
