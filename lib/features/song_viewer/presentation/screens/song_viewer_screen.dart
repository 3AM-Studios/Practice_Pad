import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:metronome/metronome.dart';
import 'package:xml/xml.dart';
import 'package:music_sheet/simple_sheet_music.dart' as music_sheet;
import 'package:flutter_drawing_board/flutter_drawing_board.dart';

import 'package:practice_pad/features/song_viewer/presentation/widgets/beat_timeline.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_measure.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/concentric_dial_menu.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/chord_progression.dart';
import 'package:practice_pad/widgets/active_session_banner.dart';
import 'package:practice_pad/features/practice/presentation/pages/practice_session_screen.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:music_sheet/index.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';
import 'package:practice_pad/services/local_storage_service.dart';

class SongViewerScreen extends StatefulWidget {
  final String songAssetPath;
  final int bpm;
  final PracticeArea?
      practiceArea; // Optional practice area for showing practice items

  const SongViewerScreen({
    super.key,
    required this.songAssetPath,
    this.bpm = 120,
    this.practiceArea,
  });

  @override
  State<SongViewerScreen> createState() => _SongViewerScreenState();
}

class _SongViewerScreenState extends State<SongViewerScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  final Metronome _metronome = Metronome();
  StreamSubscription<int>? _tickSubscription;
  final bool _isPlaying = false;

  List<ChordSymbol> _chordSymbols = [];
  List<ChordMeasure> _chordMeasures =
      []; // Combined measures with chord symbols
  final Map<int, int> _globalToLocalIndexMap =
      {}; // Maps sheet music globalChordIndex to _chordSymbols index
  int _currentChordIndex = 0;
  double _totalSongDurationInBeats = 0;
  int _currentBpm = 0;
  String _songTitle = '';

  // Performance optimization: Cache sheet music widget
  Widget? _cachedSheetMusicWidget;
  List<ChordMeasure>? _lastRenderedMeasures;

  // Performance optimization: Use ValueNotifier for beat updates
  late ValueNotifier<int> _beatNotifier;
  late ValueNotifier<int> _songBeatNotifier;
  String _keySignature = '';
  String _originalKey = 'C'; // The original key of the song (for transposition)
  String _timeSignature = '';
  int _beatsPerMeasure = 4; // Default
  int _currentBeatInMeasure = 0;
  final List<double> _userInputBeats = [];
  int _songBeatCounter = 0; // The master logical beat counter for the song

  // Dial menu state for non-diatonic chord reharmonization
  bool _showDialMenu =
      false; // Controls whether the dial menu widget is visible
  List<ChordSymbol>?
      _selectedChordGroup; // The chord group currently selected for key change
  List<int>?
      _selectedChordGroupIndices; // The indices of the selected chord group

  // Chord selection state for practice item creation (temporarily disabled for canvas rendering)
  final Set<int> _selectedChordIndices = <int>{}; // Selected chord indices
  bool _isDragging = false; // Whether user is currently dragging
  int? _dragStartIndex; // Starting index of drag selection
  bool _isLongPressing = false; // Whether user is in long press selection mode
  int? _lastHoveredIndex; // Last chord index that was hovered during drag
  List<GlobalKey> _chordGlobalKeys =
      []; // Keys for chord widgets to get their positions

  // Auto-scroll functionality - removed since parent scroll view was removed
  Timer? _autoScrollTimer;
  Offset? _currentMousePosition;
  final GlobalKey _sheetMusicKey = GlobalKey();

  // Sheet music zoom control
  double _sheetMusicScale = 0.7;

  // Extension numbering control
  bool _extensionNumbersRelativeToChords = true;

  // Drawing functionality
  late ValueNotifier<bool> _isDrawingModeNotifier;
  late DrawingController _drawingController;
  Color _currentDrawingColor = Colors.black;
  double _currentStrokeWidth = 2.0;

  @override
  void initState() {
    super.initState();
    _currentBpm = widget.bpm;

    // Initialize ValueNotifiers for performance optimization
    _beatNotifier = ValueNotifier<int>(0);
    _songBeatNotifier = ValueNotifier<int>(0);

    // Initialize drawing functionality
    _isDrawingModeNotifier = ValueNotifier<bool>(false);
    _drawingController = DrawingController();

    // Set default drawing style - black color and thin stroke
    _drawingController.setStyle(
      color: _currentDrawingColor,
      strokeWidth: _currentStrokeWidth,
    );

    // Load saved drawings
    _loadDrawingData();

    _loadAndParseSong();
    _loadSongViewerSettings();
  }

  /// Load saved song viewer settings from local storage
  Future<void> _loadSongViewerSettings() async {
    try {
      final songChanges =
          await LocalStorageService.loadSongChanges(widget.songAssetPath);
      if (songChanges.isNotEmpty) {
        setState(() {
          if (songChanges.containsKey('canvasScale')) {
            _sheetMusicScale =
                (songChanges['canvasScale'] as double).clamp(0.3, 2.0);
          }
          if (songChanges.containsKey('extensionNumbersRelativeToChords')) {
            _extensionNumbersRelativeToChords =
                songChanges['extensionNumbersRelativeToChords'] as bool;
          }
        });
        developer
            .log('Loaded song viewer settings for ${widget.songAssetPath}');
      }
    } catch (e) {
      developer.log('Error loading song viewer settings: $e');
    }
  }

  /// Save song viewer settings to local storage
  Future<void> _saveSongViewerSettings() async {
    try {
      final settings = {
        'canvasScale': _sheetMusicScale,
        'extensionNumbersRelativeToChords': _extensionNumbersRelativeToChords,
        'lastModified': DateTime.now().toIso8601String(),
      };
      await LocalStorageService.saveSongChanges(widget.songAssetPath, settings);
      developer.log('Saved song viewer settings for ${widget.songAssetPath}');
    } catch (e) {
      developer.log('Error saving song viewer settings: $e');
    }
  }

  /// Load saved drawing data from local storage
  Future<void> _loadDrawingData() async {
    try {
      // For now, we'll implement a simpler approach that works with the current library
      // The drawings will persist during the current session but will be lost on app restart
      // This can be enhanced later with proper JSON deserialization
      developer.log(
          'Drawing persistence placeholder - drawings will persist during session');
    } catch (e) {
      developer.log('Error loading drawing data: $e');
    }
  }

  /// Save drawing data to local storage
  Future<void> _saveDrawingData() async {
    try {
      // Save the JSON data for future implementation of full persistence
      final jsonData = _drawingController.getJsonList();
      final drawingData = {
        'drawingJson': jsonData,
        'lastModified': DateTime.now().toIso8601String(),
      };
      await LocalStorageService.saveSongChanges(
          '${widget.songAssetPath}_drawings', drawingData);
      developer.log(
          'Saved ${jsonData.length} drawing elements for ${widget.songAssetPath}');
    } catch (e) {
      developer.log('Error saving drawing data: $e');
    }
  }

  /// Save non-diatonic chord keys to local storage
  Future<void> _saveChordKeys() async {
    try {
      final chordKeys = <String, dynamic>{};

      // Extract modified key signatures from chord symbols
      for (int i = 0; i < _chordSymbols.length; i++) {
        final chord = _chordSymbols[i];
        if (chord.modifiedKeySignature != null) {
          chordKeys[i.toString()] = {
            'modifiedKeySignature': chord.modifiedKeySignature.toString(),
            'chordRoot': chord.rootName,
            'chordQuality': chord.quality,
          };
        }
      }

      if (chordKeys.isNotEmpty) {
        await LocalStorageService.saveChordKeys(
            widget.songAssetPath, chordKeys);
        developer.log(
            'Saved chord keys for ${chordKeys.length} chords in ${widget.songAssetPath}');
      }
    } catch (e) {
      developer.log('Error saving chord keys: $e');
    }
  }

  /// Load non-diatonic chord keys from local storage
  Future<void> _loadChordKeys() async {
    try {
      final chordKeys =
          await LocalStorageService.loadChordKeys(widget.songAssetPath);
      if (chordKeys.isNotEmpty) {
        setState(() {
          // Apply the loaded key modifications to existing chord symbols
          chordKeys.forEach((indexStr, keyData) {
            final index = int.tryParse(indexStr);
            if (index != null && index < _chordSymbols.length) {
              final keySignatureStr =
                  keyData['modifiedKeySignature'] as String?;
              if (keySignatureStr != null) {
                final keySignature = _stringToKeySignatureType(keySignatureStr);
                if (keySignature != null) {
                  // Create new chord symbol with modified key signature
                  final originalChord = _chordSymbols[index];
                  final modifiedChord = ChordSymbol(
                    originalChord.rootName ?? '',
                    originalChord.quality ?? '',
                    position: originalChord.position,
                    originalKeySignature: originalChord.originalKeySignature,
                    modifiedKeySignature: keySignature,
                  );
                  _chordSymbols[index] = modifiedChord;

                  // Update in measures as well
                  _updateChordInMeasuresAtIndex(index, modifiedChord);
                }
              }
            }
          });
        });
        developer.log(
            'Loaded chord keys for ${chordKeys.length} chords in ${widget.songAssetPath}');
      }
    } catch (e) {
      developer.log('Error loading chord keys: $e');
    }
  }

  // Map of fifths to key signatures
  static const Map<int, String> _fifthsToKey = {
    0: 'C / Am',
    1: 'G / Em',
    2: 'D / Bm',
    3: 'A / F#m',
    4: 'E / C#m',
    5: 'B / G#m',
    6: 'F# / D#m',
    7: 'C# / A#m',
    -1: 'F / Dm',
    -2: 'Bb / Gm',
    -3: 'Eb / Cm',
    -4: 'Ab / Fm',
    -5: 'Db / Bbm',
    -6: 'Gb / Ebm',
    -7: 'Cb / Abm',
  };

  /// Shows the dial menu widget below the key indicator
  void _showDialMenuWidget(List<int> chordGroup) {
    print('🎵 SHOW DIAL MENU: Called with chord group: $chordGroup');

    // Find all consecutive non-diatonic chords starting from the tapped chord
    final sequenceResult =
        _findConsecutiveNonDiatonicSequence(chordGroup.first);
    final consecutiveGroup = sequenceResult['chords'] as List<ChordSymbol>;
    final consecutiveIndices = sequenceResult['indices'] as List<int>;
    print(
        '🎵 SHOW DIAL MENU: Found consecutive group: $consecutiveGroup at indices: $consecutiveIndices');

    setState(() {
      _selectedChordGroup = consecutiveGroup;
      _selectedChordGroupIndices = consecutiveIndices;
    });

    // Show the reharmonization dialog
    _showReharmonizationDialog();

    print('🎵 SHOW DIAL MENU: Set _selectedChordGroup to $consecutiveGroup');
  }

  /// Finds all consecutive non-diatonic chords starting from a given index
  /// Returns both the chord sequence and their indices
  Map<String, List<dynamic>> _findConsecutiveNonDiatonicSequence(
      int startIndex) {
    final List<ChordSymbol> sequence = [];
    final List<int> indices = [];

    if (startIndex >= _chordSymbols.length) {
      return {'chords': sequence, 'indices': indices};
    }

    final startChord = _chordSymbols[startIndex];
    final currentKey = _getCurrentKeySignature();

    // Only proceed if the start chord is non-diatonic
    if (!startChord.isDiatonicTo(currentKey)) {
      sequence.add(startChord);
      indices.add(startIndex);

      // Look forward for consecutive non-diatonic chords
      for (int i = startIndex + 1; i < _chordSymbols.length; i++) {
        final chord = _chordSymbols[i];
        if (!chord.isDiatonicTo(currentKey)) {
          sequence.add(chord);
          indices.add(i);
        } else {
          break; // Stop at first diatonic chord
        }
      }
    }

    return {'chords': sequence, 'indices': indices};
  }

  /// Hides the dial menu widget
  void _hideDialMenuWidget() {
    setState(() {
      _showDialMenu = false;
      _selectedChordGroup = null;
      _selectedChordGroupIndices = null;
    });
  }

  /// Shows the reharmonization dialog for non-diatonic chord sequences
  void _showReharmonizationDialog() {
    if (_selectedChordGroup == null || _selectedChordGroup!.isEmpty) return;

    // Get the current key context for non-diatonic chord
    final currentKey = _getCurrentKeyName();

    // Create the dial menu items with proper arrangement
    final outerItems = _createMajorKeyDialItems(currentKey);
    final innerItems = _createMinorKeyDialItems(currentKey);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConcentricDialMenu(
            size: 350,
            outerItems: outerItems,
            innerItems: innerItems,
            centerText: 'Reharmonize\nSequence',
            onSelectionChanged: (innerIndex, outerIndex) {
              print(
                  '🎵 DIAL MENU: Selection changed - innerIndex: $innerIndex, outerIndex: $outerIndex');

              if (outerIndex != null) {
                final selectedKey = outerItems[outerIndex].label;
                print('🎵 DIAL MENU: Selected major key "$selectedKey"');
                _applyKeyChangeToChordGroup(selectedKey, false);
                Navigator.of(context).pop();
              } else if (innerIndex != null) {
                final selectedKey = innerItems[innerIndex].label;
                print('🎵 DIAL MENU: Selected minor key "$selectedKey"');
                _applyKeyChangeToChordGroup(
                    selectedKey.replaceAll('m', ''), true);
                Navigator.of(context).pop();
              }
            },
            highlightedOuterIndex:
                _getCurrentlyModifiedMajorKeyIndex(outerItems),
            highlightedInnerIndex:
                _getCurrentlyModifiedMinorKeyIndex(innerItems),
          ),
        );
      },
    );
  }

  /// Builds the dial menu widget (now empty since we use dialog)
  Widget _buildDialMenuWidget() {
    return const SizedBox.shrink(); // No longer needed - using dialog instead
  }

  /// Applies a key change to the selected chord group
  void _applyKeyChangeToChordGroup(String keyName, bool isMinor) {
    print(
        '🎵 APPLY KEY CHANGE: Called with keyName="$keyName", isMinor=$isMinor');
    print('🎵 APPLY KEY CHANGE: _selectedChordGroup=$_selectedChordGroup');

    if (_selectedChordGroup == null || _selectedChordGroup!.isEmpty) {
      print('🎵 APPLY KEY CHANGE: No selected chord group, returning');
      return;
    }

    // Convert key name to KeySignatureType
    final newKeySignature = _getKeySignatureFromKeyName(keyName, isMinor);
    if (newKeySignature == null) {
      print('Error: Could not convert key name "$keyName" to KeySignatureType');
      return;
    }

    print('🎵 APPLY KEY CHANGE: New key signature: $newKeySignature');
    print(
        '🎵 APPLY KEY CHANGE: Updating ${_selectedChordGroup!.length} chords');

    setState(() {
      // Apply the modified key signature directly to all chords in the group
      for (int i = 0; i < _selectedChordGroup!.length; i++) {
        final originalChord = _selectedChordGroup![i];
        print(
            '🎵 APPLY KEY CHANGE: Updating chord: ${originalChord.displayText}');

        // Create a new chord with the modified key signature
        ChordSymbol newChord;
        if (originalChord.rootStep != null) {
          // From MusicXML
          newChord = ChordSymbol.fromMusicXML(
            originalChord.rootStep!,
            originalChord.rootAlter ?? 0,
            originalChord.kind!,
            originalChord.durationBeats!,
            originalChord.measureNumber!,
            position: originalChord.position,
            originalKeySignature: originalChord.originalKeySignature,
            modifiedKeySignature: newKeySignature,
          );
          print(
              '🎵 APPLY KEY CHANGE: Created MusicXML chord with modifiedKey: ${newChord.modifiedKeySignature}');
        } else {
          // Direct creation
          newChord = ChordSymbol(
            originalChord.rootName!,
            originalChord.quality!,
            position: originalChord.position,
            originalKeySignature: originalChord.originalKeySignature,
            modifiedKeySignature: newKeySignature,
          );
          print(
              '🎵 APPLY KEY CHANGE: Created direct chord with modifiedKey: ${newChord.modifiedKeySignature}');
        }

        // Update the chord in the selected group
        _selectedChordGroup![i] = newChord;

        // Find and update this chord in all data structures using the specific index
        if (_selectedChordGroupIndices != null &&
            i < _selectedChordGroupIndices!.length) {
          final chordIndex = _selectedChordGroupIndices![i];
          _updateChordAtSpecificIndex(chordIndex, newChord);
        }

        print('🎵 APPLY KEY CHANGE: Updated chord: ${newChord.displayText}');
      }

      // Invalidate sheet music cache since chord symbols have changed
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
      print('🎵 APPLY KEY CHANGE: Invalidated cache');

      // Debug: Print a few chord symbols to verify they have the new modifiedKeySignature
      for (int i = 0; i < math.min(3, _selectedChordGroup!.length); i++) {
        final chord = _selectedChordGroup![i];
        print(
            '🎵 UPDATED CHORD $i: ${chord.effectiveRootName}${chord.effectiveQuality} - originalKey: ${chord.originalKeySignature}, modifiedKey: ${chord.modifiedKeySignature}');
      }
    });

    // Show success message
    final keyDisplayName = isMinor ? '$keyName Minor' : '$keyName Major';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chord group reharmonized in $keyDisplayName'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // Save the chord key modifications
    _saveChordKeys();

    print('🎵 APPLY KEY CHANGE: Complete');
  }

  /// Updates a chord at a specific index in all data structures (_chordSymbols and _chordMeasures)
  void _updateChordAtSpecificIndex(int chordIndex, ChordSymbol newChord) {
    print(
        '🎵 UPDATE SPECIFIC INDEX: Updating chord at index $chordIndex to ${newChord.displaySymbol}');

    if (chordIndex >= 0 && chordIndex < _chordSymbols.length) {
      // Update in flat _chordSymbols list
      final oldChord = _chordSymbols[chordIndex];
      _chordSymbols[chordIndex] = newChord;
      print(
          '🎵 UPDATE SPECIFIC INDEX: Updated _chordSymbols[$chordIndex] from ${oldChord.displaySymbol} to ${newChord.displaySymbol}');
    }

    // Update in _chordMeasures - need to find which measure contains this chord index
    _updateChordInMeasuresAtIndex(chordIndex, newChord);
  }

  /// Updates a specific chord in the measures at a given global chord index
  void _updateChordInMeasuresAtIndex(
      int targetGlobalIndex, ChordSymbol newChord) {
    print(
        '🎵 UPDATE MEASURES AT INDEX: Looking for global index $targetGlobalIndex');
    int globalChordIndex = 0;

    for (int measureIndex = 0;
        measureIndex < _chordMeasures.length;
        measureIndex++) {
      final chordMeasure = _chordMeasures[measureIndex];
      final originalChordSymbols = chordMeasure.chordSymbols;

      // Check if the target index is in this measure
      if (targetGlobalIndex >= globalChordIndex &&
          targetGlobalIndex < globalChordIndex + originalChordSymbols.length) {
        // Found the measure containing our target chord
        final localChordIndex = targetGlobalIndex - globalChordIndex;
        print(
            '🎵 UPDATE MEASURES AT INDEX: Found target at measure $measureIndex, local index $localChordIndex');

        // Create a new list with the updated chord at the specific index
        final updatedChordSymbols =
            List<ChordSymbol>.from(originalChordSymbols);
        updatedChordSymbols[localChordIndex] = newChord;

        // Create a new ChordMeasure with the updated chord symbols
        _chordMeasures[measureIndex] = ChordMeasure(
          chordMeasure.musicalSymbols,
          chordSymbols: updatedChordSymbols,
          isNewLine: chordMeasure.isNewLine,
        );

        print(
            '🎵 UPDATE MEASURES AT INDEX: Updated chord in measure $measureIndex');
        return; // Found and updated, we're done
      }

      globalChordIndex += originalChordSymbols.length;
    }

    print(
        '🎵 UPDATE MEASURES AT INDEX: Target index $targetGlobalIndex not found');
  }

  /// Updates a chord in all data structures (_chordSymbols and _chordMeasures)
  void _updateChordInAllStructures(
      ChordSymbol originalChord, ChordSymbol newChord) {
    print(
        '🎵 UPDATE STRUCTURES: Updating ${originalChord.displaySymbol} -> ${newChord.displaySymbol}');

    // Update in flat _chordSymbols list using property matching instead of object equality
    for (int i = 0; i < _chordSymbols.length; i++) {
      if (_chordsMatch(_chordSymbols[i], originalChord)) {
        _chordSymbols[i] = newChord;
        print(
            '🎵 UPDATE STRUCTURES: Updated _chordSymbols[$i] from ${originalChord.displaySymbol} to ${newChord.displaySymbol}');
      }
    }

    // Update in _chordMeasures
    for (int measureIndex = 0;
        measureIndex < _chordMeasures.length;
        measureIndex++) {
      final chordMeasure = _chordMeasures[measureIndex];
      final chordSymbols = chordMeasure.chordSymbols;

      for (int localIndex = 0; localIndex < chordSymbols.length; localIndex++) {
        if (_chordsMatch(chordSymbols[localIndex], originalChord)) {
          // Create new chord measure with updated chord
          final updatedChordSymbols = List<ChordSymbol>.from(chordSymbols);
          updatedChordSymbols[localIndex] = newChord;

          _chordMeasures[measureIndex] = ChordMeasure(
            chordMeasure.musicalSymbols,
            chordSymbols: updatedChordSymbols,
            isNewLine: chordMeasure.isNewLine,
          );

          print(
              '🎵 UPDATE STRUCTURES: Updated measure $measureIndex, chord $localIndex from ${originalChord.displaySymbol} to ${newChord.displaySymbol}');
          break; // Only update the first match in each measure
        }
      }
    }
  }

  /// Checks if two chord symbols are the same chord based on their properties
  bool _chordsMatch(ChordSymbol chord1, ChordSymbol chord2) {
    return chord1.effectiveRootName == chord2.effectiveRootName &&
        chord1.effectiveQuality == chord2.effectiveQuality &&
        chord1.position == chord2.position &&
        chord1.originalKeySignature == chord2.originalKeySignature;
  }

  /// Builds mapping from sheet music globalChordIndex to _chordSymbols index
  void _buildGlobalIndexMapping() {
    _globalToLocalIndexMap.clear();
    int globalIndex = 0;
    int localIndex = 0;

    // Iterate through measures to match the sheet music widget's logic
    for (int measureIndex = 0;
        measureIndex < _chordMeasures.length;
        measureIndex++) {
      final chordMeasure = _chordMeasures[measureIndex];

      // Skip first measure rendering but count its chords (matching sheet music widget logic)
      if (measureIndex == 0) {
        // Count chords in first measure but don't map them (they're not rendered)
        globalIndex += chordMeasure.chordSymbols.length;
        localIndex += chordMeasure.chordSymbols.length;
        continue;
      }

      // Map each chord in this measure
      for (int chordIndex = 0;
          chordIndex < chordMeasure.chordSymbols.length;
          chordIndex++) {
        _globalToLocalIndexMap[globalIndex] = localIndex;
        globalIndex++;
        localIndex++;
      }
    }

    print('Created mapping: $_globalToLocalIndexMap');
  }

  /// Updates chord symbols in measures to match the flat _chordSymbols list
  /// This ensures that changes to _chordSymbols are reflected in the chord measures
  void _updateChordSymbolsInMeasures() {
    print(
        '🎵 UPDATE MEASURES: Starting update for ${_chordMeasures.length} measures');
    int globalChordIndex = 0;

    for (int measureIndex = 0;
        measureIndex < _chordMeasures.length;
        measureIndex++) {
      final chordMeasure = _chordMeasures[measureIndex];
      final originalChordSymbols = chordMeasure.chordSymbols;

      // Create a new list with updated chord symbols
      final updatedChordSymbols = <ChordSymbol>[];

      for (int localChordIndex = 0;
          localChordIndex < originalChordSymbols.length;
          localChordIndex++) {
        if (globalChordIndex < _chordSymbols.length) {
          // Add the updated chord symbol from _chordSymbols
          updatedChordSymbols.add(_chordSymbols[globalChordIndex]);
          print(
              '🎵 UPDATE MEASURES: Measure $measureIndex, local index $localChordIndex, global index $globalChordIndex: ${_chordSymbols[globalChordIndex].displayText}');
          globalChordIndex++;
        }
      }

      // Create a new ChordMeasure with the updated chord symbols
      _chordMeasures[measureIndex] = ChordMeasure(
        chordMeasure.musicalSymbols,
        chordSymbols: updatedChordSymbols,
        isNewLine: chordMeasure.isNewLine,
      );
    }

    print(
        '🎵 UPDATE MEASURES: Updated chord symbols in ${_chordMeasures.length} measures, processed $globalChordIndex total chords');
  }

  /// Converts a key name string to KeySignatureType enum
  KeySignatureType? _getKeySignatureFromKeyName(String keyName, bool isMinor) {
    // Remove any 'm' suffix for minor keys
    final cleanKeyName = keyName.replaceAll('m', '');

    // Map key names to KeySignatureType based on the available constants
    // Reference the existing _getKeySignatureFromFifths mapping
    final Map<String, List<KeySignatureType>> keyMap = {
      'C': [KeySignatureType.cMajor, KeySignatureType.aMinor],
      'G': [KeySignatureType.gMajor, KeySignatureType.eMinor],
      'D': [KeySignatureType.dMajor, KeySignatureType.bMinor],
      'A': [KeySignatureType.aMajor, KeySignatureType.fSharpMinor],
      'E': [KeySignatureType.eMajor, KeySignatureType.cSharpMinor],
      'B': [KeySignatureType.bMajor, KeySignatureType.gSharpMinor],
      'F#': [KeySignatureType.fSharpMajor, KeySignatureType.dSharpMinor],
      'C#': [KeySignatureType.cSharpMajor, KeySignatureType.aSharpMinor],
      'F': [KeySignatureType.fMajor, KeySignatureType.dMinor],
      'Bb': [KeySignatureType.bFlatMajor, KeySignatureType.gMinor],
      'Eb': [KeySignatureType.eFlatMajor, KeySignatureType.cMinor],
      'Ab': [KeySignatureType.aFlatMajor, KeySignatureType.fMinor],
      'Db': [KeySignatureType.dFlatMajor, KeySignatureType.bFlatMinor],
      'Gb': [KeySignatureType.gFlatMajor, KeySignatureType.eFlatMinor],
      'Cb': [KeySignatureType.cFlatMajor, KeySignatureType.aFlatMinor],
      // Handle minor key names directly
      'Am': [KeySignatureType.cMajor, KeySignatureType.aMinor],
      'Em': [KeySignatureType.gMajor, KeySignatureType.eMinor],
      'Bm': [KeySignatureType.dMajor, KeySignatureType.bMinor],
      'F#m': [KeySignatureType.aMajor, KeySignatureType.fSharpMinor],
      'C#m': [KeySignatureType.eMajor, KeySignatureType.cSharpMinor],
      'G#m': [KeySignatureType.bMajor, KeySignatureType.gSharpMinor],
      'D#m': [KeySignatureType.fSharpMajor, KeySignatureType.dSharpMinor],
      'A#m': [KeySignatureType.cSharpMajor, KeySignatureType.aSharpMinor],
      'Dm': [KeySignatureType.fMajor, KeySignatureType.dMinor],
      'Gm': [KeySignatureType.bFlatMajor, KeySignatureType.gMinor],
      'Cm': [KeySignatureType.eFlatMajor, KeySignatureType.cMinor],
      'Fm': [KeySignatureType.aFlatMajor, KeySignatureType.fMinor],
      'Bbm': [KeySignatureType.dFlatMajor, KeySignatureType.bFlatMinor],
      'Ebm': [KeySignatureType.gFlatMajor, KeySignatureType.eFlatMinor],
      'Abm': [KeySignatureType.cFlatMajor, KeySignatureType.aFlatMinor],
    };

    final keyTypes = keyMap[cleanKeyName] ?? keyMap[keyName];
    if (keyTypes == null) return null;

    return isMinor ? keyTypes[1] : keyTypes[0];
  }

  /// Creates the major key dial items (outer ring) with current key at top
  List<DialItem> _createMajorKeyDialItems(String currentKey) {
    final allMajorKeys = [
      'C',
      'G',
      'D',
      'A',
      'E',
      'B',
      'F#',
      'Db',
      'Ab',
      'Eb',
      'Bb',
      'F'
    ];

    // Find the index of the current key, default to C if not found
    final currentIndex = allMajorKeys.indexOf(currentKey.split(' ')[0]);
    final startIndex = currentIndex != -1 ? currentIndex : 0;

    // Arrange keys so current key is at the top (index 0)
    final orderedKeys = <String>[];
    for (int i = 0; i < allMajorKeys.length; i++) {
      final index = (startIndex + i) % allMajorKeys.length;
      orderedKeys.add(allMajorKeys[index]);
    }

    return orderedKeys
        .map((key) => DialItem(
              label: key,
            ))
        .toList();
  }

  /// Creates the minor key dial items (inner ring) with current key at top
  List<DialItem> _createMinorKeyDialItems(String currentKey) {
    final allMinorKeys = [
      'Am',
      'Em',
      'Bm',
      'F#m',
      'C#m',
      'G#m',
      'D#m',
      'Bbm',
      'Fm',
      'Cm',
      'Gm',
      'Dm'
    ];

    // Extract minor key from current key context
    final isMinorKey = _originalKey.endsWith('m');
    final currentMinorKey = isMinorKey
        ? _originalKey
        : '${_getRelativeMinor(currentKey.split(' ')[0])}m';
    final currentIndex = allMinorKeys.indexOf(currentMinorKey);
    final startIndex = currentIndex != -1 ? currentIndex : 0;

    // Arrange keys so current minor key is at the top (index 0)
    final orderedKeys = <String>[];
    for (int i = 0; i < allMinorKeys.length; i++) {
      final index = (startIndex + i) % allMinorKeys.length;
      orderedKeys.add(allMinorKeys[index]);
    }

    return orderedKeys
        .map((key) => DialItem(
              label: key,
            ))
        .toList();
  }

  /// Gets the current key name
  String _getCurrentKeyName() {
    final keyParts = _keySignature.split(' / ');
    if (keyParts.length == 2) {
      final isMinorKey = _originalKey.endsWith('m');
      return isMinorKey ? keyParts[1].trim() : keyParts[0].trim();
    }
    return keyParts[0].trim();
  }

  /// Gets the relative minor key for a major key
  String _getRelativeMinor(String majorKey) {
    const majorToMinor = {
      'C': 'Am',
      'G': 'Em',
      'D': 'Bm',
      'A': 'F#m',
      'E': 'C#m',
      'B': 'G#m',
      'F#': 'D#m',
      'Db': 'Bbm',
      'Ab': 'Fm',
      'Eb': 'Cm',
      'Bb': 'Gm',
      'F': 'Dm'
    };
    return majorToMinor[majorKey] ?? 'Am';
  }

  /// Gets suggested key for reharmonizing the selected chord group
  Map<String, String> _getSuggestedKeyForChordGroup() {
    if (_selectedChordGroup == null || _selectedChordGroup!.isEmpty) {
      return {'major': 'C', 'minor': 'Am'};
    }

    // Analyze the first chord in the group to suggest a key
    final firstChord = _selectedChordGroup!.first;
    final chordRoot = firstChord.effectiveRootName;

    // Simple heuristic: suggest the chord root as a potential key
    final suggestedMajor = chordRoot;
    final suggestedMinor = _getRelativeMinor(chordRoot);

    return {'major': suggestedMajor, 'minor': suggestedMinor};
  }

  /// Gets the highlighted index for major key in the dial
  int? _getHighlightedMajorKeyIndex(
      String suggestedKey, List<DialItem> outerItems) {
    for (int i = 0; i < outerItems.length; i++) {
      if (outerItems[i].label == suggestedKey) {
        return i;
      }
    }
    return null;
  }

  /// Gets the highlighted index for minor key in the dial
  int? _getHighlightedMinorKeyIndex(
      String suggestedKey, List<DialItem> innerItems) {
    for (int i = 0; i < innerItems.length; i++) {
      if (innerItems[i].label == suggestedKey) {
        return i;
      }
    }
    return null;
  }

  /// Gets the currently modified major key index for highlighting in the dial
  int? _getCurrentlyModifiedMajorKeyIndex(List<DialItem> outerItems) {
    if (_selectedChordGroup == null || _selectedChordGroup!.isEmpty)
      return null;

    // Get the modified key signature from the first chord in the group
    final firstChord = _selectedChordGroup!.first;
    if (firstChord.modifiedKeySignature == null) return null;

    // Convert the modified key signature to a readable key name
    final keyName = _getKeyNameFromSignature(firstChord.modifiedKeySignature!);
    if (keyName.isEmpty) return null;

    // Extract major key name (remove "Major" suffix)
    final majorKeyName = keyName.replaceAll(' Major', '');

    // Find the index in the outer items
    for (int i = 0; i < outerItems.length; i++) {
      if (outerItems[i].label == majorKeyName) {
        return i;
      }
    }
    return null;
  }

  /// Gets the currently modified minor key index for highlighting in the dial
  int? _getCurrentlyModifiedMinorKeyIndex(List<DialItem> innerItems) {
    if (_selectedChordGroup == null || _selectedChordGroup!.isEmpty)
      return null;

    // Get the modified key signature from the first chord in the group
    final firstChord = _selectedChordGroup!.first;
    if (firstChord.modifiedKeySignature == null) return null;

    // Convert the modified key signature to a readable key name
    final keyName = _getKeyNameFromSignature(firstChord.modifiedKeySignature!);
    if (keyName.isEmpty) return null;

    // Extract minor key name (remove "Minor" suffix and add "m")
    final minorKeyName = keyName.replaceAll(' Minor', 'm');

    // Find the index in the inner items
    for (int i = 0; i < innerItems.length; i++) {
      if (innerItems[i].label == minorKeyName) {
        return i;
      }
    }
    return null;
  }

  /// Builds a key change indicator for a specific chord if it starts a new reharmonized group
  Widget? _buildKeyChangeIndicatorForChord(int chordIndex) {
    if (chordIndex >= _chordSymbols.length) return null;

    final chord = _chordSymbols[chordIndex];

    // Only show indicator if this chord has a modified key signature AND is the start of a group
    if (chord.modifiedKeySignature != null &&
        _isStartOfReharmonizedGroup(chordIndex)) {
      final keyName = _getKeyNameFromSignature(chord.modifiedKeySignature!);

      if (keyName.isNotEmpty) {
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            keyName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      }
    }

    return null;
  }

  /// Checks if a chord index is the start of a reharmonized group
  bool _isStartOfReharmonizedGroup(int chordIndex) {
    if (chordIndex >= _chordSymbols.length) return false;

    final currentChord = _chordSymbols[chordIndex];
    if (currentChord.modifiedKeySignature == null) return false;

    // Check if the previous chord has a different (or no) modified key signature
    if (chordIndex == 0) return true;

    final previousChord = _chordSymbols[chordIndex - 1];
    return previousChord.modifiedKeySignature !=
        currentChord.modifiedKeySignature;
  }

  /// Gets a readable key name from KeySignatureType
  String _getKeyNameFromSignature(KeySignatureType keySignature) {
    const signatureToName = {
      KeySignatureType.cMajor: 'C Major',
      KeySignatureType.gMajor: 'G Major',
      KeySignatureType.dMajor: 'D Major',
      KeySignatureType.aMajor: 'A Major',
      KeySignatureType.eMajor: 'E Major',
      KeySignatureType.bMajor: 'B Major',
      KeySignatureType.fSharpMajor: 'F# Major',
      KeySignatureType.cSharpMajor: 'C# Major',
      KeySignatureType.fMajor: 'F Major',
      KeySignatureType.bFlatMajor: 'Bb Major',
      KeySignatureType.eFlatMajor: 'Eb Major',
      KeySignatureType.aFlatMajor: 'Ab Major',
      KeySignatureType.dFlatMajor: 'Db Major',
      KeySignatureType.gFlatMajor: 'Gb Major',
      KeySignatureType.cFlatMajor: 'Cb Major',
      KeySignatureType.aMinor: 'A Minor',
      KeySignatureType.eMinor: 'E Minor',
      KeySignatureType.bMinor: 'B Minor',
      KeySignatureType.fSharpMinor: 'F# Minor',
      KeySignatureType.cSharpMinor: 'C# Minor',
      KeySignatureType.gSharpMinor: 'G# Minor',
      KeySignatureType.dSharpMinor: 'D# Minor',
      KeySignatureType.aSharpMinor: 'A# Minor',
      KeySignatureType.dMinor: 'D Minor',
      KeySignatureType.gMinor: 'G Minor',
      KeySignatureType.cMinor: 'C Minor',
      KeySignatureType.fMinor: 'F Minor',
      KeySignatureType.bFlatMinor: 'Bb Minor',
      KeySignatureType.eFlatMinor: 'Eb Minor',
      KeySignatureType.aFlatMinor: 'Ab Minor',
    };

    return signatureToName[keySignature] ?? '';
  }

  /// Creates a KeySignature from KeySignatureType
  music_sheet.KeySignature _createKeySignatureFromType(
      KeySignatureType keySignatureType) {
    switch (keySignatureType) {
      case KeySignatureType.cMajor:
        return music_sheet.KeySignature.cMajor();
      case KeySignatureType.gMajor:
        return music_sheet.KeySignature.gMajor();
      case KeySignatureType.dMajor:
        return music_sheet.KeySignature.dMajor();
      case KeySignatureType.aMajor:
        return music_sheet.KeySignature.aMajor();
      case KeySignatureType.eMajor:
        return music_sheet.KeySignature.eMajor();
      case KeySignatureType.bMajor:
        return music_sheet.KeySignature.bMajor();
      case KeySignatureType.fSharpMajor:
        return music_sheet.KeySignature.fSharpMajor();
      case KeySignatureType.cSharpMajor:
        return music_sheet.KeySignature.cSharpMajor();
      case KeySignatureType.fMajor:
        return music_sheet.KeySignature.fMajor();
      case KeySignatureType.bFlatMajor:
        return music_sheet.KeySignature.bFlatMajor();
      case KeySignatureType.eFlatMajor:
        return music_sheet.KeySignature.eFlatMajor();
      case KeySignatureType.aFlatMajor:
        return music_sheet.KeySignature.aFlatMajor();
      case KeySignatureType.dFlatMajor:
        return music_sheet.KeySignature.dFlatMajor();
      case KeySignatureType.gFlatMajor:
        return music_sheet.KeySignature.gFlatMajor();
      case KeySignatureType.cFlatMajor:
        return music_sheet.KeySignature.cFlatMajor();
      case KeySignatureType.aMinor:
        return music_sheet.KeySignature.aMinor();
      case KeySignatureType.eMinor:
        return music_sheet.KeySignature.eMinor();
      case KeySignatureType.bMinor:
        return music_sheet.KeySignature.bMinor();
      case KeySignatureType.fSharpMinor:
        return music_sheet.KeySignature.fSharpMinor();
      case KeySignatureType.cSharpMinor:
        return music_sheet.KeySignature.cSharpMinor();
      case KeySignatureType.gSharpMinor:
        return music_sheet.KeySignature.gSharpMinor();
      case KeySignatureType.dSharpMinor:
        return music_sheet.KeySignature.dSharpMinor();
      case KeySignatureType.aSharpMinor:
        return music_sheet.KeySignature.aSharpMinor();
      case KeySignatureType.dMinor:
        return music_sheet.KeySignature.dMinor();
      case KeySignatureType.gMinor:
        return music_sheet.KeySignature.gMinor();
      case KeySignatureType.cMinor:
        return music_sheet.KeySignature.cMinor();
      case KeySignatureType.fMinor:
        return music_sheet.KeySignature.fMinor();
      case KeySignatureType.bFlatMinor:
        return music_sheet.KeySignature.bFlatMinor();
      case KeySignatureType.eFlatMinor:
        return music_sheet.KeySignature.eFlatMinor();
      case KeySignatureType.aFlatMinor:
        return music_sheet.KeySignature.aFlatMinor();
      default:
        return music_sheet.KeySignature.cMajor(); // Default fallback
    }
  }

  /// Loads and parses the MusicXML file to extract both chord symbols and musical notation
  Future<void> _loadAndParseSong() async {
    try {
      // --- 1. Load and Parse MusicXML ---
      String xmlString = await rootBundle.loadString(widget.songAssetPath);
      final doc = XmlDocument.parse(xmlString);

      // Extract basic song information
      final workElement = doc.findAllElements('work').firstOrNull;
      if (workElement != null) {
        final workTitle = workElement.findElements('work-title').firstOrNull;
        if (workTitle != null) {
          _songTitle = workTitle.innerText;
        }
      }

      // Extract attributes like time signature and key signature
      final attributesElement = doc.findAllElements('attributes').firstOrNull;
      if (attributesElement != null) {
        // Time signature
        final timeElement = attributesElement.findElements('time').firstOrNull;
        if (timeElement != null) {
          final beats =
              timeElement.findElements('beats').firstOrNull?.innerText ?? '4';
          final beatType =
              timeElement.findElements('beat-type').firstOrNull?.innerText ??
                  '4';
          _timeSignature = '$beats/$beatType';
          _beatsPerMeasure = int.tryParse(beats) ?? 4;
        }

        // Key signature
        final keyElement = attributesElement.findElements('key').firstOrNull;
        if (keyElement != null) {
          final fifthsElement = keyElement.findElements('fifths').firstOrNull;
          if (fifthsElement != null) {
            final fifths = int.tryParse(fifthsElement.innerText) ?? 0;
            _keySignature = _fifthsToKey[fifths] ?? 'C / Am';
          }
        }
      }

      // --- 2. Parse Musical Content and Create Measures ---
      int divisions = 1; // Default divisions per quarter note
      final chordMeasures = <ChordMeasure>[];

      // Find all <part> elements and then iterate through their children
      final parts = doc.findAllElements('part');
      for (final part in parts) {
        final partMeasures = part.findElements('measure');
        for (final measure in partMeasures) {
          final measureNumber =
              int.tryParse(measure.getAttribute('number') ?? '0') ?? 0;

          // Extract divisions for duration calculations
          final attributesInMeasure =
              measure.findElements('attributes').firstOrNull;
          if (attributesInMeasure != null) {
            final divisionsElement =
                attributesInMeasure.findElements('divisions').firstOrNull;
            if (divisionsElement != null) {
              divisions = int.tryParse(divisionsElement.innerText) ?? 1;
            }
          }

          // Collect musical symbols for this measure
          final musicalSymbols = <dynamic>[];
          final measureChords = <ChordSymbol>[];

          // Only add clef and key signature to the first measure
          if (measureNumber == 1) {
            // Add default clef
            musicalSymbols.add(music_sheet.Clef.treble());

            // Add key signature based on the global key signature
            final keySignatureType = _getCurrentKeySignature();
            musicalSymbols.add(_createKeySignatureFromType(keySignatureType));

            // Add time signature - parse from the existing _timeSignature variable
            final timeSigParts = _timeSignature.split('/');
            if (timeSigParts.length == 2) {
              final num = int.tryParse(timeSigParts[0]) ?? 4;
              final denom = int.tryParse(timeSigParts[1]) ?? 4;
              if (num == 4 && denom == 4) {
                musicalSymbols.add(music_sheet.TimeSignature.fourFour());
              } else if (num == 3 && denom == 4) {
                musicalSymbols.add(music_sheet.TimeSignature.threeFour());
              } else if (num == 2 && denom == 4) {
                musicalSymbols.add(music_sheet.TimeSignature.twoFour());
              } else {
                // Default to 4/4 if unsupported
                musicalSymbols.add(music_sheet.TimeSignature.fourFour());
              }
            }
          }
          // else add rest of measure length
          else {
            // Add a rest for the remaining measure length
            musicalSymbols.add(music_sheet.Rest(music_sheet.RestType.quarter));
            musicalSymbols.add(music_sheet.Rest(music_sheet.RestType.quarter));
            musicalSymbols.add(music_sheet.Rest(music_sheet.RestType.quarter));
            musicalSymbols.add(music_sheet.Note(Pitch.c4));
          }

          // Process all elements in the measure
          for (final element in measure.children.whereType<XmlElement>()) {
            switch (element.name.local) {
              case 'harmony':
                // Process harmony element to extract chord symbols immediately
                final chordSymbol = _createChordFromHarmony(
                  element,
                  4.0, // Default whole note duration for now
                  measureNumber,
                );
                if (chordSymbol != null) {
                  measureChords.add(chordSymbol);
                  print(
                      'Added chord symbol: ${chordSymbol.effectiveRootName}${chordSymbol.effectiveQuality} to measure $measureNumber');
                }
                break;

              case 'note':
                print('Processing note in measure $measureNumber');
                // Process note elements for duration calculations if needed
                final durationNode =
                    element.findElements('duration').firstOrNull;

                if (durationNode != null) {
                  final durationValue = int.parse(durationNode.innerText);
                  final durationInBeats = durationValue / divisions;
                  print('  Note duration: $durationInBeats beats');
                }
                break;
            }
          }

          print(
              'Measure $measureNumber: Found ${musicalSymbols.length} musical symbols and ${measureChords.length} chord symbols');

          // Create measure with musical symbols and chord symbols
          final chordMeasure = ChordMeasure(
            musicalSymbols.cast(),
            chordSymbols: measureChords,
            isNewLine: measureNumber % 6 ==
                1, // Set to true every 4 measures (1, 5, 9, etc.)
          );
          chordMeasures.add(chordMeasure);
        }
      }

      // Collect all chords from all measures for timeline and navigation
      final allChords = <ChordSymbol>[];
      for (final chordMeasure in chordMeasures) {
        allChords.addAll(chordMeasure.chordSymbols);
      }

      // Error handling if parsing yields no content
      if (allChords.isEmpty && chordMeasures.isEmpty) {
        throw 'No valid musical content was parsed from the MusicXML file.';
      }

      print(
          '📊 Parsed ${chordMeasures.length} measures with ${allChords.length} chords');
      for (int i = 0; i < chordMeasures.length; i++) {
        print(
            '  Measure ${i + 1}: ${chordMeasures[i].musicalSymbols.length} symbols, ${chordMeasures[i].chordSymbols.length} chords');
      }

      // --- 3. Initialize State ---
      setState(() {
        _chordSymbols = allChords;
        _chordMeasures = chordMeasures;
        _currentBpm = widget.bpm;
        _currentChordIndex = 0;
        _songBeatCounter = 0;
        _currentBeatInMeasure = 0;
        _userInputBeats.clear();
        _totalSongDurationInBeats = _chordSymbols.fold(
            0.0, (sum, chord) => sum + (chord.durationBeats ?? 0.0));

        // Create mapping from globalChordIndex to _chordSymbols index
        _buildGlobalIndexMapping();

        // Invalidate sheet music cache when measures change
        _cachedSheetMusicWidget = null;
        _lastRenderedMeasures = null;
      });

      // Initialize global keys for chord interaction
      _chordGlobalKeys =
          List.generate(_chordSymbols.length, (index) => GlobalKey());

      // Load saved chord key modifications after chord symbols are set
      await _loadChordKeys();

      // --- 4. Initialize Metronome ---
      // TODO: Add proper audio assets for metronome
      // Temporarily disabled to avoid crashes with empty audio files
      /*
      try {
        await _metronome.init(
          'assets/audio/claves44_wav.wav',
          accentedPath: 'assets/audio/woodblock_high44_wav.wav',
          bpm: _currentBpm,
          timeSignature: _beatsPerMeasure,
          enableTickCallback: true,
        );

        _tickSubscription = _metronome.tickStream.listen(_onTick);
      } catch (e) {
        print('Warning: Could not initialize metronome audio: $e');
        // Continue without metronome audio for now
      }
      */
      print('Metronome disabled - add proper audio assets to enable');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading song: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Helper method to create ChordSymbol from harmony XML element
  ChordSymbol? _createChordFromHarmony(
      XmlElement harmony, double durationInBeats, int measureNumber) {
    try {
      final rootElement = harmony.findElements('root').firstOrNull;
      if (rootElement == null) return null;

      final rootStep =
          rootElement.findElements('root-step').firstOrNull?.innerText;
      if (rootStep == null) return null;

      final rootAlter = int.tryParse(
              rootElement.findElements('root-alter').firstOrNull?.innerText ??
                  '0') ??
          0;
      final kindElement = harmony.findElements('kind').firstOrNull;
      final kind =
          kindElement?.getAttribute('text') ?? kindElement?.innerText ?? '';

      // Get the original key signature for proper roman numeral calculation
      final originalKeySignature = _getCurrentKeySignature();

      return ChordSymbol.fromMusicXML(
        rootStep,
        rootAlter,
        kind,
        durationInBeats,
        measureNumber,
        originalKeySignature: originalKeySignature,
      );
    } catch (e) {
      print('Error creating chord from harmony: $e');
      return null;
    }
  }

  /// Helper method to convert fifths to KeySignatureType
  KeySignatureType _getKeySignatureTypeFromFifths(int fifths) {
    switch (fifths) {
      case -7:
        return KeySignatureType.cFlatMajor;
      case -6:
        return KeySignatureType.gFlatMajor;
      case -5:
        return KeySignatureType.dFlatMajor;
      case -4:
        return KeySignatureType.aFlatMajor;
      case -3:
        return KeySignatureType.eFlatMajor;
      case -2:
        return KeySignatureType.bFlatMajor;
      case -1:
        return KeySignatureType.fMajor;
      case 0:
        return KeySignatureType.cMajor;
      case 1:
        return KeySignatureType.gMajor;
      case 2:
        return KeySignatureType.dMajor;
      case 3:
        return KeySignatureType.aMajor;
      case 4:
        return KeySignatureType.eMajor;
      case 5:
        return KeySignatureType.bMajor;
      case 6:
        return KeySignatureType.fSharpMajor;
      case 7:
        return KeySignatureType.cSharpMajor;
      default:
        return KeySignatureType.cMajor;
    }
  }

  /// Gets the number of fifths for a given key name
  int _getKeyFifths(String keyName) {
    const keyToFifths = {
      'C': 0,
      'G': 1,
      'D': 2,
      'A': 3,
      'E': 4,
      'B': 5,
      'F#': 6,
      'C#': 7,
      'F': -1,
      'Bb': -2,
      'Eb': -3,
      'Ab': -4,
      'Db': -5,
      'Gb': -6,
      'Cb': -7,
    };
    return keyToFifths[keyName] ?? 0;
  }

  /// Gets KeySignatureType from fifths value and major/minor flag
  KeySignatureType _getKeySignatureFromFifths(int fifths, bool isMinor) {
    const fifthsToKeyType = {
      0: [KeySignatureType.cMajor, KeySignatureType.aMinor],
      1: [KeySignatureType.gMajor, KeySignatureType.eMinor],
      2: [KeySignatureType.dMajor, KeySignatureType.bMinor],
      3: [KeySignatureType.aMajor, KeySignatureType.fSharpMinor],
      4: [KeySignatureType.eMajor, KeySignatureType.cSharpMinor],
      5: [KeySignatureType.bMajor, KeySignatureType.gSharpMinor],
      6: [KeySignatureType.fSharpMajor, KeySignatureType.dSharpMinor],
      7: [KeySignatureType.cSharpMajor, KeySignatureType.aSharpMinor],
      -1: [KeySignatureType.fMajor, KeySignatureType.dMinor],
      -2: [KeySignatureType.bFlatMajor, KeySignatureType.gMinor],
      -3: [KeySignatureType.eFlatMajor, KeySignatureType.cMinor],
      -4: [KeySignatureType.aFlatMajor, KeySignatureType.fMinor],
      -5: [KeySignatureType.dFlatMajor, KeySignatureType.bFlatMinor],
      -6: [KeySignatureType.gFlatMajor, KeySignatureType.eFlatMinor],
      -7: [KeySignatureType.cFlatMajor, KeySignatureType.aFlatMinor],
    };

    final keyPair = fifthsToKeyType[fifths] ?? fifthsToKeyType[0]!;
    return isMinor ? keyPair[1] : keyPair[0];
  }

  /// Gets the current effective key signature based on major/minor toggle
  KeySignatureType _getCurrentKeySignature() {
    final fifths = _getKeyFifths(_keySignature.split(' / ')[0].trim());
    final isMinorKey = _originalKey.endsWith('m');
    return _getKeySignatureFromFifths(fifths, isMinorKey);
  }

  /// Builds a single button for original key selection
  Widget _buildOriginalKeyButton() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final keyParts = _keySignature.split(' / ');
    if (keyParts.length != 2) {
      return const SizedBox.shrink();
    }

    final isMinorKey = _originalKey.endsWith('m');

    return GestureDetector(
      onTap: _showKeySelectionDialog,
      behavior: HitTestBehavior.opaque,
      child: ClayContainer(
        color: theme.colorScheme.surface,
        borderRadius: 18,
        curveType: CurveType.concave,
        child: Container(
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/images/wood_texture_rotated.jpg'),
              fit: BoxFit.cover,
            ),
            border: Border.all(
                color: Theme.of(context).colorScheme.surface, width: 4),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.music_note,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Key: $_originalKey ${isMinorKey ? 'Minor' : 'Major'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows dialog to select the original key of the song
  void _showKeySelectionDialog() {
    // Major keys for outer ring
    final majorKeys = [
      'C',
      'G',
      'D',
      'A',
      'E',
      'B',
      'F#',
      'Db',
      'Ab',
      'Eb',
      'Bb',
      'F'
    ];
    // Minor keys for inner ring
    final minorKeys = [
      'Am',
      'Em',
      'Bm',
      'F#m',
      'C#m',
      'G#m',
      'D#m',
      'Bbm',
      'Fm',
      'Cm',
      'Gm',
      'Dm'
    ];

    // Create dial items
    final outerItems = majorKeys.map((key) => DialItem(label: key)).toList();
    final innerItems = minorKeys.map((key) => DialItem(label: key)).toList();

    // Find the current original key to highlight
    int? highlightedOuterIndex;
    int? highlightedInnerIndex;

    if (_originalKey.endsWith('m')) {
      // Minor key - highlight in inner ring
      highlightedInnerIndex = minorKeys.indexOf(_originalKey);
      if (highlightedInnerIndex == -1) highlightedInnerIndex = null;
    } else {
      // Major key - highlight in outer ring
      highlightedOuterIndex = majorKeys.indexOf(_originalKey);
      if (highlightedOuterIndex == -1) highlightedOuterIndex = null;
    }

    print(
        '🔧 KEY DIALOG: Highlighting $_originalKey - outerIndex: $highlightedOuterIndex, innerIndex: $highlightedInnerIndex');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConcentricDialMenu(
            size: 350,
            outerItems: outerItems,
            innerItems: innerItems,
            centerText: 'Select\nOriginal Key',
            highlightedOuterIndex: highlightedOuterIndex,
            highlightedInnerIndex: highlightedInnerIndex,
            onSelectionChanged: (innerIndex, outerIndex) {
              String? selectedKey;
              if (outerIndex != null) {
                selectedKey = majorKeys[outerIndex];
              } else if (innerIndex != null) {
                selectedKey = minorKeys[innerIndex];
              }

              if (selectedKey != null) {
                _changeOriginalKey(selectedKey);
                Navigator.of(context).pop();
              }
            },
          ),
        );
      },
    );
  }

  /// Changes the original key and transposes all chord symbols
  void _changeOriginalKey(String newKey) {
    setState(() {
      final oldKey = _originalKey;
      _originalKey = newKey;

      // Transpose ALL chord symbols to the new key (not just selected group)
      _transposeAllChordSymbols(oldKey, newKey);

      // Update the key signature display
      _updateKeySignatureDisplay(newKey);

      // Invalidate sheet music cache since key context changed
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
    });
  }

  /// Updates the key signature display based on the original key
  void _updateKeySignatureDisplay(String key) {
    // Remove 'm' suffix if present to get the root
    final isMinor = key.endsWith('m');
    final root = isMinor ? key.substring(0, key.length - 1) : key;

    if (isMinor) {
      // For minor keys, show relative major / minor format
      final relativeMajor = _getRelativeMajor(root);
      _keySignature = '$relativeMajor / $key';
    } else {
      // For major keys, show major / relative minor format
      final relativeMinor = _getRelativeMinor(root);
      _keySignature = '$key / ${relativeMinor}m';
    }
  }

  /// Gets the relative major key for a minor key root
  String _getRelativeMajor(String minorRoot) {
    const minorToMajor = {
      'A': 'C',
      'E': 'G',
      'B': 'D',
      'F#': 'A',
      'C#': 'E',
      'G#': 'B',
      'D#': 'F#',
      'Bb': 'Db',
      'F': 'Ab',
      'C': 'Eb',
      'G': 'Bb',
      'D': 'F'
    };
    return minorToMajor[minorRoot] ?? 'C';
  }

  /// Converts string key to KeySignatureType
  KeySignatureType? _stringToKeySignatureType(String key) {
    // Handle enum string format like "KeySignatureType.cMajor"
    if (key.contains('.')) {
      final enumName = key.split('.').last;
      for (final keySignature in KeySignatureType.values) {
        if (keySignature.toString().split('.').last == enumName) {
          return keySignature;
        }
      }
      return null;
    }

    // Handle readable key name format like "C", "Am", etc.
    const keyMap = {
      'C': KeySignatureType.cMajor,
      'Am': KeySignatureType.aMinor,
      'G': KeySignatureType.gMajor,
      'Em': KeySignatureType.eMinor,
      'D': KeySignatureType.dMajor,
      'Bm': KeySignatureType.bMinor,
      'A': KeySignatureType.aMajor,
      'F#m': KeySignatureType.fSharpMinor,
      'E': KeySignatureType.eMajor,
      'C#m': KeySignatureType.cSharpMinor,
      'B': KeySignatureType.bMajor,
      'G#m': KeySignatureType.gSharpMinor,
      'F#': KeySignatureType.fSharpMajor,
      'D#m': KeySignatureType.dSharpMinor,
      'F': KeySignatureType.fMajor,
      'Dm': KeySignatureType.dMinor,
      'Bb': KeySignatureType.bFlatMajor,
      'Gm': KeySignatureType.gMinor,
      'Eb': KeySignatureType.eFlatMajor,
      'Cm': KeySignatureType.cMinor,
      'Ab': KeySignatureType.aFlatMajor,
      'Fm': KeySignatureType.fMinor,
      'Db': KeySignatureType.dFlatMajor,
      'Bbm': KeySignatureType.bFlatMinor,
    };
    return keyMap[key];
  }

  /// Transposes ALL chord symbols in the song from old key to new key
  void _transposeAllChordSymbols(String fromKey, String toKey) {
    print('🔧 TRANSPOSING ALL CHORDS FROM $fromKey TO $toKey');

    // Calculate the transposition interval
    final interval = _getTranspositionInterval(fromKey, toKey);
    if (interval == 0) return; // No transposition needed

    print('🔧 TRANSPOSITION INTERVAL: $interval semitones');

    // Transpose each chord symbol in the main list
    for (int i = 0; i < _chordSymbols.length; i++) {
      final chord = _chordSymbols[i];
      final newRoot = _transposeNote(chord.effectiveRootName, interval);

      // Capture the current Roman numeral before transposing (this is what we want to preserve)
      String originalRomanNumeral = '';
      final currentKeySignature = _stringToKeySignatureType(fromKey);
      if (currentKeySignature != null) {
        originalRomanNumeral =
            chord.getRomanNumeralWithKey(currentKeySignature);
        final qualitySuperscript = chord.getQualitySuperscript();
        if (qualitySuperscript.isNotEmpty) {
          originalRomanNumeral += qualitySuperscript;
        }
      }

      print(
          '🔧 TRANSPOSING CHORD $i: ${chord.effectiveRootName} (${chord.effectiveQuality}) -> $newRoot (interval: $interval), preserving Roman numeral: $originalRomanNumeral');
      print(
          '🔧 CHORD $i DEBUG: rootName=${chord.rootName}, rootStep=${chord.rootStep}, rootAlter=${chord.rootAlter}');

      // Create new chord symbol with transposed root but preserve original roman numeral
      final newChord = ChordSymbol(
        newRoot,
        chord.effectiveQuality,
        position: chord.position,
        originalKeySignature:
            _stringToKeySignatureType(toKey), // Use the new original key
        modifiedKeySignature: null, // Reset any key modifications
        preservedRomanNumeral:
            originalRomanNumeral, // Preserve the original Roman numeral
      );

      _chordSymbols[i] = newChord;
    }

    // Also update chord symbols in all measures
    for (int measureIndex = 0;
        measureIndex < _chordMeasures.length;
        measureIndex++) {
      final measure = _chordMeasures[measureIndex];
      if (measure.chordSymbols.isNotEmpty) {
        final updatedChordSymbols = <ChordSymbol>[];

        for (int k = 0; k < measure.chordSymbols.length; k++) {
          final chord = measure.chordSymbols[k];
          final newRoot = _transposeNote(chord.effectiveRootName, interval);

          // Capture the current Roman numeral before transposing
          String originalRomanNumeral = '';
          final currentKeySignature = _stringToKeySignatureType(fromKey);
          if (currentKeySignature != null) {
            originalRomanNumeral =
                chord.getRomanNumeralWithKey(currentKeySignature);
            final qualitySuperscript = chord.getQualitySuperscript();
            if (qualitySuperscript.isNotEmpty) {
              originalRomanNumeral += qualitySuperscript;
            }
          }

          // Create new chord symbol with transposed root but preserve original roman numeral
          final newChord = ChordSymbol(
            newRoot,
            chord.effectiveQuality,
            position: chord.position,
            originalKeySignature: _stringToKeySignatureType(toKey),
            modifiedKeySignature: null,
            preservedRomanNumeral: originalRomanNumeral,
          );

          updatedChordSymbols.add(newChord);
        }

        _chordMeasures[measureIndex] = ChordMeasure(
          measure.musicalSymbols,
          isNewLine: measure.isNewLine,
          chordSymbols: updatedChordSymbols,
        );

        print(
            '🔧 UPDATED _chordMeasures[$measureIndex] with ${updatedChordSymbols.length} transposed chords');
      }
    }

    print(
        '🔧 TRANSPOSITION COMPLETE: Updated ${_chordSymbols.length} chord symbols and ${_chordMeasures.length} measures');
  }

  /// Transposes all chord symbols from old key to new key (for selected chord group only)
  void _transposeChords(String fromKey, String toKey) {
    if (_selectedChordGroup == null) return;

    // Calculate the transposition interval
    final interval = _getTranspositionInterval(fromKey, toKey);
    if (interval == 0) return; // No transposition needed

    // Transpose each chord symbol - only change the root, preserve roman numeral
    for (int i = 0; i < _selectedChordGroup!.length; i++) {
      final chord = _selectedChordGroup![i];
      final newRoot = _transposeNote(chord.effectiveRootName, interval);

      // Capture the current Roman numeral before transposing (this is what we want to preserve)
      String originalRomanNumeral = '';
      final currentKeySignature = _stringToKeySignatureType(fromKey);
      if (currentKeySignature != null) {
        originalRomanNumeral =
            chord.getRomanNumeralWithKey(currentKeySignature);
        final qualitySuperscript = chord.getQualitySuperscript();
        if (qualitySuperscript.isNotEmpty) {
          originalRomanNumeral += qualitySuperscript;
        }
      }

      print(
          '🔧 TRANSPOSING: ${chord.effectiveRootName} from $fromKey to $toKey, preserving Roman numeral: $originalRomanNumeral');
      print('🔧 INTERVAL: $interval semitones, NEW ROOT: $newRoot');

      // Create new chord symbol with transposed root but preserve original roman numeral
      final newChord = ChordSymbol(
        newRoot,
        chord.effectiveQuality,
        position: chord.position,
        originalKeySignature:
            _stringToKeySignatureType(_originalKey), // Use the new original key
        modifiedKeySignature: null, // Reset any key modifications
        preservedRomanNumeral:
            originalRomanNumeral, // Preserve the original Roman numeral
      );

      print(
          '🔧 NEW CHORD: ${newChord.effectiveRootName}${newChord.effectiveQuality} with Roman numeral: ${newChord.getRomanNumeral()}');

      // Update the chord in the selected group
      _selectedChordGroup![i] = newChord;

      // Also update this chord in the main _chordSymbols list
      final originalChord = chord;
      for (int j = 0; j < _chordSymbols.length; j++) {
        if (_chordsMatch(_chordSymbols[j], originalChord)) {
          _chordSymbols[j] = newChord;
          print(
              '🔧 UPDATED _chordSymbols[$j] from ${originalChord.effectiveRootName} to ${newChord.effectiveRootName}');
          break;
        }
      }

      // Also update this chord in the chord measures
      for (int measureIndex = 0;
          measureIndex < _chordMeasures.length;
          measureIndex++) {
        final measure = _chordMeasures[measureIndex];
        for (int k = 0; k < measure.chordSymbols.length; k++) {
          if (_chordsMatch(measure.chordSymbols[k], originalChord)) {
            // Create new measure with updated chord symbols
            final updatedChordSymbols =
                List<ChordSymbol>.from(measure.chordSymbols);
            updatedChordSymbols[k] = newChord;
            _chordMeasures[measureIndex] = ChordMeasure(
              measure.musicalSymbols,
              isNewLine: measure.isNewLine,
              chordSymbols: updatedChordSymbols,
            );
            print(
                '🔧 UPDATED _chordMeasures[$measureIndex].chordSymbols[$k] from ${originalChord.effectiveRootName} to ${newChord.effectiveRootName}');
            break;
          }
        }
      }
    }
  }

  /// Gets the transposition interval (in semitones) between two keys
  int _getTranspositionInterval(String fromKey, String toKey) {
    const keyToSemitone = {
      'C': 0, 'C#': 1, 'Db': 1, 'D♭': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E♭': 3,
      'E': 4,
      'F': 5, 'F#': 6, 'Gb': 6, 'G♭': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A♭': 8,
      'A': 9,
      'A#': 10, 'Bb': 10, 'B♭': 10, 'B': 11,
      // Minor keys (treat as their relative majors for transposition)
      'Am': 0, 'A#m': 1, 'Bbm': 1, 'B♭m': 1, 'Bm': 2, 'Cm': 3, 'C#m': 4,
      'Dm': 5,
      'D#m': 6, 'Ebm': 6, 'E♭m': 6, 'Em': 7, 'Fm': 8, 'F#m': 9, 'Gm': 10,
      'G#m': 11
    };

    final fromSemitone = keyToSemitone[fromKey] ?? 0;
    final toSemitone = keyToSemitone[toKey] ?? 0;

    return (toSemitone - fromSemitone + 12) % 12;
  }

  /// Transposes a single note by the given interval (in semitones)
  String _transposeNote(String note, int interval) {
    const notes = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ];
    const noteToIndex = {
      'C': 0,
      'C#': 1,
      'Db': 1,
      'D♭': 1,
      'D': 2,
      'D#': 3,
      'Eb': 3,
      'E♭': 3,
      'E': 4,
      'F': 5,
      'F#': 6,
      'Gb': 6,
      'G♭': 6,
      'G': 7,
      'G#': 8,
      'Ab': 8,
      'A♭': 8,
      'A': 9,
      'A#': 10,
      'Bb': 10,
      'B♭': 10,
      'B': 11,
      'Cb': 11,
      'C♭': 11
    };

    final currentIndex = noteToIndex[note] ?? 0;
    final newIndex = (currentIndex + interval) % 12;
    final result = notes[newIndex];

    print(
        '🔧 TRANSPOSE NOTE: $note (index $currentIndex) + $interval semitones -> $result (index $newIndex)');

    return result;
  }

  /// Builds the key controls section (key button and indicator)
  Widget _buildKeyControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: _buildOriginalKeyButton(),
        ),
        // const SizedBox(height: 4),
        // Transform.scale(
        //   scale: 0.8,
        //   child: _buildCurrentKeyIndicator(),
        // ),
      ],
    );
  }

  /// Builds the zoom and draw controls section
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
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
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
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
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
                  ? CupertinoColors.systemBlue.withOpacity(0.8)
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
                tooltip:
                    isDrawingMode ? 'Exit Drawing Mode' : 'Enter Drawing Mode',
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                padding: const EdgeInsets.all(4),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Builds the extension numbering controls section
  Widget _buildExtensionControls(Color surfaceColor) {
    return ClayContainer(
      color: surfaceColor,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header text with improved styling
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Extension # Relative To:',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12.75,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Toggle buttons with improved styling
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClayContainer(
                  color: surfaceColor,
                  borderRadius: 20,
                  child: Container(
                    decoration: _extensionNumbersRelativeToChords
                        ? BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(
                                  'assets/images/wood_texture_rotated.jpg'),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 4),
                            borderRadius: BorderRadius.circular(20),
                          )
                        : null,
                    child: GestureDetector(
                      onTap: () => _toggleExtensionNumbering(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text(
                          'chord',
                          style: TextStyle(
                            color: _extensionNumbersRelativeToChords
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 12.75,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                ClayContainer(
                  color: surfaceColor,
                  borderRadius: 20,
                  child: Container(
                    decoration: !_extensionNumbersRelativeToChords
                        ? BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(
                                  'assets/images/wood_texture_rotated.jpg'),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 4),
                            borderRadius: BorderRadius.circular(20),
                          )
                        : null,
                    child: GestureDetector(
                      onTap: () => _toggleExtensionNumbering(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text(
                          'key',
                          style: TextStyle(
                            color: !_extensionNumbersRelativeToChords
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 12.75,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shows help dialog for sheet music interactions
  void _showSheetMusicHelp() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Sheet Music Help'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      'Hold and drag chord symbols to add progression to practice items',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      'Orange chord symbols represent a sequence of non-diatonic chords. Press an orange chord symbol to change the relative key for that chord sequence',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  /// Builds the current key indicator text below the buttons
  Widget _buildCurrentKeyIndicator() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;

    final keyParts = _keySignature.split(' / ');
    if (keyParts.length != 2) {
      return const SizedBox.shrink();
    }

    final majorKey = keyParts[0].trim();
    final minorKey = keyParts[1].trim();
    final isMinorKey = _originalKey.endsWith('m');
    final currentKey = isMinorKey ? '$minorKey Minor' : '$majorKey Major';

    return ClayContainer(
      color: surfaceColor,
      borderRadius: 15,
      depth: 8,
      spread: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'Current Key: $currentKey',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  /// Clears chord selection
  void _clearChordSelection() {
    _stopAutoScroll();
    setState(() {
      _selectedChordIndices.clear();
      _isDragging = false;
      _isLongPressing = false;
      _dragStartIndex = null;
      _lastHoveredIndex = null;

      // Invalidate sheet music cache to update visual selection
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
    });
  }

  /// Starts chord selection from a long press
  void _startLongPressSelection(int index) {
    print('🚀 Starting long press selection on chord $index');
    setState(() {
      _isLongPressing = true;
      _selectedChordIndices.clear();
      _selectedChordIndices.add(index);
      _isDragging = true; // Start dragging immediately
      _dragStartIndex = index;
      _lastHoveredIndex = index;

      // Invalidate sheet music cache to update visual selection
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
    });

    // Trigger animation and haptic feedback
    HapticFeedback.mediumImpact();
  }

  /// Updates chord selection during drag (only works if already in drag mode)
  void _updateChordSelectionDrag(int index) {
    if (_isDragging && _dragStartIndex != null && _isLongPressing) {
      // Only update if we're hovering over a different chord
      if (_lastHoveredIndex != index) {
        _lastHoveredIndex = index;

        final oldSelection = Set<int>.from(_selectedChordIndices);

        setState(() {
          _selectedChordIndices.clear();
          final start = _dragStartIndex!;
          final end = index;
          final min = start < end ? start : end;
          final max = start > end ? start : end;

          for (int i = min; i <= max && i < _chordSymbols.length; i++) {
            _selectedChordIndices.add(i);
          }

          // Invalidate sheet music cache to update visual selection
          _cachedSheetMusicWidget = null;
          _lastRenderedMeasures = null;
        });

        // Provide haptic feedback when selection changes
        if (!oldSelection.containsAll(_selectedChordIndices) ||
            !_selectedChordIndices.containsAll(oldSelection)) {
          HapticFeedback.selectionClick();
        }

        print(
            'Selection updated: start=$_dragStartIndex, end=$index, selected=${_selectedChordIndices.toList()}');
      }
    }
  }

  /// Handles mouse hover during drag
  void _onChordHover(int index) {
    print(
        '🖱️ Mouse hover on chord $index, isDragging: $_isDragging, isLongPressing: $_isLongPressing');
    if (_isDragging && _isLongPressing) {
      print('🎯 Calling updateChordSelectionDrag with $index');
      _updateChordSelectionDrag(index);
    }
  }

  /// Finds which chord is at the given position during drag
  void _findChordAtPosition(Offset localPosition) {
    if (!_isDragging || !_isLongPressing) return;

    // Get the render box of the wrap widget
    final RenderBox? wrapRenderBox = context.findRenderObject() as RenderBox?;
    if (wrapRenderBox == null) return;

    // Convert local position to global position
    final globalPosition = wrapRenderBox.localToGlobal(localPosition);

    // Check each chord widget to see if the position is within its bounds
    for (int i = 0; i < _chordGlobalKeys.length; i++) {
      final chordKey = _chordGlobalKeys[i];
      final RenderBox? chordRenderBox =
          chordKey.currentContext?.findRenderObject() as RenderBox?;

      if (chordRenderBox != null) {
        final chordGlobalPosition = chordRenderBox.localToGlobal(Offset.zero);
        final chordSize = chordRenderBox.size;

        // Check if the global position is within this chord's bounds
        if (globalPosition.dx >= chordGlobalPosition.dx &&
            globalPosition.dx <= chordGlobalPosition.dx + chordSize.width &&
            globalPosition.dy >= chordGlobalPosition.dy &&
            globalPosition.dy <= chordGlobalPosition.dy + chordSize.height) {
          // We found the chord under the drag position
          if (i != _lastHoveredIndex) {
            _updateChordSelectionDrag(i);
          }
          return;
        }
      }
    }
  }

  /// Handles when drag enters a chord area
  void _onDragEnterChord(int index) {
    if (_isDragging && _isLongPressing) {
      _updateChordSelectionDrag(index);
    }
  }

  /// Ends chord selection
  void _endChordSelection() {
    _stopAutoScroll();
    setState(() {
      _isDragging = false;
      _isLongPressing = false;
      // Keep _selectedChordIndices as is to show the selected chords
      // Note: Don't invalidate cache here - keep selection visible
    });
  }

  /// Cancels selection (if user lifts finger too early)
  void _cancelSelection() {
    setState(() {
      _isDragging = false;
      _isLongPressing = false;
      _selectedChordIndices.clear();
      _dragStartIndex = null;
    });
  }

  /// Handles tap outside chord selection to clear selection
  void _handleTapOutside() {
    if (_selectedChordIndices.isNotEmpty) {
      _clearChordSelection();
    }
  }

  /// Shows dialog to create a chord progression practice item
  void _showCreateChordProgressionDialog() {
    if (_selectedChordIndices.isEmpty) return;

    final selectedChords = _selectedChordIndices.toList()..sort();

    // Get Roman numerals with qualities for the selected chords
    final selectedRomanNumerals = selectedChords.map((i) {
      final chord = _chordSymbols[i];
      final keyToUse = chord.modifiedKeySignature ?? _getCurrentKeySignature();
      final romanNumeral = chord.getRomanNumeralWithKey(keyToUse);
      final quality = chord.getQualitySuperscript();
      return quality.isNotEmpty ? '$romanNumeral$quality' : romanNumeral;
    }).toList();

    final romanNumeralSequence = selectedRomanNumerals.join(' - ');

    final TextEditingController nameController =
        TextEditingController(text: romanNumeralSequence);
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Chord Progression Practice Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Selected Chord Progression: $romanNumeralSequence',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Practice Item Name',
                    hintText: 'e.g., "ii⁻⁷ - V⁷ - Iᵐᵃʲ⁷"',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Practice notes...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  _createChordProgressionPracticeItem(
                    name,
                    descriptionController.text.trim(),
                    selectedRomanNumerals,
                  );
                  Navigator.of(dialogContext).pop();
                  _clearChordSelection();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  /// Shows dialog to create a general practice item
  void _showCreateGeneralPracticeItemDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Practice Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Practice Item Name',
                    hintText: 'e.g., "Solo over head"',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Practice notes...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  _createGeneralPracticeItem(
                    name,
                    descriptionController.text.trim(),
                  );
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  /// Creates a chord progression practice item
  void _createChordProgressionPracticeItem(
      String name, String description, List<String> romanNumerals) {
    // Get the EditItemsViewModel to access the chord progressions area
    final editItemsViewModel =
        Provider.of<EditItemsViewModel>(context, listen: false);

    // Create chord progression with Roman numerals
    final chordProgression = ChordProgression(
      id: 'cp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      chords: romanNumerals, // Store Roman numerals with qualities
    );

    // Create practice item with chord progression
    final practiceItem = PracticeItem(
      id: 'pi_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      chordProgression: chordProgression,
    );

    // Add to the chord progressions area instead of the current practice area
    editItemsViewModel.addPracticeItem(
        editItemsViewModel.chordProgressionsArea.recordName, practiceItem);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chord progression "$name" added to Chord Progressions!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Creates a general practice item
  void _createGeneralPracticeItem(String name, String description) {
    if (widget.practiceArea == null) return;

    // Create practice item without chord progression
    final practiceItem = PracticeItem(
      id: 'pi_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
    );

    // Add to practice area
    widget.practiceArea!.addPracticeItem(practiceItem);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Practice item "$name" created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Builds the chord progression creation button
  Widget _buildChordProgressionButton() {
    // Disabled when chord symbols are disabled
    if (_chordSymbols.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_selectedChordIndices.isEmpty || widget.practiceArea == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () {
          // Prevent the tap from clearing selection by stopping propagation
          _showCreateChordProgressionDialog();
        },
        behavior: HitTestBehavior.opaque, // Block taps from going to parent
        child: ClayContainer(
          color: primaryColor,
          borderRadius: 20,
          depth: 15,
          spread: 4,
          curveType: CurveType.none,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'Create Practice Item (${_selectedChordIndices.length} chords selected)',
                  style: const TextStyle(
                    color: Colors.white,
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

  /// Builds the general practice item button (always shown at bottom)
  Widget _buildGeneralPracticeItemButton() {
    // Only show if there's a practice area to add items to
    if (widget.practiceArea == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () {
          // Prevent the tap from clearing selection by stopping propagation
          _showCreateGeneralPracticeItemDialog();
        },
        behavior: HitTestBehavior.opaque, // Block taps from going to parent
        child:  ClayContainer(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: 20,
          depth: 5,
          curveType: CurveType.convex,
          child:  Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
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
      ),
    );
  }

  void _togglePlayback() {
    // Metronome temporarily disabled - add proper audio assets to enable
    print('Metronome playback disabled');
    /*
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _metronome.play();
      } else {
        _metronome.pause();
      }
    });
    */
  }

  void _restartPlayback() {
    // Metronome temporarily disabled
    print('Metronome restart disabled');
    /*
    if (_isPlaying) {
      _metronome.pause();
    }
    setState(() {
      _songBeatCounter = 0;
      _currentChordIndex = 0;
      _currentBeatInMeasure = 0;
      _userInputBeats.clear();
      if (_isPlaying) {
        _metronome.play();
      }
    });
    */
    setState(() {
      _songBeatCounter = 0;
      _currentChordIndex = 0;
      _currentBeatInMeasure = 0;
      _userInputBeats.clear();
    });
  }

  void _changeBpm(int delta) {
    setState(() {
      _currentBpm = (_currentBpm + delta).clamp(40, 300);
      // _metronome.setBPM(_currentBpm); // Disabled
    });
  }

  void _jumpToChord(int index) {
    double newSongBeatCounter = 0;
    for (int i = 0; i < index; i++) {
      newSongBeatCounter += _chordSymbols[i].durationBeats ?? 0;
    }

    _songBeatCounter = newSongBeatCounter.floor();
    final progressInMeasure = newSongBeatCounter % _beatsPerMeasure;

    setState(() {
      _currentBeatInMeasure = progressInMeasure.floor() + 1;
    });
  }

  /// Inserts a musical symbol into a measure at a specific position.
  void _insertSymbolAtPosition(
      MusicalSymbol symbol, int measureIndex, int positionIndex) {
    if (measureIndex < 0 || measureIndex >= _chordMeasures.length) return;

    setState(() {
      // 1. Create a new list of measures to ensure immutability.
      final newMeasures = List<ChordMeasure>.from(_chordMeasures);
      final targetMeasure = newMeasures[measureIndex];
      final newSymbols = List<MusicalSymbol>.from(targetMeasure.musicalSymbols);

      if (positionIndex >= 0 && positionIndex <= newSymbols.length) {
        newSymbols.insert(positionIndex, symbol);
      } else {
        newSymbols.add(symbol);
      }

      newMeasures[measureIndex] = ChordMeasure(
        newSymbols,
        chordSymbols: targetMeasure.chordSymbols,
        isNewLine: targetMeasure.isNewLine,
      );

      // 2. Update state with the new list.
      _chordMeasures = newMeasures;

      // 3. Invalidate the cache.
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
      print(
          '🎵 Inserted symbol ${symbol.runtimeType} at measure $measureIndex, position $positionIndex. Invalidating cache.');
    });
  }

  /// Updates a musical symbol in a measure at a specific position.
  void _updateSymbolAtPosition(
      MusicalSymbol symbol, int measureIndex, int positionIndex) {
    if (measureIndex < 0 || measureIndex >= _chordMeasures.length) return;

    setState(() {
      // 1. Create a new list of measures.
      final newMeasures = List<ChordMeasure>.from(_chordMeasures);
      final targetMeasure = newMeasures[measureIndex];
      final newSymbols = List<MusicalSymbol>.from(targetMeasure.musicalSymbols);

      if (positionIndex >= 0 && positionIndex < newSymbols.length) {
        newSymbols[positionIndex] = symbol;
      }

      newMeasures[measureIndex] = ChordMeasure(
        newSymbols,
        chordSymbols: targetMeasure.chordSymbols,
        isNewLine: targetMeasure.isNewLine,
      );

      // 2. Update state with the new list.
      _chordMeasures = newMeasures;

      // 3. Invalidate the cache.
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
      print(
          '🎵 Updated symbol at measure $measureIndex, position $positionIndex. Invalidating cache.');
    });
  }

  /// Deletes a musical symbol from a measure at a specific position.
  void _deleteSymbolAtPosition(int measureIndex, int positionIndex) {
    if (measureIndex < 0 || measureIndex >= _chordMeasures.length) return;

    setState(() {
      // 1. Create a new list of measures.
      final newMeasures = List<ChordMeasure>.from(_chordMeasures);
      final targetMeasure = newMeasures[measureIndex];
      final newSymbols = List<MusicalSymbol>.from(targetMeasure.musicalSymbols);

      if (positionIndex >= 0 && positionIndex < newSymbols.length) {
        newSymbols.removeAt(positionIndex);
      }

      newMeasures[measureIndex] = ChordMeasure(
        newSymbols,
        chordSymbols: targetMeasure.chordSymbols,
        isNewLine: targetMeasure.isNewLine,
      );

      // 2. Update state with the new list.
      _chordMeasures = newMeasures;

      // 3. Invalidate the cache.
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
      print(
          '🎵 Deleted symbol at measure $measureIndex, position $positionIndex. Invalidating cache.');
    });
  }

  /// Builds the drawing overlay with sheet music as background
  Widget _buildDrawingOverlay() {
    return SizedBox(
      width: 1200, // Match sheet music width
      height: 600, // Fixed height for drawing board stability
      child: DrawingBoard(
        controller: _drawingController,
        background: Container(
          width: 1200, // Match sheet music width
          height: 600, // Fixed height for drawing board stability
          color:
              Colors.transparent, // Transparent to show sheet music underneath
          child: _buildCachedSheetMusic(),
        ),
        showDefaultActions:
            false, // Disable default actions - we'll show custom controls
        showDefaultTools:
            false, // Disable default toolbar - we'll show custom controls
        onPointerUp: (details) {
          // Save drawing data whenever user finishes drawing
          _saveDrawingData();
        },
      ),
    );
  }

  /// Builds the compact drawing controls toolbar
  Widget _buildDrawingControls() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClayContainer(
        color: theme.colorScheme.surface,
        borderRadius: 20,
        depth: 8,
        spread: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pen tool
              _buildDrawingToolButton(
                icon: Icons.edit,
                isSelected: true, // For now, pen is always selected
                onTap: () {
                  // Switch to pen tool
                  _drawingController.setStyle(
                    color: _currentDrawingColor,
                    strokeWidth: _currentStrokeWidth,
                  );
                },
              ),
              const SizedBox(width: 8),
              // Color picker
              GestureDetector(
                onTap: () => _showColorPicker(),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _currentDrawingColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.colorScheme.outline, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Stroke width controls - show current width
              _buildStrokeWidthButton(),
              const SizedBox(width: 8),
              // Undo
              _buildDrawingToolButton(
                icon: Icons.undo,
                isSelected: false,
                onTap: () => _drawingController.undo(),
              ),
              const SizedBox(width: 8),
              // Redo
              _buildDrawingToolButton(
                icon: Icons.redo,
                isSelected: false,
                onTap: () => _drawingController.redo(),
              ),
              const SizedBox(width: 8),
              // Clear all
              _buildDrawingToolButton(
                icon: Icons.clear,
                isSelected: false,
                onTap: () => _showClearConfirmation(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a drawing tool button
  Widget _buildDrawingToolButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          size: 18,
        ),
      ),
    );
  }

  /// Builds a stroke width button that shows current width
  Widget _buildStrokeWidthButton() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _showStrokeWidthPicker(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Container(
            width: 20,
            height: _currentStrokeWidth.clamp(
                1.0, 8.0), // Visual representation of stroke width
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface,
              borderRadius: BorderRadius.circular(_currentStrokeWidth / 2),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows color picker dialog
  void _showColorPicker() {
    final colors = [
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.brown,
      Colors.pink,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Color'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentDrawingColor = color;
                });
                _drawingController.setStyle(
                  color: color,
                  strokeWidth: _currentStrokeWidth,
                );
                Navigator.of(context).pop();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey, width: 1),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Shows stroke width picker dialog
  void _showStrokeWidthPicker() {
    final widths = [1.0, 2.0, 4.0, 6.0, 8.0];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Stroke Width'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widths.map((width) {
            final isSelected = _currentStrokeWidth == width;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentStrokeWidth = width;
                });
                _drawingController.setStyle(
                  color: _currentDrawingColor,
                  strokeWidth: width,
                );
                Navigator.of(context).pop();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                height: 40,
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: width,
                      decoration: BoxDecoration(
                        color: _currentDrawingColor,
                        borderRadius: BorderRadius.circular(width / 2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${width.toInt()}px',
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    if (isSelected) ...[
                      const Spacer(),
                      Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Shows clear confirmation dialog
  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Drawing'),
        content: const Text('Are you sure you want to clear all drawings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _drawingController.clear();
              _saveDrawingData(); // Save after clearing
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Builds cached sheet music widget to prevent expensive rebuilds
  Widget _buildCachedSheetMusic() {
    // Only rebuild sheet music if measures actually changed
    if (_cachedSheetMusicWidget == null ||
        _lastRenderedMeasures == null ||
        !listEquals(_lastRenderedMeasures, _chordMeasures)) {
      // Use listEquals for proper comparison

      _cachedSheetMusicWidget = _chordMeasures.isNotEmpty
          ? RepaintBoundary(
              child: GestureDetector(
                onTap: () {
                  // Clear selection when tapping on sheet music area (but not on chord symbols)
                  // This will be called for general sheet music area taps
                  if (_selectedChordIndices.isNotEmpty) {
                    _clearChordSelection();
                  }
                },
                behavior: HitTestBehavior
                    .deferToChild, // Only handle taps not handled by children
                child: MouseRegion(
                  key: _sheetMusicKey,
                  onHover: (event) {
                    _currentMousePosition = event.position;
                  },
                  child: music_sheet.SimpleSheetMusic(
                    key: ValueKey(
                        'sheet_music_${_isDrawingModeNotifier.value}'), // Force rebuild when drawing mode changes
                    width:
                        1200, // Adequate width for proper sheet music rendering
                    measures: _chordMeasures.cast<music_sheet.Measure>(),
                    debug: false, // Disable debug mode for clean rendering
                    initialKeySignatureType:
                        _getCurrentKeySignature(), // Pass current key signature
                    canvasScale: _sheetMusicScale,
                    extensionNumbersRelativeToChords:
                        _extensionNumbersRelativeToChords,
                    onSymbolAdd: _insertSymbolAtPosition,
                    onSymbolUpdate: _updateSymbolAtPosition,
                    onSymbolDelete: _deleteSymbolAtPosition,
                    // Connect chord symbol interactions to song viewer functionality
                    onChordSymbolTap: _onChordSymbolTap,
                    onChordSymbolLongPress: _onChordSymbolLongPress,
                    onChordSymbolLongPressEnd: _onChordSymbolLongPressEnd,
                    onChordSymbolHover: _onChordSymbolHover,
                    isChordSelected: _isChordSelected,
                    // Drawing parameters
                    drawingController: _drawingController,
                    isDrawingModeNotifier: _isDrawingModeNotifier,
                    onDrawingPointerUp: (details) {
                      _saveDrawingData();
                    },
                  ),
                ),
              ),
            )
          : Container(
              child: const Center(
                child: Text('No measures to display'),
              ),
            );

      _lastRenderedMeasures = List.from(_chordMeasures);
    }

    return _cachedSheetMusicWidget!;
  }

  /// Handles chord symbol taps from sheet music
  void _onChordSymbolTap(dynamic chordSymbol, int globalChordIndex) {
    print(
        'Chord symbol tapped: ${chordSymbol.toString()} at index $globalChordIndex');

    // Chord symbol tapped - this prevents the parent GestureDetector from clearing selection
    // Use the actual chord symbol that was tapped instead of relying on globalChordIndex
    if (chordSymbol != null) {
      print('Tapped chord: ${chordSymbol.displaySymbol}');
      print(
          'Current chord symbols: ${_chordSymbols.map((c) => c.displaySymbol).join(', ')}');
      final currentKey = _getCurrentKeySignature();

      // ALWAYS check against the original key signature for dial menu availability
      // A chord should be considered non-diatonic (and thus tappable) if it's non-diatonic to the ORIGINAL key
      final keyForAnalysis = chordSymbol.originalKeySignature ?? currentKey;
      if (!chordSymbol.isDiatonicTo(keyForAnalysis)) {
        print(
            'Non-diatonic chord detected: ${chordSymbol.displaySymbol} (non-diatonic to original key: $keyForAnalysis), showing dial menu');

        // Find the actual index of this chord in _chordSymbols for consecutive detection
        final actualIndex = _findChordIndex(chordSymbol);
        if (actualIndex != -1) {
          _showDialMenuWidget([actualIndex]);
        } else {
          print(
              'Warning: Could not find chord ${chordSymbol.displaySymbol} in _chordSymbols list');
        }
      } else {
        print(
            'chord ${chordSymbol.displaySymbol} is diatonic to $keyForAnalysis, no menu needed');
        // For diatonic chords, we don't show a menu but we still "handle" the tap
        // to prevent the parent GestureDetector from clearing the selection
      }
    }
  }

  /// Finds the index of a chord symbol in the _chordSymbols list
  int _findChordIndex(dynamic targetChord) {
    // First try object identity (most reliable)
    for (int i = 0; i < _chordSymbols.length; i++) {
      if (identical(_chordSymbols[i], targetChord)) {
        return i;
      }
    }

    // Fallback to property matching, but find the closest match considering position
    // This helps distinguish between duplicate chords
    for (int i = 0; i < _chordSymbols.length; i++) {
      final chord = _chordSymbols[i];
      if (_chordsMatch(chord, targetChord)) {
        // For duplicate chords, this will still return the first match
        // but it's better than nothing
        return i;
      }
    }
    return -1;
  }

  /// Handles chord symbol long press from sheet music - starts selection mode
  void _onChordSymbolLongPress(dynamic chordSymbol, int globalChordIndex) {
    print(
        'Chord symbol long pressed: ${chordSymbol.toString()} at index $globalChordIndex');

    // Use mapping to get the correct local index
    final localIndex = _globalToLocalIndexMap[globalChordIndex];
    if (localIndex != null &&
        localIndex >= 0 &&
        localIndex < _chordSymbols.length) {
      print('Mapped global index $globalChordIndex to local index $localIndex');
      _startLongPressSelection(localIndex);
    } else {
      print(
          'Warning: Could not map globalChordIndex $globalChordIndex to local index');
    }
  }

  /// Handles chord symbol long press end from sheet music - ends selection mode
  void _onChordSymbolLongPressEnd(
      dynamic chordSymbol, int globalChordIndex, dynamic details) {
    print(
        'Chord symbol long press ended: ${chordSymbol.toString()} at index $globalChordIndex');

    // End selection mode
    _endChordSelection();
  }

  /// Handles chord symbol hover during drag selection
  void _onChordSymbolHover(dynamic chordSymbol, int globalChordIndex) {
    print(
        'Chord symbol hover: ${chordSymbol.toString()} at index $globalChordIndex');

    // Update selection if we're dragging
    if (_isDragging && _isLongPressing) {
      // Use mapping to get the correct local index
      final localIndex = _globalToLocalIndexMap[globalChordIndex];
      if (localIndex != null &&
          localIndex >= 0 &&
          localIndex < _chordSymbols.length) {
        _updateChordSelectionDrag(localIndex);
        // Auto-scroll is now handled globally in the MouseRegion
      } else {
        print(
            'Warning: Could not map globalChordIndex $globalChordIndex to local index for hover');
      }
    }
  }

  /// Returns whether a chord symbol is currently selected
  bool _isChordSelected(int globalChordIndex) {
    if (_selectedChordIndices.isEmpty) return false;

    // Use mapping to get the correct local index
    final localIndex = _globalToLocalIndexMap[globalChordIndex];
    if (localIndex != null) {
      return _selectedChordIndices.contains(localIndex);
    }
    return false;
  }

  /// Check if auto-scrolling should be triggered during drag selection
  void _checkAutoScroll() {
    // Auto-scroll disabled since parent scroll view was removed
    if (_currentMousePosition == null) return;

    // Get the sheet music widget's render box
    final RenderBox? sheetMusicBox =
        _sheetMusicKey.currentContext?.findRenderObject() as RenderBox?;
    if (sheetMusicBox == null) return;

    // Get sheet music widget's position and size
    final sheetMusicPosition = sheetMusicBox.localToGlobal(Offset.zero);
    final sheetMusicSize = sheetMusicBox.size;

    // Define scroll zone (100 pixels below the sheet music widget)
    const scrollZoneHeight = 100.0;
    final sheetMusicBottom = sheetMusicPosition.dy + sheetMusicSize.height;
    final scrollZoneBottom = sheetMusicBottom + scrollZoneHeight;

    // Check if mouse is below the sheet music widget (in the scroll zone)
    if (_currentMousePosition!.dy >= sheetMusicBottom &&
        _currentMousePosition!.dy <= scrollZoneBottom) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  /// Start auto-scrolling timer
  void _startAutoScroll() {
    if (_autoScrollTimer != null) return; // Already scrolling

    _autoScrollTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isDragging || !_isLongPressing) {
        timer.cancel();
        _autoScrollTimer = null;
        return;
      }

      // Auto-scroll disabled since parent scroll view was removed
      // Users can now scroll the sheet music directly
    });
  }

  /// Stop auto-scrolling
  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  /// Increase sheet music scale (zoom in)
  void _zoomIn() {
    setState(() {
      _sheetMusicScale = (_sheetMusicScale + 0.1).clamp(0.3, 2.0);
      // Invalidate sheet music cache to force rebuild with new scale
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
    });
    // Save settings after zoom change
    _saveSongViewerSettings();
  }

  /// Decrease sheet music scale (zoom out)
  void _zoomOut() {
    setState(() {
      _sheetMusicScale = (_sheetMusicScale - 0.1).clamp(0.3, 2.0);
      // Invalidate sheet music cache to force rebuild with new scale
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
    });
    // Save settings after zoom change
    _saveSongViewerSettings();
  }

  /// Toggle extension numbering between chord-relative and key-relative
  void _toggleExtensionNumbering(bool relativeToChords) {
    setState(() {
      _extensionNumbersRelativeToChords = relativeToChords;
      // Invalidate sheet music cache to force rebuild with new numbering mode
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
    });
    // Save settings after toggle change
    _saveSongViewerSettings();
  }

  void _onTick(int tick) {
    if (!mounted || !_isPlaying) return;

    // Update beat counters efficiently without rebuilding entire widget
    _songBeatCounter++;
    _currentBeatInMeasure = tick;

    // Update ValueNotifiers (these won't trigger full widget rebuilds)
    _beatNotifier.value = tick;
    _songBeatNotifier.value = _songBeatCounter;

    if (tick == 0) {
      _userInputBeats.clear();
    }

    // Only call setState if chord index actually changes
    final oldChordIndex = _currentChordIndex;
    final chordChanged = _updateCurrentChordBasedOnBeat();

    if (chordChanged || _currentChordIndex != oldChordIndex) {
      setState(() {
        // Chord index changed, need to update UI
      });
    }
  }

  bool _updateCurrentChordBasedOnBeat() {
    if (_chordSymbols.isEmpty) return false;

    double cumulativeBeats = 0;
    int newChordIndex = 0;
    bool found = false;

    // Handle song looping
    final totalBeats = _totalSongDurationInBeats;
    if (totalBeats > 0 && _songBeatCounter > totalBeats) {
      _songBeatCounter = 1; // Loop back to the beginning
    }

    for (int i = 0; i < _chordSymbols.length; i++) {
      cumulativeBeats += _chordSymbols[i].durationBeats ?? 0;
      if (_songBeatCounter <= cumulativeBeats) {
        newChordIndex = i;
        found = true;
        break;
      }
    }

    if (found && newChordIndex != _currentChordIndex) {
      _currentChordIndex = newChordIndex;
      return true;
    }
    return false;
  }

  String _formatHarmony(ChordSymbol chord) {
    return chord.displaySymbol;
  }

  @override
  void dispose() {
    _tickSubscription?.cancel();
    _metronome.destroy();

    // Clean up auto-scroll timer
    _autoScrollTimer?.cancel();

    // Dispose ValueNotifiers
    _beatNotifier.dispose();
    _songBeatNotifier.dispose();
    _isDrawingModeNotifier.dispose();

    super.dispose();
  }

  /// Builds the practice items widget at the bottom of the screen
  Widget _buildPracticeItemsWidget() {
    if (widget.practiceArea == null ||
        widget.practiceArea!.practiceItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;
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

              child: Center(
                child: Text(
                  'Practice Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
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
                                     SizedBox(height: 6),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Loading...',
            style: TextStyle(color: onSurfaceColor),
          ),
          backgroundColor: surfaceColor,
          iconTheme: IconThemeData(color: onSurfaceColor),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: primaryColor,
          ),
        ),
      );
    }

    if (_chordMeasures.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          iconTheme: IconThemeData(color: onSurfaceColor),
        ),
        body: Center(
          child: Text(
            'Error: No measures found in song.',
            style: TextStyle(color: onSurfaceColor),
          ),
        ),
      );
    }

    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            _songTitle,
            style: TextStyle(
              fontSize: 18,
              color: onSurfaceColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 0,
          backgroundColor: surfaceColor,
          iconTheme: IconThemeData(color: onSurfaceColor),
        ),
        body: MouseRegion(
          onHover: (event) {
            // Track mouse position globally for auto-scroll detection
            _currentMousePosition = event.position;
            if (_isDragging && _isLongPressing) {
              _checkAutoScroll();
            }
          },
          child: GestureDetector(
            onTap:
                _handleTapOutside, // Clear selection when tapping anywhere outside chords
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Key signature controls
                      Container(
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
                                  final isWideScreen =
                                      constraints.maxWidth > 600;

                                  if (isWideScreen) {
                                    // Wide screen: single row layout
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        _buildKeyControls(),
                                        _buildZoomAndDrawControls(surfaceColor),
                                        _buildExtensionControls(surfaceColor),
                                      ],
                                    );
                                  } else {
                                    // Narrow screen: wrapped layout
                                    return Column(
                                      children: [
                                        // Top row: Key controls and extension controls
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildKeyControls(),
                                            _buildExtensionControls(
                                                surfaceColor),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        // Bottom row: Zoom/draw controls centered
                                        Center(
                                            child: _buildZoomAndDrawControls(
                                                surfaceColor)),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ]),
                          ),
                        ),
                      ),
                      // Add the dial menu widget below the key indicator
                      _buildDialMenuWidget(),
                      const SizedBox(height: 20),

                      // Controls row above sheet music

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

                      // Sheet Music Display with Canvas-based Chord Symbols
                      if (_chordMeasures.isNotEmpty)
                        Container(
                          height: 600,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ClayContainer(
                            color: surfaceColor,
                            borderRadius: 20,
                            depth: 10,
                            spread: 3,
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: _buildCachedSheetMusic(),
                                  ),
                                ),
                                // Help button in top left
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: ClayContainer(
                                    color: surfaceColor,
                                    borderRadius: 15,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.help_outline,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      onPressed: _showSheetMusicHelp,
                                      tooltip: 'Sheet Music Help',
                                      constraints: const BoxConstraints(
                                        minWidth: 30,
                                        minHeight: 30,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Chord progression creation button (appears when chords are selected)
                      _buildChordProgressionButton(),

                      // Center(
                      //   child: SizedBox(
                      //     width: MediaQuery.of(context).size.width * 0.8,
                      //     child: BeatTimeline(
                      //       beatsPerMeasure: _beatsPerMeasure,
                      //       currentProgress:
                      //           _currentBeatInMeasure + 1, // Convert to 1-indexed
                      //       userInputMarkers: _userInputBeats,
                      //       textColor: Theme.of(context).colorScheme.onSurface,
                      //     ),
                      //   ),
                      // ),
                      const ActiveSessionBanner(),
                      // Practice items widget
                      _buildPracticeItemsWidget(),
                      // General practice item button (always shown)
                      _buildGeneralPracticeItemButton(),

                      const SizedBox(height: 20), // Bottom padding for scroll
                    ],
                  ),
                ),
              ),
            ),
          ), // MouseRegio
        )); // Scaffold
  }
}
