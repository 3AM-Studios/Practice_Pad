import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:metronome/metronome.dart';
import 'package:xml/xml.dart';
import 'package:simple_sheet_music/simple_sheet_music.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/beat_timeline.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/concentric_dial_menu.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:practice_pad/models/chord_progression.dart';
import 'package:practice_pad/widgets/active_session_banner.dart';
import 'package:practice_pad/features/practice/presentation/pages/practice_session_screen.dart';

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

  List<ChordSymbol> _chords = [];
  int _currentChordIndex = 0;
  double _totalSongDurationInBeats = 0;
  int _currentBpm = 0;
  String _songTitle = '';
  String _keySignature = '';
  bool _isMinorKey = false; // Toggle between major/minor interpretation
  String _timeSignature = '';
  int _beatsPerMeasure = 4; // Default
  int _currentBeatInMeasure = 0;
  List<double> _userInputBeats = [];
  int _songBeatCounter = 0; // The master logical beat counter for the song

  // Dial menu state for non-diatonic chord reharmonization
  bool _showDialMenu = false; // Controls whether the dial menu widget is visible
  List<int>? _selectedChordGroup; // The chord group currently selected for key change

  // Chord selection state for practice item creation
  Set<int> _selectedChordIndices = <int>{}; // Selected chord indices
  bool _isDragging = false; // Whether user is currently dragging
  int? _dragStartIndex; // Starting index of drag selection
  bool _isLongPressing = false; // Whether user is in long press selection mode
  int? _animatingChordIndex; // Index of chord currently animating
  int? _lastHoveredIndex; // Last chord index that was hovered during drag
  List<GlobalKey> _chordGlobalKeys = []; // Keys for chord widgets to get their positions

  @override
  void initState() {
    super.initState();
    _currentBpm = widget.bpm;
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
    print('Showing dial menu widget for chord group: $chordGroup');
    
    setState(() {
      _showDialMenu = true;
      _selectedChordGroup = chordGroup;
    });
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
    if (!_showDialMenu || _selectedChordGroup == null) {
      return const SizedBox.shrink(); // Return empty widget when not showing
    }

    // Create the dial menu items
    final outerItems = _createMajorKeyDialItems();
    final innerItems = _createMinorKeyDialItems();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ConcentricDialMenu(
        size: 300,
        outerItems: outerItems,
        innerItems: innerItems,
        onSelectionChanged: (innerIndex, outerIndex) {
          // Handle key selection
          if (outerIndex != null) {
            print('Selected major key: ${outerItems[outerIndex].label} for chord group: $_selectedChordGroup');
            // TODO: Apply key change to the chord group
          }
          if (innerIndex != null) {
            print('Selected minor key: ${innerItems[innerIndex].label} for chord group: $_selectedChordGroup');
            // TODO: Apply key change to the chord group
          }
          _hideDialMenuWidget(); // Hide menu after selection
        },
      ),
    );
  }

  /// Creates the major key dial items (outer ring)
  List<DialItem> _createMajorKeyDialItems() {
    final majorKeys = [
      'C', 'G', 'D', 'A', 'E', 'B', 'F#', 'Db', 'Ab', 'Eb', 'Bb', 'F'
    ];
    
    return majorKeys.map((key) => DialItem(
      icon: Icons.music_note,
      label: key,
    )).toList();
  }

  /// Creates the minor key dial items (inner ring)
  List<DialItem> _createMinorKeyDialItems() {
    final minorKeys = [
      'Am', 'Em', 'Bm', 'F#m', 'C#m', 'G#m', 'D#m', 'Bbm', 'Fm', 'Cm', 'Gm', 'Dm'
    ];
    
    return minorKeys.map((key) => DialItem(
      icon: Icons.music_note,
      label: key,
    )).toList();
  }

  Future<void> _loadAndParseSong() async {
    try {
      // --- 1. Load and Prep ---
      final xmlString = await rootBundle.loadString(widget.songAssetPath);
      final doc = XmlDocument.parse(xmlString);

      final workTitle =
          doc.findAllElements('work-title').firstOrNull?.innerText ??
              'Unknown Title';
      final fifths = int.tryParse(
              doc.findAllElements('fifths').firstOrNull?.innerText ?? '0') ??
          0;
      final keySignature = _fifthsToKey[fifths] ?? 'Unknown';

      // Get the divisions value, essential for timing. Throws if not found.
      final divisions =
          int.parse(doc.findAllElements('divisions').first.innerText);

      // Get time signature for the metronome
      final timeElement = doc.findAllElements('time').first;
      final beats =
          int.parse(timeElement.findElements('beats').first.innerText);
      final beatType =
          int.parse(timeElement.findElements('beat-type').first.innerText);
      final timeSignature = '$beats/$beatType';
      _beatsPerMeasure = beats;

      // --- 2. The Parsing Logic ---
      final List<ChordSymbol> allChords = [];
      XmlElement? activeHarmony; // The chord that is currently active

      // Find all <part> elements and then iterate through their children
      final parts = doc.findAllElements('part');
      for (final part in parts) {
        final measures = part.findElements('measure');
        for (final measure in measures) {
          final measureNumber =
              int.tryParse(measure.getAttribute('number') ?? '0') ?? 0;
          // In each measure, process elements in order
          for (final element in measure.children.whereType<XmlElement>()) {
            // If we find a new harmony, it becomes the active one
            if (element.name.local == 'harmony') {
              activeHarmony = element;
            }

            // If we find a note, it inherits the active harmony and gives it duration
            if (element.name.local == 'note') {
              // Only process notes that have duration and aren't rests
              final durationNode = element.findElements('duration').firstOrNull;
              final isRest = element.findElements('rest').isNotEmpty;

              if (durationNode != null && !isRest && activeHarmony != null) {
                final durationValue = int.parse(durationNode.innerText);
                final durationInBeats = durationValue / divisions;

                // Extract chord details from the active harmony
                final rootElement = activeHarmony.findElements('root').first;
                final rootStep =
                    rootElement.findElements('root-step').first.innerText;
                final rootAlter = int.tryParse(rootElement
                            .findElements('root-alter')
                            .firstOrNull
                            ?.innerText ??
                        '0') ??
                    0;
                final kindElement = activeHarmony.findElements('kind').first;
                final kind =
                    kindElement.getAttribute('text') ?? kindElement.innerText;

                // Create the timed chord and add it to our list
                allChords.add(ChordSymbol.fromMusicXML(
                  rootStep,
                  rootAlter,
                  kind,
                  durationInBeats,
                  measureNumber,
                ));
              }
            }
          }
        }
      }

      // Error handling if parsing yields no chords
      if (allChords.isEmpty) {
        throw 'No valid chords were parsed from the MusicXML file.';
      }

      // --- 3. Initialize Metronome and State ---
      await _metronome.init(
        'assets/audio/claves44_wav.wav',
        accentedPath: 'assets/audio/woodblock_high44_wav.wav',
        bpm: _currentBpm,
        timeSignature: _beatsPerMeasure,
        enableTickCallback: true,
      );

      _tickSubscription = _metronome.tickStream.listen(_onTick);

      setState(() {
        _isLoading = false;
        _chords = allChords;
        _songTitle = workTitle;
        _keySignature = keySignature;
        _timeSignature = timeSignature;
        _totalSongDurationInBeats =
            _chords.fold(0, (prev, chord) => prev + (chord.durationBeats ?? 0));
        // Initialize chord keys for position tracking
        _chordGlobalKeys = List.generate(_chords.length, (index) => GlobalKey());
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading/parsing song: $e');
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
    final keyParts = _keySignature.split(' / ');
    if (keyParts.length != 2) {
      return Text(_keySignature, style: const TextStyle(fontSize: 16));
    }
    
    final majorKey = keyParts[0].trim();
    final minorKey = keyParts[1].trim();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Major key button
        ElevatedButton(
          onPressed: _isMinorKey ? () => _setMajorMode() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isMinorKey ? Colors.grey.shade300 : Colors.blue.shade700,
            foregroundColor: _isMinorKey ? Colors.grey.shade600 : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(0, 36),
            elevation: _isMinorKey ? 0 : 4,
            shadowColor: _isMinorKey ? Colors.transparent : Colors.blue.shade300,
          ),
          child: Text(
            '$majorKey Major',
            style: TextStyle(
              fontSize: 14,
              fontWeight: _isMinorKey ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Minor key button
        ElevatedButton(
          onPressed: !_isMinorKey ? () => _setMinorMode() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: !_isMinorKey ? Colors.grey.shade300 : Colors.blue.shade700,
            foregroundColor: !_isMinorKey ? Colors.grey.shade600 : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(0, 36),
            elevation: !_isMinorKey ? 0 : 4,
            shadowColor: !_isMinorKey ? Colors.transparent : Colors.blue.shade300,
          ),
          child: Text(
            '$minorKey Minor',
            style: TextStyle(
              fontSize: 14,
              fontWeight: !_isMinorKey ? FontWeight.normal : FontWeight.bold,
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
    });
  }

  /// Sets the key mode to minor
  void _setMinorMode() {
    setState(() {
      _isMinorKey = true;
    });
  }

  /// Builds the current key indicator text below the buttons
  Widget _buildCurrentKeyIndicator() {
    final keyParts = _keySignature.split(' / ');
    if (keyParts.length != 2) {
      return const SizedBox.shrink();
    }
    
    final majorKey = keyParts[0].trim();
    final minorKey = keyParts[1].trim();
    final currentKey = _isMinorKey ? '$minorKey Minor' : '$majorKey Major';
    
    return Text(
      'Current Key: $currentKey',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
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
      _animatingChordIndex = null;
      _lastHoveredIndex = null;
    });
  }

  /// Starts chord selection from a long press
  void _startLongPressSelection(int index) {
    print('🚀 Starting long press selection on chord $index');
    setState(() {
      _animatingChordIndex = index;
      _isLongPressing = true;
      _selectedChordIndices.clear();
      _selectedChordIndices.add(index);
      _isDragging = true; // Start dragging immediately
      _dragStartIndex = index;
      _lastHoveredIndex = index;
    });
    
    // Trigger animation and haptic feedback
    HapticFeedback.mediumImpact();
    
    // Clear animation after short delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _animatingChordIndex = null;
        });
      }
    });
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
          
          for (int i = min; i <= max && i < _chords.length; i++) {
            _selectedChordIndices.add(i);
          }
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
      _animatingChordIndex = null;
      // Keep _selectedChordIndices as is to show the selected chords
    });
  }

  /// Cancels selection (if user lifts finger too early)
  void _cancelSelection() {
    setState(() {
      _isDragging = false;
      _isLongPressing = false;
      _animatingChordIndex = null;
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
          final chord = _chords[i];
          final romanNumeral = chord.getRomanNumeralWithKey(_getCurrentKeySignature());
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
    if (_selectedChordIndices.isEmpty || widget.practiceArea == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: _showCreateChordProgressionDialog,
        icon: const Icon(Icons.add),
        label: Text('Create Practice Item (${_selectedChordIndices.length} chords selected)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
      child: ElevatedButton.icon(
        onPressed: _showCreateGeneralPracticeItemDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Practice Item'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _metronome.play();
      } else {
        _metronome.pause();
      }
    });
  }

  void _restartPlayback() {
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
  }

  void _changeBpm(int delta) {
    setState(() {
      _currentBpm = (_currentBpm + delta).clamp(40, 300);
      _metronome.setBPM(_currentBpm);
    });
  }

  void _jumpToChord(int index) {
    double newSongBeatCounter = 0;
    for (int i = 0; i < index; i++) {
      newSongBeatCounter += _chords[i].durationBeats ?? 0;
    }

    _songBeatCounter = newSongBeatCounter.floor();
    final progressInMeasure = newSongBeatCounter % _beatsPerMeasure;

    setState(() {
      _currentBeatInMeasure = progressInMeasure.floor() + 1;
    });
  }

  void _onTick(int tick) {
    if (!mounted || !_isPlaying) return;
    setState(() {
      _songBeatCounter++;
      _currentBeatInMeasure = tick;
      if (tick == 0) {
        _userInputBeats.clear();
      }
    });
  }


  bool _updateCurrentChordBasedOnBeat() {
    if (_chords.isEmpty) return false;

    double cumulativeBeats = 0;
    int newChordIndex = 0;
    bool found = false;

    // Handle song looping
    final totalBeats = _totalSongDurationInBeats;
    if (totalBeats > 0 && _songBeatCounter > totalBeats) {
      _songBeatCounter = 1; // Loop back to the beginning
    }

    for (int i = 0; i < _chords.length; i++) {
      cumulativeBeats += _chords[i].durationBeats ?? 0;
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
    super.dispose();
  }

  /// Builds the practice items widget at the bottom of the screen
  Widget _buildPracticeItemsWidget() {
    if (widget.practiceArea == null || widget.practiceArea!.practiceItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 160, // Increased height to accommodate larger text and more lines
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Practice Items',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
                    width: 200, // Increased width for better text display
                    margin: const EdgeInsets.only(right: 12, bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade600),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          practiceItem.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2, // Allow 2 lines for practice item names
                          overflow: TextOverflow.ellipsis,
                          softWrap: true, // Enable soft wrapping
                        ),
                        if (practiceItem.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            practiceItem.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            maxLines: 3, // Allow more lines for description
                            overflow: TextOverflow.ellipsis,
                            softWrap: true, // Enable soft wrapping
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_chords.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Error: No chords found in song.')),
      );
    }

    int lastMeasure = -1;

      return Scaffold(
        appBar: AppBar(
          title: Text(_songTitle, style: const TextStyle(fontSize: 18)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
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
                  Row(
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
                  // Add the dial menu widget below the key indicator
                  _buildDialMenuWidget(),
                  const SizedBox(height: 20),
                  // Playback controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // BPM Controls
                      IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () => _changeBpm(-5)),
                      Text('$_currentBpm BPM',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _changeBpm(5)),
                      const SizedBox(width: 16),
                      Text(_timeSignature,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // Playback Controls
                      IconButton(
                        icon: const Icon(Icons.replay),
                        iconSize: 32,
                        onPressed: _restartPlayback,
                      ),
                      IconButton(
                        icon: Icon(_isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled),
                        iconSize: 48,
                        onPressed: _togglePlayback,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Chord progression creation button (appears when chords are selected)
                  _buildChordProgressionButton(),
                  // Help text for long press selection
                  if (_selectedChordIndices.isEmpty && !_isLongPressing)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Long press and drag across chord symbols to select a progression',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click and drag across chord symbols to select multiple chords',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Chord symbols display with selection support
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 16.0,
                    children: _chords.asMap().entries.map((entry) {
                        final index = entry.key;
                        final chord = entry.value;
                        final isNonDiatonic = !chord.isDiatonicTo(_getCurrentKeySignature());
                        final isSelected = _selectedChordIndices.contains(index);
                        
                        bool isNewMeasure = false;
                        if (chord.measureNumber != lastMeasure) {
                          isNewMeasure = true;
                          lastMeasure = chord.measureNumber ?? 0;
                        }

                        return MouseRegion(
                          onEnter: (_) => _onChordHover(index),
                          child: GestureDetector(
                            onTap: () {
                              if (isNonDiatonic) {
                              // Show dial menu for non-diatonic chords
                              _showDialMenuWidget([index]);
                            } else if (_selectedChordIndices.isEmpty) {
                              // Regular jump to chord behavior only when no selection is active
                              _jumpToChord(index);
                            }
                            // If there's an active selection, tapping clears it
                            else {
                              _clearChordSelection();
                            }
                          },
                          onLongPress: () {
                            // Start long press selection for any chord (diatonic or non-diatonic)
                            _startLongPressSelection(index);
                          },
                          onLongPressEnd: (details) {
                            // Handle long press end for any chord
                            if (!_isDragging) {
                              _cancelSelection();
                            } else {
                              _endChordSelection();
                            }
                          },
                          child: AnimatedScale(
                            scale: _animatingChordIndex == index ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: AnimatedContainer(
                              key: index < _chordGlobalKeys.length ? _chordGlobalKeys[index] : null,
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.green.shade100 // Highlight selected chords (priority)
                                    : index == _currentChordIndex
                                        ? Colors.blue.shade100 // Current playing chord
                                        : isNonDiatonic
                                            ? Colors.orange.shade100.withOpacity(0.7) // Highlight non-diatonic
                                            : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: isNewMeasure
                                    ? const Border(
                                        left: BorderSide(
                                            color: Colors.black, width: 1.5))
                                    : isSelected
                                        ? Border.all(color: Colors.green, width: 2.0) // Selected border
                                        : isNonDiatonic
                                            ? Border.all(color: Colors.orange.shade400, width: 1.5)
                                            : null,
                                boxShadow: _animatingChordIndex == index
                                    ? [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: chord.getRomanNumeralWithKey(_getCurrentKeySignature()),
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              color: isSelected 
                                                  ? Colors.green.shade700
                                                  : isNonDiatonic ? Colors.orange.shade700 : Colors.blue),
                                        ),
                                        if (chord.getQualitySuperscript().isNotEmpty)
                                          TextSpan(
                                            text: chord.getQualitySuperscript(),
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.normal,
                                                color: isSelected 
                                                    ? Colors.green.shade700
                                                    : isNonDiatonic ? Colors.orange.shade700 : Colors.blue),
                                          ),
                                      ],
                                    ),
                                  ),
                                  RichText(
                                    text: TextSpan(
                                      children: chord.getFormattedChordSymbol().map((span) {
                                        return TextSpan(
                                          text: span.text,
                                          style: span.style?.copyWith(
                                            color: isSelected 
                                                ? Colors.green.shade800
                                                : isNonDiatonic ? Colors.orange.shade800 : Colors.white,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ), // GestureDetector  
                      ); // MouseRegion
                      }).toList(),
                  ), // Wrap
                  const SizedBox(height: 24),
                  // Beat timeline - positioned right after chord symbols
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