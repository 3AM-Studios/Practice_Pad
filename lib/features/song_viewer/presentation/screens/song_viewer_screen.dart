import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/widgets/active_session_banner.dart';
import 'package:practice_pad/features/song_viewer/presentation/viewers/simple_sheet_music_viewer.dart';
import 'package:practice_pad/features/song_viewer/presentation/viewers/pdf_viewer/pdf_viewer_screen.dart';

enum ViewerMode { simpleSheetMusic, pdf }

class SongViewerScreen extends StatefulWidget {
  final String songAssetPath;
  final int bpm;
  final PracticeArea? practiceArea;

  const SongViewerScreen({
    super.key,
    required this.songAssetPath,
    this.bpm = 120,
    this.practiceArea,
  });

  @override
  State<SongViewerScreen> createState() => _SongViewerScreenState();
}

class _SongViewerScreenState extends State<SongViewerScreen> {
  late ViewerMode _currentMode;
  late SimpleSheetMusicViewer? _sheetMusicViewer;
  late PDFViewer _pdfViewer;
  late bool _isPdfOnly;
  
  // Keys to maintain state across mode switches
  final GlobalKey _sheetMusicKey = GlobalKey();
  final GlobalKey _pdfKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    
    // Check if this is a PDF-only song (custom song)
    _isPdfOnly = widget.songAssetPath.startsWith('custom://pdf_only/');
    
    // Set initial mode based on song type
    _currentMode = _isPdfOnly ? ViewerMode.pdf : ViewerMode.simpleSheetMusic;
    
    // Initialize viewers based on song type
    if (!_isPdfOnly) {
      // Initialize sheet music viewer for regular songs
      _sheetMusicViewer = SimpleSheetMusicViewer(
        key: _sheetMusicKey,
        songAssetPath: widget.songAssetPath,
        bpm: widget.bpm,
        practiceArea: widget.practiceArea,
        onStateChanged: () {
          setState(() {
            // Rebuild the parent to update toolbar
          });
        },
      );
    } else {
      _sheetMusicViewer = null;
    }
    
    // Always initialize PDF viewer
    _pdfViewer = PDFViewer(
      key: _pdfKey,
      songAssetPath: widget.songAssetPath,
      bpm: widget.bpm,
      practiceArea: widget.practiceArea,
    );
    
    // Ensure toolbar appears after initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // Returns the current toolbar based on mode
  Widget _buildToolbar() {
    switch (_currentMode) {
      case ViewerMode.simpleSheetMusic:
        if (_sheetMusicViewer == null) {
          return const SizedBox(height: 60); // No toolbar for PDF-only songs
        }
        // Use a post-frame callback to ensure the widget is built
        return (_sheetMusicKey.currentState as dynamic)?.buildToolbar() ?? 
               const SizedBox(height: 60); // Placeholder while loading
      case ViewerMode.pdf:
        // Use a post-frame callback to ensure the widget is built
        return (_pdfKey.currentState as dynamic)?.buildToolbar() ?? 
               const SizedBox(height: 60); // Placeholder while loading
    }
  }

  // Returns the current content based on mode
  Widget _buildContent() {
    switch (_currentMode) {
      case ViewerMode.simpleSheetMusic:
        if (_sheetMusicViewer == null) {
          return const Center(
            child: Text('Sheet music not available for custom songs'),
          );
        }
        return _sheetMusicViewer!;
      case ViewerMode.pdf:
        return _pdfViewer;
    }
  }

  // Builds the mode toggle button for the AppBar
  Widget _buildModeToggle() {
    // Don't show mode toggle for PDF-only songs
    if (_isPdfOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'PDF Only',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<ViewerMode>(
      icon: Icon(
        _currentMode == ViewerMode.simpleSheetMusic 
          ? Icons.library_music 
          : Icons.picture_as_pdf,
      ),
      onSelected: (ViewerMode mode) {
        setState(() {
          _currentMode = mode;
        });
        // Force rebuild after next frame to ensure toolbar appears
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<ViewerMode>(
          value: ViewerMode.simpleSheetMusic,
          child: Row(
            children: [
              Icon(
                Icons.library_music,
                color: _currentMode == ViewerMode.simpleSheetMusic 
                  ? Theme.of(context).colorScheme.primary 
                  : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Sheet Music',
                style: TextStyle(
                  color: _currentMode == ViewerMode.simpleSheetMusic 
                    ? Theme.of(context).colorScheme.primary 
                    : null,
                  fontWeight: _currentMode == ViewerMode.simpleSheetMusic 
                    ? FontWeight.bold 
                    : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<ViewerMode>(
          value: ViewerMode.pdf,
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf,
                color: _currentMode == ViewerMode.pdf 
                  ? Theme.of(context).colorScheme.primary 
                  : null,
              ),
              const SizedBox(width: 8),
              Text(
                'PDF View',
                style: TextStyle(
                  color: _currentMode == ViewerMode.pdf 
                    ? Theme.of(context).colorScheme.primary 
                    : null,
                  fontWeight: _currentMode == ViewerMode.pdf 
                    ? FontWeight.bold 
                    : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    final surfaceColor = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Song Viewer',
          style: TextStyle(
            fontSize: 18,
            color: onSurfaceColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: surfaceColor,
        iconTheme: IconThemeData(color: onSurfaceColor),
        actions: [
          _buildModeToggle(),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Toolbar section
                _buildToolbar(),
                const SizedBox(height: 20),
                // Content section
                _buildContent(),
                const SizedBox(height: 20),
                
                // Practice-related widgets (shared between modes)
                const ActiveSessionBanner(),
                _buildPracticeItemsWidget(),
                _buildGeneralPracticeItemButton(),
                
                const SizedBox(height: 20), // Bottom padding for scroll
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Practice-related widgets (shared between modes)
  Widget _buildPracticeItemsWidget() => const SizedBox.shrink();
  
  Widget _buildGeneralPracticeItemButton() {
    if (widget.practiceArea == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: ClayContainer(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: 20,
        depth: 5,
        curveType: CurveType.convex,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Add Practice Item',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}