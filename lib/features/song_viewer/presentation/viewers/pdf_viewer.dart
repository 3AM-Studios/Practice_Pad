import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/services/local_storage_service.dart';
import 'package:pdf_to_image_converter/pdf_to_image_converter.dart';
import 'package:image_painter/image_painter.dart';

/// PDF viewer widget with drawing functionality using PDF-to-image conversion
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
  
  bool _isLoading = true;
  
  // PDF to Image converter
  final PdfImageConverter _converter = PdfImageConverter();
  Uint8List? _currentPageImage;
  
  // Image Painter controller
  late ImagePainterController _imagePainterController;
  
  // PDF viewer specific controls
  int _currentPage = 0; // 0-based indexing for pdf_to_image_converter
  int _totalPages = 0;
  String? _pdfPath;
  bool _isReady = false;
  

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _imagePainterController = ImagePainterController();
    
    // Listen for drawing changes to auto-save
    _imagePainterController.addListener(_onDrawingChanged);
    
    // Listen for extension label changes to auto-save
    _imagePainterController.addListener(_onExtensionLabelChanged);
    
    _loadSavedPDF();
  }

  /// Load previously saved PDF path
  Future<void> _loadSavedPDF() async {
    try {
      // Use a simple file-based approach for PDF paths
      final file = await _getPDFPathFile();
      String? savedPath;
      if (await file.exists()) {
        savedPath = await file.readAsString();
      }
      if (savedPath != null && savedPath.isNotEmpty && File(savedPath).existsSync()) {
        await _loadPDF(savedPath);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved PDF: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Save PDF path to storage
  Future<void> _savePDFPath(String path) async {
    try {
      final file = await _getPDFPathFile();
      await file.writeAsString(path);
    } catch (e) {
      debugPrint('Error saving PDF path: $e');
    }
  }

  /// Load PDF file and convert first page to image
  Future<void> _loadPDF(String path) async {
    try {
      setState(() {
        _isLoading = true;
        _isReady = false;
      });

      // Open PDF with converter
      await _converter.openPdf(path);
      
      // Get page count
      _totalPages = _converter.pageCount;
      _currentPage = 0;
      
      // Convert current page to image
      await _loadCurrentPageImage();
      
      // Save PDF path
      await _savePDFPath(path);
      
      setState(() {
        _pdfPath = path;
        _isReady = true;
        _isLoading = false;
      });
      
      // Load drawings for current page
      await _loadDrawingDataForCurrentPage();
      await _loadExtensionLabels();
      
    } catch (e) {
      debugPrint('Error loading PDF: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading PDF: $e')),
        );
      }
    }
  }

  /// Load current page as image
  Future<void> _loadCurrentPageImage() async {
    try {
      final pageImage = await _converter.renderPage(_currentPage);
      if (pageImage != null) {
        setState(() {
          _currentPageImage = pageImage;
        });
        debugPrint('Loaded page $_currentPage image (${pageImage.length} bytes)');
      }
    } catch (e) {
      debugPrint('Error loading page image: $e');
    }
  }

  /// Upload PDF file
  Future<void> _uploadPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await _loadPDF(result.files.single.path!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF loaded successfully!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading PDF: $e')),
        );
      }
    }
  }

  /// Remove current PDF
  Future<void> _removePDF() async {
    try {
      // Close PDF in converter
      if (_converter.isOpen) {
        await _converter.closePdf();
      }
      
      // Clear saved path
      await _savePDFPath('');
      
      setState(() {
        _pdfPath = null;
        _currentPage = 0;
        _totalPages = 0;
        _isReady = false;
        _currentPageImage = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF removed successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error removing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing PDF: $e')),
        );
      }
    }
  }

  /// Navigate to next page
  Future<void> _nextPage() async {
    if (_currentPage < _totalPages - 1) {
      await _saveDrawingData(); // Save current page drawings
      await _saveExtensionLabels(); // Save current page labels
      _currentPage++;
      await _loadCurrentPageImage();
      await _loadDrawingDataForCurrentPage();
      await _loadExtensionLabels();
      setState(() {});
    }
  }

  /// Navigate to previous page
  Future<void> _previousPage() async {
    if (_currentPage > 0) {
      await _saveDrawingData(); // Save current page drawings
      await _saveExtensionLabels(); // Save current page labels
      _currentPage--;
      await _loadCurrentPageImage();
      await _loadDrawingDataForCurrentPage();
      await _loadExtensionLabels();
      setState(() {});
    }
  }


  /// Save drawing data for current page
  Future<void> _saveDrawingData() async {
    if (_pdfPath == null || !_isReady || _currentPageImage == null) return;
    
    try {
      // Save PaintInfo data using LocalStorageService
      final safeFilename = _getSafeFilename(widget.songAssetPath);
      await LocalStorageService.savePDFDrawingsForSongPage(
        safeFilename,
        _currentPage,
        _imagePainterController.paintHistory,
      );
      debugPrint('PDF Drawing: Saved paint history for page $_currentPage');
    } catch (e) {
      debugPrint('Error saving drawing data: $e');
    }
  }

  /// Load drawing data for current page
  Future<void> _loadDrawingDataForCurrentPage() async {
    if (_pdfPath == null || !_isReady) return;
    
    try {
      // Load PaintInfo data using LocalStorageService
      final safeFilename = _getSafeFilename(widget.songAssetPath);
      final paintHistory = await LocalStorageService.loadPDFDrawingsForSongPage(
        safeFilename,
        _currentPage,
      );
      
      if (paintHistory.isNotEmpty) {
        // Clear existing history and add loaded drawings
        _imagePainterController.clear();
        for (final paintInfo in paintHistory) {
          _imagePainterController.addPaintInfo(paintInfo);
        }
        debugPrint('PDF Drawing: Loaded ${paintHistory.length} drawings for page $_currentPage');
      }
    } catch (e) {
      debugPrint('Error loading drawing data: $e');
    }
  }

  /// Save extension labels for current page
  Future<void> _saveExtensionLabels() async {
    if (_pdfPath == null || !_isReady) return;
    
    try {
      final labelsData = _imagePainterController.extensionLabels.map((label) => label.toJson()).toList();
      final file = await _getExtensionLabelsFile(_currentPage);
      await file.writeAsString(jsonEncode(labelsData));
      debugPrint('Extension Labels: Saved ${_imagePainterController.extensionLabels.length} labels for page $_currentPage');
    } catch (e) {
      debugPrint('Error saving extension labels: $e');
    }
  }

  /// Load extension labels for current page
  Future<void> _loadExtensionLabels() async {
    if (_pdfPath == null || !_isReady) return;
    
    try {
      final file = await _getExtensionLabelsFile(_currentPage);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final labelsData = jsonDecode(jsonString) as List<dynamic>;
        
        final labels = <ExtensionLabel>[];
        for (final labelData in labelsData) {
          labels.add(ExtensionLabel.fromJson(labelData as Map<String, dynamic>));
        }
        
        _imagePainterController.setExtensionLabels(labels);
        debugPrint('Extension Labels: Loaded ${labels.length} labels for page $_currentPage');
      } else {
        _imagePainterController.clearExtensionLabels();
      }
    } catch (e) {
      debugPrint('Error loading extension labels: $e');
      _imagePainterController.clearExtensionLabels();
    }
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

        // PDF Display with Drawing
        Container(
          height: 600,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ClayContainer(
            color: surfaceColor,
            borderRadius: 20,
            depth: 10,
            spread: 3,
            child: _pdfPath == null
                ? _buildPDFUploadPrompt()
                : _buildPDFWithDrawing(),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  /// Build PDF upload prompt
  Widget _buildPDFUploadPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Upload PDF',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to select a PDF file to view and annotate',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _uploadPDF,
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose PDF'),
          ),
        ],
      ),
    );
  }

  /// Build PDF with drawing capability
  Widget _buildPDFWithDrawing() {
    return Stack(
      children: [
        // Main PDF + Drawing Area (now handled by image_painter)
        Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _currentPageImage == null
                ? const Center(child: CircularProgressIndicator())
                : ImagePainter.memory(
                    _currentPageImage!,
                    controller: _imagePainterController,
                    scalable: true,
                    textDelegate: TextDelegate(),
                    controlsAtTop: false,
                    showControls: true,
                    controlsBackgroundColor: Colors.transparent,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    unselectedColor: Theme.of(context).colorScheme.onSurface,
                    optionColor: Theme.of(context).colorScheme.onSurface,
                  ),
          ),
        ),

        // Page navigation controls
        _buildPageControls(),
      ],
    );
  }

  /// Build page navigation controls
  Widget _buildPageControls() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _currentPage > 0 ? _previousPage : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${_currentPage + 1} / $_totalPages'),
            IconButton(
              onPressed: _currentPage < _totalPages - 1 ? _nextPage : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }




  /// Returns toolbar widget for main screen
  Widget buildToolbar() {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ClayContainer(
        color: surfaceColor,
        borderRadius: 20,
        depth: 8,
        spread: 2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Wide screen: horizontal layout
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPDFControls(),
                    _buildToolbarPageControls(),
                    _buildZoomAndDrawControls(surfaceColor),
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
                        _buildToolbarPageControls(),
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
          if (_pdfPath != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _removePDF,
              child: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZoomAndDrawControls(Color surfaceColor) {
    return const SizedBox.shrink(); // Removed drawing controls from toolbar
  }

  @override
  void dispose() {
    _disposeControllerSafely();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _disposeControllerSafely() {
    () async {
      try {
        await _saveDrawingData();
        if (_converter.isOpen) {
          await _converter.closePdf();
        }
        _imagePainterController.removeListener(_onDrawingChanged);
        _imagePainterController.removeListener(_onExtensionLabelChanged);
        _imagePainterController.dispose();
      } catch (error) {
        debugPrint('Error during PDF viewer disposal: $error');
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

  /// Get file for storing PDF path
  Future<File> _getPDFPathFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final safeFilename = _getSafeFilename(widget.songAssetPath);
    return File('${directory.path}/${safeFilename}_pdf_path.txt');
  }

  /// Get file for storing extension labels for a page
  Future<File> _getExtensionLabelsFile(int page) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeFilename = _getSafeFilename(widget.songAssetPath);
    return File('${directory.path}/${safeFilename}_pdf_page_${page}_labels.json');
  }


  /// Convert asset path to safe filename by replacing invalid characters
  String _getSafeFilename(String path) {
    return path
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(':', '_')
        .replaceAll('*', '_')
        .replaceAll('?', '_')
        .replaceAll('"', '_')
        .replaceAll('<', '_')
        .replaceAll('>', '_')
        .replaceAll('|', '_');
  }

  /// Called when drawing changes to auto-save
  void _onDrawingChanged() {
    // Debounce auto-save to avoid excessive saves
    if (_isReady && _pdfPath != null) {
      // Use a small delay to batch rapid changes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isReady && _pdfPath != null) {
          _saveDrawingData();
        }
      });
    }
  }

  /// Called when extension labels change to auto-save
  void _onExtensionLabelChanged() {
    // Debounce auto-save to avoid excessive saves
    if (_isReady && _pdfPath != null) {
      // Use a small delay to batch rapid changes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isReady && _pdfPath != null) {
          _saveExtensionLabels();
        }
      });
    }
  }

  /// Build page controls for toolbar
  Widget _buildToolbarPageControls() {
    if (_pdfPath == null) {
      return ClayContainer(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: 12,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: _uploadPDF,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.upload_file,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Upload PDF',
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

    return ClayContainer(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _currentPage > 0 ? _previousPage : null,
              icon: const Icon(Icons.chevron_left),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(4),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                '${_currentPage + 1} / $_totalPages',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: _currentPage < _totalPages - 1 ? _nextPage : null,
              icon: const Icon(Icons.chevron_right),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(4),
            ),
          ],
        ),
      ),
    );
  }
}