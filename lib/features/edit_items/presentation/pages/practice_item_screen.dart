import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

class PracticeItemScreen extends StatefulWidget {
  final PracticeArea practiceArea;

  const PracticeItemScreen({super.key, required this.practiceArea});

  @override
  State<PracticeItemScreen> createState() => _PracticeItemScreenState();
}

class _PracticeItemScreenState extends State<PracticeItemScreen> {
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
          onPressed: () => _showAddEditPracticeItemDialog(context),
        ),
      ),
      child: _buildItemList(context),
    );
  }

  Widget _buildItemList(BuildContext context) {
    final bool isLoading =
        _viewModel.isLoadingItemsForArea(widget.practiceArea.recordName);

    if (isLoading && _items.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    // TODO: Add error display from viewModel if specific item loading errors are implemented

    if (_items.isEmpty && !isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No practice items found in ${widget.practiceArea.name}.\nTap the + button to add your first item.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                child: const Text('Add Item'),
                onPressed: () => _showAddEditPracticeItemDialog(context),
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
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = _items[index];
              return CupertinoContextMenu(
                actions: <Widget>[
                  CupertinoContextMenuAction(
                    child: const Text('Edit Item'),
                    onPressed: () {
                      Navigator.pop(context); // Close context menu
                      _showAddEditPracticeItemDialog(context, item: item);
                    },
                  ),
                  CupertinoContextMenuAction(
                    isDestructiveAction: true,
                    child: const Text('Delete Item'),
                    onPressed: () async {
                      Navigator.pop(context); // Close context menu
                      // Optional: Show confirmation dialog
                      await _viewModel.deletePracticeItem(
                          item.id, widget.practiceArea.recordName);
                      _loadItems(); // Refresh list
                    },
                  ),
                ],
                child: Material(
                  color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                  child: CupertinoListTile.notched(
                    title: Text(item.name),
                    subtitle: Text(item.description.isNotEmpty
                        ? item.description
                        : 'No description'),
                    leading: const Icon(CupertinoIcons.doc_text),
                    onTap: () {
                      developer.log("Tapped on item: ${item.name} (LOCAL)",
                          name: 'PracticeItemScreen');
                      _showAddEditPracticeItemDialog(context,
                          item: item); // Or navigate to a detail view
                    },
                  ),
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
