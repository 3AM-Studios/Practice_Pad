import 'dart:async';

import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/services/local_storage_service.dart';

/// PDF viewer widget with separate drawing persistence using _pdf suffix
class PDFViewer extends StatefulWidget {
  final String songAssetPath;
  final int bpm;
  final PracticeArea? practiceArea;

  const PDFViewer({
    super.key,
    required this.songAssetPath,
    this.bpm = 120,
    this.practiceArea,
  });

  @override
  State<PDFViewer> createState() => _PDFViewerState();
}

class _PDFViewerState extends State<PDFViewer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Static controller disposal locks to prevent race conditions
  static final Map<String, Completer<void>> _controllerDisposalLocks = {};
  
  // Static map to store stable GlobalKeys per song
  static final Map<String, GlobalKey> _drawingGlobalKeys = {};
  
  bool _isLoading = true;
  
  // Drawing functionality
  late ValueNotifier<bool> _isDrawingModeNotifier;
  late DrawingController _drawingController;
  late GlobalKey _drawingKey;
  Color _currentDrawingColor = Colors.black;
  double _currentStrokeWidth = 2.0;

  // PDF viewer specific controls
  double _pdfScale = 1.0;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    
    // Register for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Initialize drawing functionality
    _isDrawingModeNotifier = ValueNotifier<bool>(false);
    
    // Use PDF suffix for separate drawing persistence
    final drawingKeyPath = '${widget.songAssetPath}_pdf';
    
    _drawingKey = _drawingGlobalKeys.putIfAbsent(
      drawingKeyPath,
      () => GlobalKey(debugLabel: 'drawing_$drawingKeyPath'),
    );
    
    // Initialize controller after waiting for any pending disposal
    _initializeControllerSafely();
    _isLoading = false; // Placeholder - no actual loading for now
  }

  /// Safely initialize the drawing controller, waiting for any pending disposal
  Future<void> _initializeControllerSafely() async {
    final drawingKeyPath = '${widget.songAssetPath}_pdf';
    
    // Wait for any pending disposal of previous controller for this song
    if (_controllerDisposalLocks.containsKey(drawingKeyPath)) {
      await _controllerDisposalLocks[drawingKeyPath]!.future;
    }
    
    // Now safe to create new controller with stable GlobalKey
    _drawingController = DrawingController(
      uniqueId: drawingKeyPath,
      globalKey: _drawingKey,
    );

    // Set default drawing style
    _drawingController.setStyle(
      color: _currentDrawingColor,
      strokeWidth: _currentStrokeWidth,
    );
    
    // Load any existing drawings
    await _loadDrawingData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    return Column(
      children: [
        const SizedBox(height: 20),

        // Drawing controls (shown when in drawing mode)
        ValueListenableBuilder<bool>(
          valueListenable: _isDrawingModeNotifier,
          builder: (context, isDrawingMode, child) {
            if (isDrawingMode) {
              return Center(child: _buildDrawingControls());
            }
            return const SizedBox.shrink();
          },
        ),

        // PDF Display placeholder
        Container(
          height: 600,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ClayContainer(
            color: surfaceColor,
            borderRadius: 20,
            depth: 10,
            spread: 3,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'PDF Viewer',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coming Soon',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'This will display PDF sheet music with:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• PDF rendering & navigation\n'
                          '• Independent annotation system\n'
                          '• Zoom & page controls\n'
                          '• Separate drawing persistence',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Path: ${widget.songAssetPath.split('/').last}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  /// Returns toolbar widget for main screen
  Widget buildToolbar() {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClayContainer(
        color: surfaceColor,
        borderRadius: 20,
        depth: 10,
        spread: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Main controls with responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                // Check if we have enough width for single row layout
                final isWideScreen = constraints.maxWidth > 600;

                if (isWideScreen) {
                  // Wide screen: single row layout
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildPDFControls(),
                      _buildZoomAndDrawControls(surfaceColor),
                      _buildPageControls(surfaceColor),
                    ],
                  );
                } else {
                  // Narrow screen: wrapped layout
                  return Column(
                    children: [
                      // Top row: PDF controls and page controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPDFControls(),
                          _buildPageControls(surfaceColor),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Bottom row: Zoom/draw controls centered
                      Center(child: _buildZoomAndDrawControls(surfaceColor)),
                    ],
                  );
                }
              },
            ),
          ]),
        ),
      ),
    );
  }


  Widget _buildPDFControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.picture_as_pdf,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'PDF Mode',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomAndDrawControls(Color surfaceColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zoom controls
        ClayContainer(
          color: surfaceColor,
          borderRadius: 8,
          child: IconButton(
            icon: const Icon(Icons.zoom_in, size: 20),
            onPressed: _zoomIn,
            tooltip: 'Zoom In',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(4),
          ),
        ),
        const SizedBox(width: 4),
        ClayContainer(
          color: surfaceColor,
          borderRadius: 8,
          child: IconButton(
            icon: const Icon(Icons.zoom_out, size: 20),
            onPressed: _zoomOut,
            tooltip: 'Zoom Out',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(4),
          ),
        ),
        const SizedBox(width: 8),
        // Drawing mode toggle button
        ValueListenableBuilder<bool>(
          valueListenable: _isDrawingModeNotifier,
          builder: (context, isDrawingMode, child) {
            return ClayContainer(
              color: isDrawingMode
                  ? Colors.blue.withOpacity(0.8)
                  : surfaceColor,
              borderRadius: 8,
              child: IconButton(
                icon: Icon(
                  isDrawingMode ? Icons.edit_off : Icons.draw,
                  size: 20,
                  color: isDrawingMode ? Colors.white : null,
                ),
                onPressed: () {
                  _isDrawingModeNotifier.value = !_isDrawingModeNotifier.value;
                  
                  // Save drawing state when exiting drawing mode
                  if (!_isDrawingModeNotifier.value) {
                    _saveDrawingData();
                  }
                },
                tooltip: isDrawingMode ? 'Exit Drawing Mode' : 'Enter Drawing Mode',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(4),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPageControls(Color surfaceColor) {
    return ClayContainer(
      color: surfaceColor,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_left),
              onPressed: _previousPage,
              tooltip: 'Previous Page',
            ),
            Text('$_currentPage / $_totalPages'),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_right),
              onPressed: _nextPage,
              tooltip: 'Next Page',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawingControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('PDF Drawing Controls (Coming Soon)'),
    );
  }

  // Control methods
  void _zoomIn() {
    setState(() {
      _pdfScale = (_pdfScale + 0.1).clamp(0.5, 3.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _pdfScale = (_pdfScale - 0.1).clamp(0.5, 3.0);
    });
  }

  void _previousPage() {
    setState(() {
      _currentPage = (_currentPage - 1).clamp(1, _totalPages);
    });
  }

  void _nextPage() {
    setState(() {
      _currentPage = (_currentPage + 1).clamp(1, _totalPages);
    });
  }

  /// Load saved drawing data from local storage with PDF suffix
  Future<void> _loadDrawingData() async {
    try {
      if (!mounted) return;
      
      final drawingKeyPath = '${widget.songAssetPath}_pdf';
      final drawingData = await LocalStorageService.loadDrawingsForSong(drawingKeyPath);
      
      if (drawingData.isNotEmpty && mounted) {
        final paintContents = LocalStorageService.drawingJsonToPaintContents(drawingData);
        if (paintContents.isNotEmpty) {
          _drawingController.clear();
          _drawingController.addContents(paintContents);
        }
      }
    } catch (e) {
      print('Error loading PDF drawings: $e');
    }
  }

  /// Save drawing data to local storage with PDF suffix
  Future<void> _saveDrawingData() async {
    try {
      if (!mounted) return;
      
      final drawingKeyPath = '${widget.songAssetPath}_pdf';
      final jsonData = _drawingController.getJsonList();
      await LocalStorageService.saveDrawingsForSong(drawingKeyPath, jsonData);
    } catch (e) {
      print('Error saving PDF drawings: $e');
    }
  }

  @override
  void dispose() {
    _disposeControllerSafely();
    _isDrawingModeNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _disposeControllerSafely() {
    final drawingKeyPath = '${widget.songAssetPath}_pdf';
    
    // Create a completer to track disposal completion
    final completer = Completer<void>();
    _controllerDisposalLocks[drawingKeyPath] = completer;
    
    () async {
      try {
        await _saveDrawingData();
        _drawingController.dispose();
      } catch (error) {
        print('Error during PDF viewer disposal: $error');
      } finally {
        completer.complete();
        Future.delayed(const Duration(milliseconds: 100), () {
          _controllerDisposalLocks.remove(drawingKeyPath);
        });
      }
    }();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveDrawingData();
    }
  }
}