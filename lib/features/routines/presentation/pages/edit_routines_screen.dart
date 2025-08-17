import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
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

  Future<void> _navigateToAddAreasToAllDaysScreen(
      BuildContext context, RoutinesViewModel routinesViewModel) async {
    final List<PracticeArea>? selectedAreas =
        await Navigator.of(context).push<List<PracticeArea>>(
      CupertinoPageRoute(
        builder: (_) => const _AddAreasToAllDaysScreen(),
        fullscreenDialog: true,
      ),
    );

    if (selectedAreas != null && selectedAreas.isNotEmpty) {
      routinesViewModel.addPracticeAreasToAllDays(selectedAreas);
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

    // Create a map to track selected days for copying
    Map<DayOfWeek, bool> selectedDays = {};
    for (final day in DayOfWeek.values) {
      if (day != sourceDay) {
        // Pre-check days that already contain all practice areas from source
        selectedDays[day] = viewModel.dayContainsAllAreasFrom(sourceDay, day);
      }
    }

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => CupertinoAlertDialog(
          title: const Text('Copy Routine'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Select days to copy the routine from ${_dayOfWeekToFullName(sourceDay)}:'),
                const SizedBox(height: 16),
                ...DayOfWeek.values
                    .where((day) => day != sourceDay)
                    .map((day) {
                  final isSelected = selectedDays[day] ?? false;
                  final alreadyContainsAreas = viewModel.dayContainsAllAreasFrom(sourceDay, day);
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              selectedDays[day] = !isSelected;
                            });
                          },
                          child: Icon(
                            isSelected 
                                ? CupertinoIcons.checkmark_circle_fill 
                                : CupertinoIcons.circle,
                            color: isSelected 
                                ? (alreadyContainsAreas ? CupertinoColors.systemGreen : CupertinoColors.activeBlue)
                                : CupertinoColors.systemGrey,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedDays[day] = !isSelected;
                              });
                            },
                            child: Text(
                              _dayOfWeekToFullName(day),
                              style: TextStyle(
                                fontSize: 16,
                                color: alreadyContainsAreas 
                                    ? CupertinoColors.systemGreen 
                                    : CupertinoColors.label.resolveFrom(context),
                              ),
                            ),
                          ),
                        ),
                        if (alreadyContainsAreas)
                          const Icon(
                            CupertinoIcons.checkmark_shield_fill,
                            color: CupertinoColors.systemGreen,
                            size: 16,
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text(
                  '✓ Green = Already contains these practice areas',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Copy'),
              onPressed: () {
                final selectedDaysList = selectedDays.entries
                    .where((entry) => entry.value)
                    .map((entry) => entry.key)
                    .toList();
                
                if (selectedDaysList.isNotEmpty) {
                  Navigator.of(dialogContext).pop();
                  viewModel.copyRoutineToDays(sourceDay, selectedDaysList);
                  _showCopyConfirmation(context, sourceDay, selectedDaysList);
                } else {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCopyConfirmation(
      BuildContext context, DayOfWeek sourceDay, List<DayOfWeek> targetDays) {
    if (targetDays.isEmpty) return;
    
    String message;
    if (targetDays.length == 1) {
      message = 'The routine from ${_dayOfWeekToFullName(sourceDay)} has been copied to ${_dayOfWeekToFullName(targetDays.first)}.';
    } else {
      final dayNames = targetDays.map(_dayOfWeekToFullName).join(', ');
      message = 'The routine from ${_dayOfWeekToFullName(sourceDay)} has been copied to: $dayNames.';
    }
    
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Routine Copied'),
        content: Text(message),
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
                // Copy routine button with wooden styling
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClayContainer(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        image: const DecorationImage(
                          image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CupertinoButton(
                        padding: const EdgeInsets.all(16),
                        onPressed: () => _showCopyRoutineDialog(context, routinesViewModel),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.doc_on_doc, color: CupertinoColors.white),
                            SizedBox(width: 8),
                            Text(
                              'Copy This Routine to Another Day',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                            child: ClayContainer(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: 12,
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
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                // Shared practice areas section
                _buildSharedAreasSection(context, routinesViewModel),
                const SizedBox(height: 80)
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSharedAreasSection(BuildContext context, RoutinesViewModel routinesViewModel) {
    final sharedAreas = routinesViewModel.getSharedPracticeAreas();
    
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.3, // Cap at 40% of screen height
      child: ClayContainer(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: 20,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.calendar,
                    color: CupertinoColors.activeBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Practice Areas Shared Across All Days',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(
                      CupertinoIcons.add,
                      color: CupertinoColors.activeBlue,
                    ),
                    onPressed: () => _navigateToAddAreasToAllDaysScreen(context, routinesViewModel),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sharedAreas.isEmpty)
                        const Text(
                          'No practice areas are shared across all days yet. Add some to practice them every day!',
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 14,
                          ),
                        )
                      else
                        ...sharedAreas.map((area) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                area.type == PracticeAreaType.song 
                                    ? CupertinoIcons.music_note_2 
                                    : CupertinoIcons.chart_bar_square,
                                color: area.type == PracticeAreaType.song 
                                    ? CupertinoColors.systemBlue 
                                    : CupertinoColors.systemOrange,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  area.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: const Icon(
                                  CupertinoIcons.delete,
                                  color: CupertinoColors.destructiveRed,
                                  size: 16,
                                ),
                                onPressed: () => _showRemoveSharedAreaDialog(context, routinesViewModel, area),
                              ),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRemoveSharedAreaDialog(BuildContext context, RoutinesViewModel routinesViewModel, PracticeArea area) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Remove from All Days'),
        content: Text(
          'Are you sure you want to remove "${area.name}" from all days of the week?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Remove'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              routinesViewModel.removeSharedPracticeArea(area);
            },
          ),
        ],
      ),
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

class _AddAreasToAllDaysScreen extends StatefulWidget {
  const _AddAreasToAllDaysScreen();

  @override
  State<_AddAreasToAllDaysScreen> createState() => _AddAreasToAllDaysScreenState();
}

class _AddAreasToAllDaysScreenState extends State<_AddAreasToAllDaysScreen> {
  final Set<PracticeArea> _selectedAreas = {};

  @override
  Widget build(BuildContext context) {
    final editItemsViewModel = Provider.of<EditItemsViewModel>(context);
    final practiceAreas = editItemsViewModel.areas;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Add To All Days'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            Navigator.of(context).pop(_selectedAreas.toList());
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
}
