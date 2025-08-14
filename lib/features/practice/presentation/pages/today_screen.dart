import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
import 'package:practice_pad/features/practice/presentation/widgets/goal_ring.dart';
import 'package:practice_pad/widgets/practice_area_tile.dart';
import 'package:practice_pad/widgets/active_session_banner.dart';
import 'package:practice_pad/widgets/practice_calendar.dart';
import 'package:provider/provider.dart';

class TodayScreen extends StatelessWidget {
  final VoidCallback? onStatsPressed;

  const TodayScreen({super.key, this.onStatsPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<TodayViewModel>(
      builder: (context, viewModel, child) {
        return _buildBody(context, viewModel);
        // return CupertinoPageScaffold(
        //   navigationBar:
        //       CupertinoNavigationBar(
        //         middle: Text(
        //           'Today\'s Practice',
        //           style: TextStyle(color: theme.colorScheme.onSurface),
        //         ),
        //         backgroundColor: theme.colorScheme.surface,
        //         transitionBetweenRoutes: false,
        //       ),
        //  child: SafeArea(
        //     child: _buildBody(context, viewModel),
        //   ),
        // );
      },
    );
  }

Widget _buildBody(BuildContext context, TodayViewModel viewModel) {
  final theme = Theme.of(context);
  
  if (viewModel.isLoading) {
    return Center(
      child: CupertinoActivityIndicator(
        color: theme.colorScheme.primary,
      ),
    );
  }
  
  if (viewModel.todaysAreas.isEmpty) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'No practice areas scheduled for today.\nAdd areas to today\'s routine in the "Routines" tab.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        // Goal ring
        const ActiveSessionBanner(),
        buildGoalRing(context, viewModel),
        // Calendar stays at bottom
        PracticeCalendar(
          onStatsPressed: onStatsPressed,
        ),
      ],
    );
  }
  
  // Main change: Use Column instead of CustomScrollView
  return Column(
    children: [
      // Active session banner at top
      
      
      // Scrollable practice areas in the middle (takes remaining space)
      Expanded(
        child: CustomScrollView(
          slivers: [
            // Practice Areas header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Center(
                  child: ClayContainer(
                    borderRadius: 20,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(25, 5, 25, 5),
                     decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                            fit: BoxFit.cover,
                          ),
                        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      child: Text(
                        'Today\'s Practice',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Practice Areas list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final area = viewModel.todaysAreas[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PracticeAreaTile(area: area, viewModel: viewModel),
                  );
                },
                childCount: viewModel.todaysAreas.length,
              ),
            ),
            
            // Optional: Add some padding at the bottom of the scroll area
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
        ),
      ),
      const ActiveSessionBanner(),
      // Goal ring between calendar and practice areas
      buildGoalRing(context, viewModel),
      
      // Calendar fixed at bottom (above nav bar)
      PracticeCalendar(
        onStatsPressed: onStatsPressed,
      ),
      SizedBox(height: 100),
    ],
  );
}
}
