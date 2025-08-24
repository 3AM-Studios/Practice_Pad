import 'dart:async';
import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/services/device_type.dart';
import 'package:xml/xml.dart';
import 'package:music_sheet/simple_sheet_music.dart' as music_sheet;
import 'package:flutter_drawing_board/flutter_drawing_board.dart';

import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_measure.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/concentric_dial_menu.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/chord_progression.dart';
import 'package:practice_pad/features/practice/presentation/pages/practice_session_screen.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:music_sheet/index.dart';
import 'package:practice_pad/services/local_storage_service.dart';

// Import transcription viewer
import 'transcription_viewer.dart';
import '../../data/models/song.dart';

/// Full sheet music viewer widget that contains ALL the original song viewer functionality
/// This is essentially the entire content from song_viewer_screen_old.dart but with separate drawing keys
class SimpleSheetMusicViewer extends StatefulWidget {
  final String songAssetPath;
  final int bpm;
  final PracticeArea? practiceArea;
  final VoidCallback? onStateChanged;

  const SimpleSheetMusicViewer({
    super.key,
    required this.songAssetPath,
    this.bpm = 120,
    this.practiceArea,
    this.onStateChanged,
  });

  @override
  State<SimpleSheetMusicViewer> createState() => _SimpleSheetMusicViewerState();
}

class _SimpleSheetMusicViewerState extends State<SimpleSheetMusicViewer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Static controller disposal locks to prevent race conditions
  static final Map<String, Completer<void>> _controllerDisposalLocks = {};
  
  // Static map to store stable GlobalKeys per song
  static final Map<String, GlobalKey> _drawingGlobalKeys = {};
  
  bool _isLoading = true;
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
  double _sheetMusicScale = 0.4;

  // Extension numbering control
  bool _extensionNumbersRelativeToChords = true;

  // Drawing functionality
  late ValueNotifier<bool> _isDrawingModeNotifier;
  late DrawingController _drawingController;
  late GlobalKey _drawingKey;
  Color _currentDrawingColor = Colors.black;
  double _currentStrokeWidth = 2.0;

  @override
  void initState() {
    super.initState();
    _currentBpm = widget.bpm;
    
    // Register for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Initialize ValueNotifiers for performance optimization
    _beatNotifier = ValueNotifier<int>(0);
    _songBeatNotifier = ValueNotifier<int>(0);

    // Initialize drawing functionality
    _isDrawingModeNotifier = ValueNotifier<bool>(false);
    
    // Reuse or create a stable GlobalKey for this song
    
    
    
    
    final drawingKeyPath = '${widget.songAssetPath}_sheet';
    final existingKey = _drawingGlobalKeys[drawingKeyPath];
    
    
    _drawingKey = _drawingGlobalKeys.putIfAbsent(
      drawingKeyPath,
      () {
        final newKey = GlobalKey(debugLabel: 'drawing_$drawingKeyPath');
        
        return newKey;
      },
    );
    
    
    
    // Initialize controller after waiting for any pending disposal
    _initializeControllerSafely();

    // Note: Drawing loading moved to after song loading completes

    _loadAndParseSong();
    _loadSongViewerSettings();
  }

  /// Safely initialize the drawing controller, waiting for any pending disposal
  Future<void> _initializeControllerSafely() async {
    final drawingKeyPath = '${widget.songAssetPath}_sheet';
    
    // Wait for any pending disposal of previous controller for this song
    if (_controllerDisposalLocks.containsKey(drawingKeyPath)) {
      
      await _controllerDisposalLocks[drawingKeyPath]!.future;
      
    }
    
    // Now safe to create new controller with stable GlobalKey
    _drawingController = DrawingController(
      uniqueId: drawingKeyPath,
      globalKey: _drawingKey,
    );

    // Debug: Log controller creation and validate clean state
    
    
    

    // Validate that we start with a completely clean state
    assert(_drawingController.currentIndex == 0, 'DrawingController should start with currentIndex = 0');
    assert(_drawingController.getHistory.isEmpty, 'DrawingController should start with empty history');

    // Set default drawing style - black color and thin stroke
    _drawingController.setStyle(
      color: _currentDrawingColor,
      strokeWidth: _currentStrokeWidth,
    );
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
                (songChanges['canvasScale'] as double).clamp(0.4, 0.8);
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
      
    } catch (e) {
      
    }
  }

  /// Load saved drawing data from local storage
  Future<void> _loadDrawingData() async {
    try {
      if (!mounted) return;
      
      final drawingKeyPath = '${widget.songAssetPath}_sheet';
      
      
      
      // Load saved drawings from LocalStorageService
      final drawingData = await LocalStorageService.loadDrawingsForSong(drawingKeyPath);
      
      
      
      if (drawingData.isNotEmpty && mounted) {
        // Convert JSON data back to PaintContent objects
        
        final paintContents = LocalStorageService.drawingJsonToPaintContents(drawingData);
        
        
        // Debug each paint content
        for (int i = 0; i < paintContents.length; i++) {
          final content = paintContents[i];
          
        }
        
        if (paintContents.isNotEmpty) {
          // Clear existing drawings first, then load new ones
          _drawingController.clear();
          
          
          _drawingController.addContents(paintContents);
          
          
        }
      } else {
        
        // Ensure controller is cleared when no drawings exist
        _drawingController.clear();
        
      }
    } catch (e) {
      
    }
  }

  /// Save drawing data to local storage
  Future<void> _saveDrawingData() async {
    try {
      if (!mounted) return;
      
      final drawingKeyPath = '${widget.songAssetPath}_sheet';
      
      
      // Save the JSON data using LocalStorageService
      final jsonData = _drawingController.getJsonList();
      
      
      
      // Always save, even if empty (to clear old data)
      await LocalStorageService.saveDrawingsForSong(drawingKeyPath, jsonData);
      
    } catch (e) {
      
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
            musicalSymbols.add(music_sheet.Note(music_sheet.Pitch.c4));
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
                  
                }
                break;

              case 'note':
                
                // Process note elements for duration calculations if needed
                final durationNode =
                    element.findElements('duration').firstOrNull;

                if (durationNode != null) {
                  final durationValue = int.parse(durationNode.innerText);
                  final durationInBeats = durationValue / divisions;
                  
                }
                break;
            }
          }

          // Create measure with musical symbols and chord symbols
          final chordMeasure = ChordMeasure(
            musicalSymbols.cast(),
            chordSymbols: measureChords,
            isNewLine: deviceType == DeviceType.phone?  measureNumber % 6 ==
                1 : measureNumber % 7 ==
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
        
        // Continue without metronome audio for now
      }
      */
      
      await _loadDrawingData();

      setState(() {
        _isLoading = false;
      });
      
      // Load drawings after song is fully loaded
      
    } catch (e) {
      
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
      
      return null;
    }
  }

  // Add all the stub methods for now - these will be the full implementations from the original file
  void _buildGlobalIndexMapping() {}
  Future<void> _loadChordKeys() async {}
  KeySignatureType _getCurrentKeySignature() => _stringToKeySignatureType(_originalKey) ?? KeySignatureType.cMajor;
  music_sheet.KeySignature _createKeySignatureFromType(KeySignatureType keySignatureType) {
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
      case KeySignatureType.dMinor:
        return music_sheet.KeySignature.dMinor();
      case KeySignatureType.gMinor:
        return music_sheet.KeySignature.gMinor();
      case KeySignatureType.cMinor:
        return music_sheet.KeySignature.cMinor();
      case KeySignatureType.fMinor:
        return music_sheet.KeySignature.fMinor();
      default:
        return music_sheet.KeySignature.cMajor();
    }
  }
  
  // Sheet music interaction methods
  void _insertSymbolAtPosition(MusicalSymbol symbol, int measureIndex, int positionIndex) {
    if (measureIndex < 0 || measureIndex >= _chordMeasures.length) return;
    
    setState(() {
      // 1. Create a new list of measures to ensure immutability
      final newMeasures = List<ChordMeasure>.from(_chordMeasures);
      final targetMeasure = newMeasures[measureIndex];
      final newSymbols = List<MusicalSymbol>.from(targetMeasure.musicalSymbols);
      
      if (positionIndex >= 0 && positionIndex <= newSymbols.length) {
        newSymbols.insert(positionIndex, symbol);
        
        // 2. Create new measure with updated symbols
        newMeasures[measureIndex] = ChordMeasure(
          newSymbols,
          chordSymbols: targetMeasure.chordSymbols,
          isNewLine: targetMeasure.isNewLine,
        );
        
        // 3. Update the main list
        _chordMeasures = newMeasures;
        
        // 4. Invalidate the cache
        _cachedSheetMusicWidget = null;
        _lastRenderedMeasures = null;
        
        
      }
    });
  }
  
  void _updateSymbolAtPosition(MusicalSymbol symbol, int measureIndex, int positionIndex) {
    if (measureIndex < 0 || measureIndex >= _chordMeasures.length) return;
    
    setState(() {
      // 1. Create a new list of measures
      final newMeasures = List<ChordMeasure>.from(_chordMeasures);
      final targetMeasure = newMeasures[measureIndex];
      final newSymbols = List<MusicalSymbol>.from(targetMeasure.musicalSymbols);
      
      if (positionIndex >= 0 && positionIndex < newSymbols.length) {
        newSymbols[positionIndex] = symbol;
        
        // 2. Create new measure with updated symbols
        newMeasures[measureIndex] = ChordMeasure(
          newSymbols,
          chordSymbols: targetMeasure.chordSymbols,
          isNewLine: targetMeasure.isNewLine,
        );
        
        // 3. Update the main list
        _chordMeasures = newMeasures;
        
        // 4. Invalidate the cache
        _cachedSheetMusicWidget = null;
        _lastRenderedMeasures = null;
        
        
      }
    });
  }
  
  void _deleteSymbolAtPosition(int measureIndex, int positionIndex) {
    if (measureIndex < 0 || measureIndex >= _chordMeasures.length) return;
    
    setState(() {
      // 1. Create a new list of measures
      final newMeasures = List<ChordMeasure>.from(_chordMeasures);
      final targetMeasure = newMeasures[measureIndex];
      final newSymbols = List<MusicalSymbol>.from(targetMeasure.musicalSymbols);
      
      if (positionIndex >= 0 && positionIndex < newSymbols.length) {
        newSymbols.removeAt(positionIndex);
        
        // 2. Create new measure with updated symbols
        newMeasures[measureIndex] = ChordMeasure(
          newSymbols,
          chordSymbols: targetMeasure.chordSymbols,
          isNewLine: targetMeasure.isNewLine,
        );
        
        // 3. Update the main list
        _chordMeasures = newMeasures;
        
        // 4. Invalidate the cache
        _cachedSheetMusicWidget = null;
        _lastRenderedMeasures = null;
        
        
      }
    });
  }
  
  void _onChordSymbolTap(dynamic chordSymbol, int globalChordIndex) {
    // Handle chord symbol tap - could be used for selection, etc.
    
  }
  
  void _onChordSymbolLongPress(dynamic chordSymbol, int globalChordIndex) {
    // Handle chord symbol long press - could show context menu
    
  }
  
  void _onChordSymbolLongPressEnd(dynamic chordSymbol, int globalChordIndex, LongPressEndDetails? details) {
    // Handle end of long press
    
  }
  
  void _onChordSymbolHover(dynamic chordSymbol, int globalChordIndex) {
    // Handle chord symbol hover
  }
  
  bool _isChordSelected(int globalChordIndex) => false;

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    return Column(
      children: [
        // Add the dial menu widget below the key indicator
        _buildDialMenuWidget(),
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
      ],
    );
  }

  // Returns toolbar widget for main screen
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildKeyControls(),
                          _buildExtensionControls(surfaceColor),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Bottom row: Zoom/draw controls centered
                      Center(
                          child: _buildZoomAndDrawControls(surfaceColor)),
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


  // PLACEHOLDER METHODS - Add minimal implementations to make it compile
  Widget _buildDialMenuWidget() => const SizedBox.shrink();
  Widget _buildDrawingControls() => Container();
  
  /// Shows dialog to select the original key of the song
  void _showKeySelectionDialog() {
    // Major keys for outer ring
    final majorKeys = [
      'C', 'G', 'D', 'A', 'E', 'B', 'F#', 'Db', 'Ab', 'Eb', 'Bb', 'F'
    ];
    // Minor keys for inner ring
    final minorKeys = [
      'Am', 'Em', 'Bm', 'F#m', 'C#m', 'G#m', 'D#m', 'Bbm', 'Fm', 'Cm', 'Gm', 'Dm'
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
    
    // Notify parent widget to rebuild toolbar
    widget.onStateChanged?.call();
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
      _keySignature = '$key / $relativeMinor';
    }
  }
  
  /// Gets the relative major key for a minor key root
  String _getRelativeMajor(String minorRoot) {
    const minorToMajor = {
      'A': 'C', 'E': 'G', 'B': 'D', 'F#': 'A', 'C#': 'E', 'G#': 'B',
      'D#': 'F#', 'Bb': 'Db', 'F': 'Ab', 'C': 'Eb', 'G': 'Bb', 'D': 'F'
    };
    return minorToMajor[minorRoot] ?? 'C';
  }
  
  /// Gets the relative minor key for a major key root  
  String _getRelativeMinor(String majorKey) {
    const majorToMinor = {
      'C': 'Am', 'G': 'Em', 'D': 'Bm', 'A': 'F#m', 'E': 'C#m', 'B': 'G#m',
      'F#': 'D#m', 'Db': 'Bbm', 'Ab': 'Fm', 'Eb': 'Cm', 'Bb': 'Gm', 'F': 'Dm'
    };
    return majorToMinor[majorKey] ?? 'Am';
  }
  
  /// Transposes all chord symbols from one key to another
  void _transposeAllChordSymbols(String fromKey, String toKey) {
    
    
    // Calculate the transposition interval
    final interval = _getTranspositionInterval(fromKey, toKey);
    if (interval == 0) return; // No transposition needed
    
    
    
    // Transpose each chord symbol in the main list
    for (int i = 0; i < _chordSymbols.length; i++) {
      final chord = _chordSymbols[i];
      final newRoot = _transposeNote(chord.effectiveRootName, interval);
      
      // Capture the current Roman numeral before transposing
      String originalRomanNumeral = '';
      final currentKeySignature = _stringToKeySignatureType(fromKey);
      if (currentKeySignature != null) {
        originalRomanNumeral = chord.getRomanNumeralWithKey(currentKeySignature);
        final qualitySuperscript = chord.getQualitySuperscript();
        if (qualitySuperscript.isNotEmpty) {
          originalRomanNumeral += qualitySuperscript;
        }
      }
      
      
      
      // Create new chord symbol with transposed root
      final newChord = ChordSymbol(
        newRoot,
        chord.effectiveQuality,
        position: chord.position,
        originalKeySignature: _stringToKeySignatureType(toKey),
        modifiedKeySignature: null,
        preservedRomanNumeral: originalRomanNumeral,
      );
      
      _chordSymbols[i] = newChord;
    }
    
    // Also update chord symbols in all measures
    for (int measureIndex = 0; measureIndex < _chordMeasures.length; measureIndex++) {
      final measure = _chordMeasures[measureIndex];
      final updatedChordSymbols = <ChordSymbol>[];
      
      for (final chord in measure.chordSymbols) {
        final newRoot = _transposeNote(chord.effectiveRootName, interval);
        
        // Capture the current Roman numeral before transposing
        String originalRomanNumeral = '';
        final currentKeySignature = _stringToKeySignatureType(fromKey);
        if (currentKeySignature != null) {
          originalRomanNumeral = chord.getRomanNumeralWithKey(currentKeySignature);
          final qualitySuperscript = chord.getQualitySuperscript();
          if (qualitySuperscript.isNotEmpty) {
            originalRomanNumeral += qualitySuperscript;
          }
        }
        
        // Create new chord symbol with transposed root
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
    }
  }
  
  /// Calculates the transposition interval between two keys in semitones
  int _getTranspositionInterval(String fromKey, String toKey) {
    const keyToSemitone = {
      'C': 0, 'C#': 1, 'Db': 1, 'D♭': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E♭': 3,
      'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G♭': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A♭': 8,
      'A': 9, 'A#': 10, 'Bb': 10, 'B♭': 10, 'B': 11,
      // Minor keys
      'Am': 0, 'A#m': 1, 'Bbm': 1, 'B♭m': 1, 'Bm': 2, 'Cm': 3, 'C#m': 4,
      'Dm': 5, 'D#m': 6, 'Ebm': 6, 'E♭m': 6, 'Em': 7, 'Fm': 8, 'F#m': 9, 'Gm': 10, 'G#m': 11
    };
    
    final fromSemitone = keyToSemitone[fromKey] ?? 0;
    final toSemitone = keyToSemitone[toKey] ?? 0;
    return (toSemitone - fromSemitone + 12) % 12;
  }
  
  /// Transposes a single note by the given interval (in semitones)
  String _transposeNote(String note, int interval) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const noteToIndex = {
      'C': 0, 'C#': 1, 'Db': 1, 'D♭': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E♭': 3,
      'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G♭': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A♭': 8,
      'A': 9, 'A#': 10, 'Bb': 10, 'B♭': 10, 'B': 11
    };
    
    final currentIndex = noteToIndex[note] ?? 0;
    final newIndex = (currentIndex + interval) % 12;
    return notes[newIndex];
  }
  
  /// Converts string key to KeySignatureType
  KeySignatureType? _stringToKeySignatureType(String key) {
    const keyMap = {
      'C': KeySignatureType.cMajor, 'Am': KeySignatureType.aMinor,
      'G': KeySignatureType.gMajor, 'Em': KeySignatureType.eMinor,
      'D': KeySignatureType.dMajor, 'Bm': KeySignatureType.bMinor,
      'A': KeySignatureType.aMajor, 'F#m': KeySignatureType.fSharpMinor,
      'E': KeySignatureType.eMajor, 'C#m': KeySignatureType.cSharpMinor,
      'B': KeySignatureType.bMajor, 'G#m': KeySignatureType.gSharpMinor,
      'F#': KeySignatureType.fSharpMajor, 'D#m': KeySignatureType.dSharpMinor,
      'F': KeySignatureType.fMajor, 'Dm': KeySignatureType.dMinor,
      'Bb': KeySignatureType.bFlatMajor, 'Gm': KeySignatureType.gMinor,
      'Eb': KeySignatureType.eFlatMajor, 'Cm': KeySignatureType.cMinor,
      'Ab': KeySignatureType.aFlatMajor, 'Fm': KeySignatureType.fMinor,
      'Db': KeySignatureType.dFlatMajor, 'Bbm': KeySignatureType.bFlatMinor,
      'Gb': KeySignatureType.gFlatMajor, 'Ebm': KeySignatureType.eFlatMinor,
    };
    
    return keyMap[key];
  }
  Widget _buildCachedSheetMusic() {
    if (_chordMeasures.isEmpty) {
      return Container(
        height: 400,
        child: const Center(
          child: Text('No measures to display'),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // Handle tap for chord selection
      },
      behavior: HitTestBehavior.deferToChild,
      child: MouseRegion(
        key: _sheetMusicKey,
        onHover: (event) {
          _currentMousePosition = event.position;
        },
        child: music_sheet.SimpleSheetMusic(
          key: ValueKey('sheet_music_${widget.songAssetPath}'),
          width: 1200, // Adequate width for proper sheet music rendering
          measures: _chordMeasures.cast<music_sheet.Measure>(),
          debug: false,
          initialKeySignatureType: _getCurrentKeySignature(),
          canvasScale: _sheetMusicScale,
          extensionNumbersRelativeToChords: _extensionNumbersRelativeToChords,
          onSymbolAdd: _insertSymbolAtPosition,
          onSymbolUpdate: _updateSymbolAtPosition,
          onSymbolDelete: _deleteSymbolAtPosition,
          onChordSymbolTap: _onChordSymbolTap,
          onChordSymbolLongPress: _onChordSymbolLongPress,
          onChordSymbolLongPressEnd: _onChordSymbolLongPressEnd,
          onChordSymbolHover: _onChordSymbolHover,
          isChordSelected: _isChordSelected,
          drawingController: _drawingController,
          isDrawingModeNotifier: _isDrawingModeNotifier,
          onDrawingPointerUp: (details) {
            _saveDrawingData();
          },
        ),
      ),
    );
  }
  Widget _buildChordProgressionButton() => const SizedBox.shrink();

  /// Builds the key controls section (key button and indicator)
  Widget _buildKeyControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: _buildOriginalKeyButton(),
        ),
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    
                    _toggleExtensionNumbering(true);
                  },
                  child: ClayContainer(
                    color: surfaceColor,
                    borderRadius: 20,
                    child: Container(
                      decoration: () {
                        
                        return _extensionNumbersRelativeToChords;
                      }()
                          ? BoxDecoration(
                              image: const DecorationImage(
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    
                    _toggleExtensionNumbering(false);
                  },
                  child: ClayContainer(
                    color: surfaceColor,
                    borderRadius: 20,
                    child: Container(
                      decoration: () {
                        
                        return !_extensionNumbersRelativeToChords;
                      }()
                          ? BoxDecoration(
                              image: const DecorationImage(
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
            const SizedBox(height: 8),
            // Transcription button
            GestureDetector(
              onTap: _openTranscriptionViewer,
              child: ClayContainer(
                color: surfaceColor,
                borderRadius: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Transcription',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginalKeyButton() {
    final theme = Theme.of(context);
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

  // Stub methods - these would be fully implemented from the original file
  void _showSheetMusicHelp() {}
  void _zoomIn() {
    setState(() {
      _sheetMusicScale = (_sheetMusicScale + 0.1).clamp(0.4, 0.8);
      _saveSongViewerSettings();
    });
  }
  void _zoomOut() {
    setState(() {
      _sheetMusicScale = (_sheetMusicScale - 0.1).clamp(0.4, 0.8);
      _saveSongViewerSettings();
    });
  }
  void _toggleExtensionNumbering(bool relativeToChords) {
    
    setState(() {
      _extensionNumbersRelativeToChords = relativeToChords;
      
      _saveSongViewerSettings();
      // Invalidate sheet music cache since extension numbering changed
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
    });
    
    // Notify parent widget to rebuild toolbar
    widget.onStateChanged?.call();
  }

  @override
  void dispose() {
    _tickSubscription?.cancel();
    _autoScrollTimer?.cancel();
    _disposeControllerSafely();
    super.dispose();
  }

  /// Safely dispose controller with synchronization to prevent race conditions
  void _disposeControllerSafely() {
    final drawingKeyPath = '${widget.songAssetPath}_sheet';
    
    // Create a completer to track disposal completion
    final completer = Completer<void>();
    _controllerDisposalLocks[drawingKeyPath] = completer;
    
    
    
    // Schedule the disposal work but don't block the dispose method
    () async {
      try {
        // Save drawings synchronously
        
        await _saveDrawingData();
        
        
        // Remove app lifecycle observer
        WidgetsBinding.instance.removeObserver(this);

        // Dispose ValueNotifiers
        _beatNotifier.dispose();
        _songBeatNotifier.dispose();
        _isDrawingModeNotifier.dispose();

        // CRITICAL: Dispose the drawing controller to prevent memory leaks and state conflicts
        
        
        
        _drawingController.dispose();
        
        
      } catch (error) {
        
      } finally {
        // Always complete the disposal lock
        completer.complete();
        // Clean up the lock after a brief delay to ensure any waiting operations complete
        Future.delayed(const Duration(milliseconds: 100), () {
          _controllerDisposalLocks.remove(drawingKeyPath);
        });
        
      }
    }();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Save drawings when app goes to background or becomes inactive
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveDrawingData();
    }
  }
}