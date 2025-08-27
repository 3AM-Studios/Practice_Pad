import 'package:flutter/material.dart';
import 'package:practice_pad/services/local_storage_service.dart';
import 'package:practice_pad/services/icloud_sync_service.dart';

class SyncStatusIndicator extends StatefulWidget {
  final bool showLabel;
  final EdgeInsets? padding;

  const SyncStatusIndicator({
    super.key,
    this.showLabel = true,
    this.padding,
  });

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  SyncStatus _syncStatus = SyncStatus.idle;
  bool _icloudSyncEnabled = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _loadSyncState();
    _setupSyncListeners();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _removeSyncListeners();
    super.dispose();
  }

  void _loadSyncState() {
    if (!mounted) return;
    
    setState(() {
      _icloudSyncEnabled = LocalStorageService.isICloudSyncEnabled;
      _syncStatus = LocalStorageService.icloudSyncService?.syncStatus ?? SyncStatus.idle;
    });
    
    if (_syncStatus == SyncStatus.syncing) {
      _animationController.repeat();
    } else {
      _animationController.stop();
    }
  }

  void _setupSyncListeners() {
    final syncService = LocalStorageService.icloudSyncService;
    syncService?.addStatusListener(_onSyncStatusChanged);
  }

  void _removeSyncListeners() {
    final syncService = LocalStorageService.icloudSyncService;
    syncService?.removeStatusListener(_onSyncStatusChanged);
  }

  void _onSyncStatusChanged(SyncStatus status) {
    if (!mounted) return;
    
    setState(() {
      _syncStatus = status;
    });
    
    if (status == SyncStatus.syncing) {
      _animationController.repeat();
    } else {
      _animationController.stop();
      _animationController.reset();
    }
  }

  IconData _getStatusIcon() {
    switch (_syncStatus) {
      case SyncStatus.idle:
        return Icons.cloud_done_outlined;
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
    switch (_syncStatus) {
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

  String _getStatusLabel() {
    switch (_syncStatus) {
      case SyncStatus.idle:
        return 'Ready';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.success:
        return 'Synced';
      case SyncStatus.error:
        return 'Error';
      case SyncStatus.conflict:
        return 'Conflicts';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_icloudSyncEnabled) {
      return const SizedBox.shrink();
    }

    final statusColor = _getStatusColor();
    
    Widget iconWidget = AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _syncStatus == SyncStatus.syncing
              ? _animationController.value * 2 * 3.14159
              : 0,
          child: Icon(
            _getStatusIcon(),
            size: 16,
            color: statusColor,
          ),
        );
      },
    );

    if (!widget.showLabel) {
      return Container(
        padding: widget.padding ?? const EdgeInsets.all(8),
        child: iconWidget,
      );
    }

    return Container(
      padding: widget.padding ?? const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 4),
          Text(
            _getStatusLabel(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}