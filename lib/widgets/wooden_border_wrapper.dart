import 'package:flutter/material.dart';

/// A widget that wraps content with a wooden border frame
/// Uses wooden texture assets to create an authentic wooden frame appearance
class WoodenBorderWrapper extends StatelessWidget {
  final Widget child;
  final double borderWidth;
  final double cornerRadius;
  
  const WoodenBorderWrapper({
    super.key,
    required this.child,
    this.borderWidth = 6.0,
    this.cornerRadius = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Wooden texture background
        image: const DecorationImage(
          image: AssetImage('assets/images/wood_texture.jpg'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(cornerRadius),
        // Add subtle shadow for depth
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius - 5),
          // Subtle inner border for depth
          border: Border.all(
            color: Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cornerRadius - 5),
          child: child,
        ),
      ),
    );
  }
}

/// Alternative wooden border implementation with separate corner and edge pieces
/// Use this if you want more detailed wooden frame graphics
class DetailedWoodenBorderWrapper extends StatelessWidget {
  final Widget child;
  final double borderWidth;
  
  const DetailedWoodenBorderWrapper({
    super.key,
    required this.child,
    this.borderWidth = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content with margin for border
        Container(
          margin: EdgeInsets.all(borderWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
        ),
        
        // Top border
        Positioned(
          top: 0,
          left: borderWidth,
          right: borderWidth,
          child: Container(
            height: borderWidth,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/wood_border_horizontal.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        
        // Bottom border
        Positioned(
          bottom: 0,
          left: borderWidth,
          right: borderWidth,
          child: Container(
            height: borderWidth,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/wood_border_horizontal.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        
        // Left border
        Positioned(
          top: borderWidth,
          bottom: borderWidth,
          left: 0,
          child: Container(
            width: borderWidth,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/wood_border_vertical.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        
        // Right border
        Positioned(
          top: borderWidth,
          bottom: borderWidth,
          right: 0,
          child: Container(
            width: borderWidth,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/wood_border_vertical.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        
        // Corners
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: borderWidth,
            height: borderWidth,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/wood_corner_top_left.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: borderWidth,
            height: borderWidth,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/wood_corner_top_right.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        
        Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            width: borderWidth,
            height: borderWidth,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/wood_corner_bottom_left.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: borderWidth,
            height: borderWidth,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/wood_corner_bottom_right.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}