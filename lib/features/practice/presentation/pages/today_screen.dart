import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
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
        return CupertinoPageScaffold(
          navigationBar:
              CupertinoNavigationBar(
                middle: Text(
                  'Today\'s Practice',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                backgroundColor: theme.colorScheme.surface,
                transitionBetweenRoutes: false,
              ),
         child: SafeArea(
            child: _buildBody(context, viewModel),
          ),
        );
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
          const ActiveSessionBanner(),
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
          // Show calendar even when no practice areas
          PracticeCalendar(
            onStatsPressed: onStatsPressed,
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        // Active session banner
        const SliverToBoxAdapter(
          child: ActiveSessionBanner(),
        ),
        
        // Practice Areas header and list
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Today\'s Practice Areas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
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
        
        // Practice Calendar at the bottom
        SliverToBoxAdapter(
          child: PracticeCalendar(
            onStatsPressed: onStatsPressed,
          ),
        ),
      ],
    );
  }
}
