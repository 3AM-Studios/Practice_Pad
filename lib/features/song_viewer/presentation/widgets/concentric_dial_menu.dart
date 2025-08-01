import 'dart:math';
import 'package:flutter/material.dart';

// Represents an item on the dial
class DialItem {
  final IconData? icon;
  final String label;
  final String? outerText; // Optional text to display on the outer edge of buttons

  DialItem({this.icon, required this.label, this.outerText});
}

// Enhanced concentric dial menu with size, swipe detection, and center text support
class ConcentricDialMenu extends StatefulWidget {
  final double size;
  final List<DialItem> outerItems;
  final List<DialItem> innerItems;
  final Function(int? innerIndex, int? outerIndex) onSelectionChanged;
  final String? centerText;
  final int? highlightedOuterIndex;
  final int? highlightedInnerIndex;
  final double ringSpacing; // Distance between inner and outer rings
  final bool enableOuterHighlight; // Whether to highlight outer buttons when selected
  final bool enableInnerHighlight; // Whether to highlight inner buttons when selected
  final double innerButtonScale; // Scale factor for inner button size (1.0 = same size as outer)

  const ConcentricDialMenu({
    super.key,
    required this.outerItems,
    required this.innerItems,
    required this.onSelectionChanged,
    this.centerText,
    this.size = 300,
    this.highlightedOuterIndex,
    this.highlightedInnerIndex,
    this.ringSpacing = 0.3, // Default spacing between rings (as fraction of size)
    this.enableOuterHighlight = true, // Default to highlighting outer buttons
    this.enableInnerHighlight = true, // Default to highlighting inner buttons
    this.innerButtonScale = 1.0, // Default to same size as outer buttons
  });

  @override
  State<ConcentricDialMenu> createState() => _ConcentricDialMenuState();
}

class _ConcentricDialMenuState extends State<ConcentricDialMenu> {
  int? _selectedOuterIndex;
  int? _selectedInnerIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        onTapDown: (details) {
          final result = _getIndexFromPosition(details.localPosition);
          setState(() {
            _selectedOuterIndex = result['outerIndex'];
            _selectedInnerIndex = result['innerIndex'];
            widget.onSelectionChanged(_selectedInnerIndex, _selectedOuterIndex);
          });
        },
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _DialPainter(
            outerItems: widget.outerItems,
            innerItems: widget.innerItems,
            selectedOuterIndex: _selectedOuterIndex,
            selectedInnerIndex: _selectedInnerIndex,
            centerText: widget.centerText,
            ringSpacing: widget.ringSpacing,
            enableOuterHighlight: widget.enableOuterHighlight,
            enableInnerHighlight: widget.enableInnerHighlight,
            innerButtonScale: widget.innerButtonScale,
          ),
        ),
      ),
    );
  }

  Map<String, int?> _getIndexFromPosition(Offset position) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;

    final distance = sqrt(dx * dx + dy * dy);

    // Use the SAME radius values as in the drawing logic
    final outerRadius = widget.size / 2 * 0.8;
    final innerRadius = outerRadius - (widget.size / 2 * widget.ringSpacing); // Use ringSpacing
    final buttonRadius = widget.size / 2 * 0.15;
    final innerButtonRadius = buttonRadius * widget.innerButtonScale; // Use configurable scale

    int? outerIndex;
    int? innerIndex;

    // Check outer ring - find the closest button by calculating distance to each button center
    if (distance > (outerRadius - buttonRadius * 1.5) && distance < (outerRadius + buttonRadius * 1.5)) {
      double minDistance = double.infinity;
      for (int i = 0; i < widget.outerItems.length; i++) {
        final anglePerItem = 2 * pi / widget.outerItems.length;
        final buttonAngle = i * anglePerItem - pi / 2; // Same as drawing logic
        final buttonCenter = Offset(
          center.dx + outerRadius * cos(buttonAngle),
          center.dy + outerRadius * sin(buttonAngle),
        );
        final distanceToButton = sqrt(
          pow(position.dx - buttonCenter.dx, 2) + 
          pow(position.dy - buttonCenter.dy, 2)
        );
        if (distanceToButton < minDistance && distanceToButton <= buttonRadius * 1.2) {
          minDistance = distanceToButton;
          outerIndex = i;
        }
      }
    }
    // Check inner ring - find the closest button by calculating distance to each button center
    else if (widget.innerItems.isNotEmpty && distance > (innerRadius - innerButtonRadius * 1.5) && distance < (innerRadius + innerButtonRadius * 1.5)) {
      double minDistance = double.infinity;
      for (int i = 0; i < widget.innerItems.length; i++) {
        final anglePerItem = 2 * pi / widget.innerItems.length;
        final buttonAngle = i * anglePerItem - pi / 2; // Same as drawing logic
        final buttonCenter = Offset(
          center.dx + innerRadius * cos(buttonAngle),
          center.dy + innerRadius * sin(buttonAngle),
        );
        final distanceToButton = sqrt(
          pow(position.dx - buttonCenter.dx, 2) + 
          pow(position.dy - buttonCenter.dy, 2)
        );
        if (distanceToButton < minDistance && distanceToButton <= innerButtonRadius * 1.2) {
          minDistance = distanceToButton;
          innerIndex = i;
        }
      }
    }

    return {'outerIndex': outerIndex, 'innerIndex': innerIndex};
  }
}

class _DialPainter extends CustomPainter {
  final List<DialItem> outerItems;
  final List<DialItem> innerItems;
  final int? selectedOuterIndex;
  final int? selectedInnerIndex;
  final String? centerText;
  final double ringSpacing;
  final bool enableOuterHighlight;
  final bool enableInnerHighlight;
  final double innerButtonScale;

  _DialPainter({
    required this.outerItems,
    required this.innerItems,
    this.selectedOuterIndex,
    this.selectedInnerIndex,
    this.centerText,
    required this.ringSpacing,
    required this.enableOuterHighlight,
    required this.enableInnerHighlight,
    required this.innerButtonScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 * 0.8;
    final innerRadius = outerRadius - (size.width / 2 * ringSpacing); // Use ringSpacing for proper positioning
    final buttonRadius = size.width / 2 * 0.15;
    final innerButtonRadius = buttonRadius * innerButtonScale; // Use configurable scale

    // Draw outer ring first
    _drawRing(canvas, center, outerRadius, outerItems, enableOuterHighlight ? selectedOuterIndex : null, buttonRadius, true);
    
    // Draw inner buttons at the calculated inner radius position
    _drawRing(canvas, center, innerRadius, innerItems, enableInnerHighlight ? selectedInnerIndex : null, innerButtonRadius, false);
    
    // Draw center text if provided
    if (centerText != null && centerText!.isNotEmpty) {
      _drawCenterText(canvas, center, centerText!);
    }
  }

  void _drawCenterText(Canvas canvas, Offset center, String text) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawRing(Canvas canvas, Offset center, double ringRadius, List<DialItem> items, int? selectedIndex, double buttonRadius, bool isOuterRing) {
    final anglePerItem = 2 * pi / items.length;
    
    for (int i = 0; i < items.length; i++) {
      final angle = i * anglePerItem - pi / 2; // Start from the top
      final itemCenter = Offset(
        center.dx + ringRadius * cos(angle),
        center.dy + ringRadius * sin(angle),
      );

      final paint = Paint()
        ..color = (i == selectedIndex) 
          ? Colors.blueAccent 
          : (isOuterRing ? Colors.grey.shade300 : const Color(0xFF2C2C2E)) // Darker inner buttons
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(itemCenter, buttonRadius, paint);
      
      // Only draw icon if it exists
      if (items[i].icon != null) {
        TextPainter iconPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: String.fromCharCode(items[i].icon!.codePoint),
            style: TextStyle(
              color: (i == selectedIndex) ? Colors.white : Colors.black,
              fontSize: buttonRadius * 0.8,
              fontFamily: items[i].icon!.fontFamily,
              package: items[i].icon!.fontPackage,
            ),
          ),
        );
        iconPainter.layout();
        iconPainter.paint(
          canvas, 
          Offset(
            itemCenter.dx - iconPainter.width / 2,
            itemCenter.dy - iconPainter.height / 2,
          ),
        );
      } else {
        // Draw text label instead of icon
        String displayText = items[i].label;
        
        // For inner ring (minus buttons), always show minus symbol
        if (!isOuterRing) {
          displayText = '-';
        }
        
        TextPainter labelPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: displayText,
            style: TextStyle(
              color: (i == selectedIndex) 
                ? Colors.white 
                : (isOuterRing ? Colors.black : Colors.white), // White text for dark inner buttons
              fontSize: isOuterRing ? buttonRadius * 0.3 : buttonRadius * 0.5, // Larger minus text
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        labelPainter.layout();
        labelPainter.paint(
          canvas, 
          Offset(
            itemCenter.dx - labelPainter.width / 2,
            itemCenter.dy - labelPainter.height / 2,
          ),
        );
      }
      
      // Draw outer text if this is the outer ring and outer text is provided
      if (isOuterRing && items[i].outerText != null && items[i].outerText!.isNotEmpty) {
        final outerTextRadius = ringRadius + buttonRadius + 10; // Position outside the button
        final outerTextCenter = Offset(
          center.dx + outerTextRadius * cos(angle),
          center.dy + outerTextRadius * sin(angle),
        );
        
        TextPainter outerTextPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: items[i].outerText!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        outerTextPainter.layout();
        outerTextPainter.paint(
          canvas,
          Offset(
            outerTextCenter.dx - outerTextPainter.width / 2,
            outerTextCenter.dy - outerTextPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}