import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:practice_pad/services/local_storage_service.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';

class TranscriptionViewer extends StatefulWidget {
  final Song song;

  const TranscriptionViewer({
    super.key,
    required this.song,
  });

  @override
  State<TranscriptionViewer> createState() => _TranscriptionViewerState();
}

class _TranscriptionViewerState extends State<TranscriptionViewer> {
  YoutubePlayerController? _controller;
  final TextEditingController _urlController = TextEditingController();
  bool _isAutoLoop = false;
  double _loopStartTime = 0.0;
  double _loopEndTime = 0.0;
  bool _hasLoopSection = false;
  String? _currentVideoId;
  bool _isLoadingVideo = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    _loadYoutubeData();
  }

  @override
  void dispose() {
    // Remove listener before disposing
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
      _controller = null;
    }
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadYoutubeData() async {
    try {
      final youtubeData = await LocalStorageService.loadYoutubeLinkForSong(widget.song.path);
      if (youtubeData.isNotEmpty) {
        final url = youtubeData['url'] as String?;
        final loopStartTime = (youtubeData['loopStartTime'] as num?)?.toDouble() ?? 0.0;
        final loopEndTime = (youtubeData['loopEndTime'] as num?)?.toDouble() ?? 0.0;
        final isAutoLoop = youtubeData['isAutoLoop'] as bool? ?? false;

        if (url != null && url.isNotEmpty) {
          _urlController.text = url;
          _loopStartTime = loopStartTime;
          _loopEndTime = loopEndTime;
          _isAutoLoop = isAutoLoop;
          _hasLoopSection = loopEndTime > loopStartTime;
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
      };
      await LocalStorageService.saveYoutubeLinkForSong(widget.song.path, youtubeData);
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
        if (_controller != null) {
          _controller!.removeListener(_videoListener);
          _controller!.dispose();
          _controller = null;
        }
        
        // Create new controller
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
    if (_controller != null && _controller!.value.isReady && _isAutoLoop && _hasLoopSection) {
      final currentTime = _controller!.value.position.inSeconds.toDouble();
      if (currentTime >= _loopEndTime && currentTime > 0) {
        _controller!.seekTo(Duration(seconds: _loopStartTime.toInt()));
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


  void _playFromLoopStart() {
    if (_controller != null && _controller!.value.isReady && _hasLoopSection) {
      _controller!.seekTo(Duration(seconds: _loopStartTime.toInt()));
      _controller!.play();
    }
  }


  String _formatTime(double seconds) {
    final int minutes = (seconds ~/ 60);
    final int remainingSeconds = (seconds % 60).toInt();
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Transcription - ${widget.song.title}'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // URL input section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YouTube Video URL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
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
            ),
            const SizedBox(height: 16),

            // Video player
            if (_isLoadingVideo)
              const Expanded(
                flex: 3,
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
              Expanded(
                flex: 3,
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
              Expanded(
                flex: 3,
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
                                      loopStart: _hasLoopSection ? Duration(seconds: _loopStartTime.toInt()) : null,
                                      loopEnd: _hasLoopSection ? Duration(seconds: _loopEndTime.toInt()) : null,
                                      isLoopEnabled: _isAutoLoop,
                                      onLoopUpdate: (start, end) {
                                        setState(() {
                                          _loopStartTime = start.inSeconds.toDouble();
                                          _loopEndTime = end.inSeconds.toDouble();
                                          _hasLoopSection = true;
                                        });
                                        _saveYoutubeData();
                                      },
                                      onLoopPlay: _playFromLoopStart,
                                      onLoopToggle: (enabled) {
                                        setState(() {
                                          _isAutoLoop = enabled;
                                        });
                                        _saveYoutubeData();
                                      },
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

            // Loop status and instructions
            if (_controller != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enhanced Loop Player',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Create test loop button (if no loop exists)
                      if (!_hasLoopSection)
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _loopStartTime = 10.0; // 10 seconds
                              _loopEndTime = 30.0;   // 30 seconds  
                              _hasLoopSection = true;
                            });
                            _saveYoutubeData();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Test Loop (10s-30s)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade100,
                          ),
                        ),

                      // Loop status
                      if (_hasLoopSection)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Loop: ${_formatTime(_loopStartTime)} - ${_formatTime(_loopEndTime)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    _isAutoLoop ? Icons.repeat : Icons.repeat_one,
                                    color: _isAutoLoop ? Colors.green : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isAutoLoop ? 'Auto ON' : 'Auto OFF',
                                    style: TextStyle(
                                      color: _isAutoLoop ? Colors.green : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How to use the integrated loop controls:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 6),
                            Text('• Drag the golden handles on the progress bar to set loop points', style: TextStyle(fontSize: 12)),
                            Text('• Use the loop button (⭯) to play from loop start', style: TextStyle(fontSize: 12)),
                            Text('• Toggle auto-loop (⭯/⭯) to repeat automatically', style: TextStyle(fontSize: 12)),
                            Text('• Clear button (✕) removes the current loop', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // No video loaded message
            if (_controller == null)
              const Expanded(
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
    );
  }
}