import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
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
        const SliverToBoxAdapter(
          child: SizedBox(height: 50),
        ),  
        if (viewModel.songAreas.isEmpty &&
            !viewModel.isLoadingAreas &&
            viewModel.error == null)
          SliverFillRemaining(
            child: Center(
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
                        mainAxisSize: MainAxisSize.min,
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
                                CupertinoIcons.music_note_list,
                                size: 40,
                                color: CupertinoColors.systemBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Your Song Library',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: CupertinoTheme.of(context).textTheme.textStyle.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No songs added yet',
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
                                'Tap the + button to add your first song\n\nDefault practice items will be created automatically including:\n• Full Song\n• Verse & Chorus sections\n• Chord Changes',
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
