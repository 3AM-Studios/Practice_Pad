import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:practice_pad/features/edit_items/presentation/pages/practice_item_screen.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/features/song_viewer/presentation/screens/song_list_screen.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

class SongAreasScreen extends StatefulWidget {
  const SongAreasScreen({super.key});

  @override
  State<SongAreasScreen> createState() => _SongAreasScreenState();
}

class _SongAreasScreenState extends State<SongAreasScreen> {
  void _showAddSongDialog(BuildContext context, EditItemsViewModel viewModel) async {
    // Navigate to song list screen and wait for song selection
    final Song? selectedSong = await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const SongListScreen(),
      ),
    );

    if (selectedSong != null) {
      // Create practice area with the selected song
      viewModel.addPracticeAreaWithSong(selectedSong.title, selectedSong);
    }
  }

  void _showEditSongDialog(
      BuildContext context, EditItemsViewModel viewModel, PracticeArea area) {
    final TextEditingController nameController =
        TextEditingController(text: area.name);

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Edit Song Name'),
          content: CupertinoTextField(
            controller: nameController,
            placeholder: 'Song Name',
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
            middle: const Text('Songs'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.add),
              onPressed: () => _showAddSongDialog(context, itemsViewModel),
            ),
          ),
          child: _buildBody(context, itemsViewModel),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, EditItemsViewModel viewModel) {
    if (viewModel.isLoadingAreas && viewModel.songAreas.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (viewModel.error != null && viewModel.songAreas.isEmpty) {
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
        viewModel.error != null && viewModel.songAreas.isNotEmpty;

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
        if (viewModel.songAreas.isEmpty &&
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
                      CupertinoIcons.music_note_2,
                      size: 64,
                      color: CupertinoColors.systemGrey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No songs found.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first song.\nDefault practice items will be created automatically.',
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
                final area = viewModel.songAreas[index];
                return CupertinoContextMenu(
                  actions: <Widget>[
                    CupertinoContextMenuAction(
                      child: const Text('Edit Song Name'),
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditSongDialog(context, viewModel, area);
                      },
                    ),
                    CupertinoContextMenuAction(
                      isDestructiveAction: true,
                      child: const Text('Delete Song'),
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
                      subtitle: Text(area.song != null 
                        ? 'Song: ${area.song!.title} • ${area.practiceItems.length} practice items'
                        : '${area.practiceItems.length} practice items'),
                      leading: const Icon(
                        CupertinoIcons.music_note_2,
                        color: CupertinoColors.systemBlue,
                      ),
                      trailing: const Icon(CupertinoIcons.right_chevron),
                      onTap: () {
                        developer.log(
                            "Tapped on song: ${area.name} - Navigating",
                            name: 'SongAreasScreen');
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
              childCount: viewModel.songAreas.length,
            ),
          ),
      ],
    );
  }
}
