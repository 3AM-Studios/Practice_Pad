import 'package:flutter_test/flutter_test.dart';
import 'package:simple_sheet_music/simple_sheet_music.dart';
import 'package:practice_pad/features/song_viewer/presentation/widgets/measure/chord_symbol/chord_symbol.dart';

void main() {
  group('ChordSymbol Diatonic Tests', () {
    test('Ab Major - C7 should be non-diatonic (III7)', () {
      final chord = ChordSymbol('C', '7', originalKeySignature: KeySignatureType.aFlatMajor);
      
      expect(chord.isDiatonic, false, reason: 'C7 in Ab major should be non-diatonic (III7 instead of iiimin7)');
      expect(chord.getRomanNumeral(), 'III');
      expect(chord.getQualitySuperscript(), '⁷');
    });
    
    test('Ab Major - G7 should be non-diatonic (VII7)', () {
      final chord = ChordSymbol('G', '7', originalKeySignature: KeySignatureType.aFlatMajor);
      
      expect(chord.isDiatonic, false, reason: 'G7 in Ab major should be non-diatonic (VII7 instead of viiø7)');
      expect(chord.getRomanNumeral(), 'VII');
      expect(chord.getQualitySuperscript(), '⁷');
    });
    
    test('Ab Major - Eb7 should be diatonic (V7)', () {
      final chord = ChordSymbol('Eb', '7', originalKeySignature: KeySignatureType.aFlatMajor);
      
      expect(chord.isDiatonic, true, reason: 'Eb7 in Ab major should be diatonic (V7)');
      expect(chord.getRomanNumeral(), 'V');
      expect(chord.getQualitySuperscript(), '⁷');
    });
    
    test('C Major - G7 should be diatonic (V7)', () {
      final chord = ChordSymbol('G', '7', originalKeySignature: KeySignatureType.cMajor);
      
      expect(chord.isDiatonic, true, reason: 'G7 in C major should be diatonic (V7)');
      expect(chord.getRomanNumeral(), 'V');
      expect(chord.getQualitySuperscript(), '⁷');
    });
    
    test('C Major - C7 should be non-diatonic (I7)', () {
      final chord = ChordSymbol('C', '7', originalKeySignature: KeySignatureType.cMajor);
      
      expect(chord.isDiatonic, false, reason: 'C7 in C major should be non-diatonic (I7 instead of Imaj7)');
      expect(chord.getRomanNumeral(), 'I');
      expect(chord.getQualitySuperscript(), '⁷');
    });
    
    test('A Minor - G7 should be diatonic (VII7)', () {
      final chord = ChordSymbol('G', '7', originalKeySignature: KeySignatureType.aMinor);
      
      expect(chord.isDiatonic, true, reason: 'G7 in A minor should be diatonic (VII7)');
      expect(chord.getRomanNumeral(), 'VII');
      expect(chord.getQualitySuperscript(), '⁷');
    });
    
    test('Ab Major - Db7 should be non-diatonic (IV7)', () {
      final chord = ChordSymbol('Db', '7', originalKeySignature: KeySignatureType.aFlatMajor);
      
      expect(chord.isDiatonic, false, reason: 'Db7 in Ab major should be non-diatonic (IV7 instead of IVmaj7)');
      expect(chord.getRomanNumeral(), 'IV');
      expect(chord.getQualitySuperscript(), '⁷');
    });
    
    test('C Major - Fmaj7 should be diatonic (IVmaj7)', () {
      final chord = ChordSymbol('F', 'maj7', originalKeySignature: KeySignatureType.cMajor);
      
      expect(chord.isDiatonic, true, reason: 'Fmaj7 in C major should be diatonic (IVmaj7)');
      expect(chord.getRomanNumeral(), 'IV');
      expect(chord.getQualitySuperscript(), 'ᴹ⁷');
    });
    
    test('C Major - Bm7b5 should be diatonic (viiø7)', () {
      final chord = ChordSymbol('B', 'm7b5', originalKeySignature: KeySignatureType.cMajor);
      
      expect(chord.isDiatonic, true, reason: 'Bm7b5 in C major should be diatonic (viiø7)');
      expect(chord.getRomanNumeral(), 'vii');
      expect(chord.getQualitySuperscript(), 'ø⁷');
    });
  });

  group('ChordSymbol Dual Key Signature Tests', () {
    test('Chord with both original and modified key signatures', () {
      final chord = ChordSymbol('G', '7', 
          originalKeySignature: KeySignatureType.cMajor,
          modifiedKeySignature: KeySignatureType.fMajor);
      
      // Should use original key signature by default
      expect(chord.getRomanNumeral(original: true), 'V');
      
      // Should use modified key signature when specified
      expect(chord.getRomanNumeral(original: false), 'II');
      
      // Backward compatibility getter should return original
      expect(chord.keySignature, KeySignatureType.cMajor);
    });
  });
}
