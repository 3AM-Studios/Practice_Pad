import 'package:flutter/material.dart';
import 'package:practice_pad/services/local_storage_service.dart';
import 'package:practice_pad/services/icloud_sync_service.dart';
import 'package:practice_pad/features/sync/presentation/widgets/sync_status_card.dart';
import 'package:practice_pad/features/sync/presentation/widgets/conflict_resolution_dialog.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  bool _isLoading = true;
  bool _icloudSyncEnabled = false;
  SyncStatus _syncStatus = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncTime;
  Map<String, int> _storageUsage = {};
  List<ConflictItem> _conflicts = [];

  @override
  void initState() {
    super.initState();
    _initializeSync();
    _loadSyncState();
  }

  Future<void> _initializeSync() async {
    try {
      await LocalStorageService.initializeICloudSync();
      _loadSyncState();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize sync: $e')),
        );
      }
    }
  }

  Future<void> _loadSyncState() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final syncService = LocalStorageService.icloudSyncService;
      setState(() {
        _icloudSyncEnabled = LocalStorageService.isICloudSyncEnabled;
        _syncStatus = syncService?.syncStatus ?? SyncStatus.idle;
        _lastError = syncService?.lastError;
        _lastSyncTime = syncService?.lastSyncTime;
      });

      if (_icloudSyncEnabled) {
        final usage = await LocalStorageService.getICloudStorageUsage();
        setState(() {
          _storageUsage = usage;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sync state: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleICloudSync(bool enabled) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await LocalStorageService.setICloudSyncEnabled(enabled);
      await _loadSyncState();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('iCloud sync ${enabled ? 'enabled' : 'disabled'}'),
            backgroundColor: enabled ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling sync: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncNow() async {
    if (!_icloudSyncEnabled) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await LocalStorageService.syncAllToICloud();
      
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ All data synced successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (result.conflicts.isNotEmpty) {
        setState(() {
          _conflicts = result.conflicts;
        });
        _showConflictResolutionDialog();
      } else if (result.error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sync failed: ${result.error}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during sync: $e')),
        );
      }
    } finally {
      await _loadSyncState();
    }
  }

  void _showConflictResolutionDialog() {
    showDialog(
      context: context,
      builder: (context) => ConflictResolutionDialog(
        conflicts: _conflicts,
        onConflictsResolved: () {
          setState(() {
            _conflicts = [];
          });
          _loadSyncState();
        },
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return 'Never';
    
    final now = DateTime.now();
    final diff = now.difference(lastSync);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('iCloud Sync Settings'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enable/Disable iCloud Sync
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.cloud_sync,
                                color: _icloudSyncEnabled 
                                    ? Colors.blue 
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'iCloud Sync',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _icloudSyncEnabled,
                                onChanged: _toggleICloudSync,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _icloudSyncEnabled
                                ? 'Your practice data is synced across all your devices'
                                : 'Enable to sync your data across all your devices',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (_icloudSyncEnabled) ...[
                    const SizedBox(height: 16),
                    
                    // Sync Status Card
                    SyncStatusCard(
                      syncStatus: _syncStatus,
                      lastError: _lastError,
                      lastSyncTime: _lastSyncTime,
                      onSyncNow: _syncNow,
                      hasConflicts: _conflicts.isNotEmpty,
                      onResolveConflicts: _conflicts.isNotEmpty 
                          ? _showConflictResolutionDialog 
                          : null,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Storage Usage
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.storage, color: Colors.purple),
                                const SizedBox(width: 8),
                                const Text(
                                  'Storage Usage',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_storageUsage.isNotEmpty) ...[
                              _buildStorageRow(
                                'Total Files',
                                '${_storageUsage['fileCount'] ?? 0} files',
                                Icons.insert_drive_file,
                                Colors.blue,
                              ),
                              _buildStorageRow(
                                'JSON Data',
                                _formatFileSize(_storageUsage['jsonSize'] ?? 0),
                                Icons.data_object,
                                Colors.green,
                              ),
                              _buildStorageRow(
                                'PDF Files',
                                _formatFileSize(_storageUsage['pdfSize'] ?? 0),
                                Icons.picture_as_pdf,
                                Colors.red,
                              ),
                              const Divider(),
                              _buildStorageRow(
                                'Total Size',
                                _formatFileSize(_storageUsage['totalSize'] ?? 0),
                                Icons.cloud_queue,
                                Colors.purple,
                              ),
                            ] else
                              const Text('No data synced yet'),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Sync Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info, color: Colors.orange),
                                const SizedBox(width: 8),
                                const Text(
                                  'Sync Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Practice areas and items are synced automatically\n'
                              '• Custom songs and PDFs are synced when created or modified\n'
                              '• Changes sync in real-time when possible\n'
                              '• Conflicts are resolved by choosing the most recent version',
                              style: TextStyle(height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStorageRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}