import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';

class TextureUtils {
  // Private constructor for singleton pattern
  TextureUtils._privateConstructor();

  // Singleton instance
  static final TextureUtils instance = TextureUtils._privateConstructor();

  // Map to hold loaded textures with string keys
  final Map<String, ui.Image> _loadedTextures = {};

  final Map<String, String> _texturePaths = {};

  // Getter to access a texture by key
  ui.Image? getTexture(String key) => _loadedTextures[key];
  
  // To get DecorationImage object for use with BoxDecoration
  AssetImage getDecorationImage(String key) => AssetImage(_texturePaths[key]!);

  // Generic method to load a texture without rotation
  Future<ui.Image> loadTexture(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Image image = await decodeImageFromList(data.buffer.asUint8List());
    return image;
  }

  // Method to load the rosewood texture with rotation
  Future<void> loadRosewoodTexture() async {
    const assetPath = 'assets/images/wood_texture_rotated.jpg';
    final ui.Image originalImage = await loadTexture(assetPath);
    final rotatedImage =
        await _rotateImage(originalImage, pi / 2); // 90 degrees
    _loadedTextures['rosewood'] = rotatedImage;
    _texturePaths['rosewood'] = assetPath;
  }

  // Private method to rotate an image by a given angle
  Future<ui.Image> _rotateImage(ui.Image image, double angle) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = ui.Size(image.height.toDouble(), image.width.toDouble());
    final paint = Paint();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.translate(-image.width / 2, -image.height / 2);
    canvas.drawImage(image, ui.Offset.zero, paint);
    final picture = recorder.endRecording();
    return await picture.toImage(size.width.toInt(), size.height.toInt());
  }

  // Method to load multiple textures
  Future<void> loadTextures() async {
    await loadRosewoodTexture();
  }
}

