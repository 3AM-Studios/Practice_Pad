import 'package:flutter/material.dart';
import 'package:practice_pad/services/icloud_sync_service.dart';
import 'package:practice_pad/services/local_storage_service.dart';

class ConflictResolutionDialog extends StatefulWidget {
  final List<ConflictItem> conflicts;
  final VoidCallback onConflictsResolved;

  const ConflictResolutionDialog({
    super.key,
    required this.conflicts,
    required this.onConflictsResolved,
  });

  @override
  State<ConflictResolutionDialog> createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  bool _isResolving = false;
  final Map<ConflictItem, String> _resolutions = {}; // 'local' or 'icloud'

  @override
  void initState() {
    super.initState();
    // Default to the newer version for each conflict
    for (final conflict in widget.conflicts) {
      _resolutions[conflict] = conflict.localModified.isAfter(conflict.icloudModified) 
          ? 'local' 
          : 'icloud';
    }
  }

  Future<void> _resolveConflicts() async {
    setState(() {
      _isResolving = true;
    });

    try {
      final syncService = LocalStorageService.icloudSyncService;
      if (syncService == null) {
        throw Exception('Sync service not available');
      }

      for (final entry in _resolutions.entries) {
        final conflict = entry.key;
        final resolution = entry.value;

        if (resolution == 'local') {
          await syncService.resolveConflictWithLocal(conflict);
        } else {
          await syncService.resolveConflictWithICloud(conflict);
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onConflictsResolved();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Resolved ${widget.conflicts.length} conflicts'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resolving conflicts: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildConflictItem(ConflictItem conflict) {
    final selectedResolution = _resolutions[conflict] ?? 'local';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.merge_type, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conflict.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Choose which version to keep:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            
            const SizedBox(height: 12),
            
            // Local version option
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectedResolution == 'local' 
                      ? Colors.blue 
                      : Colors.grey.withOpacity(0.3),
                  width: selectedResolution == 'local' ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: selectedResolution == 'local'
                    ? Colors.blue.withOpacity(0.1)
                    : null,
              ),
              child: RadioListTile<String>(
                title: const Text('This Device'),
                subtitle: Text(
                  'Modified: ${_formatDateTime(conflict.localModified)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                value: 'local',
                groupValue: selectedResolution,
                onChanged: (value) {
                  setState(() {
                    _resolutions[conflict] = value!;
                  });
                },
                activeColor: Colors.blue,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // iCloud version option
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectedResolution == 'icloud' 
                      ? Colors.green 
                      : Colors.grey.withOpacity(0.3),
                  width: selectedResolution == 'icloud' ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: selectedResolution == 'icloud'
                    ? Colors.green.withOpacity(0.1)
                    : null,
              ),
              child: RadioListTile<String>(
                title: const Text('iCloud'),
                subtitle: Text(
                  'Modified: ${_formatDateTime(conflict.icloudModified)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                value: 'icloud',
                groupValue: selectedResolution,
                onChanged: (value) {
                  setState(() {
                    _resolutions[conflict] = value!;
                  });
                },
                activeColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.merge_type, color: Colors.orange),
          SizedBox(width: 8),
          Text('Resolve Sync Conflicts'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Found ${widget.conflicts.length} file(s) with conflicts. '
              'Choose which version to keep for each file:',
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: ListView.builder(
                itemCount: widget.conflicts.length,
                itemBuilder: (context, index) {
                  return _buildConflictItem(widget.conflicts[index]);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isResolving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        
        ElevatedButton(
          onPressed: _isResolving ? null : _resolveConflicts,
          child: _isResolving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Resolve Conflicts'),
        ),
      ],
    );
  }
}