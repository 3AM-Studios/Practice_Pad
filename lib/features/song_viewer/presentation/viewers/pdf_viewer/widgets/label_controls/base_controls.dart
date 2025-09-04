import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:image_painter/image_painter.dart';

class BaseControls extends StatefulWidget {
  final ImagePainterController controller;

  const BaseControls({
    super.key,
    required this.controller,
  });

  @override
  State<BaseControls> createState() => _BaseControlsState();
}

class _BaseControlsState extends State<BaseControls> {
  bool _showAllColors = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Color and size controls (centered)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _showAllColors 
            ? _buildColorPickerLayout()
            : _buildNormalLayout(),
        ),
      ],
    );
  }

  Widget _buildNormalLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Color controls
        AnimatedBuilder(
          animation: widget.controller,
          builder: (_, __) {
            return _buildWoodenClayButton(
              icon: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  color: widget.controller.labelColor,
                ),
              ),
              onPressed: () {
                setState(() {
                  _showAllColors = !_showAllColors;
                });
              },
              tooltip: 'Color',
            );
          },
        ),
        const SizedBox(width: 16),
        
        // Size controls
        _buildWoodenClayButton(
          icon: const Icon(Icons.remove, size: 16, color: Colors.white),
          onPressed: () {
            widget.controller.decreaseLabelSize();
          },
          tooltip: 'Decrease Size',
        ),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: widget.controller,
          builder: (_, __) {
            return ClayContainer(
              color: Theme.of(context).colorScheme.surface,
              depth: 15,
              borderRadius: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${widget.controller.labelSize.round()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        _buildWoodenClayButton(
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          onPressed: () {
            widget.controller.increaseLabelSize();
          },
          tooltip: 'Increase Size',
        ),
      ],
    );
  }

  Widget _buildColorPickerLayout() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Color toggle button
          AnimatedBuilder(
            animation: widget.controller,
            builder: (_, __) {
              return _buildWoodenClayButton(
                icon: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    color: widget.controller.labelColor,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _showAllColors = !_showAllColors;
                  });
                },
                tooltip: 'Color',
              );
            },
          ),
          const SizedBox(width: 8),
          // Color options in scrollable row
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
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, __) {
        final isSelected = widget.controller.labelColor == color;
        final isTransparent = color.opacity == 0;

        return Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(2),
          child: _buildClayButton(
            icon: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isTransparent ? Colors.white : color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.grey,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected ? [
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                ] : null,
              ),
            ),
            onPressed: () {
              widget.controller.setLabelColor(color);
            },
            tooltip: 'Color',
          ),
        );
      },
    );
  }

  Widget _buildWoodenClayButton({
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
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/wood_texture_rotated.jpg'),
            fit: BoxFit.cover,
          ),
          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Center(child: icon),
          ),
        ),
      ),
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