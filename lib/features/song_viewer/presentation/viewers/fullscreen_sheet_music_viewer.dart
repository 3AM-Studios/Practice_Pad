import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_sheet/simple_sheet_music.dart' as music_sheet;
import 'package:music_sheet/index.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:clay_containers/clay_containers.dart';

import '../widgets/measure/chord_measure.dart';

/// Dedicated fullscreen sheet music viewer page
class FullscreenSheetMusicViewer extends StatefulWidget {
  final List<ChordMeasure> measures;
  final double initialCanvasScale;
  final bool extensionNumbersRelativeToChords;
  final KeySignatureType initialKeySignatureType;
  final DrawingController? drawingController;
  final ValueNotifier<bool>? isDrawingModeNotifier;
  final VoidCallback? onExit;

  // Interaction callbacks
  final Function(MusicalSymbol, int, int)? onSymbolAdd;
  final Function(MusicalSymbol, int, int)? onSymbolUpdate;
  final Function(int, int)? onSymbolDelete;
  final Function(dynamic, int)? onChordSymbolTap;
  final Function(dynamic, int)? onChordSymbolLongPress;
  final Function(dynamic, int, LongPressEndDetails?)? onChordSymbolLongPressEnd;
  final Function(dynamic, int)? onChordSymbolHover;
  final bool Function(int)? isChordSelected;
  final Function(PointerUpEvent)? onDrawingPointerUp;

  const FullscreenSheetMusicViewer({
    super.key,
    required this.measures,
    required this.initialCanvasScale,
    required this.extensionNumbersRelativeToChords,
    required this.initialKeySignatureType,
    this.drawingController,
    this.isDrawingModeNotifier,
    this.onExit,
    this.onSymbolAdd,
    this.onSymbolUpdate,
    this.onSymbolDelete,
    this.onChordSymbolTap,
    this.onChordSymbolLongPress,
    this.onChordSymbolLongPressEnd,
    this.onChordSymbolHover,
    this.isChordSelected,
    this.onDrawingPointerUp,
  });

  @override
  State<FullscreenSheetMusicViewer> createState() => _FullscreenSheetMusicViewerState();
}

class _FullscreenSheetMusicViewerState extends State<FullscreenSheetMusicViewer> {
  late double _canvasScale;
  late List<ChordMeasure> _measures;
  bool _showControls = false;


  @override
  void initState() {
    super.initState();
    _canvasScale = widget.initialCanvasScale;
    _measures = List<ChordMeasure>.from(widget.measures); // Create a copy
    // Set fullscreen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _zoomIn() {
    setState(() {
      _canvasScale = (_canvasScale + 0.1).clamp(0.2, 1.2);
    });
  }

  void _zoomOut() {
    setState(() {
      _canvasScale = (_canvasScale - 0.1).clamp(0.2, 1.2);
    });
  }

  void _insertSymbolAtPosition(MusicalSymbol symbol, int measureIndex, int positionIndex) {
    if (measureIndex < 0 || measureIndex >= _measures.length) return;

    setState(() {
      final newMeasures = List<ChordMeasure>.from(_measures);
      final targetMeasure = newMeasures[measureIndex];
      final newSymbols = List<MusicalSymbol>.from(targetMeasure.musicalSymbols);

      if (positionIndex >= 0 && positionIndex <= newSymbols.length) {
        newSymbols.insert(positionIndex, symbol);

        newMeasures[measureIndex] = ChordMeasure(
          newSymbols,
          chordSymbols: targetMeasure.chordSymbols,
          isNewLine: targetMeasure.isNewLine,
        );

        _measures = newMeasures;
      }
    });
    widget.onSymbolAdd?.call(symbol, measureIndex, positionIndex);
  }

  void _updateSymbolAtPosition(MusicalSymbol symbol, int measureIndex, int positionIndex) {
    if (measureIndex < 0 || measureIndex >= _measures.length) return;

    setState(() {
      final newMeasures = List<ChordMeasure>.from(_measures);
      final targetMeasure = newMeasures[measureIndex];
      final newSymbols = List<MusicalSymbol>.from(targetMeasure.musicalSymbols);

      if (positionIndex >= 0 && positionIndex < newSymbols.length) {
        newSymbols[positionIndex] = symbol;

        newMeasures[measureIndex] = ChordMeasure(
          newSymbols,
          chordSymbols: targetMeasure.chordSymbols,
          isNewLine: targetMeasure.isNewLine,
        );

        _measures = newMeasures;
      }
    });
    widget.onSymbolUpdate?.call(symbol, measureIndex, positionIndex);
  }

  void _deleteSymbolAtPosition(int measureIndex, int positionIndex) {
    if (measureIndex < 0 || measureIndex >= _measures.length) return;

    setState(() {
      final newMeasures = List<ChordMeasure>.from(_measures);
      final targetMeasure = newMeasures[measureIndex];
      final newSymbols = List<MusicalSymbol>.from(targetMeasure.musicalSymbols);

      if (positionIndex >= 0 && positionIndex < newSymbols.length) {
        newSymbols.removeAt(positionIndex);

        newMeasures[measureIndex] = ChordMeasure(
          newSymbols,
          chordSymbols: targetMeasure.chordSymbols,
          isNewLine: targetMeasure.isNewLine,
        );

        _measures = newMeasures;
      }
    });
    widget.onSymbolDelete?.call(measureIndex, positionIndex);
  }

  @override
  void dispose() {
    // Restore system UI when exiting fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main fullscreen sheet music
          SizedBox.expand(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: music_sheet.SimpleSheetMusic(
                key: const ValueKey('fullscreen_sheet_music'),
                width: screenSize.width * 1.5, // Wider for better layout
                
                measures: _measures.cast<music_sheet.Measure>(),
                debug: false,
                initialKeySignatureType: widget.initialKeySignatureType,
                canvasScale: _canvasScale,
                extensionNumbersRelativeToChords: widget.extensionNumbersRelativeToChords,
                onSymbolAdd: _insertSymbolAtPosition,
                onSymbolUpdate: _updateSymbolAtPosition,
                onSymbolDelete: _deleteSymbolAtPosition,
                onChordSymbolTap: widget.onChordSymbolTap,
                onChordSymbolLongPress: widget.onChordSymbolLongPress,
                onChordSymbolLongPressEnd: widget.onChordSymbolLongPressEnd,
                onChordSymbolHover: widget.onChordSymbolHover,
                isChordSelected: widget.isChordSelected,
                drawingController: widget.drawingController,
                isDrawingModeNotifier: widget.isDrawingModeNotifier,
                onDrawingPointerUp: widget.onDrawingPointerUp,
              ),
            ),
          ),

          // UI Controls Toggle
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trigger button
                ClayContainer(
                  color: Colors.white,
                  borderRadius: 30,
                  depth: 10,
                  spread: 3,
                  child: IconButton(
                    icon: const Icon(
                      Icons.tune,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _showControls = !_showControls;
                      });
                    },
                    tooltip: 'Show Controls',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                
                // Conditionally visible controls
                if (_showControls) ...[
                  const SizedBox(height: 16),
                  // Exit fullscreen button
                  ClayContainer(
                    color: Colors.white,
                    borderRadius: 15,
                    depth: 10,
                    spread: 3,
                    child: IconButton(
                      icon: const Icon(
                        Icons.fullscreen_exit,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        widget.onExit?.call();
                        Navigator.of(context).pop();
                      },
                      tooltip: 'Exit Fullscreen',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Canvas scale controls
                  ClayContainer(
                    color: Colors.white,
                    borderRadius: 15,
                    depth: 10,
                    spread: 3,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_in, size: 18, color: Colors.grey),
                          onPressed: _zoomIn,
                          tooltip: 'Zoom In',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: const EdgeInsets.all(6),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: Text(
                            '${(_canvasScale * 100).round()}%',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_out, size: 18, color: Colors.grey),
                          onPressed: _zoomOut,
                          tooltip: 'Zoom Out',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: const EdgeInsets.all(6),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}