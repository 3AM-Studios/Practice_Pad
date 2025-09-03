import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

/// Utility class for calculating actual rendered image bounds within a container
class ImageBoundsCalculator {
  /// Calculate the actual rendered image rectangle within the container
  /// Handles AspectRatio widget behavior (BoxFit.contain)
  static Rect calculateImageBounds(Size containerSize, ui.Image image) {
    if (image.width == 0 || image.height == 0) {
      return Rect.fromLTWH(0, 0, containerSize.width, containerSize.height);
    }
    
    final containerAspect = containerSize.width / containerSize.height;
    final imageAspect = image.width / image.height;
    
    late Size renderedSize;
    
    // AspectRatio widget behavior: BoxFit.contain
    if (imageAspect > containerAspect) {
      // Image wider than container - constrained by width
      renderedSize = Size(
        containerSize.width,
        containerSize.width / imageAspect, // Maintain aspect ratio
      );
    } else {
      // Image taller than container - constrained by height  
      renderedSize = Size(
        containerSize.height * imageAspect, // Maintain aspect ratio
        containerSize.height,
      );
    }
    
    // Center the image within container
    final offset = Offset(
      (containerSize.width - renderedSize.width) / 2,
      (containerSize.height - renderedSize.height) / 2,
    );
    
    return Rect.fromLTWH(
      offset.dx, 
      offset.dy, 
      renderedSize.width, 
      renderedSize.height,
    );
  }
}

/// Handles coordinate transformations between screen and image-relative coordinates
class CoordinateTransformer {
  final Rect imageBounds;
  final Matrix4? transformation; // InteractiveViewer transformation
  
  CoordinateTransformer({
    required this.imageBounds,
    this.transformation,
  });
  
  /// Convert screen coordinate to image-relative coordinate (0.0 to 1.0)
  Offset screenToRelative(Offset screenCoord) {
    if (imageBounds.width == 0 || imageBounds.height == 0) {
      return Offset.zero;
    }
    
    Offset adjustedCoord = screenCoord;
    
    // Apply inverse transformation if InteractiveViewer is active
    if (transformation != null) {
      try {
        final Matrix4 inverse = Matrix4.inverted(transformation!);
        final Vector3 transformed = inverse.transform3(Vector3(
          screenCoord.dx, 
          screenCoord.dy, 
          0.0,
        ));
        adjustedCoord = Offset(transformed.x, transformed.y);
      } on Exception {
        // If matrix inversion fails, use original coordinate
        adjustedCoord = screenCoord;
      }
    }
    
    // Convert to relative coordinate within image bounds
    final relativeX = (adjustedCoord.dx - imageBounds.left) / imageBounds.width;
    final relativeY = (adjustedCoord.dy - imageBounds.top) / imageBounds.height;
    
    return Offset(
      relativeX.clamp(0.0, 1.0), 
      relativeY.clamp(0.0, 1.0),
    );
  }
  
  /// Convert image-relative coordinate to current screen coordinate
  Offset relativeToScreen(Offset relativeCoord) {
    if (imageBounds.width == 0 || imageBounds.height == 0) {
      return Offset.zero;
    }
    
    // Convert relative coordinate to image space
    final imageSpaceX = imageBounds.left + (relativeCoord.dx * imageBounds.width);
    final imageSpaceY = imageBounds.top + (relativeCoord.dy * imageBounds.height);
    
    Offset screenCoord = Offset(imageSpaceX, imageSpaceY);
    
    // Apply transformation if InteractiveViewer is active
    if (transformation != null) {
      final Vector3 transformed = transformation!.transform3(Vector3(
        screenCoord.dx,
        screenCoord.dy,
        0.0,
      ));
      screenCoord = Offset(transformed.x, transformed.y);
    }
    
    return screenCoord;
  }
  
  /// Convert relative stroke width to current screen pixels
  double relativeStrokeToScreen(double relativeStroke) {
    if (imageBounds.width == 0) return relativeStroke;
    return relativeStroke * imageBounds.width;
  }
  
  /// Convert screen stroke width to relative value
  double screenStrokeToRelative(double screenStroke) {
    if (imageBounds.width == 0) return screenStroke;
    return screenStroke / imageBounds.width;
  }
  
  /// Convert relative label size to current screen pixels
  double relativeLabelSizeToScreen(double relativeLabelSize) {
    if (imageBounds.height == 0) return relativeLabelSize;
    return relativeLabelSize * imageBounds.height;
  }
  
  /// Convert screen label size to relative value
  double screenLabelSizeToRelative(double screenLabelSize) {
    if (imageBounds.height == 0) return screenLabelSize;
    return screenLabelSize / imageBounds.height;
  }
  
  /// Get the current display scale factor
  /// This represents how much the image is scaled from its natural size
  double getDisplayScale() {
    // Use the smaller dimension to maintain aspect ratio consistency
    // This ensures consistent scaling regardless of image orientation
    return imageBounds.width.isFinite ? imageBounds.width : 1.0;
  }
  
  /// Get the effective image width for scaling calculations
  double get imageDisplayWidth => imageBounds.width;
  
  /// Get the effective image height for scaling calculations
  double get imageDisplayHeight => imageBounds.height;
  
  /// Convert relative font size to actual pixels for current display
  double scaleFont(double relativeFontSize) {
    // Use height for font scaling to maintain readability regardless of aspect ratio
    return relativeLabelSizeToScreen(relativeFontSize);
  }
  
  /// Convert relative stroke width to actual pixels for current display
  double scaleStroke(double relativeStrokeWidth) {
    // Use width for stroke scaling for consistency with drawing gestures
    return relativeStrokeToScreen(relativeStrokeWidth);
  }
}

/// Extension to provide coordinate transformation capabilities to widgets
mixin CoordinateTransformationMixin {
  Rect? _cachedImageBounds;
  CoordinateTransformer? _cachedTransformer;
  
  /// Get current image bounds (implement in widget)
  Rect getCurrentImageBounds();
  
  /// Get current InteractiveViewer transformation (implement in widget)
  Matrix4? getCurrentTransformation();
  
  /// Get or create coordinate transformer
  CoordinateTransformer getCoordinateTransformer() {
    final currentBounds = getCurrentImageBounds();
    final currentTransformation = getCurrentTransformation();
    
    // Return cached transformer if bounds haven't changed (with tolerance for floating point precision)
    if (_cachedImageBounds != null && 
        _cachedTransformer != null &&
        _boundsEqual(_cachedImageBounds!, currentBounds) &&
        _cachedTransformer!.transformation == currentTransformation) {
      return _cachedTransformer!;
    }
    
    // Create new transformer and cache it
    _cachedImageBounds = currentBounds;
    _cachedTransformer = CoordinateTransformer(
      imageBounds: currentBounds,
      transformation: currentTransformation,
    );
    
    return _cachedTransformer!;
  }
  
  /// Check if two rectangles are equal with floating point tolerance
  bool _boundsEqual(Rect a, Rect b, {double tolerance = 0.001}) {
    return (a.left - b.left).abs() < tolerance &&
           (a.top - b.top).abs() < tolerance &&
           (a.width - b.width).abs() < tolerance &&
           (a.height - b.height).abs() < tolerance;
  }
  
  /// Force cache invalidation (useful during orientation changes)
  void invalidateCoordinateCache() {
    _cachedImageBounds = null;
    _cachedTransformer = null;
  }
}