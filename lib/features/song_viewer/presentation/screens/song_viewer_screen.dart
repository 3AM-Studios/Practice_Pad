import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/features/practice/presentation/pages/practice_session_screen.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/widgets/active_session_banner.dart';
import 'package:practice_pad/features/song_viewer/presentation/viewers/simple_sheet_music_viewer.dart';
import 'package:practice_pad/features/song_viewer/presentation/viewers/pdf_viewer/pdf_viewer_screen.dart';
import 'package:practice_pad/features/edit_items/presentation/pages/practice_items_screen.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:provider/provider.dart';

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
  bool _isFullscreen = false; // Track fullscreen state
  
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
    
    // Always initialize PDF viewer with fullscreen callback
    _pdfViewer = PDFViewer(
      key: _pdfKey,
      songAssetPath: widget.songAssetPath,
      bpm: widget.bpm,
      practiceArea: widget.practiceArea,
      onFullscreenChanged: (isFullscreen) {
        setState(() {
          _isFullscreen = isFullscreen;
        });
      },
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

    // If in fullscreen mode, show only the content widget
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildContent(),
      );
    }

    // Normal mode - show full layout
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
                _currentMode == ViewerMode.pdf ?  const SizedBox.shrink() : const SizedBox(height: 12),
                // Content section
                _buildContent(),
                const SizedBox(height: 20),
                
                // Practice-related widgets (shared between modes)
                _buildAddProgressionButton(),
                const ActiveSessionBanner(),
                _buildPracticeItemsWidget(),
                
                
                const SizedBox(height: 20), // Bottom padding for scroll
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Practice-related widgets (shared between modes)
  Widget _buildPracticeItemsWidget() {
    if (widget.practiceArea == null ||
        widget.practiceArea!.practiceItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;

    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: ClayContainer(
        color: surfaceColor,
        borderRadius: 15,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => _navigateToEditItems(context),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Practice Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: primaryColor.withOpacity(0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: widget.practiceArea!.practiceItems.length,
                itemBuilder: (context, index) {
                  final practiceItem =
                      widget.practiceArea!.practiceItems[index];
                  return GestureDetector(
                      onTap: () async {
                        // Start a practice session for this item
                        await Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => PracticeSessionScreen(
                              practiceItem: practiceItem,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 12, bottom: 12),
                        child: ClayContainer(
                          color: Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: 20,
                          curveType: CurveType.none,
                          child: Container(
                            // decoration: BoxDecoration(
                            //   image: const DecorationImage(
                            //     image: AssetImage(
                            //         'assets/images/wood_texture_rotated.jpg'),
                            //     fit: BoxFit.cover,
                            //   ),
                            //   border: Border.all(
                            //       color: Theme.of(context).colorScheme.surface,
                            //       width: 4),
                            //   borderRadius: BorderRadius.circular(20),
                            // ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    practiceItem.name,
                                    style:  TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                  ),
                                  if (practiceItem.description.isNotEmpty) ...[
                                     const SizedBox(height: 6),
                                    Text(
                                      practiceItem.description,
                                      style:  TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEditItems(BuildContext context) {
    if (widget.practiceArea == null) return;
    
    // Get EditItemsViewModel instance
    final editItemsViewModel = Provider.of<EditItemsViewModel>(context, listen: false);
    
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: editItemsViewModel,
          child: PracticeItemsScreen(practiceArea: widget.practiceArea!),
        ),
      ),
    );
  }

  Widget _buildAddProgressionButton() {
    // Only show if we have a practice area and selected chords
    if (widget.practiceArea == null) {
      return const SizedBox.shrink();
    }

    // Check if we're in sheet music mode and have selected chords
    final hasSelectedChords = _currentMode == ViewerMode.simpleSheetMusic && 
        _sheetMusicViewer != null && 
        (_sheetMusicKey.currentState as dynamic)?.hasSelectedChords() == true;

    if (!hasSelectedChords) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: _addSelectedProgressionToPracticeItems,
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
                  'Add Selected Progression',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Adds the selected chord progression to practice items
  Future<void> _addSelectedProgressionToPracticeItems() async {
    if (widget.practiceArea == null || _sheetMusicViewer == null) return;

    try {
      // Get the selected chord progression from the sheet music viewer
      final progression = (_sheetMusicKey.currentState as dynamic)?.getSelectedChordProgression();
      
      if (progression == null) {
        _showErrorDialog('No chord progression selected');
        return;
      }

      // Get the EditItemsViewModel
      final editItemsViewModel = Provider.of<EditItemsViewModel>(context, listen: false);

      // Create a new practice item with the chord progression
      final practiceItem = PracticeItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Chord Progression: ${progression.name}',
        description: 'Chords: ${progression.chords.join(' - ')}',
        chordProgression: progression,
      );

      // Add the practice item to the practice area
      await editItemsViewModel.addPracticeItem(widget.practiceArea!.recordName, practiceItem);

      // Clear the selection in the sheet music viewer
      (_sheetMusicKey.currentState as dynamic)?.clearChordSelection();

      // Show success feedback
      _showSuccessDialog('Chord progression added to practice items!');

    } catch (e) {
      _showErrorDialog('Failed to add chord progression: $e');
    }
  }

  /// Shows an error dialog to the user
  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Shows a success dialog to the user
  void _showSuccessDialog(String message) {
    if (!mounted) return;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}