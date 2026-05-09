import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/pages/player/widgets/audio_track_button.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/subtitle_track_button.widget.dart';

void main() {
  testWidgets('AudioTrackButton renders an audiotrack icon and fires onTap',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AudioTrackButton(onTap: () => taps++)),
      ),
    );
    expect(find.byIcon(Icons.audiotrack), findsOneWidget);
    await tester.tap(find.byType(AudioTrackButton));
    expect(taps, 1);
  });

  testWidgets('AudioTrackButton with null onTap is disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AudioTrackButton()),
      ),
    );
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('SubtitleTrackButton renders the outlined icon when inactive',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SubtitleTrackButton(onTap: () {})),
      ),
    );
    expect(find.byIcon(Icons.closed_caption_outlined), findsOneWidget);
  });

  testWidgets('SubtitleTrackButton renders the filled icon when active',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtitleTrackButton(onTap: () {}, active: true),
        ),
      ),
    );
    expect(find.byIcon(Icons.closed_caption), findsOneWidget);
  });

  testWidgets('SubtitleTrackButton with null onTap is disabled',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SubtitleTrackButton()),
      ),
    );
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
  });
}
