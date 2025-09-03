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
import 'package:practice_pad/services/icloud_sync_service.dart';
import 'package:practice_pad/services/local_storage_service.dart';
import 'package:practice_pad/features/transcription/presentation/pages/youtube_videos_page.dart';
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

  Widget _buildTranscribeButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hearing,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Transcribe',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
        SizedBox(height: MediaQuery.of(context).size.height * 0.003), //30% of overall height
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
      const SizedBox(height: 30),
    ],
  );
}

Widget _buildFixedHeader(BuildContext context) {
  final isIPhone = Platform.isIOS && deviceType == DeviceType.phone;
  
  if (isIPhone) {
    return Column(
      children: [
        // Top section with sync buttons
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: _buildSyncButtons(context),
              ),
            ],
          ),
        ),
        // Banner section with top padding
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), // 60 - 8 = 52 to match original positioning
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
      ],
    );
  } else {
    // Non-iPhone layout
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8.0, 16, 8),
      child: Row(
        children: [
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
        onTap: () => _downloadFromICloud(context),
        onLongPress: () => _showDebugInfo(context),
      ),
      const SizedBox(width: 8),
      // Upload to iCloud button
      _buildSyncButton(
        context: context,
        icon: CupertinoIcons.cloud_upload,
        color: CupertinoColors.systemGreen,
        onTap: () => _uploadToICloud(context),
        onLongPress: () => _showDebugInfo(context),
      ),
    ],
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

Future<void> _downloadFromICloud(BuildContext context) async {
  // First check iCloud availability
  final icloudService = ICloudSyncService();
  final isAvailable = await icloudService.isICloudAvailable();
  
  if (!isAvailable) {
    if (context.mounted) {
      // Check if we're on simulator to provide specific messaging
      final accountStatus = await icloudService.getAccountStatus();
      final isSimulator = Platform.isIOS;
      
      String title = 'iCloud Not Available';
      String message = 'Please ensure you are signed into iCloud and have enabled iCloud Documents for this app.';
      
      if (isSimulator) {
        title = 'Development/Testing Mode';
        message = 'iCloud Documents sync limitations detected:\n\n'
                 '• iOS Simulator has limited iCloud functionality\n'
                 '• App uses example bundle ID (com.example.*)\n'
                 '• Example bundle IDs don\'t have proper iCloud entitlements\n\n'
                 'For full iCloud sync functionality:\n'
                 '• Use a proper bundle ID (not com.example.*)\n'
                 '• Configure iCloud capabilities in Apple Developer Portal\n'
                 '• Test on physical iOS devices\n\n'
                 'Current account status: $accountStatus';
      } else if (accountStatus == 'notAvailable') {
        message = 'iCloud account not detected.\n\n'
                 'Please:\n'
                 '• Sign into iCloud in Settings\n'
                 '• Enable iCloud Documents\n'
                 '• Restart the app if needed\n\n'
                 'Note: This app uses an example bundle ID which may not have proper iCloud entitlements configured.';
      }
      
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
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
            Text('Downloading from iCloud...\nThis may take a few moments.'),
          ],
        ),
      ),
    );
  }

  try {
    // Download specific practice-related files
    final filesToDownload = [
      'custom_songs.json',
      'practice_sessions.json',
      'practice_areas.json',
      'practice_items.json',
      'weekly_schedule.json',
      'song_changes.json',
      'chord_keys.json',
    ];
    
    int successCount = 0;
    List<String> failedFiles = [];
    
    for (final fileName in filesToDownload) {
      try {
        final result = await icloudService.downloadFile(fileName);
        if (result.success) {
          successCount++;
        } else {
          failedFiles.add('$fileName: ${result.error ?? "Unknown error"}');
        }
      } catch (e) {
        failedFiles.add('$fileName: $e');
      }
    }

    if (context.mounted) {
      Navigator.of(context).pop();
      
      if (failedFiles.isEmpty) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: Text('Successfully downloaded $successCount files from iCloud.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      } else {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Partial Success'),
            content: Text('Downloaded $successCount/${filesToDownload.length} files.\n\nFailed files:\n${failedFiles.join('\n')}'),
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
    if (context.mounted) {
      Navigator.of(context).pop();
      
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Failed to download from iCloud: $e'),
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

Future<void> _uploadToICloud(BuildContext context) async {
  // First check iCloud availability
  final icloudService = ICloudSyncService();
  final isAvailable = await icloudService.isICloudAvailable();
  
  if (!isAvailable) {
    if (context.mounted) {
      // Check if we're on simulator to provide specific messaging
      final accountStatus = await icloudService.getAccountStatus();
      final isSimulator = Platform.isIOS;
      
      String title = 'iCloud Not Available';
      String message = 'Please ensure you are signed into iCloud and have enabled iCloud Documents for this app.';
      
      if (isSimulator) {
        title = 'Development/Testing Mode';
        message = 'iCloud Documents sync limitations detected:\n\n'
                 '• iOS Simulator has limited iCloud functionality\n'
                 '• App uses example bundle ID (com.example.*)\n'
                 '• Example bundle IDs don\'t have proper iCloud entitlements\n\n'
                 'For full iCloud sync functionality:\n'
                 '• Use a proper bundle ID (not com.example.*)\n'
                 '• Configure iCloud capabilities in Apple Developer Portal\n'
                 '• Test on physical iOS devices\n\n'
                 'Current account status: $accountStatus';
      } else if (accountStatus == 'notAvailable') {
        message = 'iCloud account not detected.\n\n'
                 'Please:\n'
                 '• Sign into iCloud in Settings\n'
                 '• Enable iCloud Documents\n'
                 '• Restart the app if needed\n\n'
                 'Note: This app uses an example bundle ID which may not have proper iCloud entitlements configured.';
      }
      
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
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
            Text('Uploading to iCloud...\nThis may take a few moments.'),
          ],
        ),
      ),
    );
  }

  try {
    final result = await LocalStorageService.syncAllToICloud();

    if (context.mounted) {
      Navigator.of(context).pop();
      
      if (result.success) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: const Text('Successfully uploaded all practice data to iCloud.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      } else if (result.conflicts.isNotEmpty) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Conflicts Detected'),
            content: Text('Some files have conflicts that need to be resolved:\n${result.conflicts.map((c) => c.fileName).join(', ')}'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      } else {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Upload failed: ${result.error ?? "Unknown error"}'),
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
    if (context.mounted) {
      Navigator.of(context).pop();
      
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Failed to upload to iCloud: $e'),
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
    final icloudService = ICloudSyncService();
    final diagnostics = await icloudService.getDiagnosticInfo();
    
    if (context.mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('iCloud Debug Info'),
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
                  const ActiveSessionBanner(isTabletOrDesktop: true),
                  buildGoalRing(context, viewModel, isLarge: true), // Large goal ring for tablets/desktop, small on iOS
                ],
              ),
            ),
            // Right side: Calendar
            Expanded(
              flex: 1,
              child: PracticeCalendar(
                onStatsPressed: onStatsPressed,
                calendarSize: CalendarSize.medium, // Use medium size for better visibility
              ),
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
            Expanded(
              flex:1,
              child: PracticeCalendar(
                calendarSize: CalendarSize.small,
                onStatsPressed: onStatsPressed,
              ),
            ),
          ],
        ),
  );
}
}
