import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/features/edit_items/presentation/pages/practice_items_screen.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/services/device_type.dart';
import 'package:practice_pad/services/local_storage_service.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

class ExerciseAreasScreen extends StatefulWidget {
  const ExerciseAreasScreen({super.key});

  @override
  State<ExerciseAreasScreen> createState() => _ExerciseAreasScreenState();
}

class _ExerciseAreasScreenState extends State<ExerciseAreasScreen> {
  void _showAddExerciseDialog(BuildContext context, EditItemsViewModel viewModel) {
    final TextEditingController nameController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Add New Exercise'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Exercise Name (e.g., Scales, Arpeggios)',
                autofocus: true,
              ),
              const SizedBox(height: 12),
              const Text(
                'No default items will be added.\nYou can create custom practice items.',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Add Exercise'),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(dialogContext).pop(name);
                }
              },
            ),
          ],
        );
      },
    ).then((value) {
      if (value is String && value.isNotEmpty) {
        viewModel.addPracticeArea(value, PracticeAreaType.exercise);
      }
    });
  }

  void _showEditExerciseDialog(
      BuildContext context, EditItemsViewModel viewModel, PracticeArea area) {
    final TextEditingController nameController =
        TextEditingController(text: area.name);

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Edit Exercise Name'),
          content: CupertinoTextField(
            controller: nameController,
            placeholder: 'Exercise Name',
            autofocus: true,
          ),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Save'),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(dialogContext).pop(name);
                }
              },
            ),
          ],
        );
      },
    ).then((value) {
      if (value is String && value.isNotEmpty) {
        area.name = value;
        viewModel.updatePracticeArea(area);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditItemsViewModel>(
      builder: (context, itemsViewModel, child) {
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Exercises'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.add),
              onPressed: () => _showAddExerciseDialog(context, itemsViewModel),
            ),
          ),
          child: _buildBody(context, itemsViewModel),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, EditItemsViewModel viewModel) {
    if (viewModel.isLoadingAreas && viewModel.exerciseAreas.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (viewModel.error != null && viewModel.exerciseAreas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Error: ${viewModel.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: CupertinoColors.systemRed)),
            const SizedBox(height: 8),
            CupertinoButton(
                child: const Text("Retry"),
                onPressed: () => viewModel.fetchPracticeAreas()),
          ]),
        ),
      );
    }

    final bool hasErrorAndData =
        viewModel.error != null && viewModel.exerciseAreas.isNotEmpty;
  final isTabletOrDesktop = deviceType == DeviceType.tablet || deviceType == DeviceType.macOS;

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: viewModel.fetchPracticeAreas,
        ),
        if (hasErrorAndData)
          SliverToBoxAdapter(
            child: Container(
              color: CupertinoColors.systemRed.withOpacity(0.1),
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Error: ${viewModel.error}',
                style: const TextStyle(color: CupertinoColors.systemRed),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        // Add padding for navigation bar
        SliverToBoxAdapter(
          child: SizedBox(height: isTabletOrDesktop ? 55 : 110),
        ),
        
        // Always show Chord Progressions area at the top
        SliverToBoxAdapter(
          child: Material(
            color: CupertinoTheme.of(context).scaffoldBackgroundColor,
            child: CupertinoListTile.notched(
              title: const Text('Chord Progressions'),
              subtitle: Text('${viewModel.chordProgressionsArea.practiceItems.length} chord progressions'),
              leading: const Icon(
                CupertinoIcons.music_note_2,
                color: CupertinoColors.systemPurple,
              ),
              trailing: const Icon(CupertinoIcons.right_chevron),
              onTap: () {
                developer.log(
                    "Tapped on Chord Progressions - Navigating",
                    name: 'ExerciseAreasScreen');
                Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: viewModel,
                    child: PracticeItemsScreen(practiceArea: viewModel.chordProgressionsArea),
                  ),
                ));
              },
            ),
          ),
        ),
        
        if (viewModel.exerciseAreas.isEmpty &&
            !viewModel.isLoadingAreas &&
            viewModel.error == null)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(24),
              child: ClayContainer(
                color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                borderRadius: 24,
                depth: 20,
                spread: 2,
                curveType: CurveType.concave,
                child: DefaultTextStyle(
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        ClayContainer(
                          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                          borderRadius: 20,
                          depth: 15,
                          spread: 1,
                          curveType: CurveType.none,
                          child: Container(
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            child: const Icon(
                              CupertinoIcons.music_albums,
                              size: 40,
                              color: CupertinoColors.systemOrange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Ready to Practice?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: CupertinoTheme.of(context).textTheme.textStyle.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No custom exercises yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: CupertinoTheme.of(context).textTheme.textStyle.color?.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ClayContainer(
                          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                          borderRadius: 16,
                          depth: 8,
                          spread: 0,
                          curveType: CurveType.concave,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Text(
                              'Tap the + button above to create exercises for:\n• Scales & Arpeggios\n• Technical Studies\n• Sight Reading',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: CupertinoTheme.of(context).textTheme.textStyle.color,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        
        // Show regular exercise areas
        if (viewModel.exerciseAreas.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final area = viewModel.exerciseAreas[index];
                return CupertinoContextMenu(
                  actions: <Widget>[
                    CupertinoContextMenuAction(
                      child: const Text('Edit Exercise Name'),
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditExerciseDialog(context, viewModel, area);
                      },
                    ),
                    CupertinoContextMenuAction(
                      isDestructiveAction: true,
                      child: const Text('Delete Exercise'),
                      onPressed: () {
                        Navigator.pop(context);
                        viewModel.deletePracticeArea(area.recordName);
                      },
                    ),
                  ],
                  child: Material(
                    color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                    child: CupertinoListTile.notched(
                      title: Text(area.name),
                      subtitle: Text('${area.practiceItems.length} practice items'),
                      leading: const Icon(
                        CupertinoIcons.chart_bar_square,
                        color: CupertinoColors.systemOrange,
                      ),
                      trailing: const Icon(CupertinoIcons.right_chevron),
                      onTap: () {
                        developer.log(
                            "Tapped on exercise: ${area.name} - Navigating",
                            name: 'ExerciseAreasScreen');
                        Navigator.of(context).push(CupertinoPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: viewModel,
                            child: PracticeItemsScreen(practiceArea: area),
                          ),
                        ));
                      },
                    ),
                  ),
                );
              },
              childCount: viewModel.exerciseAreas.length,
            ),
          ),
      ],
    );
  }




  void _showSuccessDialog(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
