import 'package:flutter/cupertino.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
import 'package:practice_pad/features/practice/presentation/pages/practice_session_screen.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/widgets/active_session_banner.dart';
import 'package:provider/provider.dart';

class PracticeItemSelectionScreen extends StatefulWidget {
  final PracticeArea area;
  final TodayViewModel viewModel;

  const PracticeItemSelectionScreen({
    super.key,
    required this.area,
    required this.viewModel,
  });

  @override
  State<PracticeItemSelectionScreen> createState() => _PracticeItemSelectionScreenState();
}

class _PracticeItemSelectionScreenState extends State<PracticeItemSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.area.name),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Back'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Edit Items'),
          onPressed: () {
            // Navigate to edit items screen for this area
            Navigator.of(context).pushNamed('/edit-items', arguments: widget.area);
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const ActiveSessionBanner(),
            Expanded(
              child: widget.area.practiceItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.area.type == PracticeAreaType.song
                                ? CupertinoIcons.music_note_2
                                : CupertinoIcons.chart_bar_square,
                            size: 64,
                            color: CupertinoColors.systemGrey3,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Practice Items',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.area.type == PracticeAreaType.song
                                ? 'This song has no practice items yet.'
                                : 'This exercise has no practice items yet.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          CupertinoButton.filled(
                            child: const Text('Add Practice Items'),
                            onPressed: () {
                              Navigator.of(context).pushNamed('/edit-items', arguments: widget.area);
                            },
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.area.practiceItems.length,
                      itemBuilder: (context, index) {
                        final item = widget.area.practiceItems[index];
                        final isSelected = widget.viewModel.isPracticeItemSelected(item);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CupertinoListTile.notched(
                            title: Text(item.name),
                            subtitle: item.description.isNotEmpty
                                ? Text(item.description)
                                : null,
                            trailing: Icon(
                              isSelected
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              color: isSelected
                                  ? CupertinoColors.activeGreen
                                  : CupertinoColors.systemGrey,
                              size: 24,
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
                              if (sessionCompleted == true && mounted) {
                                setState(() {
                                  // Refresh the UI if needed
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
