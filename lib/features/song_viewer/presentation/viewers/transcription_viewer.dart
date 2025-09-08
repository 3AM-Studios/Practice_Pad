import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/services/storage/local_storage_service.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/practice_session_manager.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/statistics.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:practice_pad/services/device_type.dart';

class TranscriptionViewer extends StatefulWidget {
  final Song? song;
  final Map<String, dynamic>? youtubeVideo;
  final bool isSongMode;

  const TranscriptionViewer({
    super.key,
    this.song,
    this.youtubeVideo,
    required this.isSongMode,
  }) : assert(
         (isSongMode && song != null) || (!isSongMode && youtubeVideo != null),
         'Either song (for song mode) or youtubeVideo (for standalone mode) must be provided',
       );

  @override
  State<TranscriptionViewer> createState() => _TranscriptionViewerState();
}

class _TranscriptionViewerState extends State<TranscriptionViewer> {
  YoutubePlayerController? _controller;
  final TextEditingController _urlController = TextEditingController();
  bool _isAutoLoop = false;
  double _loopStartTime = 0.0;
  double _loopEndTime = 30.0; // Default 30-second loop
  bool _hasLoopSection = true; // Always true now
  String? _currentVideoId;
  bool _isLoadingVideo = false;
  String? _videoError;
  double _playbackSpeed = 1.0;
  List<Map<String, dynamic>> _savedLoops = [];
  
  // Loop control state
  bool _isUserScrubbing = false;
  
  // Practice session state
  PracticeSessionManager? _sessionManager;
  int _elapsedSeconds = 0;
  bool _isTimerRunning = false;

  // Helper methods for dual mode support
  String _getStorageKey() {
    if (widget.isSongMode) {
      return widget.song!.path;
    } else {
      return widget.youtubeVideo!['id'];
    }
  }
  
  String _getDisplayTitle() {
    if (widget.isSongMode) {
      return widget.song!.title;
    } else {
      return widget.youtubeVideo!['title'] ?? 'Unknown Video';
    }
  }
  
  String _getPracticeItemId() {
    if (widget.isSongMode) {
      return 'transcription_${widget.song!.path}';
    } else {
      return 'transcription_${widget.youtubeVideo!['id']}';
    }
  }
  
  String _getPracticeItemName() {
    if (widget.isSongMode) {
      return 'Transcription - ${widget.song!.title}';
    } else {
      return 'Transcription - ${widget.youtubeVideo!['title'] ?? 'Unknown Video'}';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadYoutubeData();
    _loadSavedLoops();
    
    // Initialize practice session manager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionManager = Provider.of<PracticeSessionManager>(context, listen: false);
      if (_sessionManager!.hasActiveSession) {
        setState(() {
          _elapsedSeconds = _sessionManager!.elapsedSeconds;
          _isTimerRunning = _sessionManager!.isTimerRunning;
        });
        _sessionManager!.addListener(_syncWithSessionManager);
      }
    });
  }

  @override
  void dispose() {
    // Safely dispose of the YouTube controller
    _disposeController();
    _sessionManager?.removeListener(_syncWithSessionManager);
    _urlController.dispose();
    super.dispose();
  }

  void _disposeController() {
    if (_controller != null) {
      try {
        _controller!.removeListener(_videoListener);
        _controller!.dispose();
      } catch (e) {
        debugPrint('Error disposing controller: $e');
      } finally {
        _controller = null;
      }
    }
  }

  Future<void> _loadYoutubeData() async {
    try {
      // For standalone mode, check if video URL is provided directly
      if (!widget.isSongMode && widget.youtubeVideo != null) {
        final videoUrl = widget.youtubeVideo!['url'] as String?;
        if (videoUrl != null && videoUrl.isNotEmpty) {
          _urlController.text = videoUrl;
          await _loadVideoFromUrl(videoUrl);
        }
      }
      
      // Load saved YouTube data for this storage key
      final youtubeData = await LocalStorageService.loadYoutubeLinkForSong(_getStorageKey());
      if (youtubeData.isNotEmpty) {
        final url = youtubeData['url'] as String?;
        final loopStartTime = (youtubeData['loopStartTime'] as num?)?.toDouble() ?? 0.0;
        final loopEndTime = (youtubeData['loopEndTime'] as num?)?.toDouble() ?? 0.0;
        final isAutoLoop = youtubeData['isAutoLoop'] as bool? ?? false;
        final playbackSpeed = (youtubeData['playbackSpeed'] as num?)?.toDouble() ?? 1.0;

        if (url != null && url.isNotEmpty) {
          _urlController.text = url;
          _loopStartTime = loopStartTime;
          _loopEndTime = loopEndTime > loopStartTime ? loopEndTime : loopStartTime + 30.0;
          _isAutoLoop = isAutoLoop;
          _playbackSpeed = playbackSpeed;
          await _loadVideoFromUrl(url);
        }
      }
    } catch (e) {
      debugPrint('Error loading YouTube data: $e');
    }
  }

  Future<void> _saveYoutubeData() async {
    try {
      final youtubeData = {
        'url': _urlController.text,
        'loopStartTime': _loopStartTime,
        'loopEndTime': _loopEndTime,
        'isAutoLoop': _isAutoLoop,
        'playbackSpeed': _playbackSpeed,
      };
      await LocalStorageService.saveYoutubeLinkForSong(_getStorageKey(), youtubeData);
    } catch (e) {
      debugPrint('Error saving YouTube data: $e');
    }
  }

  Future<void> _loadVideoFromUrl(String url) async {
    setState(() {
      _isLoadingVideo = true;
      _videoError = null;
    });

    try {
      final videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId != null) {
        _currentVideoId = videoId;
        
        // Dispose existing controller safely
        _disposeController();
        
        // Small delay to ensure disposal is complete
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Create new controller only if widget is still mounted
        if (mounted) {
          _controller = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              enableCaption: true,
              loop: false,
            ),
          );

          _controller!.addListener(_videoListener);
          _updatePlaybackSpeed();
        }
        setState(() {
          _isLoadingVideo = false;
        });
        await _saveYoutubeData();
      } else {
        setState(() {
          _isLoadingVideo = false;
          _videoError = 'Invalid YouTube URL';
        });
        _showError('Invalid YouTube URL. Please enter a valid YouTube video URL.');
      }
    } catch (e) {
      debugPrint('Error loading YouTube video: $e');
      setState(() {
        _isLoadingVideo = false;
        _videoError = 'Platform error: ${e.toString()}';
      });
      _showError('Error loading video. This may be due to platform compatibility issues.');
    }
  }

  void _videoListener() {
    if (_controller != null && !_controller!.value.hasError && _controller!.value.isReady && mounted && !_isUserScrubbing) {
      try {
        final currentTime = _controller!.value.position.inSeconds.toDouble();
        if (currentTime >= _loopEndTime && currentTime > 0) {
          if (_isAutoLoop) {
            // Auto loop is on: jump back to start
            _controller!.seekTo(Duration(seconds: _loopStartTime.toInt()));
          } else {
            // Auto loop is off: pause the video
            _controller!.pause();
          }
        }
      } catch (e) {
        // Controller may have been disposed, ignore the error
        debugPrint('Video listener error (controller likely disposed): $e');
      }
    }
  }

  Future<void> _loadSavedLoops() async {
    try {
      final loops = await LocalStorageService.loadSavedLoopsForSong(_getStorageKey());
      setState(() {
        _savedLoops = loops;
      });
    } catch (e) {
      debugPrint('Error loading saved loops: $e');
    }
  }

  Future<void> _saveSavedLoops() async {
    try {
      await LocalStorageService.saveSavedLoopsForSong(_getStorageKey(), _savedLoops);
    } catch (e) {
      debugPrint('Error saving loops: $e');
    }
  }

  void _showSaveLoopDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Loop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Loop: ${_formatTime(_loopStartTime)} → ${_formatTime(_loopEndTime)}'),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Loop Title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                _saveCurrentLoop(titleController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _saveCurrentLoop(String title) {
    final newLoop = {
      'title': title,
      'startTime': _loopStartTime,
      'endTime': _loopEndTime,
      'speed': _playbackSpeed,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    setState(() {
      _savedLoops.add(newLoop);
    });
    
    _saveSavedLoops();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loop "$title" saved!')),
    );
  }

  void _loadLoop(Map<String, dynamic> loop) {
    setState(() {
      _loopStartTime = (loop['startTime'] as num).toDouble();
      _loopEndTime = (loop['endTime'] as num).toDouble();
      _playbackSpeed = (loop['speed'] as num?)?.toDouble() ?? 1.0;
    });
    
    _updatePlaybackSpeed();
    _saveYoutubeData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded loop "${loop['title']}"')),
    );
  }

  void _deleteLoop(int index) {
    final loop = _savedLoops[index];
    setState(() {
      _savedLoops.removeAt(index);
    });
    
    _saveSavedLoops();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted loop "${loop['title']}"')),
    );
  }

  void _syncWithSessionManager() {
    if (mounted && _sessionManager != null && _sessionManager!.hasActiveSession) {
      setState(() {
        _elapsedSeconds = _sessionManager!.elapsedSeconds;
        _isTimerRunning = _sessionManager!.isTimerRunning;
      });
    }
  }

  void _startPracticeTimer() {
    if (_sessionManager == null) return;
    
    // Create a dummy practice item for the song
    final practiceItem = PracticeItem(
      id: _getPracticeItemId(),
      name: _getPracticeItemName(),
      description: 'Practice session for ${_getDisplayTitle()}',
    );

    if (!_sessionManager!.hasActiveSession) {
      _sessionManager!.startSession(
        item: practiceItem,
        targetSeconds: 1800, // Default 30 minutes
      );
    }
    
    _sessionManager!.startTimer();
    _sessionManager!.addListener(_syncWithSessionManager);
    
    setState(() {
      _isTimerRunning = true;
    });
  }

  void _stopPracticeTimer() {
    _sessionManager?.stopTimer();
    setState(() {
      _isTimerRunning = false;
    });
  }

  void _completePracticeSession() async {
    if (_sessionManager == null || !_sessionManager!.hasActiveSession) return;

    try {
      // Create and save the practice session as statistics
      final statistics = Statistics(
        practiceItemId: _getPracticeItemId(),
        timestamp: DateTime.now(),
        totalReps: 0,
        totalTime: Duration(seconds: _elapsedSeconds),
        metadata: {
          'time': _elapsedSeconds,
          'songTitle': _getDisplayTitle(),
          'type': 'transcription',
        },
      );

      // Save to statistics
      await statistics.save();

      // Complete the session in the global manager
      _sessionManager!.completeSession();

      setState(() {
        _elapsedSeconds = 0;
        _isTimerRunning = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Practice session completed! ${_formatPracticeTime(_elapsedSeconds)} logged.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving practice session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatPracticeTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _updatePlaybackSpeed() {
    if (_controller != null && _controller!.value.isReady && mounted) {
      try {
        _controller!.setPlaybackRate(_playbackSpeed);
      } catch (e) {
        debugPrint('Error updating playback speed (controller likely disposed): $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


  void _playFromLoopStart() {
    if (_controller != null && _controller!.value.isReady && mounted) {
      try {
        _controller!.seekTo(Duration(seconds: _loopStartTime.toInt()));
        _controller!.play();
      } catch (e) {
        debugPrint('Error playing from loop start (controller likely disposed): $e');
      }
    }
  }

  void _playFromSecondsBeforeEnd() {
    if (_controller != null && _controller!.value.isReady && mounted) {
      try {
        // Play from 2 seconds before the loop end time
        final playTime = (_loopEndTime - 2).clamp(0, _loopEndTime);
        _controller!.seekTo(Duration(seconds: playTime.toInt()));
        _controller!.play();
      } catch (e) {
        debugPrint('Error playing from seconds before end (controller likely disposed): $e');
      }
    }
  }


  String _formatTime(double seconds) {
    final int minutes = (seconds ~/ 60);
    final int remainingSeconds = (seconds % 60).toInt();
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildClayButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _buildClayButtonWidget(icon: icon, color: color),
    );
  }

  Widget _buildClayButtonWidget({
    required IconData icon,
    required Color color,
  }) {
    return ClayContainer(
      color: Theme.of(context).colorScheme.surface,
      depth: 20,
      borderRadius: 12,
      width: 44,
      height: 44,
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }


  Widget _buildSimpleButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClayContainer(
        color: color,
        depth: 10,
        borderRadius: 8,
        child: Container(
          width: 32,
          height: 32,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPracticeSessionControls() {
    return ClayContainer(
      color: const Color.fromARGB(255, 172, 139, 103),
      depth: 15,
      borderRadius: 12,
      child: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/wood_texture_rotated.jpg'),
            fit: BoxFit.cover,
          ),
          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer display
            if (_sessionManager?.hasActiveSession == true)
              ClayContainer(
                spread: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatPracticeTime(_elapsedSeconds),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (_sessionManager?.hasActiveSession == true)
              const SizedBox(width: 6),
            
            // Start/Stop timer button
            GestureDetector(
              onTap: _isTimerRunning ? _stopPracticeTimer : _startPracticeTimer,
              child: Container(                               
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _isTimerRunning ? Colors.red.shade600 : Colors.green.shade600,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _isTimerRunning ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            
            // "Start practice session" text when no session is active
            if (_sessionManager?.hasActiveSession != true)
              const SizedBox(width: 8),
            if (_sessionManager?.hasActiveSession != true)
              const Text(
                'Start practice session',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            
            // Complete session button
            if (_sessionManager?.hasActiveSession == true)
              GestureDetector(
                onTap: _completePracticeSession,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlSection() {
    return ClayContainer(
      color: Theme.of(context).colorScheme.surface,
      depth: 20,
      borderRadius: 16,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClayContainer(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: 8,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(50, 4, 50, 4),
                  child: const Text(
                    'YouTube Video URL',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'Paste YouTube URL here...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(17))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final Uri youtubeUrl = Uri.parse('https://youtube.com');
                    if (await canLaunchUrl(youtubeUrl)) {
                      await launchUrl(youtubeUrl);
                    }
                  },
                  child: ClayContainer(
                    color: Theme.of(context).colorScheme.surface,
                    depth: 15,
                    borderRadius: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_browser,
                            color: Theme.of(context).colorScheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Browse YouTube',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  onPressed: () {
                    if (_urlController.text.isNotEmpty) {
                      _loadVideoFromUrl(_urlController.text);
                    }
                  },
                  child: const Text('Load'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoopSection() {
    return ClayContainer(
      color: Theme.of(context).colorScheme.surface,
      depth: 20,
      borderRadius: 16,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Wooden header for Loop Section
            ClayContainer(
              color: Theme.of(context).colorScheme.surface,
              depth: 15,
              borderRadius: 12,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Loop Section',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Start time, arrow, end time row
            Row(
              children: [
                // Start time clay container
                Expanded(
                  child: ClayContainer(
                    color: Theme.of(context).colorScheme.surface,
                    depth: 10,
                    borderRadius: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      child: Column(
                        children: [
                          const Text(
                            'Start',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(_loopStartTime),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Arrow
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
                
                // End time clay container
                Expanded(
                  child: ClayContainer(
                    color: Theme.of(context).colorScheme.surface,
                    depth: 10,
                    borderRadius: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      child: Column(
                        children: [
                          const Text(
                            'End',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(_loopEndTime),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebViewFallback() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'YouTube Player Unavailable',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'There\'s an issue with the video player on this device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (_urlController.text.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                // Open YouTube URL in external browser
                final url = _urlController.text;
                // You could use url_launcher here to open the URL externally
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('YouTube URL: $url')),
                );
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open in YouTube App'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeviceType>(
      future: getDeviceType(),
      builder: (context, snapshot) {
        final deviceType = snapshot.data ?? DeviceType.phone;
        final isTabletOrDesktop = deviceType == DeviceType.tablet || deviceType == DeviceType.macOS;
        
        return _buildContent(context, isTabletOrDesktop);
      },
    );
  }
  
  Widget _buildContent(BuildContext context, bool isTabletOrDesktop) {
    
    return Scaffold(
      body: SafeArea(
        bottom: false,
        top: false,
        right: false,
        left: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom:0.0,top:0.0, right: 16.0, left: 16.0),
          child: Column(
            children: [
            isTabletOrDesktop
                ? const SizedBox(height: 17)
                : const SizedBox(height: 60),
            // Wooden Header
            ClayContainer(
              color: Theme.of(context).colorScheme.surface,
              depth: 20,
              borderRadius: 20,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: isTabletOrDesktop
                    ? Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Transcription - ${_getDisplayTitle()}',
                                    style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 3,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Practice session controls - Wooden clay container
                                _buildPracticeSessionControls(),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Transcription - ${_getDisplayTitle()}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 3,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildPracticeSessionControls(),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
        
            // URL and Loop Section - Row for tablet/desktop, Column for iPhone
            if (isTabletOrDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // YouTube URL section - 60% width
                  Expanded(
                    flex: 6,
                    child: _buildUrlSection(),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Loop section - 40% width - Only show if there's a video URL
                  if (_urlController.text.isNotEmpty)
                    Expanded(
                      flex: 2,
                      child: _buildLoopSection(),
                    ),
                ],
              )
            else
              Column(
                children: [
                  // YouTube URL section
                  _buildUrlSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Loop section - Only show if there's a video URL
                  if (_urlController.text.isNotEmpty)
                    _buildLoopSection(),
                ],
              ),
          const SizedBox(height: 16),
        
          // Video player - Fixed height instead of Expanded
          if (_isLoadingVideo)
            SizedBox(
              height: 250,
              child: Card(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading video...'),
                    ],
                  ),
                ),
              ),
            )
          else if (_videoError != null)
            SizedBox(
              height: 250,
              child: Card(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Video Load Error',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _videoError!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _videoError = null;
                          });
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_controller != null)
            SizedBox(
              height: 250,
              child: Card(
                child: Column(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          try {
                            return YoutubePlayerBuilder(
                              onExitFullScreen: () {
                                // Handle exit fullscreen if needed
                              },
                              player: YoutubePlayer(
                                controller: _controller!,
                                showVideoProgressIndicator: true,
                                progressIndicatorColor: Colors.amber,
                                progressColors: const ProgressBarColors(
                                  playedColor: Colors.amber,
                                  handleColor: Colors.amberAccent,
                                ),
                                bottomActions: [
                                  const CurrentPosition(),
                                  LoopProgressBar(
                                    isExpanded: true,
                                    loopStart: Duration(seconds: _loopStartTime.toInt()),
                                    loopEnd: Duration(seconds: _loopEndTime.toInt()),
                                    isLoopEnabled: _isAutoLoop,
                                    onLoopUpdate: (start, end) {
                                      debugPrint('PARENT: Received loop update start=${start.inSeconds}s, end=${end.inSeconds}s');
                                      
                                      // Check if end time changed (for drag end control)
                                      final oldEndTime = _loopEndTime;
                                      final newEndTime = end.inSeconds.toDouble();
                                      final endTimeChanged = oldEndTime != newEndTime;
                                      
                                      setState(() {
                                        _loopStartTime = start.inSeconds.toDouble();
                                        _loopEndTime = newEndTime;
                                        _hasLoopSection = true;
                                      });
                                      _saveYoutubeData();
                                      
                                      // If end time changed via drag, play from 2 seconds before end
                                      if (endTimeChanged) {
                                        _playFromSecondsBeforeEnd();
                                      }
                                    },
                                    onLoopPlay: _playFromLoopStart,
                                    onLoopToggle: (enabled) {
                                      setState(() {
                                        _isAutoLoop = enabled;
                                      });
                                      _saveYoutubeData();
                                    },
                                    showControls: false, // Hide controls from video player
                                  ),
                                  const RemainingDuration(),
                                  const FullScreenButton(),
                                ],
                              ),
                              builder: (context, player) {
                                return player;
                              },
                            );
                          } catch (e) {
                            debugPrint('Error creating YoutubePlayer: $e');
                            return _buildWebViewFallback();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        
          const SizedBox(height: 16),
        
          // Loop Controls and Saved Loops Section - Only show if video is loaded
          if (_controller != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main controls row
                    Row(
                      children: [
                        // Play Loop Button
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _controller != null && _controller!.value.isReady ? () {
                              _controller!.seekTo(Duration(seconds: _loopStartTime.toInt()));
                              _controller!.play();
                            } : null,
                            child: ClayContainer(
                              color: Theme.of(context).colorScheme.surface,
                              depth: 20,
                              borderRadius: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_arrow,
                                      color: Colors.blue.shade600,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Play Loop',
                                      style: TextStyle(
                                        color: Colors.blue.shade600,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Auto Loop Toggle
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isAutoLoop = !_isAutoLoop;
                              });
                              _saveYoutubeData();
                            },
                            child: ClayContainer(
                              color: Theme.of(context).colorScheme.surface,
                              depth: _isAutoLoop ? 15 : 20,
                              borderRadius: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isAutoLoop ? Icons.repeat : Icons.repeat_one,
                                      color: _isAutoLoop ? Colors.green.shade600 : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isAutoLoop ? 'Auto Loop ON' : 'Auto Loop OFF',
                                      style: TextStyle(
                                        color: _isAutoLoop ? Colors.green.shade600 : Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Fine-tune controls row with labels
                    Row(
                      children: [
                        // Start controls
                        Expanded(
             
                          child: Column(
                            children: [
                              Text(
                                'Start',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildClayButton(
                                    icon: Icons.remove,
                                    color: Colors.red.shade600,
                                    onTap: () {
                                      setState(() {
                                        _loopStartTime = (_loopStartTime - 1).clamp(0, _loopEndTime - 1);
                                      });
                                      _saveYoutubeData();
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  _buildClayButton(
                                    icon: Icons.add,
                                    color: Colors.green.shade600,
                                    onTap: () {
                                      setState(() {
                                        _loopStartTime = (_loopStartTime + 1).clamp(0, _loopEndTime - 1);
                                      });
                                      _saveYoutubeData();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 20),
                        
                        // Speed controls
                        Expanded(
     
                          child: Column(
                            children: [
                              Text(
                                'Speed',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClayContainer(
                                color: Theme.of(context).colorScheme.surface,
                                depth: 15,
                                borderRadius: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: isTabletOrDesktop
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildSimpleButton(
                                              label: '-',
                                              color: Theme.of(context).colorScheme.surface,
                                              onTap: () {
                                                setState(() {
                                                  _playbackSpeed = (_playbackSpeed - 0.25).clamp(0.25, 2.0);
                                                });
                                                _updatePlaybackSpeed();
                                                _saveYoutubeData();
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${_playbackSpeed.toStringAsFixed(2)}x',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildSimpleButton(
                                              label: '+',
                                              color: Theme.of(context).colorScheme.surface,
                                              onTap: () {
                                                setState(() {
                                                  _playbackSpeed = (_playbackSpeed + 0.25).clamp(0.25, 2.0);
                                                });
                                                _updatePlaybackSpeed();
                                                _saveYoutubeData();
                                              },
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _buildSimpleButton(
                                                  label: '-',
                                                  color: Theme.of(context).colorScheme.surface,
                                                  onTap: () {
                                                    setState(() {
                                                      _playbackSpeed = (_playbackSpeed - 0.25).clamp(0.25, 2.0);
                                                    });
                                                    _updatePlaybackSpeed();
                                                    _saveYoutubeData();
                                                  },
                                                ),
                                                const SizedBox(width: 12),
                                                _buildSimpleButton(
                                                  label: '+',
                                                  color: Theme.of(context).colorScheme.surface,
                                                  onTap: () {
                                                    setState(() {
                                                      _playbackSpeed = (_playbackSpeed + 0.25).clamp(0.25, 2.0);
                                                    });
                                                    _updatePlaybackSpeed();
                                                    _saveYoutubeData();
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${_playbackSpeed.toStringAsFixed(2)}x',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 20),
                        
                        // End controls
                        Expanded(
                        
                          child: Column(
                            children: [
                              Text(
                                'End',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTapDown: (_) {
                                      setState(() {
                                        _isUserScrubbing = true;
                                      });
                                    },
                                    onTapUp: (_) {
                                      setState(() {
                                        _isUserScrubbing = false;
                                        _loopEndTime = (_loopEndTime - 1).clamp(_loopStartTime + 1, double.infinity);
                                      });
                                      _saveYoutubeData();
                                      // Play from 2 seconds before the new end time
                                      _playFromSecondsBeforeEnd();
                                    },
                                    onTapCancel: () {
                                      setState(() {
                                        _isUserScrubbing = false;
                                      });
                                    },
                                    child: _buildClayButtonWidget(
                                      icon: Icons.remove,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTapDown: (_) {
                                      setState(() {
                                        _isUserScrubbing = true;
                                      });
                                    },
                                    onTapUp: (_) {
                                      setState(() {
                                        _isUserScrubbing = false;
                                        _loopEndTime = _loopEndTime + 1;
                                      });
                                      _saveYoutubeData();
                                      // Play from 2 seconds before the new end time
                                      _playFromSecondsBeforeEnd();
                                    },
                                    onTapCancel: () {
                                      setState(() {
                                        _isUserScrubbing = false;
                                      });
                                    },
                                    child: _buildClayButtonWidget(
                                      icon: Icons.add,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        
                    const SizedBox(height: 16),
        
                    // Saved Loops Section - Fixed height with scrollable content
                    ClayContainer(
                      color: Theme.of(context).colorScheme.surface,
                      depth: 20,
                      borderRadius: 16,
                      child: Container(
                        height: 250,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.bookmark, size: 16, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Saved Loops',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 14, 
                                        color: Theme.of(context).colorScheme.onSurface
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: _showSaveLoopDialog,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Save', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    minimumSize: Size.zero,
                                    alignment: Alignment.center,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _savedLoops.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No saved loops yet. Tap "Save" to save the current loop.',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _savedLoops.length,
                                      itemBuilder: (context, index) {
                                        final loop = _savedLoops[index];
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () => _loadLoop(loop),
                                                    child: ClayContainer(
                                                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                                                      depth: 15,
                                                      borderRadius: 12,
                                                      child: Container(
                                                        padding: const EdgeInsets.all(12),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              loop['title'] as String,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            Text(
                                                              '${_formatTime((loop['startTime'] as num).toDouble())} → ${_formatTime((loop['endTime'] as num).toDouble())} (${((loop['speed'] as num?)?.toDouble() ?? 1.0).toStringAsFixed(2)}x)',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors.grey.shade600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 15),
                                                GestureDetector(
                                                  onTap: () => _deleteLoop(index),
                                                  child: ClayContainer(
                                                    color: Colors.red.shade100,
                                                    depth: 10,
                                                    spread: 2,
                                                    borderRadius: 8,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(6),
                                                      child: Icon(
                                                        Icons.delete_outline,
                                                        size: 16,
                                                        color: Colors.red.shade600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        
          // No video loaded message
          if (_controller == null)
            const SizedBox(
              height: 250,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No video loaded',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Paste a YouTube URL above to get started',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}