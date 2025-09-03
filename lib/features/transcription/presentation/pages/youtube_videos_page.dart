import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/services/local_storage_service.dart';
import 'package:practice_pad/features/song_viewer/presentation/viewers/transcription_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

class YouTubeVideosPage extends StatefulWidget {
  const YouTubeVideosPage({super.key});

  @override
  State<YouTubeVideosPage> createState() => _YouTubeVideosPageState();
}

class _YouTubeVideosPageState extends State<YouTubeVideosPage> {
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _filteredVideos = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _searchController.addListener(_filterVideos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final videos = await LocalStorageService.loadYoutubeVideosList();
      setState(() {
        _videos = videos;
        _filteredVideos = videos;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading videos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterVideos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredVideos = _videos.where((video) {
        final title = (video['title'] as String? ?? '').toLowerCase();
        final url = (video['url'] as String? ?? '').toLowerCase();
        return title.contains(query) || url.contains(query);
      }).toList();
    });
  }

  void _showAddVideoDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Add YouTube Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Video Title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'YouTube URL',
                border: OutlineInputBorder(),
                hintText: 'https://www.youtube.com/watch?v=...',
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final Uri youtubeUrl = Uri.parse('https://youtube.com');
                if (await canLaunchUrl(youtubeUrl)) {
                  await launchUrl(youtubeUrl);
                }
              },
              child: ClayContainer(
                color: Colors.red,
                parentColor: Theme.of(context).colorScheme.surface,
                depth: 15,
                emboss: true,
                borderRadius: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.youtube_searched_for,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Browse YouTube',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
              if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                _addVideo(titleController.text, urlController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addVideo(String title, String url) async {
    final video = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'url': url,
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      await LocalStorageService.addYoutubeVideo(video);
      await _loadVideos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "$title" to your videos!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding video: $e')),
        );
      }
    }
  }

  Future<void> _deleteVideo(String videoId, String title) async {
    try {
      await LocalStorageService.deleteYoutubeVideo(videoId);
      await _loadVideos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "$title"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting video: $e')),
        );
      }
    }
  }

  void _navigateToTranscription(Map<String, dynamic> video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TranscriptionViewer(
          isSongMode: false,
          youtubeVideo: video,
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown date';
    }
  }

  String _getUrlPreview(String url) {
    if (url.length > 40) {
      return '${url.substring(0, 37)}...';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
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
                  child: Row(
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
                      const Center(
                        child: Text(
                          'YouTube Videos',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Search Bar and Add Button Row
              Row(
                children: [
                  // Search Bar
                  Expanded(
                    flex: 3,
                    child: ClayContainer(
                      color: Theme.of(context).colorScheme.surface,
                      depth: 15,
                      borderRadius: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: TextField(
                          controller: _searchController,
                          textAlign: TextAlign.center,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: const InputDecoration(
                            floatingLabelAlignment: FloatingLabelAlignment.center,
                            alignLabelWithHint: true,
                           
                            hintText: 'Search videos...',
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Add Video Button
                  GestureDetector(
                    onTap: _showAddVideoDialog,
                    child: ClayContainer(
                      color: Theme.of(context).colorScheme.primary,
                      parentColor: Theme.of(context).colorScheme.surface,
                      depth: 15,
                      spread: 15,
                      borderRadius: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Add Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Videos List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredVideos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.video_library_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _videos.isEmpty ? 'No videos added yet' : 'No videos match your search',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _videos.isEmpty 
                                      ? 'Tap "Add Video" to get started'
                                      : 'Try a different search term',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredVideos.length,
                            itemBuilder: (context, index) {
                              final video = _filteredVideos[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: () => _navigateToTranscription(video),
                                  child: ClayContainer(
                                    color: Theme.of(context).colorScheme.surface,
                                    depth: 15,
                                    borderRadius: 16,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          // Video Icon
                                          ClayContainer(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                            parentColor: Theme.of(context).colorScheme.surface,
                                            depth: 10,
                                            borderRadius: 12,
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              child: Icon(
                                                Icons.play_circle_outline,
                                                color: Theme.of(context).colorScheme.primary,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                          
                                          const SizedBox(width: 16),
                                          
                                          // Video Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  video['title'] ?? 'Untitled Video',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _getUrlPreview(video['url'] ?? ''),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Added: ${_formatDate(video['createdAt'] ?? '')}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Delete Button
                                          GestureDetector(
                                            onTap: () => _deleteVideo(
                                              video['id'] ?? '',
                                              video['title'] ?? 'Unknown',
                                            ),
                                            child: ClayContainer(
                                              color: Colors.red.shade100.withOpacity(0.6),
                                              parentColor: Theme.of(context).colorScheme.surface,
                                              depth: 10,
                                              borderRadius: 8,
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                child: Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red.shade600,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
    );
  }
}