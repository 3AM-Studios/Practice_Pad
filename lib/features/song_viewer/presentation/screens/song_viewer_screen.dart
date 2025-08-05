import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:metronome/metronome.dart';
import 'package:xml/xml.dart';
import 'package:music_sheet/simple_sheet_music.dart' as music_sheet;

import 'package:practice_pad/features/song_viewer/presentation/widgets/beat_timeline.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_measure.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/concentric_dial_menu.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/chord_progression.dart';
import 'package:practice_pad/widgets/active_session_banner.dart';
import 'package:practice_pad/features/practice/presentation/pages/practice_session_screen.dart';
import 'package:music_sheet/index.dart';
import 'package:music_sheet/src/music_objects/interface/musical_symbol.dart';

class SongViewerScreen extends StatefulWidget {
  final String songAssetPath;
  final int bpm;
  final PracticeArea? practiceArea; // Optional practice area for showing practice items

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
  bool _isPlaying = false;

  List<ChordSymbol> _chordSymbols = [];
  List<ChordMeasure> _chordMeasures = []; // Combined measures with chord symbols
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
  bool _isMinorKey = false; // Toggle between major/minor interpretation
  String _timeSignature = '';
  int _beatsPerMeasure = 4; // Default
  int _currentBeatInMeasure = 0;
  List<double> _userInputBeats = [];
  int _songBeatCounter = 0; // The master logical beat counter for the song

  // Dial menu state for non-diatonic chord reharmonization
  bool _showDialMenu = false; // Controls whether the dial menu widget is visible
  List<ChordSymbol>? _selectedChordGroup; // The chord group currently selected for key change

  // Chord selection state for practice item creation (temporarily disabled for canvas rendering)
  Set<int> _selectedChordIndices = <int>{}; // Selected chord indices
  bool _isDragging = false; // Whether user is currently dragging
  int? _dragStartIndex; // Starting index of drag selection
  bool _isLongPressing = false; // Whether user is in long press selection mode
  int? _lastHoveredIndex; // Last chord index that was hovered during drag
  List<GlobalKey> _chordGlobalKeys = []; // Keys for chord widgets to get their positions

  @override
  void initState() {
    super.initState();
    _currentBpm = widget.bpm;
    
    // Initialize ValueNotifiers for performance optimization
    _beatNotifier = ValueNotifier<int>(0);
    _songBeatNotifier = ValueNotifier<int>(0);
    
    _loadAndParseSong();
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
    final consecutiveGroup = _findConsecutiveNonDiatonicSequence(chordGroup.first);
    print('🎵 SHOW DIAL MENU: Found consecutive group: $consecutiveGroup');
    
    setState(() {
      _showDialMenu = true;
      _selectedChordGroup = consecutiveGroup;
    });
    
    print('🎵 SHOW DIAL MENU: Set _selectedChordGroup to $consecutiveGroup');
  }

  /// Finds all consecutive non-diatonic chords starting from a given index
  List<ChordSymbol> _findConsecutiveNonDiatonicSequence(int startIndex) {
    final List<ChordSymbol> sequence = [];
    
    if (startIndex >= _chordSymbols.length) return sequence;
    
    final startChord = _chordSymbols[startIndex];
    final currentKey = _getCurrentKeySignature();
    
    // Only proceed if the start chord is non-diatonic
    if (!startChord.isDiatonicTo(currentKey)) {
      sequence.add(startChord);
      
      // Look forward for consecutive non-diatonic chords
      for (int i = startIndex + 1; i < _chordSymbols.length; i++) {
        final chord = _chordSymbols[i];
        if (!chord.isDiatonicTo(currentKey)) {
          sequence.add(chord);
        } else {
          break; // Stop at first diatonic chord
        }
      }
    }
    
    return sequence;
  }

  /// Hides the dial menu widget
  void _hideDialMenuWidget() {
    setState(() {
      _showDialMenu = false;
      _selectedChordGroup = null;
    });
  }

  /// Builds the dial menu widget that appears below the key indicator
  Widget _buildDialMenuWidget() {
    // Disabled when chord symbols are disabled
    if (_chordSymbols.isEmpty) {
      return const SizedBox.shrink();
    }
    
    if (!_showDialMenu || _selectedChordGroup == null) {
      return const SizedBox.shrink(); // Return empty widget when not showing
    }

    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    // Get the current key context for non-diatonic chord
    final currentKey = _getCurrentKeyName();

    // Create the dial menu items with proper arrangement
    final outerItems = _createMajorKeyDialItems(currentKey);
    final innerItems = _createMinorKeyDialItems(currentKey);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ClayContainer(
        color: surfaceColor,
        borderRadius: 20,
        depth: 12,
        spread: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Reharmonize Sequence',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              ConcentricDialMenu(
                size: 250,
                outerItems: outerItems,
                innerItems: innerItems,
                onSelectionChanged: (innerIndex, outerIndex) {
                  print('🎵 DIAL MENU: Selection changed - innerIndex: $innerIndex, outerIndex: $outerIndex');
                  
                  if (outerIndex != null) {
                    final selectedKey = outerItems[outerIndex].label;
                    print('🎵 DIAL MENU: Selected major key "$selectedKey"');
                    _applyKeyChangeToChordGroup(selectedKey, false);
                    _hideDialMenuWidget();
                  } else if (innerIndex != null) {
                    final selectedKey = innerItems[innerIndex].label;
                    print('🎵 DIAL MENU: Selected minor key "$selectedKey"');
                    _applyKeyChangeToChordGroup(selectedKey.replaceAll('m', ''), true);
                    _hideDialMenuWidget();
                  }
                },
                centerText: 'Keys',
                highlightedOuterIndex: _getCurrentlyModifiedMajorKeyIndex(outerItems),
                highlightedInnerIndex: _getCurrentlyModifiedMinorKeyIndex(innerItems),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _hideDialMenuWidget,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Applies a key change to the selected chord group
  void _applyKeyChangeToChordGroup(String keyName, bool isMinor) {
    print('🎵 APPLY KEY CHANGE: Called with keyName="$keyName", isMinor=$isMinor');
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
    print('🎵 APPLY KEY CHANGE: Updating ${_selectedChordGroup!.length} chords');

    setState(() {
      // Apply the modified key signature directly to all chords in the group
      for (int i = 0; i < _selectedChordGroup!.length; i++) {
        final originalChord = _selectedChordGroup![i];
        print('🎵 APPLY KEY CHANGE: Updating chord: ${originalChord.displayText}');
        
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
          print('🎵 APPLY KEY CHANGE: Created MusicXML chord with modifiedKey: ${newChord.modifiedKeySignature}');
        } else {
          // Direct creation
          newChord = ChordSymbol(
            originalChord.rootName!,
            originalChord.quality!,
            position: originalChord.position,
            originalKeySignature: originalChord.originalKeySignature,
            modifiedKeySignature: newKeySignature,
          );
          print('🎵 APPLY KEY CHANGE: Created direct chord with modifiedKey: ${newChord.modifiedKeySignature}');
        }
        
        // Update the chord in the selected group
        _selectedChordGroup![i] = newChord;
        
        // Find and update this chord in all data structures
        _updateChordInAllStructures(originalChord, newChord);
        
        print('🎵 APPLY KEY CHANGE: Updated chord: ${newChord.displayText}');
      }
      
      // Invalidate sheet music cache since chord symbols have changed
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
      print('🎵 APPLY KEY CHANGE: Invalidated cache');
      
      // Debug: Print a few chord symbols to verify they have the new modifiedKeySignature
      for (int i = 0; i < math.min(3, _selectedChordGroup!.length); i++) {
        final chord = _selectedChordGroup![i];
        print('🎵 UPDATED CHORD $i: ${chord.effectiveRootName}${chord.effectiveQuality} - originalKey: ${chord.originalKeySignature}, modifiedKey: ${chord.modifiedKeySignature}');
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
    
    print('🎵 APPLY KEY CHANGE: Complete');
  }

  /// Updates a chord in all data structures (_chordSymbols and _chordMeasures)
  void _updateChordInAllStructures(ChordSymbol originalChord, ChordSymbol newChord) {
    print('🎵 UPDATE STRUCTURES: Updating ${originalChord.displaySymbol} -> ${newChord.displaySymbol}');
    
    // Update in flat _chordSymbols list using property matching instead of object equality
    for (int i = 0; i < _chordSymbols.length; i++) {
      if (_chordsMatch(_chordSymbols[i], originalChord)) {
        _chordSymbols[i] = newChord;
        print('🎵 UPDATE STRUCTURES: Updated _chordSymbols[$i] from ${originalChord.displaySymbol} to ${newChord.displaySymbol}');
      }
    }
    
    // Update in _chordMeasures
    for (int measureIndex = 0; measureIndex < _chordMeasures.length; measureIndex++) {
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
          
          print('🎵 UPDATE STRUCTURES: Updated measure $measureIndex, chord $localIndex from ${originalChord.displaySymbol} to ${newChord.displaySymbol}');
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

  /// Updates chord symbols in measures to match the flat _chordSymbols list
  /// This ensures that changes to _chordSymbols are reflected in the chord measures
  void _updateChordSymbolsInMeasures() {
    print('🎵 UPDATE MEASURES: Starting update for ${_chordMeasures.length} measures');
    int globalChordIndex = 0;
    
    for (int measureIndex = 0; measureIndex < _chordMeasures.length; measureIndex++) {
      final chordMeasure = _chordMeasures[measureIndex];
      final originalChordSymbols = chordMeasure.chordSymbols;
      
      // Create a new list with updated chord symbols
      final updatedChordSymbols = <ChordSymbol>[];
      
      for (int localChordIndex = 0; localChordIndex < originalChordSymbols.length; localChordIndex++) {
        if (globalChordIndex < _chordSymbols.length) {
          // Add the updated chord symbol from _chordSymbols
          updatedChordSymbols.add(_chordSymbols[globalChordIndex]);
          print('🎵 UPDATE MEASURES: Measure $measureIndex, local index $localChordIndex, global index $globalChordIndex: ${_chordSymbols[globalChordIndex].displayText}');
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
    
    print('🎵 UPDATE MEASURES: Updated chord symbols in ${_chordMeasures.length} measures, processed $globalChordIndex total chords');
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
      'C', 'G', 'D', 'A', 'E', 'B', 'F#', 'Db', 'Ab', 'Eb', 'Bb', 'F'
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
    
    return orderedKeys.map((key) => DialItem(
      label: key,
    )).toList();
  }

  /// Creates the minor key dial items (inner ring) with current key at top
  List<DialItem> _createMinorKeyDialItems(String currentKey) {
    final allMinorKeys = [
      'Am', 'Em', 'Bm', 'F#m', 'C#m', 'G#m', 'D#m', 'Bbm', 'Fm', 'Cm', 'Gm', 'Dm'
    ];
    
    // Extract minor key from current key context
    final currentMinorKey = _isMinorKey ? currentKey.split(' ')[0] + 'm' : _getRelativeMinor(currentKey.split(' ')[0]);
    final currentIndex = allMinorKeys.indexOf(currentMinorKey);
    final startIndex = currentIndex != -1 ? currentIndex : 0;
    
    // Arrange keys so current minor key is at the top (index 0)
    final orderedKeys = <String>[];
    for (int i = 0; i < allMinorKeys.length; i++) {
      final index = (startIndex + i) % allMinorKeys.length;
      orderedKeys.add(allMinorKeys[index]);
    }
    
    return orderedKeys.map((key) => DialItem(
      label: key,
    )).toList();
  }

  /// Gets the current key name
  String _getCurrentKeyName() {
    final keyParts = _keySignature.split(' / ');
    if (keyParts.length == 2) {
      return _isMinorKey ? keyParts[1].trim() : keyParts[0].trim();
    }
    return keyParts[0].trim();
  }

  /// Gets the relative minor key for a major key
  String _getRelativeMinor(String majorKey) {
    const majorToMinor = {
      'C': 'Am', 'G': 'Em', 'D': 'Bm', 'A': 'F#m', 'E': 'C#m', 'B': 'G#m',
      'F#': 'D#m', 'Db': 'Bbm', 'Ab': 'Fm', 'Eb': 'Cm', 'Bb': 'Gm', 'F': 'Dm'
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
  int? _getHighlightedMajorKeyIndex(String suggestedKey, List<DialItem> outerItems) {
    for (int i = 0; i < outerItems.length; i++) {
      if (outerItems[i].label == suggestedKey) {
        return i;
      }
    }
    return null;
  }

  /// Gets the highlighted index for minor key in the dial
  int? _getHighlightedMinorKeyIndex(String suggestedKey, List<DialItem> innerItems) {
    for (int i = 0; i < innerItems.length; i++) {
      if (innerItems[i].label == suggestedKey) {
        return i;
      }
    }
    return null;
  }

  /// Gets the currently modified major key index for highlighting in the dial
  int? _getCurrentlyModifiedMajorKeyIndex(List<DialItem> outerItems) {
    if (_selectedChordGroup == null || _selectedChordGroup!.isEmpty) return null;
    
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
    if (_selectedChordGroup == null || _selectedChordGroup!.isEmpty) return null;
    
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
    if (chord.modifiedKeySignature != null && _isStartOfReharmonizedGroup(chordIndex)) {
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
    return previousChord.modifiedKeySignature != currentChord.modifiedKeySignature;
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
          final beats = timeElement.findElements('beats').firstOrNull?.innerText ?? '4';
          final beatType = timeElement.findElements('beat-type').firstOrNull?.innerText ?? '4';
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
          final measureNumber = int.tryParse(measure.getAttribute('number') ?? '0') ?? 0;
          
          // Extract divisions for duration calculations
          final attributesInMeasure = measure.findElements('attributes').firstOrNull;
          if (attributesInMeasure != null) {
            final divisionsElement = attributesInMeasure.findElements('divisions').firstOrNull;
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
                  print('Added chord symbol: ${chordSymbol.effectiveRootName}${chordSymbol.effectiveQuality} to measure $measureNumber');
                }
                break;
                
              case 'note':
                print('Processing note in measure $measureNumber');
                // Process note elements for duration calculations if needed
                final durationNode = element.findElements('duration').firstOrNull;
                
                if (durationNode != null) {
                  final durationValue = int.parse(durationNode.innerText);
                  final durationInBeats = durationValue / divisions;
                  print('  Note duration: $durationInBeats beats');
                }
                break;
            }
          }
          
          print('Measure $measureNumber: Found ${musicalSymbols.length} musical symbols and ${measureChords.length} chord symbols');
          
          // Create measure with musical symbols and chord symbols
          final chordMeasure = ChordMeasure(
            musicalSymbols.cast(),
            chordSymbols: measureChords,
            isNewLine: measureNumber % 6 == 1, // Set to true every 4 measures (1, 5, 9, etc.)
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

      print('📊 Parsed ${chordMeasures.length} measures with ${allChords.length} chords');
      for (int i = 0; i < chordMeasures.length; i++) {
        print('  Measure ${i + 1}: ${chordMeasures[i].musicalSymbols.length} symbols, ${chordMeasures[i].chordSymbols.length} chords');
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
        _totalSongDurationInBeats = _chordSymbols.fold(0.0, (sum, chord) => sum + (chord.durationBeats ?? 0.0));
        
        // Invalidate sheet music cache when measures change
        _cachedSheetMusicWidget = null;
        _lastRenderedMeasures = null;
      });

      // Initialize global keys for chord interaction
      _chordGlobalKeys = List.generate(_chordSymbols.length, (index) => GlobalKey());

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
  ChordSymbol? _createChordFromHarmony(XmlElement harmony, double durationInBeats, int measureNumber) {
    try {
      final rootElement = harmony.findElements('root').firstOrNull;
      if (rootElement == null) return null;
      
      final rootStep = rootElement.findElements('root-step').firstOrNull?.innerText;
      if (rootStep == null) return null;
      
      final rootAlter = int.tryParse(rootElement.findElements('root-alter').firstOrNull?.innerText ?? '0') ?? 0;
      final kindElement = harmony.findElements('kind').firstOrNull;
      final kind = kindElement?.getAttribute('text') ?? kindElement?.innerText ?? '';
      
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
      case -7: return KeySignatureType.cFlatMajor;
      case -6: return KeySignatureType.gFlatMajor;
      case -5: return KeySignatureType.dFlatMajor;
      case -4: return KeySignatureType.aFlatMajor;
      case -3: return KeySignatureType.eFlatMajor;
      case -2: return KeySignatureType.bFlatMajor;
      case -1: return KeySignatureType.fMajor;
      case 0: return KeySignatureType.cMajor;
      case 1: return KeySignatureType.gMajor;
      case 2: return KeySignatureType.dMajor;
      case 3: return KeySignatureType.aMajor;
      case 4: return KeySignatureType.eMajor;
      case 5: return KeySignatureType.bMajor;
      case 6: return KeySignatureType.fSharpMajor;
      case 7: return KeySignatureType.cSharpMajor;
      default: return KeySignatureType.cMajor;
    }
  }

  /// Gets the number of fifths for a given key name
  int _getKeyFifths(String keyName) {
    const keyToFifths = {
      'C': 0, 'G': 1, 'D': 2, 'A': 3, 'E': 4, 'B': 5, 'F#': 6, 'C#': 7,
      'F': -1, 'Bb': -2, 'Eb': -3, 'Ab': -4, 'Db': -5, 'Gb': -6, 'Cb': -7,
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
    return _getKeySignatureFromFifths(fifths, _isMinorKey);
  }

  /// Builds two buttons for major/minor key selection
  Widget _buildKeyModeButtons() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    
    final keyParts = _keySignature.split(' / ');
    if (keyParts.length != 2) {
      return Text(
        _keySignature,
        style: TextStyle(
          fontSize: 16,
          color: onSurfaceColor,
        ),
      );
    }
    
    final majorKey = keyParts[0].trim();
    final minorKey = keyParts[1].trim();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Major key button
        GestureDetector(
          onTap: _isMinorKey ? () => _setMajorMode() : null,
          child: ClayContainer(
            color: _isMinorKey ? surfaceColor : primaryColor,
            borderRadius: 18,
            depth: _isMinorKey ? 5 : 12,
            spread: _isMinorKey ? 1 : 3,
            curveType: _isMinorKey ? CurveType.none : CurveType.concave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '$majorKey Major',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: _isMinorKey ? FontWeight.normal : FontWeight.bold,
                  color: _isMinorKey ? onSurfaceColor.withOpacity(0.6) : Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Minor key button
        GestureDetector(
          onTap: !_isMinorKey ? () => _setMinorMode() : null,
          child: ClayContainer(
            color: !_isMinorKey ? surfaceColor : primaryColor,
            borderRadius: 18,
            depth: !_isMinorKey ? 5 : 12,
            spread: !_isMinorKey ? 1 : 3,
            curveType: !_isMinorKey ? CurveType.none : CurveType.concave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '$minorKey Minor',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: !_isMinorKey ? FontWeight.normal : FontWeight.bold,
                  color: !_isMinorKey ? onSurfaceColor.withOpacity(0.6) : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Sets the key mode to major
  void _setMajorMode() {
    setState(() {
      _isMinorKey = false;
      
      // Invalidate sheet music cache since key context changed
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
    });
  }

  /// Sets the key mode to minor
  void _setMinorMode() {
    setState(() {
      _isMinorKey = true;
      
      // Invalidate sheet music cache since key context changed
      _cachedSheetMusicWidget = null;
      _lastRenderedMeasures = null;
    });
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
    final currentKey = _isMinorKey ? '$minorKey Minor' : '$majorKey Major';
    
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
        
        print('Selection updated: start=${_dragStartIndex}, end=$index, selected=${_selectedChordIndices.toList()}');
      }
    }
  }

  /// Handles mouse hover during drag
  void _onChordHover(int index) {
    print('🖱️ Mouse hover on chord $index, isDragging: $_isDragging, isLongPressing: $_isLongPressing');
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
      final RenderBox? chordRenderBox = chordKey.currentContext?.findRenderObject() as RenderBox?;
      
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

    final selectedChords = _selectedChordIndices
        .toList()
        ..sort();
    
    // Get Roman numerals with qualities for the selected chords
    final selectedRomanNumerals = selectedChords
        .map((i) {
          final chord = _chordSymbols[i];
          final keyToUse = chord.modifiedKeySignature ?? _getCurrentKeySignature();
          final romanNumeral = chord.getRomanNumeralWithKey(keyToUse);
          final quality = chord.getQualitySuperscript();
          return quality.isNotEmpty ? '$romanNumeral$quality' : romanNumeral;
        })
        .toList();
    
    final romanNumeralSequence = selectedRomanNumerals.join(' - ');
    
    final TextEditingController nameController = TextEditingController(text: romanNumeralSequence);
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
  void _createChordProgressionPracticeItem(String name, String description, List<String> romanNumerals) {
    if (widget.practiceArea == null) return;

    // Create chord progression with Roman numerals
    final chordProgression = ChordProgression(
      id: 'cp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      chords: romanNumerals, // Store Roman numerals with qualities
      key: _isMinorKey ? _keySignature.split(' / ')[1].trim() : _keySignature.split(' / ')[0].trim(),
      tempo: _currentBpm,
      timeSignature: _timeSignature,
      romanNumerals: romanNumerals, // Also store in the romanNumerals field for consistency
    );

    // Create practice item
    final practiceItem = PracticeItem(
      id: 'pi_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      chordProgression: chordProgression,
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
        onTap: _showCreateChordProgressionDialog,
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
                Icon(
                  Icons.add,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'Create Practice Item (${_selectedChordIndices.length} chords selected)',
                  style: TextStyle(
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

    final theme = Theme.of(context);
    final tertiaryColor = theme.colorScheme.tertiary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: _showCreateGeneralPracticeItemDialog,
        child: ClayContainer(
          color: tertiaryColor,
          borderRadius: 20,
    
          curveType: CurveType.convex,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Practice Item',
                  style: TextStyle(
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
  void _insertSymbolAtPosition(MusicalSymbol symbol, int measureIndex, int positionIndex) {
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
      print('🎵 Inserted symbol ${symbol.runtimeType} at measure $measureIndex, position $positionIndex. Invalidating cache.');
    });
  }

  /// Updates a musical symbol in a measure at a specific position.
  void _updateSymbolAtPosition(MusicalSymbol symbol, int measureIndex, int positionIndex) {
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
      print('🎵 Updated symbol at measure $measureIndex, position $positionIndex. Invalidating cache.');
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
      print('🎵 Deleted symbol at measure $measureIndex, position $positionIndex. Invalidating cache.');
    });
  }

  /// Builds cached sheet music widget to prevent expensive rebuilds
  Widget _buildCachedSheetMusic() {
    // Only rebuild sheet music if measures actually changed
    if (_cachedSheetMusicWidget == null || 
        _lastRenderedMeasures == null ||
        !listEquals(_lastRenderedMeasures, _chordMeasures)) { // Use listEquals for proper comparison
      
      _cachedSheetMusicWidget = _chordMeasures.isNotEmpty 
        ? RepaintBoundary(
            child: music_sheet.SimpleSheetMusic(
              height: 300,
              width: 800, // Increased width for better visibility
              measures: _chordMeasures.cast<music_sheet.Measure>(),
              debug: false, // Disable debug mode for performance
              initialKeySignatureType: _getCurrentKeySignature(), // Pass current key signature
              onSymbolAdd: _insertSymbolAtPosition,
              onSymbolUpdate: _updateSymbolAtPosition,
              onSymbolDelete: _deleteSymbolAtPosition,
              // Connect chord symbol interactions to song viewer functionality
              onChordSymbolTap: _onChordSymbolTap,
              onChordSymbolLongPress: _onChordSymbolLongPress,
              onChordSymbolLongPressEnd: _onChordSymbolLongPressEnd,
              onChordSymbolHover: _onChordSymbolHover,
              isChordSelected: _isChordSelected,
            ),
          )
        : Container(
            child: Center(
              child: Text('No measures to display'),
            ),
          );
      
      _lastRenderedMeasures = List.from(_chordMeasures);
    }
    
    return _cachedSheetMusicWidget!;
  }

  /// Handles chord symbol taps from sheet music
  void _onChordSymbolTap(dynamic chordSymbol, int globalChordIndex) {
    print('Chord symbol tapped: ${chordSymbol.toString()} at index $globalChordIndex');
    
    // Use the actual chord symbol that was tapped instead of relying on globalChordIndex
    if (chordSymbol != null) {
      print('Tapped chord: ${chordSymbol.displaySymbol}');
      print('Current chord symbols: ${_chordSymbols.map((c) => c.displaySymbol).join(', ')}');
      final currentKey = _getCurrentKeySignature();
      
      // ALWAYS check against the original key signature for dial menu availability
      // A chord should be considered non-diatonic (and thus tappable) if it's non-diatonic to the ORIGINAL key
      final keyForAnalysis = chordSymbol.originalKeySignature ?? currentKey;
      if (!chordSymbol.isDiatonicTo(keyForAnalysis)) {
        print('Non-diatonic chord detected: ${chordSymbol.displaySymbol} (non-diatonic to original key: $keyForAnalysis), showing dial menu');
        
        // Find the actual index of this chord in _chordSymbols for consecutive detection
        final actualIndex = _findChordIndex(chordSymbol);
        if (actualIndex != -1) {
          _showDialMenuWidget([actualIndex]);
        } else {
          print('Warning: Could not find chord ${chordSymbol.displaySymbol} in _chordSymbols list');
        }
      } else {
        print('chord ${chordSymbol.displaySymbol} is diatonic to $keyForAnalysis, no menu needed');
      }
    }
  }

  /// Finds the index of a chord symbol in the _chordSymbols list
  int _findChordIndex(dynamic targetChord) {
    for (int i = 0; i < _chordSymbols.length; i++) {
      final chord = _chordSymbols[i];
      // Use the same matching logic as _chordsMatch
      if (_chordsMatch(chord, targetChord)) {
        return i;
      }
    }
    return -1;
  }

  /// Handles chord symbol long press from sheet music - starts selection mode
  void _onChordSymbolLongPress(dynamic chordSymbol, int globalChordIndex) {
    print('Chord symbol long pressed: ${chordSymbol.toString()} at index $globalChordIndex');
    
    // Use the actual chord symbol instead of relying on globalChordIndex
    if (chordSymbol != null) {
      final actualIndex = _findChordIndex(chordSymbol);
      if (actualIndex != -1) {
        _startLongPressSelection(actualIndex);
      } else {
        print('Warning: Could not find chord ${chordSymbol.displaySymbol} in _chordSymbols list for long press');
      }
    }
  }

  /// Handles chord symbol long press end from sheet music - ends selection mode
  void _onChordSymbolLongPressEnd(dynamic chordSymbol, int globalChordIndex, dynamic details) {
    print('Chord symbol long press ended: ${chordSymbol.toString()} at index $globalChordIndex');
    
    // End selection mode
    _endChordSelection();
  }

  /// Handles chord symbol hover during drag selection
  void _onChordSymbolHover(dynamic chordSymbol, int globalChordIndex) {
    print('Chord symbol hover: ${chordSymbol.toString()} at index $globalChordIndex');
    
    // Update selection if we're dragging
    if (_isDragging && _isLongPressing) {
      _updateChordSelectionDrag(globalChordIndex);
    }
  }

  /// Returns whether a chord symbol is currently selected
  bool _isChordSelected(int globalChordIndex) {
    return _selectedChordIndices.contains(globalChordIndex);
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
    
    // Dispose ValueNotifiers
    _beatNotifier.dispose();
    _songBeatNotifier.dispose();
    
    super.dispose();
  }

  /// Builds the practice items widget at the bottom of the screen
  Widget _buildPracticeItemsWidget() {
    if (widget.practiceArea == null || widget.practiceArea!.practiceItems.isEmpty) {
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
        depth: 12,
        spread: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Practice Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: widget.practiceArea!.practiceItems.length,
                itemBuilder: (context, index) {
                  final practiceItem = widget.practiceArea!.practiceItems[index];
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
                        color: secondaryColor,
                        borderRadius: 12,
                        depth: 8,
                        spread: 2,
                        curveType: CurveType.none,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                practiceItem.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                              if (practiceItem.description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  practiceItem.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
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
        body: GestureDetector(
          onTap: _handleTapOutside, // Clear selection when tapping anywhere outside chords
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                _buildKeyModeButtons(),
                                const SizedBox(height: 8),
                                _buildCurrentKeyIndicator(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Add the dial menu widget below the key indicator
                  _buildDialMenuWidget(),
                  const SizedBox(height: 20),
                  // Playback controls
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClayContainer(
                      color: surfaceColor,
                      borderRadius: 20,
                      depth: 10,
                      spread: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // BPM Controls
                            ClayContainer(
                              color: surfaceColor,
                              borderRadius: 15,
                              depth: 5,
                              spread: 1,
                              curveType: CurveType.concave,
                              child: IconButton(
                                icon: Icon(Icons.remove, color: primaryColor),
                                onPressed: () => _changeBpm(-5),
                              ),
                            ),
                            Text(
                              '$_currentBpm BPM',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: onSurfaceColor,
                              ),
                            ),
                            ClayContainer(
                              color: surfaceColor,
                              borderRadius: 15,
                              depth: 5,
                              spread: 1,
                              curveType: CurveType.concave,
                              child: IconButton(
                                icon: Icon(Icons.add, color: primaryColor),
                                onPressed: () => _changeBpm(5),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              _timeSignature,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: onSurfaceColor,
                              ),
                            ),
                            const Spacer(),
                            // Playback Controls
                            ClayContainer(
                              color: surfaceColor,
                              borderRadius: 20,
                              depth: 8,
                              spread: 2,
                              curveType: CurveType.concave,
                              child: IconButton(
                                icon: Icon(Icons.replay, color: primaryColor),
                                iconSize: 32,
                                onPressed: _restartPlayback,
                              ),
                            ),
                            ClayContainer(
                              color: primaryColor,
                              borderRadius: 25,
                              depth: 12,
                              spread: 3,
                              curveType: _isPlaying ? CurveType.concave : CurveType.none,
                              child: IconButton(
                                icon: Icon(
                                  _isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  color: Colors.white,
                                ),
                                iconSize: 48,
                                onPressed: _togglePlayback,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Sheet Music Display with Canvas-based Chord Symbols
                  if (_chordMeasures.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClayContainer(
                        color: surfaceColor,
                        borderRadius: 20,
                        depth: 10,
                        spread: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            width: double.infinity, // Use full available width
                            height: 300, // Increased height to match SimpleSheetMusic
                            child: _buildCachedSheetMusic(),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Chord progression creation button (appears when chords are selected)
                  _buildChordProgressionButton(),
                  // Help text for long press selection
                  if (_selectedChordIndices.isEmpty && !_isLongPressing)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ClayContainer(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: 12,
                        depth: 8,
                        spread: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Chord symbols are displayed above each measure in the sheet music',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Beat timeline - positioned right after sheet music
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: BeatTimeline(
                        beatsPerMeasure: _beatsPerMeasure,
                        currentProgress:
                            _currentBeatInMeasure + 1, // Convert to 1-indexed
                        userInputMarkers: _userInputBeats,
                        textColor: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
        ), // GestureDetector
      );
  }
    }
