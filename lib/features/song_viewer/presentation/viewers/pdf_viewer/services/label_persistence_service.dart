import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/label_base.dart';
import '../models/extension_label.dart';
import '../models/roman_numeral_label.dart';

/// Service for persisting and loading different types of labels
class LabelPersistenceService {
  /// Save labels to file
  static Future<void> saveLabels(String filePath, List<Label> labels) async {
    try {
      final labelsData = labels.map((label) => label.toJson()).toList();
      final file = File(filePath);
      await file.writeAsString(jsonEncode(labelsData));
    } catch (e) {
      throw Exception('Failed to save labels: $e');
    }
  }
  
  /// Load labels from file
  static Future<List<Label>> loadLabels(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return [];
      }
      
      final jsonString = await file.readAsString();
      final labelsData = jsonDecode(jsonString) as List<dynamic>;
      
      final labels = <Label>[];
      for (final labelData in labelsData) {
        final json = labelData as Map<String, dynamic>;
        final labelType = json['labelType'] as String?;
        
        // Handle old format without labelType (assume extension)
        if (labelType == null || labelType == 'extension') {
          labels.add(ExtensionLabel.fromJson(json));
        } else if (labelType == 'romanNumeral') {
          labels.add(RomanNumeralLabel.fromJson(json));
        } else {
          // Skip unknown label types
          continue;
        }
      }
      
      return labels;
    } catch (e) {
      throw Exception('Failed to load labels: $e');
    }
  }
  
  /// Get file path for labels for a specific page
  static Future<String> getLabelsFilePath(String songAssetPath, int page, {String? labelType}) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeFilename = _getSafeFilename(songAssetPath);
    final suffix = labelType != null ? '_${labelType}_labels' : '_labels';
    return '${directory.path}/${safeFilename}_pdf_page_${page}$suffix.json';
  }
  
  /// Create a safe filename from asset path
  static String _getSafeFilename(String path) {
    return path
        .split('/')
        .last
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'), '_')
        .replaceAll(RegExp(r'_{2,}'), '_');
  }
  
  /// Save labels for a specific page and song
  static Future<void> saveLabelsForPage(String songAssetPath, int page, List<Label> labels) async {
    final filePath = await getLabelsFilePath(songAssetPath, page);
    await saveLabels(filePath, labels);
  }
  
  /// Load labels for a specific page and song
  static Future<List<Label>> loadLabelsForPage(String songAssetPath, int page) async {
    final filePath = await getLabelsFilePath(songAssetPath, page);
    return await loadLabels(filePath);
  }
  
  /// Check if labels file exists for a page
  static Future<bool> labelsExistForPage(String songAssetPath, int page) async {
    final filePath = await getLabelsFilePath(songAssetPath, page);
    return await File(filePath).exists();
  }
  
  /// Delete labels file for a page
  static Future<void> deleteLabelsForPage(String songAssetPath, int page) async {
    final filePath = await getLabelsFilePath(songAssetPath, page);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}