import 'package:flutter/material.dart';
import 'package:practice_pad/features/song_viewer/data/models/song.dart';
import 'package:practice_pad/features/song_viewer/data/services/song_manifest_service.dart';
import 'package:practice_pad/features/song_viewer/presentation/screens/song_viewer_screen.dart';

class SongListScreen extends StatefulWidget {
  final bool returnSelectedSong; // If true, return selected song instead of navigating to chord player
  
  const SongListScreen({
    super.key, 
    this.returnSelectedSong = true,
  });

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  final TextEditingController _searchController = TextEditingController();
  final SongManifestService _manifestService = SongManifestService();

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _searchController.addListener(_filterSongs);
  }

  Future<void> _loadSongs() async {
    final loadedSongs = await _manifestService.loadSongs();
    setState(() {
      _songs = loadedSongs;
      _filteredSongs = _songs;
    });
  }

  void _filterSongs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSongs = _songs.where((song) {
        return song.title.toLowerCase().contains(query) ||
            song.composer.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _showCreateSongDialog() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Song'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Song Name',
                  hintText: 'Enter the name of your song',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'This will create a PDF-only song where you can upload and annotate sheet music.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _createNewSong(nameController.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _createNewSong(String songName) async {
    if (songName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a song name')),
      );
      return;
    }

    Navigator.of(context).pop(); // Close dialog

    // Create a PDF-only song
    final newSong = Song.createPdfOnly(
      title: songName,
      composer: 'Custom',
    );

    try {
      // Save the custom song to local storage
      await _manifestService.saveCustomSong(newSong);
      
      // Refresh the song list to show the new song
      await _loadSongs();

      if (widget.returnSelectedSong) {
        // Return the new song to the previous screen
        Navigator.of(context).pop(newSong);
      } else {
        // Navigate directly to the song viewer
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SongViewerScreen(songPath: newSong.path),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating song: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.returnSelectedSong ? 'Select a Song for Practice' : 'Select a Song'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateSongDialog,
            tooltip: 'Create New Song',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by title or composer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredSongs.length,
              itemBuilder: (context, index) {
                final song = _filteredSongs[index];
                return ListTile(
                  title: Text(song.title),
                  subtitle: Text(song.composer),
                  onTap: () {
                    if (widget.returnSelectedSong) {
                      // Return the selected song to the previous screen
                      Navigator.of(context).pop(song);
                    } else {
                      // Navigate to chord player screen (original behavior)
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            SongViewerScreen(songPath: song.path),
                      ));
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
