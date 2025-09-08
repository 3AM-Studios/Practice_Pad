import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;
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
import 'package:practice_pad/features/practice/presentation/viewmodels/practice_session_manager.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/features/routines/presentation/viewmodels/routines_viewmodel.dart';
import 'package:practice_pad/services/widget/widget_integration.dart';
import 'package:practice_pad/services/icloud_sync_service.dart';
import 'package:practice_pad/services/storage/local_storage_service.dart';
import 'package:practice_pad/features/transcription/presentation/pages/youtube_videos_page.dart';
import 'package:practice_pad/onboarding.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

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
    developer.log('🔄 Reloading all ViewModels after iCloud sync');
    
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
      
      // Get ViewModels from Provider
      if (context.mounted) {
        final editItemsViewModel = Provider.of<EditItemsViewModel>(context, listen: false);
        final routinesViewModel = Provider.of<RoutinesViewModel>(context, listen: false);
        final todayViewModel = Provider.of<TodayViewModel>(context, listen: false);
        
        // Reload in proper order: EditItems -> Routines -> Today
        // EditItemsViewModel needs to load first since others depend on it
        await editItemsViewModel.reloadFromStorage();
        
        // RoutinesViewModel depends on EditItemsViewModel data
        await routinesViewModel.reloadFromStorage();
        
        // TodayViewModel depends on both
        await todayViewModel.reloadFromStorage();
        
        developer.log('✅ All ViewModels reloaded successfully after iCloud sync');
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
        
        // Show error message with specific error details
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Reload Failed'),
            content: Text('Data downloaded successfully but failed to reload the interface.\n\nError: $e\n\nPlease restart the app to see your synced data.'),
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

Future<void> _downloadFromICloud(BuildContext context) async {
  // First check iCloud availability
  final icloudService = ICloudSyncService();
  
  // Migrate to organized structure first (if needed)
  try {
    await ICloudSyncService.migrateToOrganizedStructure();
  } catch (e) {
    developer.log('⚠️ Migration failed but continuing: $e');
  }
  
  // DEBUG: Show container analysis IMMEDIATELY
  print("🔍 [DEBUG] Starting container analysis...");
  try {
    await icloudService.listICloudFiles();
  } catch (e) {
    print("❌ [DEBUG] Container analysis failed: $e");
  }
  
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
    // Get all available files in iCloud
    final availableFiles = await icloudService.listICloudFiles();
    
    // Download ALL files from iCloud - let the service handle timestamp comparison
    final filesToDownload = availableFiles.toList();
    
    developer.log('📥 [DOWNLOAD] Checking ${filesToDownload.length} files for sync: $filesToDownload');
    
    int successCount = 0;
    List<String> failedFiles = [];
    List<String> actualFilesToDownload = [];
    
    if (filesToDownload.isEmpty) {
      developer.log('ℹ️ No files found in iCloud to download');
    }
    
    // First pass: check which files actually need downloading (newer than local)
    for (final fileName in filesToDownload) {
      try {
        final fileInfo = await icloudService.getICloudFileInfo(fileName);
        final localDir = await getApplicationDocumentsDirectory();
        final localFile = File('${localDir.path}/$fileName');
        
        if (!await localFile.exists()) {
          // Local file doesn't exist, download it
          actualFilesToDownload.add(fileName);
          developer.log('📥 [DOWNLOAD] Local file missing, will download: $fileName');
        } else {
          // Compare timestamps if available
          if (fileInfo['lastModified'] != null) {
            final localTimestamp = await localFile.lastModified();
            final remoteTimestamp = DateTime.parse(fileInfo['lastModified']);
            
            if (remoteTimestamp.isAfter(localTimestamp)) {
              actualFilesToDownload.add(fileName);
              developer.log('📥 [DOWNLOAD] Remote newer, will download: $fileName (remote: $remoteTimestamp, local: $localTimestamp)');
            } else {
              developer.log('📥 [DOWNLOAD] Local up-to-date, skipping: $fileName');
            }
          } else {
            // No timestamp info available, download anyway to be safe
            actualFilesToDownload.add(fileName);
            developer.log('📥 [DOWNLOAD] No timestamp info, will download: $fileName');
          }
        }
      } catch (e) {
        // If we can't get file info, try downloading anyway
        actualFilesToDownload.add(fileName);
        developer.log('📥 [DOWNLOAD] Error checking file info, will download: $fileName - $e');
      }
    }
    
    developer.log('📥 [DOWNLOAD] Will download ${actualFilesToDownload.length} files that need updating');
    
    // Second pass: actually download the files that need updating
    for (final fileName in actualFilesToDownload) {
      try {
        final result = await icloudService.downloadFile(fileName);
        
        if (result.success) {
          successCount++;
          
          // Show what was actually downloaded for practice_areas.json only
          if (fileName == 'practice_areas.json') {
            try {
              final localDir = await getApplicationDocumentsDirectory();
              final file = File('${localDir.path}/$fileName');
              if (await file.exists()) {
                final content = await file.readAsString();
                developer.log('📥 [DOWNLOAD] practice_areas.json content: $content');
              }
            } catch (e) {
              developer.log('❌ Could not read downloaded practice_areas.json: $e');
            }
          }
        } else {
          final error = result.error ?? "Unknown error";
          failedFiles.add('$fileName: $error');
        }
      } catch (e) {
        failedFiles.add('$fileName: $e');
      }
    }

    if (context.mounted) {
      Navigator.of(context).pop();
      
      if (failedFiles.isEmpty) {
        final message = actualFilesToDownload.isEmpty
            ? 'All files are up to date. No downloads needed.'
            : 'Successfully downloaded $successCount files from iCloud.';
        
        // If files were successfully downloaded, reload all ViewModels
        if (successCount > 0) {
          await _reloadAllViewModelsAfterSync(context);
        }
        
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: Text(message),
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
            content: Text('Downloaded $successCount/${actualFilesToDownload.length} files.\n\nFailed files:\n${failedFiles.join('\n')}'),
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
  
  // Migrate to organized structure first (if needed)
  try {
    await ICloudSyncService.migrateToOrganizedStructure();
  } catch (e) {
    developer.log('⚠️ Migration failed but continuing: $e');
  }
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
    // Create complete organized folder structure before upload
    developer.log('📤 [UPLOAD] Creating organized folder structure for upload');
    
    if (context.mounted) {
      final editItemsViewModel = Provider.of<EditItemsViewModel>(context, listen: false);
      final routinesViewModel = Provider.of<RoutinesViewModel>(context, listen: false);
      final todayViewModel = Provider.of<TodayViewModel>(context, listen: false);
      
      // Create organized structure based on current app data
      await _createOrganizedStructureForUpload(editItemsViewModel, routinesViewModel);
      
      developer.log('📤 [UPLOAD] Organized structure created successfully');
    }
    
    // DEBUG: Show what data is being uploaded
    developer.log('📤 [UPLOAD] Starting upload to iCloud');
    final localDir = await getApplicationDocumentsDirectory();
    final practiceAreasFile = File('${localDir.path}/practice_areas.json');
    if (await practiceAreasFile.exists()) {
      final content = await practiceAreasFile.readAsString();
      developer.log('📤 [UPLOAD] practice_areas.json content: $content');
    }
    
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
    developer.log('❌ [UPLOAD DEBUG] Upload exception: $e');
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

  /// Reload all ViewModels after successful iCloud sync
}

/// Create organized folder structure for upload
Future<void> _createOrganizedStructureForUpload(
  EditItemsViewModel editItemsViewModel, 
  RoutinesViewModel routinesViewModel,
) async {
  try {
    final localDir = await getApplicationDocumentsDirectory();
    
    // 1. Create config files
    developer.log('📤 Creating config files...');
    await LocalStorageService.saveCustomSongs([]);  
    await LocalStorageService.saveBooks([]);        
    await LocalStorageService.saveYoutubeVideosList([]);
    
    // 2. Create main practice areas structure  
    developer.log('📤 Creating practice areas structure...');
    await LocalStorageService.savePracticeAreas(editItemsViewModel.areas);
    
    // 3. Create individual practice area folders with their data
    for (final area in editItemsViewModel.areas) {
      developer.log('📤 Creating folder for practice area: ${area.name}');
      
      // Create practice area JSON file
      final areaData = {
        'recordName': area.recordName,
        'name': area.name,
        'type': area.type.toString(),
        'song': area.song?.toJson(),  // Convert song to JSON if it exists
        'itemCount': area.practiceItems.length,
      };
      
      // Save individual practice area file
      final areaFileName = 'practice_areas_${area.recordName}_area.json';
      final areaFile = File('${localDir.path}/$areaFileName');
      await areaFile.writeAsString(json.encode(areaData));
      
      // Create practice items for this area
      if (area.practiceItems.isNotEmpty) {
        for (int i = 0; i < area.practiceItems.length; i++) {
          final item = area.practiceItems[i];
          final itemData = {
            'id': item.id,
            'name': item.name,
            'description': item.description,
            'chordProgression': item.chordProgression?.toJson(),  // Convert chord progression if it exists
            'keysPracticed': item.keysPracticed,
          };
          
          final itemFileName = 'practice_areas_${area.recordName}_item_${i + 1}.json';
          final itemFile = File('${localDir.path}/$itemFileName');
          await itemFile.writeAsString(json.encode(itemData));
        }
      }
    }
    
    // 4. Create songs structure (if any songs exist)
    developer.log('📤 Creating songs structure...');
    // For now, create empty structure - can be enhanced later with actual song data
    final songsData = {
      'songs': [],
      'drawings': {},
      'sheet_music': {},
    };
    final songsFile = File('${localDir.path}/songs_structure.json');
    await songsFile.writeAsString(json.encode(songsData));
    
    developer.log('📤 Organized structure creation completed');
  } catch (e) {
    developer.log('❌ Error creating organized structure: $e');
    rethrow;
  }
}

Widget _buildBottomSection(BuildContext context, TodayViewModel viewModel, VoidCallback? onStatsPressed, bool isTabletOrDesktop) {
  // Get screen height and calculate 25% shorter bottom area
  final screenHeight = MediaQuery.of(context).size.height;
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
