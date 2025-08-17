import 'package:flutter/cupertino.dart';
import 'package:practice_pad/features/edit_items/presentation/pages/song_areas_screen.dart';
import 'package:practice_pad/features/edit_items/presentation/pages/exercise_areas_screen.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:provider/provider.dart';

class EditItemsScreen extends StatefulWidget {
  const EditItemsScreen({super.key});

  @override
  State<EditItemsScreen> createState() => _EditItemsScreenState();
}

class _EditItemsScreenState extends State<EditItemsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<EditItemsViewModel>(
      builder: (context, itemsViewModel, child) {
        return CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Practice Items'),
            transitionBetweenRoutes: false,
          ),
          child: _buildSplitScreenBody(context, itemsViewModel),
        );
      },
    );
  }

  Widget _buildSplitScreenBody(BuildContext context, EditItemsViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header section
          const SizedBox(height: 50),
          const Text(
            'Choose Practice Type',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the type of practice items you want to work with',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          
          // Split screen buttons
          Expanded(
            child: Row(
              children: [
                // Songs button (left half)
                Expanded(
                  child: _buildTypeButton(
                    context: context,
                    title: 'Songs',
                    subtitle: '${viewModel.songAreas.length} songs',
                    icon: CupertinoIcons.music_note_2,
                    color: CupertinoColors.systemBlue,
                    description: 'Chord progressions with\ndefault practice items',
                    onTap: () => _navigateToSongs(context, viewModel),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Exercises button (right half)
                Expanded(
                  child: _buildTypeButton(
                    context: context,
                    title: 'Exercises',
                    subtitle: '${viewModel.allExerciseAreas.length} exercises',
                    icon: CupertinoIcons.chart_bar_square,
                    color: CupertinoColors.systemOrange,
                    description: 'Add custom exercises like scales, arpeggios, etc',
                    onTap: () => _navigateToExercises(context, viewModel),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 100),
          
          // Quick stats section
        ],
      ),
    );
  }

  Widget _buildTypeButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CupertinoColors.systemGrey4,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 64,
                color: color,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.tertiaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Tap to explore',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }

  void _navigateToSongs(BuildContext context, EditItemsViewModel viewModel) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel,
          child: const SongAreasScreen(),
        ),
      ),
    );
  }

  void _navigateToExercises(BuildContext context, EditItemsViewModel viewModel) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel,
          child: const ExerciseAreasScreen(),
        ),
      ),
    );
  }
}
