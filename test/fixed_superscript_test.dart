import 'package:flutter_test/flutter_test.dart';
import 'package:simple_sheet_music/simple_sheet_music.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';

void main() {
  group('Fixed Superscript Tests', () {
    test('Minor 7th chord should show iii^{-7}', () {
      final chord = ChordSymbol('C', 'min7', originalKeySignature: KeySignatureType.aFlatMajor);
      
      expect(chord.getRomanNumeral(), 'iii');
      expect(chord.getQualitySuperscript(), '⁻⁷');
      expect(chord.displayText, 'Cmin7\niii^⁻⁷');
    });
    
    test('Dominant 7th chord should show III^{7}', () {
      final chord = ChordSymbol('C', '7', originalKeySignature: KeySignatureType.aFlatMajor);
      
      expect(chord.getRomanNumeral(), 'III');
      expect(chord.getQualitySuperscript(), '⁷');
      expect(chord.displayText, 'C7\nIII^⁷');
      expect(chord.isDiatonic, false);
    });
    
    test('Minor 6th chord should show iii^{-6}', () {
      final chord = ChordSymbol('C', 'm6', originalKeySignature: KeySignatureType.aFlatMajor);
      
      expect(chord.getRomanNumeral(), 'iii');
      expect(chord.getQualitySuperscript(), '⁻⁶');
      expect(chord.displayText, 'Cm6\niii^⁻⁶');
    });
    
    test('Minor 9th chord should show iii^{-9}', () {
      final chord = ChordSymbol('C', 'm9', originalKeySignature: KeySignatureType.aFlatMajor);
      
      expect(chord.getRomanNumeral(), 'iii');
      expect(chord.getQualitySuperscript(), '⁻⁹');
      expect(chord.displayText, 'Cm9\niii^⁻⁹');
    });
  });
}
