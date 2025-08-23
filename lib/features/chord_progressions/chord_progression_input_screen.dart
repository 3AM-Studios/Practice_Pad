import 'package:flutter/material.dart';
import 'package:practice_pad/features/chord_progressions/chord_symbol_parser.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';
import 'package:practice_pad/models/chord_progression.dart';

class ChordProgressionInputScreen extends StatefulWidget {
  final ChordProgression? initialProgression;

  const ChordProgressionInputScreen({
    super.key,
    this.initialProgression,
  });

  @override
  State<ChordProgressionInputScreen> createState() => _ChordProgressionInputScreenState();
}

class _ChordProgressionInputScreenState extends State<ChordProgressionInputScreen> {
  final TextEditingController _chordInputController = TextEditingController();
  final FocusNode _chordInputFocusNode = FocusNode();
  
  final List<String> _chords = [];
  int? _selectedChordIndex; // Index of currently highlighted chord
  String? _parseError;
  
  // Roman numeral mode state
  bool _isRomanNumeralMode = false;
  String _currentQuality = 'Maj'; // 'Maj', 'Min', 'o/', 'o', '7th'
  String _currentRomanNumeral = 'I';

  @override
  void initState() {
    super.initState();
    
    // Load initial progression if provided
    if (widget.initialProgression != null) {
      _chords.addAll(widget.initialProgression!.chords);
    }
    
    // Focus the input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chordInputFocusNode.requestFocus();
    });
  }

  void _addChord() {
    final input = _chordInputController.text.trim();
    if (input.isEmpty) return;

    try {
      // Test parsing to validate input
      ChordSymbolParser.parseChordSymbol(input);
      
      setState(() {
        _chords.add(input);
        _selectedChordIndex = _chords.length - 1; // Highlight the new chord
        _chordInputController.clear();
        _parseError = null;
      });
      
      // Focus back to input field
      _chordInputFocusNode.requestFocus();
      
    } catch (e) {
      setState(() {
        _parseError = e.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  void _editChord(int index) {
    setState(() {
      _selectedChordIndex = index;
      _chordInputController.text = _chords[index];
    });
    _chordInputFocusNode.requestFocus();
  }

  void _updateSelectedChord() {
    if (_selectedChordIndex == null) return;
    
    final input = _chordInputController.text.trim();
    if (input.isEmpty) return;

    try {
      // Test parsing to validate input
      ChordSymbolParser.parseChordSymbol(input);
      
      setState(() {
        _chords[_selectedChordIndex!] = input;
        _parseError = null;
      });
      
    } catch (e) {
      setState(() {
        _parseError = e.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  void _removeChord(int index) {
    setState(() {
      _chords.removeAt(index);
      if (_selectedChordIndex == index) {
        _selectedChordIndex = null;
        _chordInputController.clear();
      } else if (_selectedChordIndex != null && _selectedChordIndex! > index) {
        _selectedChordIndex = _selectedChordIndex! - 1;
      }
    });
  }

  void _deselectChord() {
    setState(() {
      _selectedChordIndex = null;
      _chordInputController.clear();
      _parseError = null;
    });
  }

  ChordProgression _buildChordProgression() {
    final progressionName = _chords.join(' - ');
    
    return ChordProgression(
      id: widget.initialProgression?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: progressionName,
      chords: List.from(_chords),
    );
  }

  bool _isValid() {
    return _chords.isNotEmpty;
  }

  // Roman numeral methods
  void _toggleRomanNumeralMode() {
    setState(() {
      _isRomanNumeralMode = !_isRomanNumeralMode;
      if (_isRomanNumeralMode) {
        _updateTextFromRomanNumeral();
      }
    });
  }

  void _setQuality(String quality) {
    setState(() {
      _currentQuality = quality;
      _updateTextFromRomanNumeral();
    });
  }

  void _setRomanNumeral(String numeral) {
    setState(() {
      _currentRomanNumeral = numeral;
      _updateTextFromRomanNumeral();
    });
  }

  void _updateTextFromRomanNumeral() {
    if (!_isRomanNumeralMode) return;

    String result = _currentRomanNumeral;
    
    // Apply case based on quality
    if (_currentQuality == 'Min' || _currentQuality == 'o/' || _currentQuality == 'o') {
      result = result.toLowerCase();
    } else {
      result = result.toUpperCase();
    }
    
    // Apply quality suffix
    switch (_currentQuality) {
      case '7th':
        result += '7';
        break;
      case 'Maj':
        // No suffix for major
        break;
      case 'Min':
        // Lowercase already applied
        break;
      case 'o/':
        result += 'ø7';
        break;
      case 'o':
        result += '°7';
        break;
    }

    _chordInputController.text = result;
  }

  List<String> _getRomanNumerals() {
    return ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];
  }

  Widget _buildQualityButton(String quality, String displayText) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _currentQuality == quality;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _setQuality(quality),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? colorScheme.primary 
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? colorScheme.primary 
                  : colorScheme.outline.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            displayText,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected 
                  ? colorScheme.onPrimary 
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRomanNumeralButton(String numeral) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _currentRomanNumeral == numeral;
    
    // Display case based on quality
    String displayText = numeral;
    if (_currentQuality == 'Min' || _currentQuality == 'o/' || _currentQuality == 'o') {
      displayText = displayText.toLowerCase();
    }
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _setRomanNumeral(numeral),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? colorScheme.primary 
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? colorScheme.primary 
                  : colorScheme.outline.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            displayText,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isSelected 
                  ? colorScheme.onPrimary 
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  String _getDisplayText(String chord) {
    try {
      // Parse to get the standardized quality, but preserve the original root
      final parsedChord = ChordSymbolParser.parseChordSymbol(chord);
      return _formatChordProgressionDisplay(chord, parsedChord);
    } catch (e) {
      return chord;
    }
  }
  
  String _formatChordProgressionDisplay(String originalChord, ChordSymbol parsedChord) {
    // Extract root from original input to preserve Roman numerals vs chord names
    final romanMatch = RegExp(r'^(i{1,3}v?|iv|v|vi{0,2}|VII?)', caseSensitive: false).firstMatch(originalChord);
    final chordNameMatch = RegExp(r'^[A-G][#b♯♭]?').firstMatch(originalChord);
    
    String root;
    
    if (romanMatch != null) {
      // Roman numeral - preserve exact case from user input
      root = romanMatch.group(0)!;
    } else if (chordNameMatch != null) {
      // Chord name - preserve exact case from user input  
      root = chordNameMatch.group(0)!;
    } else {
      root = parsedChord.effectiveRootName;
    }
    
    // Use the standardized formatting from ChordSymbol
    final quality = parsedChord.effectiveQuality;
    final formattedQuality = ChordSymbol.formatChordQuality(quality);
    
    return '$root$formattedQuality';
  }

  @override
  void dispose() {
    _chordInputController.dispose();
    _chordInputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.initialProgression != null ? 'Edit Chord Progression' : 'Add Chord Progression',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isValid() ? () {
              final progression = _buildChordProgression();
              Navigator.of(context).pop(progression);
            } : null,
            style: TextButton.styleFrom(
              foregroundColor: _isValid() ? colorScheme.primary : colorScheme.outline,
              textStyle: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header section
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.music_note,
                          size: 48,
                          color: colorScheme.primary.withOpacity(0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chord Progression',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add chords one by one to build your progression',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Chord display area
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.playlist_play,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Progression',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            if (_chords.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_chords.length} chord${_chords.length != 1 ? 's' : ''}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        if (_chords.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.music_off,
                                  size: 40,
                                  color: colorScheme.outline.withOpacity(0.7),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No chords added yet',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.outline,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Start adding chords below',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              ..._chords.asMap().entries.map((entry) {
                                final index = entry.key;
                                final chord = entry.value;
                                final isSelected = index == _selectedChordIndex;
                                
                                return GestureDetector(
                                  onTap: () => _editChord(index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? colorScheme.primary
                                          : colorScheme.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected 
                                            ? colorScheme.primary
                                            : colorScheme.outline.withOpacity(0.3),
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: isSelected ? [
                                        BoxShadow(
                                          color: colorScheme.primary.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ] : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _getDisplayText(chord),
                                          style: textTheme.titleMedium?.copyWith(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected 
                                                ? colorScheme.onPrimary
                                                : colorScheme.onSurface,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => _removeChord(index),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 20,
                                              color: colorScheme.onPrimary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              
                              // Add chord button
                              if (_selectedChordIndex == null)
                                GestureDetector(
                                  onTap: () => _chordInputFocusNode.requestFocus(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: colorScheme.secondary.withOpacity(0.5),
                                        width: 1,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add,
                                          size: 20,
                                          color: colorScheme.onSecondaryContainer,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Add Chord',
                                          style: textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Input section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _parseError != null 
                            ? colorScheme.error.withOpacity(0.5)
                            : colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _selectedChordIndex != null ? Icons.edit : Icons.add_circle_outline,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedChordIndex != null ? 'Edit Chord' : 'Add New Chord',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Mode toggle
                        Row(
                          children: [
                            Text(
                              'Input Mode:',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment(
                                  value: false,
                                  label: Text('Text'),
                                  icon: Icon(Icons.keyboard, size: 16),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('Roman'),
                                  icon: Icon(Icons.format_list_numbered, size: 16),
                                ),
                              ],
                              selected: {_isRomanNumeralMode},
                              onSelectionChanged: (Set<bool> newSelection) {
                                _toggleRomanNumeralMode();
                              },
                              style: SegmentedButton.styleFrom(
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                foregroundColor: colorScheme.onSurface,
                                selectedBackgroundColor: colorScheme.primary,
                                selectedForegroundColor: colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _chordInputController,
                                focusNode: _chordInputFocusNode,
                                readOnly: _isRomanNumeralMode,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: _selectedChordIndex != null 
                                      ? 'Edit chord...'
                                      : _isRomanNumeralMode 
                                          ? 'Use buttons below to build Roman numeral'
                                          : 'Enter chord (e.g., Imaj7, ii7, V7)',
                                  hintStyle: textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.error,
                                      width: 1,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                                onFieldSubmitted: (_) {
                                  if (_selectedChordIndex != null) {
                                    _updateSelectedChord();
                                  } else {
                                    _addChord();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                if (_selectedChordIndex != null) {
                                  _updateSelectedChord();
                                } else {
                                  _addChord();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                _selectedChordIndex != null ? 'Update' : 'Add',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Error message
                        if (_parseError != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: colorScheme.onErrorContainer,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _parseError!,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Cancel edit button
                        if (_selectedChordIndex != null) ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _deselectChord,
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.outline,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Cancel Edit',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Roman numeral buttons (when in Roman numeral mode)
          if (_isRomanNumeralMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Row 1: Quality buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQualityButton('7th', '7th'),
                      _buildQualityButton('Maj', 'Maj'),
                      _buildQualityButton('Min', 'min'),
                      _buildQualityButton('o/', 'ø7'),
                      _buildQualityButton('o', '°7'),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Row 2: Roman numeral buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _getRomanNumerals().map((numeral) {
                      return _buildRomanNumeralButton(numeral);
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Help section at bottom
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Examples',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isRomanNumeralMode) ...[
                  Text(
                    'Select quality (7th, Maj, min, ø7, °7) then Roman numeral (I-VII)',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Examples: I, ii, V7, viø7, vii°7',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(
                    'Roman numerals: Iᵐᵃʲ⁷, ii⁷, V⁷, vi, I, iiø⁷',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chord names: Cᵐᵃʲ⁷, Dm⁷, G⁷, Am, F',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _isRomanNumeralMode 
                    ? 'Tap buttons to build chord • Switch to Text mode for manual entry'
                    : 'Tap any chord to edit • Switch to Roman mode for guided entry',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}