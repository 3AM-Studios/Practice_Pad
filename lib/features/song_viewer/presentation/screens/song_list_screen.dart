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
                            SongViewerScreen(songAssetPath: song.path),
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
