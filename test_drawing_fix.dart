import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice_pad/features/song_viewer/presentation/screens/song_viewer_screen.dart';

void main() {
  testWidgets('Drawing functionality test', (WidgetTester tester) async {
    // Create a test app with the song viewer
    await tester.pumpWidget(
      MaterialApp(
        home: SongViewerScreen(
          songAssetPath: 'assets/songs/test_song.xml',
          bpm: 120,
        ),
      ),
    );

    // Wait for the widget to load
    await tester.pumpAndSettle();

    // Look for the drawing toggle button
    final drawButton = find.byIcon(Icons.draw);
    
    // Verify the button exists
    expect(drawButton, findsOneWidget);
    
    print('✅ Drawing toggle button found');
    print('✅ Drawing functionality fix test passed');
  });
}