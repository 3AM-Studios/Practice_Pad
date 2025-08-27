import 'package:flutter/material.dart';
import 'package:practice_pad/services/icloud_sync_service.dart';

class SyncStatusCard extends StatelessWidget {
  final SyncStatus syncStatus;
  final String? lastError;
  final DateTime? lastSyncTime;
  final VoidCallback onSyncNow;
  final bool hasConflicts;
  final VoidCallback? onResolveConflicts;

  const SyncStatusCard({
    super.key,
    required this.syncStatus,
    this.lastError,
    this.lastSyncTime,
    required this.onSyncNow,
    this.hasConflicts = false,
    this.onResolveConflicts,
  });

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return 'Never';
    
    final now = DateTime.now();
    final diff = now.difference(lastSync);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _getStatusIcon() {
    switch (syncStatus) {
      case SyncStatus.idle:
        return Icons.cloud_done;
      case SyncStatus.syncing:
        return Icons.cloud_sync;
      case SyncStatus.success:
        return Icons.cloud_done;
      case SyncStatus.error:
        return Icons.cloud_off;
      case SyncStatus.conflict:
        return Icons.merge_type;
    }
  }

  Color _getStatusColor() {
    switch (syncStatus) {
      case SyncStatus.idle:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.conflict:
        return Colors.orange;
    }
  }

  String _getStatusText() {
    switch (syncStatus) {
      case SyncStatus.idle:
        return 'Ready to sync';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.success:
        return 'Up to date';
      case SyncStatus.error:
        return 'Sync failed';
      case SyncStatus.conflict:
        return 'Conflicts detected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: syncStatus == SyncStatus.syncing
                      ? SizedBox(
                          key: const ValueKey('syncing'),
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        )
                      : Icon(
                          key: const ValueKey('static'),
                          _getStatusIcon(),
                          color: statusColor,
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Last sync: ${_formatLastSync(lastSyncTime)}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            if (lastError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lastError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (hasConflicts) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Some files have conflicts and need to be resolved',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasConflicts && onResolveConflicts != null)
                  TextButton.icon(
                    onPressed: onResolveConflicts,
                    icon: const Icon(Icons.merge_type),
                    label: const Text('Resolve Conflicts'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                
                if (hasConflicts && onResolveConflicts != null)
                  const SizedBox(width: 8),
                
                ElevatedButton.icon(
                  onPressed: syncStatus == SyncStatus.syncing ? null : onSyncNow,
                  icon: syncStatus == SyncStatus.syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(syncStatus == SyncStatus.syncing ? 'Syncing...' : 'Sync Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}