import 'package:flutter/cupertino.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
import 'package:practice_pad/features/practice/presentation/pages/practice_session_screen.dart';
import 'package:practice_pad/features/practice/presentation/pages/practice_item_selection_screen.dart';
import 'package:practice_pad/features/song_viewer/presentation/screens/song_viewer_screen.dart';
import 'package:practice_pad/services/practice_session_manager.dart';
import 'package:provider/provider.dart';

/// Expandable tile widget for practice areas that shows practice items as sub-items
class PracticeAreaTile extends StatefulWidget {
  final PracticeArea area;
  final TodayViewModel viewModel;

  const PracticeAreaTile({
    super.key,
    required this.area,
    required this.viewModel,
  });

  @override
  State<PracticeAreaTile> createState() => _PracticeAreaTileState();
}

class _PracticeAreaTileState extends State<PracticeAreaTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // Area header
          CupertinoListTile.notched(
            title: Text(widget.area.name),
            subtitle: Text(
              widget.area.type == PracticeAreaType.song && widget.area.song != null
                  ? 'Song: ${widget.area.song!.title} • ${widget.area.practiceItems.length} items'
                  : '${widget.area.type == PracticeAreaType.song ? 'Song' : 'Exercise'} • ${widget.area.practiceItems.length} items',
            ),
            leading: Icon(
              widget.area.type == PracticeAreaType.song 
                  ? CupertinoIcons.music_note_2 
                  : CupertinoIcons.chart_bar_square,
              color: widget.area.type == PracticeAreaType.song 
                  ? CupertinoColors.systemBlue 
                  : CupertinoColors.systemOrange,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Practice Items button - navigate to dedicated screen
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.list_bullet, color: CupertinoColors.systemGreen),
                  onPressed: () {
                    // Navigate to practice item selection screen
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => PracticeItemSelectionScreen(
                          area: widget.area,
                          viewModel: widget.viewModel,
                        ),
                      ),
                    );
                  },
                ),
                // Song viewer button (if it's a song area)
                if (widget.area.type == PracticeAreaType.song && widget.area.song != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.music_note, color: CupertinoColors.systemBlue),
                    onPressed: () {
                      // Navigate to chord player screen
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => SongViewerScreen(
                            songAssetPath: widget.area.song!.path,
                            practiceArea: widget.area,
                          ),
                        ),
                      );
                    },
                  ),
                // Expand/collapse button
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    _isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                    color: CupertinoColors.systemGrey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          
          // Expandable practice items list
          if (_isExpanded)
            Container(
              margin: const EdgeInsets.only(left: 16, top: 8),
              child: Column(
                children: widget.area.practiceItems.map((item) {
                  return _PracticeItemSubTile(
                    item: item,
                    viewModel: widget.viewModel,
                    area: widget.area,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sub-tile widget for individual practice items
class _PracticeItemSubTile extends StatelessWidget {
  final PracticeItem item;
  final TodayViewModel viewModel;
  final PracticeArea area;

  const _PracticeItemSubTile({
    required this.item,
    required this.viewModel,
    required this.area,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: CupertinoListTile.notched(
        title: Text(
          item.name,
          style: const TextStyle(fontSize: 16),
        ),
        subtitle: item.description.isNotEmpty 
            ? Text(
                item.description,
                style: const TextStyle(fontSize: 14),
              )
            : null,
        leading: const Icon(
          CupertinoIcons.circle,
          color: CupertinoColors.systemGrey3,
          size: 12,
        ),
        trailing: Consumer<PracticeSessionManager>(
          builder: (context, sessionManager, child) {
            // Show different states based on active session
            if (sessionManager.hasActiveSession && 
                sessionManager.activePracticeItem?.id == item.id) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }
            
            return const Icon(
              CupertinoIcons.play_circle,
              color: CupertinoColors.systemGrey,
            );
          },
        ),
        onTap: () async {
          // Start a practice session for this item
          final bool? sessionCompleted = await Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => PracticeSessionScreen(
                practiceItem: item,
              ),
            ),
          );
          
          // Optional: Handle session completion if needed
          if (sessionCompleted == true) {
            // Session was completed successfully
          }
        },
      ),
    );
  }
}
