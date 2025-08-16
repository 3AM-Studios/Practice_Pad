import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
import 'package:practice_pad/features/practice/presentation/widgets/goal_ring.dart';
import 'package:practice_pad/services/device_type.dart';
import 'package:practice_pad/widgets/practice_area_tile.dart';
import 'package:practice_pad/widgets/active_session_banner.dart';
import 'package:practice_pad/widgets/practice_calendar.dart';
import 'package:practice_pad/services/practice_session_manager.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/services/widget_integration.dart';
import 'package:provider/provider.dart';

class TodayScreen extends StatefulWidget {
  final VoidCallback? onStatsPressed;

  const TodayScreen({super.key, this.onStatsPressed});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _widgetIntegrationSetup = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer3<TodayViewModel, PracticeSessionManager, EditItemsViewModel>(
      builder: (context, todayViewModel, sessionManager, editItemsViewModel, child) {
        // Set up widget integration once all providers are available
        if (Platform.isIOS && !_widgetIntegrationSetup) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetIntegration.setupWidgetCallbacks(
              todayViewModel: todayViewModel,
              sessionManager: sessionManager,
              editItemsViewModel: editItemsViewModel,
            );
            
            // Sync session state from widget when app starts/becomes active
            WidgetIntegration.syncSessionStateFromWidget(
              sessionManager: sessionManager,
            );
            
            _widgetIntegrationSetup = true;
          });
        }

        return _buildBody(context, todayViewModel);
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
  final isTabletOrDesktop = deviceType == DeviceType.tablet || deviceType == DeviceType.macOS;

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
        _buildBottomSection(context, viewModel, widget.onStatsPressed, isTabletOrDesktop),
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
                    borderRadius: 10,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(35, 5, 35, 5),
                     decoration: BoxDecoration(
                          image: const DecorationImage(
                            image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                            fit: BoxFit.cover,
                          ),
                        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      child: const Text(
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
      // Responsive bottom section
      _buildBottomSection(context, viewModel, widget.onStatsPressed, isTabletOrDesktop),
      const SizedBox(height: 100),
    ],
  );
}

Widget _buildBottomSection(BuildContext context, TodayViewModel viewModel, VoidCallback? onStatsPressed, bool isTabletOrDesktop) {
  // Get screen height and calculate 25% shorter bottom area
  final screenHeight = MediaQuery.of(context).size.height;
  final bottomAreaHeight = screenHeight * 0.54; // Reduced from ~30% to ~23% (25% reduction)
  
  return SizedBox(
    height: bottomAreaHeight,
    child: isTabletOrDesktop 
      ? Row(
          children: [
            // Left side: Goal ring and Active session banner (centered)
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ActiveSessionBanner(),
                  buildGoalRing(context, viewModel, isLarge: true), // Large goal ring for tablets/desktop
                ],
              ),
            ),
            // Right side: Calendar
            Expanded(
              flex: 1,
              child: PracticeCalendar(
                onStatsPressed: onStatsPressed,
                calendarSize: CalendarSize.small, // Use medium size for better visibility
              ),
            ),
          ],
        )
      : Column(
          children: [
            const Expanded(child: ActiveSessionBanner()),
            Expanded(
              flex: 2,
              child: buildGoalRing(context, viewModel), // Regular size for phones
            ),
            Expanded(
              flex: 3,
              child: PracticeCalendar(
                onStatsPressed: onStatsPressed,
              ),
            ),
          ],
        ),
  );
}
}
