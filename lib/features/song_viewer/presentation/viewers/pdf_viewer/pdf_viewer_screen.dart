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

// Import new label system
import 'models/label_base.dart' as base_models;
import 'models/extension_label.dart' as models;
import 'models/roman_numeral_label.dart' as roman_models;

// Import control widgets
import 'widgets/label_controls/roman_numeral_label_controls.dart';
import 'widgets/label_controls/extension_label_controls.dart';

// Import transcription viewer
import '../transcription_viewer.dart';
import '../../../data/models/song.dart';

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
  bool _isDisposed = false;
  

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize the ImagePainterController
    _imagePainterController = ImagePainterController();
    
    // Add listeners for auto-save functionality
    _imagePainterController.addListener(_onDrawingChanged);
    _imagePainterController.addListener(_onLabelChanged);
    
    _loadSavedPDF();
  }

  /// Load previously saved PDF path
  Future<void> _loadSavedPDF() async {
    try {
      // Use a simple file-based approach for PDF paths
      final file = await _getPDFPathFile();
      String? savedPath;
      if (await file.exists()) {
        final savedFileName = await file.readAsString();
        debugPrint('Loaded PDF filename from file: $savedFileName');
        
        // Reconstruct full path using current Documents directory
        final directory = await getApplicationDocumentsDirectory();
        savedPath = '${directory.path}/$savedFileName';
        debugPrint('Reconstructed PDF path: $savedPath');
        debugPrint('Checking if file exists: ${File(savedPath).existsSync()}');
      } else {
        debugPrint('PDF path file does not exist at: ${file.path}');
      }
      if (savedPath != null && savedPath.isNotEmpty && File(savedPath).existsSync()) {
        debugPrint('Found saved PDF path: $savedPath');
        await _loadPDF(savedPath);
      } else {
        debugPrint('PDF was not found');
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
      // Save only the filename, not the full path
      final fileName = path.split('/').last;
      await file.writeAsString(fileName);
      debugPrint('Saved PDF filename to file: $fileName');
      debugPrint('File location: ${file.path}');
    } catch (e) {
      debugPrint('Error saving PDF path: $e');
    }
  }

  /// Reinitialize the ImagePainterController for a new PDF
  void _reinitializeController() {
    // Safety check to prevent double disposal
    if (_isDisposed) return;
    
    try {
      // Remove listeners from current controller if it exists
      try {
        _imagePainterController.removeListener(_onDrawingChanged);
        _imagePainterController.removeListener(_onLabelChanged);
      } catch (e) {
        debugPrint('Error removing listeners from old controller: $e');
      }
      
      // Dispose current controller safely
      try {
        _imagePainterController.dispose();
      } catch (e) {
        debugPrint('Error disposing old controller: $e');
      }
      
      // Create new controller
      _imagePainterController = ImagePainterController();
      
      // Add listeners to new controller
      _imagePainterController.addListener(_onDrawingChanged);
      _imagePainterController.addListener(_onLabelChanged);
      
      debugPrint('ImagePainterController reinitialized successfully');
    } catch (e) {
      debugPrint('Error reinitializing ImagePainterController: $e');
      // Create a fresh controller as fallback
      _imagePainterController = ImagePainterController();
      _imagePainterController.addListener(_onDrawingChanged);
      _imagePainterController.addListener(_onLabelChanged);
    }
  }

  /// Load PDF file and convert first page to image
  Future<void> _loadPDF(String path) async {
    try {
      setState(() {
        _isLoading = true;
        _isReady = false;
      });

      // Reinitialize the ImagePainterController for the new PDF
      _reinitializeController();

      // Copy PDF to app documents directory for permanent storage
      String permanentPdfPath = path;
      if (!path.startsWith((await getApplicationDocumentsDirectory()).path)) {
        permanentPdfPath = await _copyPDFToDocuments(path);
      }

      // Close existing PDF if open - with better error handling
      if (_converter.isOpen) {
        try {
          await _converter.closePdf();
          debugPrint('Successfully closed existing PDF');
        } catch (e) {
          debugPrint('Error closing existing PDF (continuing anyway): $e');
          // Continue with loading new PDF even if close fails
        }
      }

      // Open PDF with converter
      await _converter.openPdf(permanentPdfPath);
      
      // Get page count
      _totalPages = _converter.pageCount;
      _currentPage = 0;
      
      // Convert current page to image
      await _loadCurrentPageImage();
      
      // Save permanent PDF path
      await _savePDFPath(permanentPdfPath);
      
      setState(() {
        _pdfPath = permanentPdfPath;
        _isReady = true;
        _isLoading = false;
      });
      
      // Load drawings for current page
      await _loadDrawingDataForCurrentPage();
      await _loadLabels();
      
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

  /// Copy PDF file to app documents directory for permanent storage
  Future<String> _copyPDFToDocuments(String originalPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeFilename = _getSafeFilename(widget.songAssetPath);
    final fileName = '${safeFilename}_pdf.pdf';
    final permanentFile = File('${directory.path}/$fileName');
    
    // Copy original file to documents directory
    final originalFile = File(originalPath);
    await originalFile.copy(permanentFile.path);
    
    debugPrint('Copied PDF to permanent location: ${permanentFile.path}');
    return permanentFile.path;
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
      
      // Delete the copied PDF file
      if (_pdfPath != null) {
        final pdfFile = File(_pdfPath!);
        if (await pdfFile.exists()) {
          await pdfFile.delete();
          debugPrint('Deleted PDF file: $_pdfPath');
        }
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
      await _saveLabels(); // Save current page labels
      _currentPage++;
      await _loadCurrentPageImage();
      await _loadDrawingDataForCurrentPage();
      await _loadLabels();
      setState(() {});
    }
  }

  /// Navigate to previous page
  Future<void> _previousPage() async {
    if (_currentPage > 0) {
      await _saveDrawingData(); // Save current page drawings
      await _saveLabels(); // Save current page labels
      _currentPage--;
      await _loadCurrentPageImage();
      await _loadDrawingDataForCurrentPage();
      await _loadLabels();
      setState(() {});
    }
  }


  /// Save drawing data for current page
  Future<void> _saveDrawingData() async {
    if (!mounted || _pdfPath == null || !_isReady || _currentPageImage == null) return;
    
    try {
      // Safety check to prevent usage after disposal
      if (_isDisposed) return;
      
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
    if (!mounted || _pdfPath == null || !_isReady) return;
    
    try {
      // Safety check to prevent usage after disposal
      if (_isDisposed) return;
      
      // Load PaintInfo data using LocalStorageService
      final safeFilename = _getSafeFilename(widget.songAssetPath);
      final paintHistory = await LocalStorageService.loadPDFDrawingsForSongPage(
        safeFilename,
        _currentPage,
      );
      
      if (paintHistory.isNotEmpty && mounted && !_isDisposed) {
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

  /// Save labels for current page
  Future<void> _saveLabels() async {
    if (_pdfPath == null || !_isReady) return;
    
    try {
      await LocalStorageService.saveLabelsForPage(
        widget.songAssetPath,
        _currentPage,
        _imagePainterController.labels,
      );
      debugPrint('Labels: Saved ${_imagePainterController.labels.length} labels for page $_currentPage');
    } catch (e) {
      debugPrint('Error saving labels: $e');
    }
  }

  /// Load labels for current page
  Future<void> _loadLabels() async {
    if (_pdfPath == null || !_isReady) return;
    
    try {
      final labelsData = await LocalStorageService.loadLabelsForPage(
        widget.songAssetPath,
        _currentPage,
      );
      
      final extensionLabels = <ExtensionLabel>[];
      final romanLabels = <RomanNumeralLabel>[];
      
      for (final labelData in labelsData) {
        final Map<String, dynamic> data = labelData as Map<String, dynamic>;
        final labelType = data['labelType'] as String;
        
        if (labelType == 'extension') {
          extensionLabels.add(ExtensionLabel.fromJson(data));
        } else if (labelType == 'romanNumeral') {
          romanLabels.add(RomanNumeralLabel.fromJson(data));
        }
      }
      
      // Clear existing labels
      _imagePainterController.clearExtensionLabels();
      
      // Add loaded labels
      final allLabels = <Label>[];
      allLabels.addAll(extensionLabels);
      allLabels.addAll(romanLabels);
      for (final label in allLabels) {
        _imagePainterController.labels.add(label);
      }
      debugPrint('Labels: Loaded ${allLabels.length} labels for page $_currentPage');
    } catch (e) {
      debugPrint('Error loading labels: $e');
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
                    romanNumeralControlsWidget: RomanNumeralLabelControls(
                      controller: _imagePainterController,
                    ),
                    extensionLabelControlsWidget: ExtensionLabelControls(
                      controller: _imagePainterController,
                    ),
                  ),
          ),
        ),

        // Page navigation controls
        _buildPageNavigator(),
      ],
    );
  }

  /// Build page navigation controls
  Widget _buildPageNavigator() {
    if (_totalPages < 2) return const SizedBox.shrink();

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
                    // Left spacer for centering
                    Opacity(
                      opacity: 0.0, // Invisible but takes up space
                      child: _buildTranscribeButton(),
                    ),
                    
                    // Center: Books and Upload buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBooksButton(),
                        const SizedBox(width: 12),
                        _buildUploadButton(),
                      ],
                    ),
                    
                    // Right side: Transcribe button
                    _buildTranscribeButton(),
                  ],
                );
              } else {
                // Narrow screen: wrapped layout
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left spacer for centering
                    Opacity(
                      opacity: 0.0, // Invisible but takes up space
                      child: _buildTranscribeButton(),
                    ),
                    
                    // Center: Books and Upload buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBooksButton(),
                        const SizedBox(width: 8),
                        _buildUploadButton(),
                      ],
                    ),
                    
                    // Right side: Transcribe button
                    _buildTranscribeButton(),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }


  Widget _buildBooksButton() {
    return ClayContainer(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: _showBooksDialog,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Books',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
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

  Widget _buildTranscribeButton() {
    return GestureDetector(
      onTap: _openTranscriptionViewer,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library,
              color: Theme.of(context).colorScheme.secondary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'Transcribe',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _openTranscriptionViewer() {
    // Create a Song object from the available data
    final song = Song(
      title: widget.practiceArea?.name ?? 'Unknown Song',
      composer: 'Unknown Composer',
      path: widget.songAssetPath,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TranscriptionViewer(song: song),
      ),
    );
  }

  @override
  void dispose() {
    // Mark as disposed to prevent further usage
    _isDisposed = true;
    
    // Immediately remove listeners and dispose controller synchronously
    _imagePainterController.removeListener(_onDrawingChanged);
    _imagePainterController.removeListener(_onLabelChanged);
    _imagePainterController.dispose();
    
    // Close PDF converter if open
    if (_converter.isOpen) {
      _converter.closePdf().catchError((e) {
        debugPrint('Error closing PDF converter during disposal: $e');
      });
    }
    
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

  /// Get the full path for a book from its filename
  Future<String?> _getBookPath(Map<String, dynamic> book) async {
    try {
      final fileName = book['fileName'] as String?;
      if (fileName == null) {
        // Legacy books might still have 'path' - try to extract filename
        final oldPath = book['path'] as String?;
        if (oldPath != null) {
          final legacyFileName = oldPath.split('/').last;
          final directory = await getApplicationDocumentsDirectory();
          final fullPath = '${directory.path}/$legacyFileName';
          
          if (File(fullPath).existsSync()) {
            // Update book to use fileName instead of path
            final updatedBook = Map<String, dynamic>.from(book);
            updatedBook['fileName'] = legacyFileName;
            updatedBook.remove('path');
            await LocalStorageService.updateBook(book['id'], updatedBook);
            return fullPath;
          }
        }
        return null;
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final fullPath = '${directory.path}/$fileName';
      
      if (File(fullPath).existsSync()) {
        return fullPath;
      } else {
        debugPrint('Book file not found: $fullPath');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting book path: $e');
      return null;
    }
  }

  /// Called when drawing changes to auto-save
  void _onDrawingChanged() {
    // Safety check to prevent usage after disposal
    if (!mounted || _isDisposed) return;
    
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

  /// Called when labels change to auto-save
  void _onLabelChanged() {
    // Safety check to prevent usage after disposal
    if (!mounted || _isDisposed) return;
    
    // Debounce auto-save to avoid excessive saves
    if (_isReady && _pdfPath != null) {
      // Use a small delay to batch rapid changes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isReady && _pdfPath != null) {
          _saveLabels();
        }
      });
    }
  }

  /// Show dialog to select from registered books or register a new book
  void _showBooksDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Books',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Books list (placeholder for now)
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadBooks(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final books = snapshot.data ?? [];
                      
                      if (books.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No books registered',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Register a new book to get started',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          final book = books[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.menu_book),
                              title: Text(book['name'] ?? 'Unknown Book'),
                              subtitle: Text('${book['pageCount'] ?? 0} pages'),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () => _showBookOptions(book),
                              ),
                              onTap: () => _selectFromBook(book),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Register new book button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _registerNewBook,
                    icon: const Icon(Icons.add),
                    label: const Text('Register New Book'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  /// Load registered books from local storage
  Future<List<Map<String, dynamic>>> _loadBooks() async {
    try {
      final books = await LocalStorageService.loadBooks();
      // Clean up any books whose files no longer exist
      await _cleanupMissingBooks(books);
      return books;
    } catch (e) {
      debugPrint('Error loading books: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Clean up books whose files no longer exist
  Future<void> _cleanupMissingBooks(List<Map<String, dynamic>> books) async {
    final directory = await getApplicationDocumentsDirectory();
    final booksToRemove = <String>[];
    
    for (final book in books) {
      final fileName = book['fileName'] as String? ?? 
                     (book['path'] as String?)?.split('/').last;
      
      if (fileName != null) {
        final fullPath = '${directory.path}/$fileName';
        if (!File(fullPath).existsSync()) {
          debugPrint('Removing orphaned book: ${book['name']} (file not found)');
          booksToRemove.add(book['id']);
        }
      }
    }
    
    // Remove orphaned books
    for (final bookId in booksToRemove) {
      try {
        await LocalStorageService.deleteBook(bookId);
      } catch (e) {
        debugPrint('Error removing orphaned book $bookId: $e');
      }
    }
  }

  /// Get the page count of a PDF file
  Future<int> _getPDFPageCount(String pdfPath) async {
    PdfImageConverter? tempConverter;
    try {
      // Create a temporary converter instance to get page count
      tempConverter = PdfImageConverter();
      await tempConverter.openPdf(pdfPath);
      final pageCount = tempConverter.pageCount;
      return pageCount;
    } catch (e) {
      debugPrint('Error getting PDF page count: $e');
      return 1; // Default to 1 page if we can't determine the count
    } finally {
      // Always dispose the temporary converter
      if (tempConverter != null) {
        try {
          await tempConverter.closePdf();
        } catch (e) {
          debugPrint('Error closing temporary PDF converter: $e');
        }
      }
    }
  }

  /// Register a new book
  void _registerNewBook() {
    Navigator.of(context).pop(); // Close books dialog
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final nameController = TextEditingController();
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Register New Book',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Book Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _uploadAndRegisterBook(nameController.text),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Upload and register a new book
  Future<void> _uploadAndRegisterBook(String bookName) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    
    if (bookName.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a book name')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        navigator.pop(); // Close register dialog
        
        final pdfPath = result.files.single.path!;
        
        // Copy to permanent storage and get page count
        final permanentPath = await _copyPDFToDocuments(pdfPath);
        
        // Get page count by temporarily loading the PDF
        int pageCount = await _getPDFPageCount(permanentPath);
        
        // Save book to storage (store only filename, not full path)
        final fileName = permanentPath.split('/').last;
        final book = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': bookName.trim(),
          'fileName': fileName, // Store filename instead of full path
          'pageCount': pageCount,
          'registeredDate': DateTime.now().toIso8601String(),
        };
        
        // Save to LocalStorageService
        await LocalStorageService.addBook(book);
        debugPrint('Registered book: $book');
        
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Book "$bookName" registered successfully!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error registering book: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error registering book: $e')),
        );
      }
    }
  }

  /// Select pages from a book
  void _selectFromBook(Map<String, dynamic> book) async {
    try {
      debugPrint('Selecting from book: ${book['name']}');
      Navigator.of(context).pop(); // Close books dialog
      
      final bookPath = await _getBookPath(book);
      final pageCount = book['pageCount'] as int? ?? 1;
      
      debugPrint('Book path: $bookPath, Page count: $pageCount');
      
      if (bookPath != null) {
        // Always show page selector to let user choose what they want to load
        debugPrint('Showing page selector for book');
        // Add a small delay to ensure the previous dialog is fully closed
        await Future.delayed(const Duration(milliseconds: 200));
        _showPageSelector(book);
      } else {
        // Book file not found
        debugPrint('Book file not found: ${book['name']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Book "${book['name']}" file not found. It may have been deleted.'),
              action: SnackBarAction(
                label: 'Remove',
                onPressed: () => _deleteBook(book),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error selecting from book: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading book: $e')),
        );
      }
    }
  }

  /// Show page selector dialog with actual page previews
  void _showPageSelector(Map<String, dynamic> book) async {
    try {
      debugPrint('_showPageSelector called for book: ${book['name']}');
      final pageCount = book['pageCount'] as int? ?? 1;
      final bookPath = await _getBookPath(book);
      
      debugPrint('Page selector - pageCount: $pageCount, bookPath: $bookPath');
      
      if (bookPath == null) {
        debugPrint('Book path is null, showing error message');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Book "${book['name']}" file not found.')),
          );
        }
        return;
      }
      
      if (!mounted) {
        debugPrint('Widget not mounted, returning early');
        return;
      }
      
      debugPrint('About to show page selector dialog');
      
      showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
            padding: const EdgeInsets.all(20),
            child: PageSelectorWidget(
              book: book,
              bookPath: bookPath,
              pageCount: pageCount,
              onPageSelected: (pageIndex) {
                Navigator.of(context).pop();
                _loadBookPage(bookPath, pageIndex);
              },
              onLoadEntireBook: () {
                Navigator.of(context).pop();
                _loadPDF(bookPath);
              },
            ),
          ),
        );
      },
    );
    } catch (e) {
      debugPrint('Error in _showPageSelector: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error showing page selector: $e')),
        );
      }
    }
  }

  /// Load a specific page from a book
  Future<void> _loadBookPage(String bookPath, int pageIndex) async {
    try {
      setState(() {
        _isLoading = true;
        _isReady = false;
      });

      // Reinitialize the ImagePainterController for the new PDF
      _reinitializeController();

      // Close current PDF if open - with better error handling
      if (_converter.isOpen) {
        try {
          await _converter.closePdf();
          debugPrint('Successfully closed existing PDF for book page');
        } catch (e) {
          debugPrint('Error closing existing PDF for book page (continuing anyway): $e');
          // Continue with loading new PDF even if close fails
        }
      }

      // Open PDF with converter
      await _converter.openPdf(bookPath);
      
      // Get page count and set to specific page
      _totalPages = _converter.pageCount;
      _currentPage = pageIndex;
      
      // Convert specific page to image
      await _loadCurrentPageImage();
      
      // Save the permanent PDF path (book path is already permanent)
      await _savePDFPath(bookPath.split('/').last);
      
      setState(() {
        _pdfPath = bookPath;
        _isReady = true;
        _isLoading = false;
      });
      
      // Load drawings for current page
      await _loadDrawingDataForCurrentPage();
      await _loadLabels();
      
    } catch (e) {
      debugPrint('Error loading book page: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading page: $e')),
        );
      }
    }
  }

  /// Show options for a book (edit name, delete, etc.)
  void _showBookOptions(Map<String, dynamic> book) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Rename Book'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _renameBook(book);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Book'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteBook(book);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Rename a book
  void _renameBook(Map<String, dynamic> book) {
    final controller = TextEditingController(text: book['name']);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename Book'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Book Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                
                final newName = controller.text.trim();
                if (newName.isNotEmpty && newName != book['name']) {
                  try {
                    final updatedBook = Map<String, dynamic>.from(book);
                    updatedBook['name'] = newName;
                    await LocalStorageService.updateBook(book['id'], updatedBook);
                    
                    if (mounted) {
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Book renamed successfully!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error renaming book: $e')),
                      );
                    }
                  }
                } else {
                  navigator.pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Delete a book
  void _deleteBook(Map<String, dynamic> book) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Book'),
          content: Text('Are you sure you want to delete "${book['name']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                
                try {
                  await LocalStorageService.deleteBook(book['id']);
                  
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Book deleted successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error deleting book: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

/// Widget for selecting pages from a book with actual page previews
class PageSelectorWidget extends StatefulWidget {
  final Map<String, dynamic> book;
  final String bookPath;
  final int pageCount;
  final Function(int pageIndex) onPageSelected;
  final VoidCallback onLoadEntireBook;

  const PageSelectorWidget({
    super.key,
    required this.book,
    required this.bookPath,
    required this.pageCount,
    required this.onPageSelected,
    required this.onLoadEntireBook,
  });

  @override
  State<PageSelectorWidget> createState() => _PageSelectorWidgetState();
}

class _PageSelectorWidgetState extends State<PageSelectorWidget> {
  late PdfImageConverter _previewConverter;
  final Map<int, Uint8List?> _pagePreviewCache = {};
  final Set<int> _selectedPages = {};
  bool _isGridView = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _previewConverter = PdfImageConverter();
    _initializePreviews();
  }

  Future<void> _initializePreviews() async {
    try {
      await _previewConverter.openPdf(widget.bookPath);
      setState(() {
        _isLoading = false;
      });
      debugPrint('Preview converter initialized for ${widget.pageCount} pages');
    } catch (e) {
      debugPrint('Error initializing preview converter: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Uint8List?> _getPagePreview(int pageIndex) async {
    if (_pagePreviewCache.containsKey(pageIndex)) {
      return _pagePreviewCache[pageIndex];
    }

    try {
      final preview = await _previewConverter.renderPage(pageIndex);
      _pagePreviewCache[pageIndex] = preview;
      return preview;
    } catch (e) {
      debugPrint('Error rendering page $pageIndex preview: $e');
      return null;
    }
  }

  @override
  void dispose() {
    if (_previewConverter.isOpen) {
      _previewConverter.closePdf().catchError((e) {
        debugPrint('Error closing preview converter: $e');
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with view toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.book['name'] ?? 'Unknown Book',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Select pages to load (${_selectedPages.length} selected)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                // View toggle
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Pages view
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isGridView
                  ? _buildGridView()
                  : _buildListView(),
        ),
        
        const SizedBox(height: 16),
        
        // Action buttons
        Row(
          children: [
            if (_selectedPages.isNotEmpty) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadSelectedPages,
                  icon: const Icon(Icons.check, color: Colors.white),
  
                  label: Text(
                    'Load Selected (${_selectedPages.length})',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onLoadEntireBook,
                icon: const Icon(Icons.menu_book),
                label: const Text('Load Entire Book'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: widget.pageCount,
      itemBuilder: (context, index) => _buildPagePreview(index),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: widget.pageCount,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 120,
          child: _buildPagePreview(index, isListView: true),
        ),
      ),
    );
  }

  Widget _buildPagePreview(int index, {bool isListView = false}) {
    final pageNumber = index + 1;
    final isSelected = _selectedPages.contains(index);
    
    return Card(
      elevation: isSelected ? 8 : 2,
      color: isSelected 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : null,
      child: InkWell(
        onTap: () => _togglePageSelection(index),
        onDoubleTap: () => widget.onPageSelected(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: isListView ? _buildListPageContent(index, pageNumber, isSelected)
                           : _buildGridPageContent(index, pageNumber, isSelected),
        ),
      ),
    );
  }

  Widget _buildGridPageContent(int index, int pageNumber, bool isSelected) {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<Uint8List?>(
            future: _getPagePreview(index),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasData && snapshot.data != null) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                );
              }
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text('Preview unavailable', style: Theme.of(context).textTheme.bodySmall),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Page $pageNumber',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildListPageContent(int index, int pageNumber, bool isSelected) {
    return Row(
      children: [
        // Page preview
        SizedBox(
          width: 80,
          child: FutureBuilder<Uint8List?>(
            future: _getPagePreview(index),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasData && snapshot.data != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                  ),
                );
              }
              
              return Icon(
                Icons.picture_as_pdf,
                size: 40,
                color: Colors.grey[400],
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        // Page info
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Page $pageNumber',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                'Tap to select, double-tap to load',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // Selection indicator
        if (isSelected)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            ),
          ),
      ],
    );
  }

  void _togglePageSelection(int pageIndex) {
    setState(() {
      if (_selectedPages.contains(pageIndex)) {
        _selectedPages.remove(pageIndex);
      } else {
        _selectedPages.add(pageIndex);
      }
    });
  }

  void _loadSelectedPages() {
    if (_selectedPages.isEmpty) return;
    
    // For now, load the first selected page
    // You can extend this to handle multiple page selection
    final firstSelectedPage = _selectedPages.first;
    widget.onPageSelected(firstSelectedPage);
  }
}