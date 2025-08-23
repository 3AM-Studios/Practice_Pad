import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:image_painter/image_painter.dart';
import 'base_controls.dart';

/// Extension label controls widget for accidentals and numbers
class ExtensionLabelControls extends StatefulWidget {
  final ImagePainterController controller;
  
  const ExtensionLabelControls({
    super.key,
    required this.controller,
  });

  @override
  State<ExtensionLabelControls> createState() => _ExtensionLabelControlsState();
}

class _ExtensionLabelControlsState extends State<ExtensionLabelControls> {

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TOP SECTION: Colors, Size and Delete button
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Base controls (color and size)
              Expanded(
                child: BaseControls(controller: widget.controller),
              ),
              // Delete button (if label selected)
              AnimatedBuilder(
                animation: widget.controller,
                builder: (_, __) {
                  if (widget.controller.selectedLabel != null) {
                    return _buildClayButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () {
                        widget.controller.deleteSelectedLabel();
                      },
                      tooltip: 'Delete Label',
                    );
                  } else {
                    return const SizedBox(width: 40); // Placeholder to maintain layout
                  }
                },
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
              _buildAccidentalButton('♭'),
              _buildAccidentalButton('♯'),
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

  Widget _buildAccidentalButton(String accidental) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, __) {
        final isSelected = widget.controller.currentAccidental == accidental;
        return Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(2),
          child: _buildClayButton(
            icon: Text(
              accidental,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected 
                    ? Colors.blue
                    : Colors.grey[700],
              ),
            ),
            onPressed: () {
              widget.controller.setCurrentAccidental(accidental);
            },
            tooltip: 'Accidental $accidental',
          ),
        );
      },
    );
  }

  Widget _buildNumberButton(String number) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, __) {
        final isSelected = widget.controller.currentNumber == number;
        return Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(2),
          child: _buildClayButton(
            icon: Text(
              number,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected 
                    ? Colors.blue
                    : Colors.grey[700],
              ),
            ),
            onPressed: () {
              widget.controller.setCurrentNumber(number);
            },
            tooltip: 'Number $number',
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
}