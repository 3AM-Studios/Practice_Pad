import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:practice_pad/features/edit_items/presentation/pages/practice_item_screen.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/models/practice_area.dart';
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
        if (viewModel.exerciseAreas.isEmpty &&
            !viewModel.isLoadingAreas &&
            viewModel.error == null)
          const SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.chart_bar_square,
                      size: 64,
                      color: CupertinoColors.systemGrey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No exercises found.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first exercise.\nCreate custom practice items for scales, arpeggios, etc.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CupertinoColors.secondaryLabel),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
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
                            child: PracticeItemScreen(practiceArea: area),
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
}
