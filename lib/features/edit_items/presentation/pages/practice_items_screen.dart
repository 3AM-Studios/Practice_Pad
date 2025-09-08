import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/features/chord_progressions/chord_progression_input_screen.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/chord_progression.dart';
import 'package:practice_pad/services/device_type.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

class PracticeItemsScreen extends StatefulWidget {
  final PracticeArea practiceArea;

  const PracticeItemsScreen({super.key, required this.practiceArea});

  @override
  State<PracticeItemsScreen> createState() => _PracticeItemsScreenState();
}

class _PracticeItemsScreenState extends State<PracticeItemsScreen> {
  late EditItemsViewModel _viewModel;
  List<PracticeItem> _items = [];

  @override
  void initState() {
    super.initState();
    _viewModel = Provider.of<EditItemsViewModel>(context, listen: false);
    _loadItems();
  }

  Future<void> _loadItems() async {
    // No need to set loading state here if viewModel handles it,
    // but this screen can manage its own loading/empty/error for items specifically.
    final fetchedItems = await _viewModel
        .fetchPracticeItemsForArea(widget.practiceArea.recordName);
    if (mounted) {
      setState(() {
        _items = fetchedItems;
      });
    }
  }

  void _showChordProgressionDialog(BuildContext context, {PracticeItem? item}) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ChordProgressionInputScreen(
          initialProgression: item?.chordProgression,
        ),
      ),
    ).then((value) async {
      if (value is ChordProgression) {
        final practiceItem = PracticeItem(
          id: item?.id ?? '',
          name: value.name,
          description: 'Chord progression: ${value.chords.join(' - ')}',
          chordProgression: value,
        );
        
        if (item != null) {
          // Update existing item
          await _viewModel.updatePracticeItem(widget.practiceArea.recordName, practiceItem);
        } else {
          // Add new item
          await _viewModel.addPracticeItem(widget.practiceArea.recordName, practiceItem);
        }
        _loadItems();
      }
    });
  }

  void _showAddEditPracticeItemDialog(BuildContext context,
      {PracticeItem? item}) {
    final bool isEditing = item != null;
    final TextEditingController nameController =
        TextEditingController(text: item?.name ?? '');
    final TextEditingController descriptionController =
        TextEditingController(text: item?.description ?? '');

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (stfContext, stfSetState) {
          return CupertinoAlertDialog(
            title: Text(isEditing ? 'Edit Practice Item' : 'Add Practice Item'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: 'Item Name (e.g., C Major Scale)',
                    textInputAction: TextInputAction.next,
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: descriptionController,
                    placeholder: 'Description (optional)',
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                ],
              ),
            ),
            actions: <CupertinoDialogAction>[
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: Text(isEditing ? 'Save' : 'Add'),
                onPressed: () {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();
                  if (name.isNotEmpty) {
                    final newItemDetails = {
                      'name': name,
                      'description': description,
                    };
                    Navigator.of(dialogContext).pop(newItemDetails);
                  }
                },
              ),
            ],
          );
        });
      },
    ).then((value) async {
      if (value is Map<String, dynamic>) {
        if (isEditing) {
          final updatedItem = item.copyWith(
            name: value['name'],
            description: value['description'],
          );
          await _viewModel.updatePracticeItem(widget.practiceArea.recordName, updatedItem);
        } else {
          final newItem = PracticeItem(
            id: '',
            name: value['name'],
            description: value['description'],
          );
          await _viewModel.addPracticeItem(
              widget.practiceArea.recordName, newItem);
        }
        _loadItems();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.practiceArea.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add),
          onPressed: () {
            if (widget.practiceArea.type == PracticeAreaType.chordProgression) {
              _showChordProgressionDialog(context);
            } else {
              _showAddEditPracticeItemDialog(context);
            }
          },
        ),
      ),
      child: _buildItemList(context),
    );
  }

  Widget _buildItemList(BuildContext context) {
    final isTabletOrDesktop = deviceType == DeviceType.tablet || deviceType == DeviceType.macOS;
    
    final bool isLoading =
        _viewModel.isLoadingItemsForArea(widget.practiceArea.recordName);

    if (isLoading && _items.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }




    if (_items.isEmpty && !isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DefaultTextStyle(
                style: CupertinoTheme.of(context).textTheme.textStyle,
                child: Text(
                  'No practice items found in ${widget.practiceArea.name}.\nTap the + button to add your first item.',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                child: const Text('Add Item'),
                onPressed: () {
                  if (widget.practiceArea.type == PracticeAreaType.chordProgression) {
                    _showChordProgressionDialog(context);
                  } else {
                    _showAddEditPracticeItemDialog(context);
                  }
                },
              )
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _loadItems,
        ),
                 SliverToBoxAdapter(
          child: SizedBox(height: isTabletOrDesktop? 50: 100),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = _items[index];
              return Material(
                color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                child: CupertinoListTile.notched(
                  title: Text(item.name),
                  subtitle: Text(item.description.isNotEmpty
                      ? item.description
                      : 'No description'),
                  leading: Icon(
                    (widget.practiceArea.type == PracticeAreaType.chordProgression || item.chordProgression != null)
                        ? CupertinoIcons.music_note_2
                        : CupertinoIcons.doc_text,
                    color: (widget.practiceArea.type == PracticeAreaType.chordProgression || item.chordProgression != null)
                        ? CupertinoColors.systemPurple
                        : CupertinoColors.systemBlue,
                  ),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(
                      CupertinoIcons.delete,
                      color: CupertinoColors.systemRed,
                      size: 20,
                    ),
                    onPressed: () async {
                      // Show confirmation dialog before deleting
                      final bool? confirmDelete = await showCupertinoDialog<bool>(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Delete Practice Item'),
                          content: Text('Are you sure you want to delete "${item.name}"?'),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              child: const Text('Delete'),
                              onPressed: () => Navigator.of(context).pop(true),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirmDelete == true) {
                        await _viewModel.deletePracticeItem(
                            item.id, widget.practiceArea.recordName);
                        _loadItems(); // Refresh list
                      }
                    },
                  ),
                  onTap: () {
                    developer.log("Tapped on item: ${item.name} (LOCAL)",
                        name: 'PracticeItemsScreen');
                    if (widget.practiceArea.type == PracticeAreaType.chordProgression || item.chordProgression != null) {
                      _showChordProgressionDialog(context, item: item);
                    } else {
                      _showAddEditPracticeItemDialog(context, item: item);
                    }
                  },
                ),
              );
            },
            childCount: _items.length,
          ),
        ),
      ],
    );
  }
}
