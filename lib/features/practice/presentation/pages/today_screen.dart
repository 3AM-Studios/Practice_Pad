import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
import 'package:practice_pad/features/practice/presentation/widgets/goal_ring.dart';
import 'package:practice_pad/services/device_type.dart';
import 'package:practice_pad/widgets/practice_area_tile.dart';
import 'package:practice_pad/widgets/active_session_banner.dart';
import 'package:practice_pad/widgets/practice_calendar.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/practice_session_manager.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/features/routines/presentation/viewmodels/routines_viewmodel.dart';
import 'package:practice_pad/services/widget/widget_integration.dart';
import 'package:practice_pad/services/storage/cloudkit_service.dart';
import 'package:practice_pad/services/storage/storage_service.dart';
import 'package:practice_pad/features/transcription/presentation/pages/youtube_videos_page.dart';
import 'package:practice_pad/onboarding.dart';
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
      },
    );
  }

Widget _buildTranscribeButton(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;

  final double iconSize = (screenWidth * 0.052).clamp(20.0, 28.0);
  final double fontSize = (screenWidth * 0.038).clamp(16.0, 22.0);

  return Container(
    padding: EdgeInsets.symmetric(horizontal: screenWidth - (screenWidth * 0.75)),
    child: GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const YouTubeVideosPage(),
          ),
        );
      },
      child: ClayContainer(
        color: Theme.of(context).colorScheme.surface,
        depth: 15,
        borderRadius: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hearing,
                color: Theme.of(context).colorScheme.primary,
                size: iconSize,
              ),
              const SizedBox(width: 12),
              Text(
                'Transcribe',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
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
        const SizedBox(height: 10),
        _buildFixedHeader(context),
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
        _buildTranscribeButton(context),
        const SizedBox(height: 16),
        _buildBottomSection(context, viewModel, widget.onStatsPressed, isTabletOrDesktop),
        SizedBox(height: isTabletOrDesktop? 120 : 0),
      ],
    );
  }
  
  return Column(
    children: [
      const SizedBox(height: 10),
      _buildFixedHeader(context),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
          itemCount: viewModel.todaysAreas.length,
          itemBuilder: (context, index) {
            final area = viewModel.todaysAreas[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PracticeAreaTile(area: area, viewModel: viewModel),
            );
          },
        ),
      ),
      _buildTranscribeButton(context),
      const SizedBox(height: 16),
      _buildBottomSection(context, viewModel, widget.onStatsPressed, isTabletOrDesktop),
       SizedBox(height: isTabletOrDesktop? 120 : 0),
    ],
  );
}

Widget _buildFixedHeader(BuildContext context) {
  final isIPhone = Platform.isIOS && deviceType == DeviceType.phone;
  
  if (isIPhone) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 25, 16, 8),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildTutorialButton(context),
                ),
              ),
              Expanded(
                child: Center(
                  child: ClayContainer(
                    borderRadius: 10,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(13.0, 5, 13.0, 5),
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
                          fontSize: 14.0,
                          fontWeight: FontWeight.w700,
                          color: Colors.white
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildSyncButtons(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  } else {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8.0, 16, 8),
      child: Row(
        children: [
          _buildTutorialButton(context),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: ClayContainer(
                borderRadius: 10,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(35.0, 5, 35.0, 5),
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
                      fontSize: 20.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildSyncButtons(context),
        ],
      ),
    );
  }
}

Widget _buildSyncButtons(BuildContext context) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _buildSyncButton(
        context: context,
        icon: CupertinoIcons.cloud_download,
        color: CupertinoColors.systemBlue,
        onTap: () => _syncWithCloudKit(context),
        onLongPress: () => _showDebugInfo(context),
      ),
      const SizedBox(width: 8),
      _buildSyncButton(
        context: context,
        icon: CupertinoIcons.cloud_upload,
        color: CupertinoColors.systemGreen,
        onTap: () => _syncWithCloudKit(context),
        onLongPress: () => _showDebugInfo(context),
      ),
    ],
  );
}

Widget _buildTutorialButton(BuildContext context) {
  return _buildSyncButton(
    context: context,
    icon: CupertinoIcons.question_circle,
    color: Theme.of(context).colorScheme.primary,
    onTap: () => _showTutorial(context),
  );
}

void _showTutorial(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => OnboardingScreen(
        onComplete: () => Navigator.pop(context),
      ),
    ),
  );
}

Widget _buildSyncButton({
  required BuildContext context,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
  VoidCallback? onLongPress,
}) {
  return GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    child: ClayContainer(
      borderRadius: 8,
      depth: 8,
      spread: 2,
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
    ),
  );
}
  Future<void> _reloadAllViewModelsAfterSync(BuildContext context) async {
    developer.log('🔄 Reloading all ViewModels after CloudKit sync');
    
    try {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const CupertinoAlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(),
                SizedBox(height: 16),
                Text('Reloading data...\nYour synced data will appear shortly.'),
              ],
            ),
          ),
        );
      }
      
      if (context.mounted) {
        try {
          final editItemsViewModel = Provider.of<EditItemsViewModel>(context, listen: false);
          final routinesViewModel = Provider.of<RoutinesViewModel>(context, listen: false);
          final todayViewModel = Provider.of<TodayViewModel>(context, listen: false);
          
          await editItemsViewModel.reloadFromStorage();
          await routinesViewModel.reloadFromStorage();
          await todayViewModel.reloadFromStorage();
          
        } catch (providerError) {
          developer.log('❌ Error getting ViewModels from Provider: $providerError');
          rethrow;
        }
      }
      
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      developer.log('❌ Error reloading ViewModels after sync: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Data Synced'),
            content: const Text('CloudKit sync completed. The interface will refresh automatically.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

Future<void> _syncWithCloudKit(BuildContext context) async {
  final isAvailable = await CloudKitService.isAccountAvailable();
  if (!isAvailable) {
    if (context.mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('CloudKit Not Available'),
          content: const Text('Please ensure you are signed into iCloud and CloudKit is enabled for this app.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
    return;
  }

  if (context.mounted) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(height: 16),
            Text('Syncing with CloudKit...\nThis may take a few moments.'),
          ],
        ),
      ),
    );
  }

  try {
    await CloudKitService.handleNotification();
    
    if (context.mounted) {
      Navigator.of(context).pop();
      await _reloadAllViewModelsAfterSync(context);
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: const Text('CloudKit sync completed. Data has been refreshed.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  } catch (e) {
    developer.log('❌ CloudKit sync failed: $e');
    if (context.mounted) {
      Navigator.of(context).pop();
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Failed to sync with CloudKit: $e'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }
}

Future<void> _showDebugInfo(BuildContext context) async {
  try {
    final diagnostics = <String, dynamic>{
      'CloudKit Account Available': await CloudKitService.isAccountAvailable(),
      'Last Sync Time': 'Not implemented yet',
      'Sync Status': 'Ready',
    };
    
    if (context.mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('CloudKit Debug Info'),
          content: SingleChildScrollView(
            child: Text(
              diagnostics.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n'),
              style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Debug Error'),
          content: Text('Failed to get debug info: $e'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }
}


Widget _buildBottomSection(BuildContext context, TodayViewModel viewModel, VoidCallback? onStatsPressed, bool isTabletOrDesktop) {
  final bottomAreaHeight = (isTabletOrDesktop ?350.0: 510.0);
  
  return SizedBox(
    height: bottomAreaHeight,
    child: isTabletOrDesktop 
      ? Row(
          children: [
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ActiveSessionBanner(isTabletOrDesktop: true),
                  buildGoalRing(context, viewModel, isLarge: true),
                ],
              ),
            ),
            PracticeCalendar(
                calendarSize: CalendarSize.medium,
                onStatsPressed: onStatsPressed,
              ),
          ],
        )
      : Column(
          children: [
            
            Expanded(
              flex: 0,
              child: buildGoalRing(context, viewModel, isLarge: false),
            ),
            const Expanded(flex: 0, child: ActiveSessionBanner(isTabletOrDesktop: false)),
            PracticeCalendar(
                calendarSize: CalendarSize.small,
                onStatsPressed: onStatsPressed,
              ),
            
          ],
        ),
  );
}
}
