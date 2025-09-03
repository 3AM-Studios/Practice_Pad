import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_painter/image_painter.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/features/song_viewer/presentation/viewers/pdf_viewer/widgets/label_controls/extension_label_controls.dart';
import 'package:practice_pad/features/song_viewer/presentation/viewers/pdf_viewer/widgets/label_controls/roman_numeral_label_controls.dart';

/// Dedicated fullscreen PDF viewer page
class FullscreenPDFViewer extends StatefulWidget {
  final ImagePainterController sourceController; // Source controller to copy data from
  final Uint8List pageImage; // The current page image data
  final Function(int)? onPageChange; // Callback for page navigation
  final VoidCallback? onExit; // Callback when exiting fullscreen

  const FullscreenPDFViewer({
    super.key,
    required this.sourceController,
    required this.pageImage,
    this.onPageChange,
    this.onExit,
  });

  @override
  State<FullscreenPDFViewer> createState() => _FullscreenPDFViewerState();
}

class _FullscreenPDFViewerState extends State<FullscreenPDFViewer> {
  late ImagePainterController _controller;
  
  @override
  void initState() {
    super.initState();
    debugPrint('=== FULLSCREEN INIT: Starting initialization ===');
    // Create a new controller for the fullscreen viewer
    _controller = ImagePainterController();
    debugPrint('FULLSCREEN INIT: Created new controller');
    
    // Add listener to track controller changes
    _controller.addListener(() {
      debugPrint('FULLSCREEN CONTROLLER: Listener triggered - paintHistory: ${_controller.paintHistory.length}, labels: ${_controller.labels.length}');
    });
    
    // Defer copying drawing data until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('FULLSCREEN INIT: PostFrameCallback executing');
      _copyDrawingData();
    });
  }
  
  @override
  void dispose() {
    debugPrint('=== FULLSCREEN DISPOSE: Starting disposal ===');
    _controller.dispose();
    super.dispose();
    debugPrint('=== FULLSCREEN DISPOSE: Disposal completed ===');
  }
  
  
  /// Copy drawing data from source controller
  void _copyDrawingData() {
    debugPrint('=== FULLSCREEN COPY: Starting data copy ===');
    debugPrint('FULLSCREEN COPY: Source controller - paintHistory: ${widget.sourceController.paintHistory.length}, labels: ${widget.sourceController.labels.length}');
    
    // Copy paint history directly without coordinate conversion
    for (final paintInfo in widget.sourceController.paintHistory) {
      _controller.addPaintInfo(paintInfo);
      debugPrint('FULLSCREEN COPY: Added paintInfo to controller');
    }
    
    // Copy labels directly without coordinate conversion
    for (final label in widget.sourceController.labels) {
      _controller.labels.add(label);
      debugPrint('FULLSCREEN COPY: Added label to controller: ${label.runtimeType}');
    }
    
    debugPrint('FULLSCREEN COPY: Final controller state - paintHistory: ${_controller.paintHistory.length}, labels: ${_controller.labels.length}');
    debugPrint('=== FULLSCREEN COPY: Data copy completed ===');
  }
  

  /// Copy changes back to source controller when exiting fullscreen
  void _copyChangesBack() {
    // Clear source controller's current data
    widget.sourceController.clear();
    
    // Copy updated paint history back directly without coordinate conversion
    for (final paintInfo in _controller.paintHistory) {
      widget.sourceController.addPaintInfo(paintInfo);
    }
    
    // Copy labels back directly without coordinate conversion
    widget.sourceController.labels.clear();
    for (final label in _controller.labels) {
      widget.sourceController.labels.add(label);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('=== FULLSCREEN BUILD: Widget building, controller ready: ${_controller.paintHistory.isNotEmpty || _controller.labels.isNotEmpty} ===');
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main fullscreen image painter with touch debug
          SizedBox.expand(
            child: GestureDetector(
              onTapDown: (details) {
                debugPrint('=== FULLSCREEN TOUCH: TapDown detected at ${details.localPosition} ===');
              },
              onPanStart: (details) {
                debugPrint('=== FULLSCREEN TOUCH: PanStart detected at ${details.localPosition} ===');
              },
              onTap: () {
                debugPrint('=== FULLSCREEN TOUCH: Tap detected ===');
              },
              behavior: HitTestBehavior.translucent,
              child: ImagePainter.memory(
                widget.pageImage,
                controller: _controller,
                scalable: true,
                controlsAtTop: false,
                showControls: true,
                textDelegate: TextDelegate() ,
                enableFullscreen: true,
                selectedColor: Theme.of(context).colorScheme.primary  ,
                unselectedColor: Theme.of(context).colorScheme.onSurface      ,
                optionColor: Theme.of(context).colorScheme.onSurface   ,
                romanNumeralControlsWidget: RomanNumeralLabelControls(controller: _controller) ,
                extensionLabelControlsWidget: ExtensionLabelControls(controller: _controller),
                controlsBackgroundColor: Colors.transparent,
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                key: UniqueKey(), // Add unique key to avoid hero tag conflicts
              ),
            ),
          ),
          
          // Exit fullscreen button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: () {
                    debugPrint('=== FULLSCREEN OVERLAY: Exit button tapped ===');
                    // Copy any changes made in fullscreen back to the source controller
                    _copyChangesBack();
                    widget.onExit?.call();
                    Navigator.of(context).pop();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.fullscreen_exit,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Navigation arrows container
          if (widget.onPageChange != null)
            Positioned(
              bottom: 80,
              right: 20,
              child: ClayContainer(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: 8,
                depth: 4,
                spread: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Left arrow
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                        onTap: () {
                          debugPrint('=== FULLSCREEN OVERLAY: Previous page button tapped ===');
                          widget.onPageChange!(-1);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.chevron_left,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    // Divider
                    Container(
                      width: 1,
                      height: 48,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    ),
                    // Right arrow
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        onTap: () {
                          debugPrint('=== FULLSCREEN OVERLAY: Next page button tapped ===');
                          widget.onPageChange!(1);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}