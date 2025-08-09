import 'package:flutter/material.dart';

/// A circular wooden background widget for navigation icons
/// Creates a wooden outline effect when placed behind clay containers
class WoodenIconBackground extends StatelessWidget {
  final double size;
  final bool isSelected;
  
  const WoodenIconBackground({
    super.key,
    required this.size,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF8B4513), // Saddle brown color
          border: Border.all(
            color: Colors.brown.shade800,
            width: 3.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alternative wooden background with more detailed styling
class DetailedWoodenIconBackground extends StatelessWidget {
  final double size;
  final bool isSelected;
  
  const DetailedWoodenIconBackground({
    super.key,
    required this.size,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Wooden texture background
        image: const DecorationImage(
          image: AssetImage('assets/images/wood_texture.jpg'),
          fit: BoxFit.cover,
        ),
        // Layered shadows for depth
        boxShadow: [
          // Outer shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
            spreadRadius: 1,
          ),
          // Inner highlight (simulated)
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, -1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Subtle gradient overlay for more realistic wood effect
          gradient: RadialGradient(
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(isSelected ? 0.1 : 0.05),
            ],
            stops: const [0.6, 1.0],
          ),
          // Subtle border
          border: Border.all(
            color: Colors.brown.withOpacity(0.3),
            width: 1.0,
          ),
        ),
      ),
    );
  }
}