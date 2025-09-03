import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_painter/image_painter.dart';

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
    // Create a new controller for the fullscreen viewer
    _controller = ImagePainterController();
    // Defer copying drawing data until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _copyDrawingData();
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  /// Convert relative coordinate to fullscreen coordinate
  Offset _relativeToFullscreen(Offset relativeCoord) {
    final screenSize = MediaQuery.of(context).size;
    return Offset(
      relativeCoord.dx * screenSize.width,
      relativeCoord.dy * screenSize.height,
    );
  }
  
  /// Convert fullscreen coordinate to relative coordinate  
  Offset _fullscreenToRelative(Offset screenCoord) {
    final screenSize = MediaQuery.of(context).size;
    return Offset(
      (screenCoord.dx / screenSize.width).clamp(0.0, 1.0),
      (screenCoord.dy / screenSize.height).clamp(0.0, 1.0),
    );
  }
  
  /// Copy paint info with coordinate conversion
  PaintInfo _convertPaintInfo(PaintInfo original) {
    final convertedOffsets = original.offsets.map((offset) {
      return offset != null ? _relativeToFullscreen(offset) : null;
    }).toList();
    
    return PaintInfo(
      mode: original.mode,
      offsets: convertedOffsets,
      color: original.color,
      strokeWidth: original.strokeWidth,
      text: original.text,
      fill: original.fill,
    );
  }
  
  /// Copy drawing data from source controller with coordinate conversion
  void _copyDrawingData() {
    // Copy paint history with coordinate conversion
    for (final paintInfo in widget.sourceController.paintHistory) {
      _controller.addPaintInfo(_convertPaintInfo(paintInfo));
    }
    
    // Copy labels with coordinate conversion
    for (final label in widget.sourceController.labels) {
      if (label is ExtensionLabel) {
        final convertedLabel = ExtensionLabel(
          id: label.id,
          position: _relativeToFullscreen(label.position),
          number: label.number,
          size: label.size,
          color: label.color,
          isSelected: label.isSelected,
        );
        _controller.labels.add(convertedLabel);
      } else if (label is RomanNumeralLabel) {
        final convertedLabel = RomanNumeralLabel(
          id: label.id,
          position: _relativeToFullscreen(label.position),
          romanNumeral: label.romanNumeral,
          size: label.size,
          color: label.color,
          isSelected: label.isSelected,
        );
        _controller.labels.add(convertedLabel);
      }
    }
  }
  
  /// Copy paint info back with coordinate conversion (fullscreen to relative)
  PaintInfo _convertPaintInfoBack(PaintInfo original) {
    final convertedOffsets = original.offsets.map((offset) {
      return offset != null ? _fullscreenToRelative(offset) : null;
    }).toList();
    
    return PaintInfo(
      mode: original.mode,
      offsets: convertedOffsets,
      color: original.color,
      strokeWidth: original.strokeWidth,
      text: original.text,
      fill: original.fill,
    );
  }

  /// Copy changes back to source controller when exiting fullscreen
  void _copyChangesBack() {
    // Clear source controller's current data
    widget.sourceController.clear();
    
    // Copy updated paint history back with coordinate conversion
    for (final paintInfo in _controller.paintHistory) {
      widget.sourceController.addPaintInfo(_convertPaintInfoBack(paintInfo));
    }
    
    // Copy labels back with coordinate conversion
    widget.sourceController.labels.clear();
    for (final label in _controller.labels) {
      if (label is ExtensionLabel) {
        final convertedLabel = ExtensionLabel(
          id: label.id,
          position: _fullscreenToRelative(label.position),
          number: label.number,
          size: label.size,
          color: label.color,
          isSelected: label.isSelected,
        );
        widget.sourceController.labels.add(convertedLabel);
      } else if (label is RomanNumeralLabel) {
        final convertedLabel = RomanNumeralLabel(
          id: label.id,
          position: _fullscreenToRelative(label.position),
          romanNumeral: label.romanNumeral,
          size: label.size,
          color: label.color,
          isSelected: label.isSelected,
        );
        widget.sourceController.labels.add(convertedLabel);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main fullscreen image painter
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (widget.onPageChange != null) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > 500) {
                  // Swipe right - go to previous page
                  widget.onPageChange!(-1);
                } else if (velocity < -500) {
                  // Swipe left - go to next page
                  widget.onPageChange!(1);
                }
              }
            },
            child: SizedBox.expand(
              child: ImagePainter.memory(
                widget.pageImage,
                controller: _controller,
                scalable: true,
                showControls: false,
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
        ],
      ),
    );
  }
}