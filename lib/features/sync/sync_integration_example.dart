// Example integration of iCloud sync functionality
// This file demonstrates how to integrate iCloud sync into your app

import 'package:flutter/material.dart';
import 'package:practice_pad/services/local_storage_service.dart';
import 'package:practice_pad/features/sync/presentation/screens/sync_settings_screen.dart';
import 'package:practice_pad/features/sync/presentation/widgets/sync_status_indicator.dart';

/// Example: Initialize iCloud sync in your app's main function or startup
/// Call this early in your app lifecycle, ideally in main() or during splash screen
Future<void> initializeAppWithSync() async {
  // Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize iCloud sync service
  try {
    await LocalStorageService.initializeICloudSync();
    print('✅ iCloud sync initialized successfully');
  } catch (e) {
    print('⚠️ iCloud sync initialization failed: $e');
    // App will continue to work without sync
  }
  
  // Continue with your app initialization
  // runApp(MyApp());
}

/// Example: Adding sync settings to your app's settings page
class ExampleSettingsPage extends StatelessWidget {
  const ExampleSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Your existing settings tiles...
          
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('iCloud Sync'),
            subtitle: const Text('Sync your data across devices'),
            trailing: const SyncStatusIndicator(),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SyncSettingsScreen(),
                ),
              );
            },
          ),
          
          // More settings tiles...
        ],
      ),
    );
  }
}

/// Example: Adding sync status to your app bar
class ExampleAppBarWithSync extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  
  const ExampleAppBarWithSync({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        // Your existing actions...
        
        // Add sync status indicator
        const SyncStatusIndicator(showLabel: false),
        
        // Settings button that includes sync settings
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ExampleSettingsPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Example: Manual sync trigger (for testing or user-initiated sync)
class ExampleManualSyncButton extends StatefulWidget {
  const ExampleManualSyncButton({super.key});

  @override
  State<ExampleManualSyncButton> createState() => _ExampleManualSyncButtonState();
}

class _ExampleManualSyncButtonState extends State<ExampleManualSyncButton> {
  bool _isSyncing = false;

  Future<void> _triggerSync() async {
    if (!LocalStorageService.isICloudSyncEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('iCloud sync is not enabled'),
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await LocalStorageService.syncAllToICloud();
      
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Sync completed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (result.conflicts.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Found ${result.conflicts.length} conflicts'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Resolve',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SyncSettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          );
        }
      } else if (result.error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Sync failed: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isSyncing ? null : _triggerSync,
      icon: _isSyncing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
      label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
    );
  }
}

/// Example: Automatic sync on data changes
/// This demonstrates how sync happens automatically when data is saved
class ExampleDataOperations {
  
  /// Example: Adding a practice area with automatic sync
  static Future<void> addPracticeAreaWithSync(String name) async {
    try {
      // Load existing areas
      final areas = await LocalStorageService.loadPracticeAreas();
      
      // Add new area (your PracticeArea creation logic here)
      // areas.add(newArea);
      
      // Save - this will automatically trigger iCloud sync if enabled
      // await LocalStorageService.savePracticeAreas(areas);
      
      print('✅ Practice area added and synced');
    } catch (e) {
      print('❌ Failed to add practice area: $e');
      rethrow;
    }
  }
  
  /// Example: Adding a custom song with PDF sync
  static Future<void> addCustomSongWithSync(
    String songName,
    String pdfFileName,
  ) async {
    try {
      // Create custom song data
      final songData = {
        'title': songName,
        'composer': 'Custom',
        'path': 'custom://pdf_only/${songName.replaceAll(' ', '_')}-${DateTime.now().millisecondsSinceEpoch}',
        'isPdfOnly': true,
        'isCustom': true,
      };
      
      // Add song - this will automatically sync JSON data
      await LocalStorageService.addCustomSong(songData);
      
      // Sync PDF file separately if it exists
      if (pdfFileName.isNotEmpty) {
        final pdfResult = await LocalStorageService.syncPdfToICloud(pdfFileName);
        if (!pdfResult.success) {
          print('⚠️ PDF sync failed: ${pdfResult.error}');
        }
      }
      
      print('✅ Custom song added and synced');
    } catch (e) {
      print('❌ Failed to add custom song: $e');
      rethrow;
    }
  }
}

/// Example: App lifecycle integration
/// Add this to your main app widget's dispose method
void disposeSync() {
  LocalStorageService.disposeICloudSync();
}

/// Example: Testing sync functionality
class ExampleSyncTest {
  
  /// Test basic sync functionality
  static Future<void> testBasicSync() async {
    print('🧪 Testing iCloud sync functionality...');
    
    try {
      // Initialize sync
      await LocalStorageService.initializeICloudSync();
      print('✅ Sync initialized');
      
      // Check if available
      final isEnabled = LocalStorageService.isICloudSyncEnabled;
      print('📱 Sync enabled: $isEnabled');
      
      if (!isEnabled) {
        print('⚠️ iCloud sync not available on this device');
        return;
      }
      
      // Test sync operation
      final result = await LocalStorageService.syncAllToICloud();
      if (result.success) {
        print('✅ Test sync completed successfully');
      } else {
        print('❌ Test sync failed: ${result.error}');
      }
      
      // Get storage usage
      final usage = await LocalStorageService.getICloudStorageUsage();
      print('📊 Storage usage: ${usage['totalSize']} bytes, ${usage['fileCount']} files');
      
    } catch (e) {
      print('❌ Sync test failed: $e');
    }
  }
}

/*
INTEGRATION CHECKLIST:
======================

1. ✅ Add iCloud entitlements to iOS project (Runner.entitlements)
2. ✅ Initialize sync service early in app lifecycle
3. ✅ Add sync settings screen to your settings/preferences
4. ✅ Add sync status indicator to relevant screens
5. ✅ Handle sync conflicts appropriately
6. ✅ Test on physical devices with iCloud enabled
7. ✅ Monitor sync status and provide user feedback
8. ✅ Dispose sync service when app closes

IMPORTANT NOTES:
================

• iCloud sync only works on physical iOS devices with iCloud enabled
• Test thoroughly with multiple devices to ensure sync works correctly
• Handle network failures gracefully - app should work offline
• Sync conflicts should be resolved by user choice when possible
• Monitor sync status and provide appropriate user feedback
• Consider implementing retry logic for failed syncs
• PDF files may take longer to sync due to size - show progress when appropriate

DEBUGGING:
==========

• Check iOS device settings: Settings > [Your Name] > iCloud > iCloud Drive
• Ensure your app appears in the iCloud Drive app list
• Check Console.app on macOS for detailed iCloud sync logs
• Test with multiple devices to verify cross-device synchronization
• Use the storage usage API to monitor sync progress

*/