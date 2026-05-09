import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/pages/home/widgets/trailer_header.widget.dart';
import 'package:media_kit_video/media_kit_video.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TrailerHeader', () {
    testWidgets(
      'falls back to the backdrop image when trailerUrl is null',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const TrailerHeader(
              trailerUrl: null,
              fallbackImageUrl:
                  'https://image.tmdb.org/t/p/original/backdrop.jpg',
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(Video), findsNothing);
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      },
    );

    testWidgets(
      'falls back when trailerUrl is not a recognised YouTube URL',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const TrailerHeader(
              trailerUrl: 'https://example.com/some/page',
              fallbackImageUrl:
                  'https://image.tmdb.org/t/p/original/backdrop.jpg',
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(Video), findsNothing);
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      },
    );

    testWidgets(
      'renders only the placeholder Container when both URLs are null',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const TrailerHeader(
              trailerUrl: null,
              fallbackImageUrl: null,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(Video), findsNothing);
        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.byType(AspectRatio), findsOneWidget);
      },
    );

    testWidgets('keeps the 16:9 ratio in fallback mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrailerHeader(
            trailerUrl: null,
            fallbackImageUrl: null,
          ),
        ),
      );
      await tester.pump();

      final aspectRatio =
          tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, 16 / 9);
    });

    testWidgets(
      'overlays the logo on top of the fallback when logoUrl is provided',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const TrailerHeader(
              trailerUrl: null,
              fallbackImageUrl:
                  'https://image.tmdb.org/t/p/original/backdrop.jpg',
              logoUrl: 'https://image.tmdb.org/t/p/original/logo.png',
            ),
          ),
        );
        await tester.pump();

        // One CachedNetworkImage for the backdrop fallback, another for the
        // logo overlay sitting in a Positioned at bottom-left.
        expect(find.byType(CachedNetworkImage), findsNWidgets(2));
        expect(find.byType(Positioned), findsOneWidget);
      },
    );

    testWidgets(
      'no Stack/Positioned overlay when logoUrl is null',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const TrailerHeader(
              trailerUrl: null,
              fallbackImageUrl:
                  'https://image.tmdb.org/t/p/original/backdrop.jpg',
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CachedNetworkImage), findsOneWidget);
        expect(find.byType(Positioned), findsNothing);
      },
    );
  });
}
