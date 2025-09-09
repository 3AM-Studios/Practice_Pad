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

Widget _buildTranscribeButton(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;

  final double iconSize = (screenWidth * 0.052).clamp(20.0, 28.0);
  final double fontSize = (screenWidth * 0.038).clamp(16.0, 22.0);

  return Container(
    // This container creates the responsive padding on the sides
    padding: EdgeInsets.symmetric(horizontal: screenWidth - (screenWidth * 0.75)),
    child: GestureDetector( // Remove the Center widget from here
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
            // Change MainAxisSize.min to MainAxisAlignment.center
            // This makes the Row expand to fill the width and centers its children.
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
        // Fixed header with Today's Practice banner and sync buttons (also shown in empty state)
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
        // Transcribe button  
        _buildTranscribeButton(context),
        const SizedBox(height: 16),
        _buildBottomSection(context, viewModel, widget.onStatsPressed, isTabletOrDesktop),
        SizedBox(height: isTabletOrDesktop? 120 : 0),
      ],
    );
  }
  
  // Main change: Use Column with fixed header and scrollable content
  return Column(
    children: [
      const SizedBox(height: 10),
      // Fixed header with Today's Practice banner and sync buttons
      _buildFixedHeader(context),
      // Scrollable practice areas in the middle (takes remaining space)
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
      // Transcribe button
      _buildTranscribeButton(context),
      const SizedBox(height: 16),
      // Responsive bottom section
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
        const SizedBox(height: 16), // Top spacing
        // Combined row with tutorial button, banner, and sync buttons on same level
        Container(
          padding: const EdgeInsets.fromLTRB(16, 25, 16, 8),
          child: Row(
            children: [
              // Tutorial button on the left - fixed width for symmetry
              SizedBox(
                width: 80, // Fixed width to balance with sync buttons
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildTutorialButton(context),
                ),
              ),
              // Expanded banner in the center
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
              // Sync buttons on the right - fixed width for symmetry
              SizedBox(
                width: 80, // Fixed width to balance with tutorial button
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
    // Non-iPhone layout
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8.0, 16, 8),
      child: Row(
        children: [
          // Tutorial button at the start of the row
          _buildTutorialButton(context),
          const SizedBox(width: 16),
          // Expanded banner that takes up available space and centers content
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
          // Sync buttons positioned at the end of the row
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
      // Download from iCloud button
      _buildSyncButton(
        context: context,
        icon: CupertinoIcons.cloud_download,
        color: CupertinoColors.systemBlue,
        onTap: () => _downloadFromCloudKit(context),
        onLongPress: () => _showDebugInfo(context),
      ),
      const SizedBox(width: 8),
      // Upload to iCloud button
      _buildSyncButton(
        context: context,
        icon: CupertinoIcons.cloud_upload,
        color: CupertinoColors.systemGreen,
        onTap: () => _uploadToCloudKit(context),
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
      // Show loading dialog while reloading
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
      
      // Get ViewModels from Provider with error handling
      if (context.mounted) {
        try {
          final editItemsViewModel = Provider.of<EditItemsViewModel>(context, listen: false);
          final routinesViewModel = Provider.of<RoutinesViewModel>(context, listen: false);
          final todayViewModel = Provider.of<TodayViewModel>(context, listen: false);
          
          // Reload EditItemsViewModel first (other ViewModels depend on it)
          try {
            await editItemsViewModel.reloadFromStorage();
            developer.log('✅ EditItemsViewModel reloaded successfully');
          } catch (editError) {
            developer.log('⚠️ EditItemsViewModel reload failed: $editError');
          }
          
          // Reload RoutinesViewModel second
          try {
            await routinesViewModel.reloadFromStorage();
            developer.log('✅ RoutinesViewModel reloaded successfully');
          } catch (routinesError) {
            developer.log('⚠️ RoutinesViewModel reload failed: $routinesError');
          }
          
          // Special handling for TodayViewModel since it's prone to disposal
          try {
            await todayViewModel.reloadFromStorage();
            developer.log('✅ TodayViewModel reloaded successfully');
          } catch (todayError) {
            developer.log('⚠️ TodayViewModel reload failed (likely disposed): $todayError');
            // Continue anyway - the UI will refresh when the widget rebuilds
          }
          
          developer.log('✅ ViewModels reload completed after CloudKit sync');
        } catch (providerError) {
          developer.log('❌ Error getting ViewModels from Provider: $providerError');
          rethrow;
        }
      }
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      developer.log('❌ Error reloading ViewModels after sync: $e');
      developer.log('❌ Stack trace: ${StackTrace.current}');
      
      // Close loading dialog if it's still open
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show less alarming error message since data is downloaded
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Data Downloaded'),
            content: const Text('CloudKit sync completed successfully. The interface will refresh automatically. If changes don\'t appear, try navigating to another tab and back.'),
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

Future<void> _downloadFromCloudKit(BuildContext context) async {
  // Check CloudKit availability
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
            Text('Downloading from CloudKit...\nThis may take a few moments.'),
          ],
        ),
      ),
    );
  }

  try {
    developer.log('📥 Starting CloudKit download sync...');
    
    // Perform full CloudKit sync to get latest data
    await CloudKitService.handleNotification();
    
    if (context.mounted) {
      Navigator.of(context).pop();
      
      // Always reload ViewModels after sync attempt
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
    developer.log('❌ CloudKit download failed: $e');
    if (context.mounted) {
      Navigator.of(context).pop();
      
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Failed to download from CloudKit: $e'),
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

Future<void> _uploadToCloudKit(BuildContext context) async {
  // Check CloudKit availability
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
            Text('Uploading to CloudKit...\nThis may take a few moments.'),
          ],
        ),
      ),
    );
  }

  try {
    developer.log('📤 ===== CLOUDKIT SYNC STARTED =====');
    developer.log('📤 Upload started at: ${DateTime.now().toIso8601String()}');
    
    if (context.mounted) {
      // Get current app data for upload
      final editItemsViewModel = Provider.of<EditItemsViewModel>(context, listen: false);
      final routinesViewModel = Provider.of<RoutinesViewModel>(context, listen: false);
      
      developer.log('📤 Found ${editItemsViewModel.areas.length} practice areas to upload');
      
      // Upload practice areas to CloudKit using the public method
      await StorageService.savePracticeAreas(editItemsViewModel.areas);
      developer.log('📤 Practice areas uploaded to CloudKit');
      
      // Upload routines to CloudKit - convert to schedule format and sync
      final weeklySchedule = <String, List<String>>{};
      routinesViewModel.routines.forEach((dayOfWeek, routinesList) {
        weeklySchedule[dayOfWeek.toString()] = routinesList.map((routine) => routine.recordName).toList();
        developer.log('📤 Prepared ${routinesList.length} routines for ${dayOfWeek.toString()}');
      });
      
      developer.log('📤 Found weekly schedule with ${weeklySchedule.length} days');
      
      // Actually upload the weekly schedule to CloudKit
      await StorageService.saveWeeklySchedule(weeklySchedule);
      developer.log('📤 Weekly schedule uploaded to CloudKit');
      
      // Get books and check for PDF upload needs
      final books = await StorageService.loadBooks();
      final customSongs = await StorageService.loadCustomSongs();
      
      developer.log('📤 ⚠️ IMPORTANT: PDF FILES NOT UPLOADED!');
      developer.log('📤 Found ${books.length} books in local storage');
      developer.log('📤 Found ${customSongs.length} custom songs in local storage');
      developer.log('📤 Current upload only syncs practice metadata, NOT PDF files');
      developer.log('📤 To upload PDFs, use StorageService.savePDFWithAsset() method');
      
      developer.log('✅ CLOUDKIT METADATA SYNC COMPLETED');
      developer.log('📤 ===== CLOUDKIT SYNC FINISHED =====');
    }

    if (context.mounted) {
      Navigator.of(context).pop();
      
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Success'),
          content: const Text('Successfully uploaded practice schedules to CloudKit.\n\nNote: PDF books and songs are not uploaded yet. Only practice metadata is synced.'),
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
    developer.log('❌ CloudKit upload failed: $e');
    if (context.mounted) {
      Navigator.of(context).pop();
      
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Failed to upload to CloudKit: $e'),
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
  // Calculate bottom area height based on device type
  final bottomAreaHeight = (isTabletOrDesktop ?350.0: 510.0); // Reduced from ~30% to ~23% (25% reduction)
  
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
                  const ActiveSessionBanner(isTabletOrDesktop: true),
                  buildGoalRing(context, viewModel, isLarge: true), // Large goal ring for tablets/desktop, small on iOS
                ],
              ),
            ),
            // Right side: Calendar
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
              child: buildGoalRing(context, viewModel, isLarge: false), // Small size for phones
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
