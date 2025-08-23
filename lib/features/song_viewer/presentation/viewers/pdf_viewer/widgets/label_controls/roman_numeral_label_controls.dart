import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';

/// UI controls for Roman numeral labels
class RomanNumeralLabelControls extends StatefulWidget {
  final String currentRomanNumeral;
  final double labelSize;
  final Color labelColor;
  final bool hasSelectedLabel;
  final VoidCallback? onDeleteSelected;
  final Function(String) onRomanNumeralChanged;
  final Function(double) onSizeChanged;
  final Function(Color) onColorChanged;

  const RomanNumeralLabelControls({
    super.key,
    required this.currentRomanNumeral,
    required this.labelSize,
    required this.labelColor,
    required this.hasSelectedLabel,
    this.onDeleteSelected,
    required this.onRomanNumeralChanged,
    required this.onSizeChanged,
    required this.onColorChanged,
  });

  @override
  State<RomanNumeralLabelControls> createState() => _RomanNumeralLabelControlsState();
}

class _RomanNumeralLabelControlsState extends State<RomanNumeralLabelControls> {
  bool _showAllColors = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TOP SECTION: Colors and Delete button
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Compact color picker
              Row(
                children: [
                  // Current color button that shows/hides all colors
                  _buildClayButton(
                    icon: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                        color: widget.labelColor,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _showAllColors = !_showAllColors;
                      });
                    },
                    tooltip: 'Color',
                  ),
                  // Expandable color options
                  if (_showAllColors) ...[
                    const SizedBox(width: 8),
                    _buildColorButton(const Color(0xFF2196F3)), // Blue
                    const SizedBox(width: 4),
                    _buildColorButton(const Color(0xFF4CAF50)), // Green
                    const SizedBox(width: 4),
                    _buildColorButton(const Color(0xFFFF9800)), // Orange
                    const SizedBox(width: 4),
                    _buildColorButton(const Color(0xFFF44336)), // Red
                    const SizedBox(width: 4),
                    _buildColorButton(const Color(0xFF9C27B0)), // Purple
                    const SizedBox(width: 4),
                    _buildColorButton(const Color(0xFFFFFFFF)), // White
                  ],
                ],
              ),
              // Delete button (if label selected)
              if (widget.hasSelectedLabel)
                _buildClayButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: widget.onDeleteSelected ?? () {},
                  tooltip: 'Delete Label',
                )
              else
                const SizedBox(width: 40), // Placeholder to maintain layout
            ],
          ),
        ),
        
        // Size controls
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildClayButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: () {
                  final newSize = (widget.labelSize - 2.0).clamp(10.0, 50.0);
                  widget.onSizeChanged(newSize);
                },
                tooltip: 'Decrease Size',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.labelSize.round()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildClayButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () {
                  final newSize = (widget.labelSize + 2.0).clamp(10.0, 50.0);
                  widget.onSizeChanged(newSize);
                },
                tooltip: 'Increase Size',
              ),
            ],
          ),
        ),
        
        // Roman numeral selection (2x6 grid for I-XII)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              // First row: I-VI
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final numeral in ['I', 'II', 'III', 'IV', 'V', 'VI'])
                      _buildRomanNumeralButton(numeral),
                  ],
                ),
              ),
              // Second row: VII-XII
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final numeral in ['VII', 'VIII', 'IX', 'X', 'XI', 'XII'])
                      _buildRomanNumeralButton(numeral),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClayButton({
    required Widget icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return ClayContainer(
      height: 40,
      width: 40,
      depth: 20,
      borderRadius: 20,
      spread: 2,
      color: Colors.grey[200],
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Center(child: icon),
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = widget.labelColor == color;
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: isSelected ? Colors.black : Colors.grey,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onColorChanged(color),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildRomanNumeralButton(String numeral) {
    final isSelected = widget.currentRomanNumeral == numeral;
    return Container(
      width: 50,
      height: 40,
      margin: const EdgeInsets.all(2),
      child: ClayContainer(
        height: 40,
        width: 50,
        depth: isSelected ? 10 : 20,
        borderRadius: 8,
        spread: 2,
        color: Colors.grey[200],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onRomanNumeralChanged(numeral),
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Text(
                numeral,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blue : Colors.grey[700],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}