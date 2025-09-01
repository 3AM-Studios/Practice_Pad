import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:image_painter/image_painter.dart';
import 'base_controls.dart';

/// Roman numeral chord editor controls widget
class RomanNumeralLabelControls extends StatefulWidget {
  final ImagePainterController controller;

  const RomanNumeralLabelControls({
    super.key,
    required this.controller,
  });

  @override
  State<RomanNumeralLabelControls> createState() => _RomanNumeralLabelControlsState();
}

class _RomanNumeralLabelControlsState extends State<RomanNumeralLabelControls> {
  late TextEditingController _textController;
  bool _seventhToggled = false;
  String _currentQuality = 'Maj'; // Track current quality state
  String _selectedAccidental = '♮'; // Track selected accidental (natural by default)

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    
    // Listen to controller changes to update text field
    widget.controller.addListener(_onControllerChanged);
    _updateTextField();
    _parseCurrentChord();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    _updateTextField();
    _parseCurrentChord();
  }

  void _updateTextField() {
    if (_textController.text != widget.controller.currentChordText) {
      _textController.text = widget.controller.currentChordText;
    }
  }

  void _parseCurrentChord() {
    final chord = widget.controller.currentChordText;
    setState(() {
      _seventhToggled = chord.contains('7');
      _currentQuality = _getCurrentQuality(chord);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350, // Increased width to prevent button cutoff
      padding: const EdgeInsets.all(8), // Add padding to prevent clipping
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
        // Color and size controls (centered with input)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            children: [
              BaseControls(controller: widget.controller),
              Container(
                margin: const EdgeInsets.only(top: 8),
                child: Divider(
                  color: Colors.grey[700],
                  thickness: 1,
                  height: 1,
                ),
              ),
            ],
          ),
        ),

        // Row 0: Accidental buttons (centered with input)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final accidental in ['♮', '♭', '♯'])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildAccidentalButton(accidental),
                ),
            ],
          ),
        ),

        // Text input for chord text (centered with wooden clay styling)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 50,
          constraints: const BoxConstraints(maxWidth: 300),
          child: ClayContainer(
            color: Theme.of(context).colorScheme.surface,
            depth: 20,
            borderRadius: 20,
            child: Container(
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _textController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  hintText: 'Chord (e.g., I, ii, V7, viø7)',
                  hintStyle: TextStyle(color: Colors.white70),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: InputBorder.none,
                ),
                onChanged: (value) => widget.controller.setCurrentChordText(value),
              ),
            ),
          ),
        ),

        // Row 1: Quality modifiers and Delete button (centered with input)
        Container(
          margin: const EdgeInsets.only(bottom: 8), // Reduced margin to prevent clipping
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildToggleButton('7th', _seventhToggled, () {
                  setState(() {
                    _seventhToggled = !_seventhToggled;
                  });
                }),
                const SizedBox(width: 6),
                SizedBox(
                  height: 24,
                  child: VerticalDivider(
                    color: Colors.grey[700],
                    thickness: 1,
                    width: 12,
                  ),
                ),
                _buildModifierButton('Maj', () {
                  setState(() {
                    _currentQuality = 'Maj';
                  });
                  final baseNumeral = _getBaseNumeral(widget.controller.currentChordText);
                  String newChord = _applyQuality(baseNumeral, 'Maj', hasSeventh: _seventhToggled);
                  widget.controller.setCurrentChordText(newChord);
                }),
                const SizedBox(width: 6),
                _buildModifierButton('Min', () {
                  setState(() {
                    _currentQuality = 'Min';
                  });
                  final baseNumeral = _getBaseNumeral(widget.controller.currentChordText);
                  String newChord = _applyQuality(baseNumeral, 'Min', hasSeventh: _seventhToggled);
                  widget.controller.setCurrentChordText(newChord);
                }),
                const SizedBox(width: 6),
                _buildModifierButton('Dom', _seventhToggled ? () {
                  setState(() {
                    _currentQuality = 'Dom';
                  });
                  final baseNumeral = _getBaseNumeral(widget.controller.currentChordText);
                  String newChord = '${baseNumeral.toUpperCase()}7';
                  widget.controller.setCurrentChordText(newChord);
                } : null), // Disabled when 7th not selected
                const SizedBox(width: 6),
                _buildModifierButton('ø', () {
                  setState(() {
                    _currentQuality = 'ø';
                  });
                  final baseNumeral = _getBaseNumeral(widget.controller.currentChordText);
                  String newChord = _applyQuality(baseNumeral, 'ø', hasSeventh: _seventhToggled);
                  widget.controller.setCurrentChordText(newChord);
                }),
                const SizedBox(width: 6),
                _buildModifierButton('°', () {
                  setState(() {
                    _currentQuality = 'o';
                  });
                  final baseNumeral = _getBaseNumeral(widget.controller.currentChordText);
                  String newChord = _applyQuality(baseNumeral, 'o', hasSeventh: _seventhToggled);
                  widget.controller.setCurrentChordText(newChord);
                }),
                const SizedBox(width: 12),
                // Delete button
                AnimatedBuilder(
                  animation: widget.controller,
                  builder: (_, __) {
                    if (widget.controller.selectedLabel != null && widget.controller.selectedLabel is RomanNumeralLabel) {
                      return _buildClayButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        onPressed: () => widget.controller.deleteSelectedLabel(),
                        tooltip: 'Delete Label',
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),

        // Row 2: Roman numeral buttons (centered with input)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            children: [
              // First row: I-VI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final numeral in ['I', 'II', 'III', 'IV', 'V', 'VI'])
                    _buildRomanNumeralButton(numeral),
                ],
              ),
              const SizedBox(height: 6),
              // Second row: VII (centered)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRomanNumeralButton('VII'),
                ],
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildAccidentalButton(String accidental) {
    final isSelected = _selectedAccidental == accidental;
    return SizedBox(
      width: 40,
      height: 32,
      child: FloatingActionButton(
        mini: true,
        onPressed: () {
          setState(() {
            _selectedAccidental = accidental;
          });
        },
        backgroundColor: isSelected ? Colors.blue[200] : Colors.grey[200],
        foregroundColor: isSelected ? Colors.blue[800] : Colors.grey[700],
        elevation: isSelected ? 2 : 4,
        child: Text(
          accidental,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isToggled, VoidCallback onPressed) {
    return SizedBox(
      height: 28, // Reduced height to prevent clipping
      child: FloatingActionButton(
        mini: true,
        onPressed: onPressed,
        backgroundColor: isToggled ? Colors.blue[200] : Colors.grey[200],
        foregroundColor: isToggled ? Colors.blue[800] : Colors.grey[700],
        elevation: isToggled ? 2 : 4,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildModifierButton(String label, VoidCallback? onPressed) {
    final isEnabled = onPressed != null;
    return SizedBox(
      height: 28, // Reduced height to prevent clipping
      child: FloatingActionButton(
        mini: true,
        onPressed: onPressed,
        backgroundColor: isEnabled ? Colors.grey[200] : Colors.grey[100],
        foregroundColor: isEnabled ? Colors.grey[700] : Colors.grey[400],
        elevation: isEnabled ? 4 : 1,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9, // Reduced font size
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRomanNumeralButton(String numeral) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, __) {
        final isCurrentBase = _getBaseNumeral(widget.controller.currentChordText).toUpperCase() == numeral;
        
        return SizedBox(
          width: 40,
          height: 28, // Reduced height to prevent clipping
          child: FloatingActionButton(
            mini: true,
            onPressed: () {
              // Use the stored _currentQuality instead of parsing from text
              String baseChord = _applyQuality(numeral, _currentQuality, hasSeventh: _seventhToggled);
              
              // Add accidental prefix if not natural
              String newChord = _selectedAccidental == '♮' ? baseChord : '$_selectedAccidental$baseChord';
              widget.controller.setCurrentChordText(newChord);
            },
            backgroundColor: isCurrentBase ? Colors.blue[100] : Colors.grey[200],
            foregroundColor: isCurrentBase ? Colors.blue[800] : Colors.grey[700],
            elevation: isCurrentBase ? 2 : 4,
            child: Text(
              numeral,
              style: const TextStyle(
                fontSize: 9, // Reduced font size
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClayButton({
    required Widget icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return ClayContainer(
      height: 32,
      width: 32,
      depth: 15,
      borderRadius: 16,
      spread: 2,
      color: Colors.grey[200],
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(child: icon),
        ),
      ),
    );
  }

  // Helper methods for Roman numeral chord editing
  String _getBaseNumeral(String chord) {
    String text = chord;
    
    // Remove all quality indicators and modifiers
    text = text.replaceAll('7', '');
    text = text.replaceAll('ø', '');
    text = text.replaceAll('°', '');
    text = text.replaceAll(RegExp(r'maj', caseSensitive: false), ''); // Remove maj
    text = text.replaceAll(RegExp(r'min', caseSensitive: false), ''); // Remove min
    text = text.replaceAll(RegExp(r'dom', caseSensitive: false), ''); // Remove dom
    
    // Remove any accidentals at the start
    text = text.replaceAll('♯', '');
    text = text.replaceAll('♭', '');
    text = text.replaceAll('♮', '');
    
    // Convert to uppercase to get base roman numeral
    String base = text.toUpperCase().trim();
    return base.isNotEmpty ? base : 'I';
  }

  String _applyQuality(String base, String quality, {bool hasSeventh = false}) {
    switch (quality) {
      case 'Maj':
        if (hasSeventh) {
          return '${base.toUpperCase()}maj7'; // Major 7th chord
        } else {
          return base.toUpperCase(); // Simple major chord
        }
      case 'Min':
        if (hasSeventh) {
          return '${base.toLowerCase()}min7'; // Minor 7th chord - shows as "iimin7"
        } else {
          return base.toLowerCase(); // Simple minor chord
        }
      case 'Dom':
        return '${base.toUpperCase()}7'; // Dominant 7th chord (always has 7)
      case 'ø':
        if (hasSeventh) {
          return '${base.toLowerCase()}ø7'; // Half-diminished 7th chord
        } else {
          return '${base.toLowerCase()}ø'; // Half-diminished chord
        }
      case 'o':
        if (hasSeventh) {
          return '${base.toLowerCase()}°7'; // Diminished 7th chord
        } else {
          return '${base.toLowerCase()}°'; // Diminished chord
        }
      default:
        if (hasSeventh) {
          return '${base.toUpperCase()}7';
        } else {
          return base.toUpperCase();
        }
    }
  }


  String _getCurrentQuality(String chord) {
    if (chord.contains('ø')) return 'ø';
    if (chord.contains('°')) return 'o';
    
    // Check for dominant 7th chord (uppercase with just 7, no maj)
    if (chord.contains('7') && !chord.toLowerCase().contains('maj') && !chord.toLowerCase().contains('min') && chord == chord.toUpperCase()) {
      return 'Dom';
    }
    
    // Check if it contains 'maj' (like Imaj7)
    if (chord.toLowerCase().contains('maj')) return 'Maj';
    
    // Check if it contains 'min' (like iimin7)
    if (chord.toLowerCase().contains('min')) return 'Min';
    
    // Check case for minor vs major
    if (chord.replaceAll('7', '') == chord.replaceAll('7', '').toLowerCase() && chord.replaceAll('7', '').isNotEmpty) return 'Min';
    
    return 'Maj';
  }
}