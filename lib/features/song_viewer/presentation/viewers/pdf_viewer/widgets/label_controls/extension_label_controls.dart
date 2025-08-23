import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';

/// UI controls for extension labels (accidental + number system)
class ExtensionLabelControls extends StatefulWidget {
  final String currentAccidental;
  final String currentNumber;
  final double labelSize;
  final Color labelColor;
  final bool hasSelectedLabel;
  final VoidCallback? onDeleteSelected;
  final Function(String) onAccidentalChanged;
  final Function(String) onNumberChanged;
  final Function(double) onSizeChanged;
  final Function(Color) onColorChanged;

  const ExtensionLabelControls({
    super.key,
    required this.currentAccidental,
    required this.currentNumber,
    required this.labelSize,
    required this.labelColor,
    required this.hasSelectedLabel,
    this.onDeleteSelected,
    required this.onAccidentalChanged,
    required this.onNumberChanged,
    required this.onSizeChanged,
    required this.onColorChanged,
  });

  @override
  State<ExtensionLabelControls> createState() => _ExtensionLabelControlsState();
}

class _ExtensionLabelControlsState extends State<ExtensionLabelControls> {
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
        
        // Accidental buttons row (♮, b, #)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAccidentalButton('♮'),
              _buildAccidentalButton('b'),
              _buildAccidentalButton('#'),
            ],
          ),
        ),
        
        // BOTTOM SECTION: Number pad (3x3 grid)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              // Numbers 1-9 in 3x3 grid
              for (int row = 0; row < 3; row++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (int col = 0; col < 3; col++)
                        _buildNumberButton('${row * 3 + col + 1}'),
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

  Widget _buildAccidentalButton(String accidental) {
    final isSelected = widget.currentAccidental == accidental;
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.all(2),
      child: ClayContainer(
        height: 40,
        width: 40,
        depth: isSelected ? 10 : 20,
        borderRadius: 20,
        spread: 2,
        color: Colors.grey[200],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onAccidentalChanged(accidental),
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: Text(
                accidental,
                style: TextStyle(
                  fontSize: 16,
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

  Widget _buildNumberButton(String number) {
    final isSelected = widget.currentNumber == number;
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.all(2),
      child: ClayContainer(
        height: 40,
        width: 40,
        depth: isSelected ? 10 : 20,
        borderRadius: 20,
        spread: 2,
        color: Colors.grey[200],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onNumberChanged(number),
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 16,
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