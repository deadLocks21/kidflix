import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/ui/pages/player/widgets/player_error_state.widget.dart';

void main() {
  testWidgets('failed status shows the download-failed message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerErrorState(
            status: DownloadStatusDto.failed,
            onRetry: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    expect(find.text('Impossible de télécharger le film.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Retour'), findsOneWidget);
  });

  testWidgets('cancelled status shows the cancellation message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerErrorState(
            status: DownloadStatusDto.cancelled,
            onRetry: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    expect(find.text('Téléchargement annulé.'), findsOneWidget);
  });

  testWidgets('retry and back buttons invoke callbacks', (tester) async {
    var retries = 0;
    var backs = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerErrorState(
            status: DownloadStatusDto.failed,
            onRetry: () => retries++,
            onBack: () => backs++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.tap(find.text('Retour'));
    await tester.pump();
    expect(retries, 1);
    expect(backs, 1);
  });
}
