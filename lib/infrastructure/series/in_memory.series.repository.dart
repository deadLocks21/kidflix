import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';

/// In-memory fake [SeriesRepository] used until the HTTP backend is ready.
///
/// Seeds a single fictional series — Pingu — with two regular seasons
/// (5 episodes each) plus a Specials season (2 episodes) so the modal
/// detail UX is exercisable without a backend.
///
/// `findById` returns the seed when the id matches, throws
/// [StateError] otherwise. No age filter is applied (consistent with
/// the in-memory `CatalogRepository`'s posture).
class InMemorySeriesRepository implements SeriesRepository {
  static const String _tmdbImageBase = 'https://image.tmdb.org/t/p/original';
  static String _img(String hash) => '$_tmdbImageBase/$hash';

  static final List<Series> _series = _seed();

  /// Single source of truth for the seeded series, exposed so the
  /// in-memory catalog repository can project the same instances into
  /// its `/catalog` listing without drift.
  static List<Series> get seed => List.unmodifiable(_series);

  @override
  Future<Series> findById(String seriesId) async {
    final hit = _series.where((s) => s.id == seriesId).toList();
    if (hit.isEmpty) {
      throw StateError(
        'InMemorySeriesRepository: no series with id "$seriesId"',
      );
    }
    return hit.single;
  }

  static List<Series> _seed() {
    final addedRef = DateTime(2026, 5, 4);
    DateTime added(int daysAgo) => addedRef.subtract(Duration(days: daysAgo));

    final pinguEpisodes = <Episode>[
      // Season 1 — 5 episodes
      Episode(
        id: 'pingu-s1e1',
        seriesId: 'pingu',
        seasonNumber: 1,
        episodeNumber: 1,
        title: 'Hello Pingu',
        synopsis: 'Pingu se présente.',
        duration: const Duration(minutes: 5),
        thumbUrl: _img('pingu_s1e1_thumb.jpg'),
        airedAt: DateTime.utc(1990, 4, 13),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
      Episode(
        id: 'pingu-s1e2',
        seriesId: 'pingu',
        seasonNumber: 1,
        episodeNumber: 2,
        title: 'Pingu se promène',
        synopsis: 'Pingu se balade dans la banquise.',
        duration: const Duration(minutes: 5),
        thumbUrl: _img('pingu_s1e2_thumb.jpg'),
        airedAt: DateTime.utc(1990, 4, 20),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
      Episode(
        id: 'pingu-s1e3',
        seriesId: 'pingu',
        seasonNumber: 1,
        episodeNumber: 3,
        title: 'Pingu joue',
        synopsis: 'Pingu joue avec ses amis.',
        duration: const Duration(minutes: 5),
        thumbUrl: _img('pingu_s1e3_thumb.jpg'),
        airedAt: DateTime.utc(1990, 4, 27),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
      Episode(
        id: 'pingu-s1e4',
        seriesId: 'pingu',
        seasonNumber: 1,
        episodeNumber: 4,
        title: 'Pingu pêche',
        synopsis: 'Pingu apprend à pêcher.',
        duration: const Duration(minutes: 5),
        thumbUrl: _img('pingu_s1e4_thumb.jpg'),
        airedAt: DateTime.utc(1990, 5, 4),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
      Episode(
        id: 'pingu-s1e5',
        seriesId: 'pingu',
        seasonNumber: 1,
        episodeNumber: 5,
        title: 'Pingu danse',
        synopsis: 'Pingu danse avec sa sœur.',
        duration: const Duration(minutes: 5),
        thumbUrl: _img('pingu_s1e5_thumb.jpg'),
        airedAt: DateTime.utc(1990, 5, 11),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
    ];

    final pinguSeason2Episodes = <Episode>[
      Episode(
        id: 'pingu-s2e1',
        seriesId: 'pingu',
        seasonNumber: 2,
        episodeNumber: 1,
        title: 'Pingu et le bonhomme de neige',
        synopsis: 'Pingu construit un bonhomme de neige.',
        duration: const Duration(minutes: 5),
        thumbUrl: _img('pingu_s2e1_thumb.jpg'),
        airedAt: DateTime.utc(1992, 1, 5),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
      Episode(
        id: 'pingu-s2e2',
        seriesId: 'pingu',
        seasonNumber: 2,
        episodeNumber: 2,
        title: 'Pingu et le poisson',
        synopsis: 'Pingu observe les poissons sous la glace.',
        duration: const Duration(minutes: 5),
        thumbUrl: _img('pingu_s2e2_thumb.jpg'),
        airedAt: DateTime.utc(1992, 1, 12),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
      Episode(
        id: 'pingu-s2e3',
        seriesId: 'pingu',
        seasonNumber: 2,
        episodeNumber: 3,
        title: 'Pingu fait du toboggan',
        synopsis: 'Pingu glisse sur la banquise.',
        duration: const Duration(minutes: 5),
        thumbUrl: _img('pingu_s2e3_thumb.jpg'),
        airedAt: DateTime.utc(1992, 1, 19),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
      Episode(
        id: 'pingu-s2e4',
        seriesId: 'pingu',
        seasonNumber: 2,
        episodeNumber: 4,
        title: 'Pingu et l\'igloo',
        synopsis: 'Pingu rénove son igloo.',
        duration: const Duration(minutes: 5),
        thumbUrl: _img('pingu_s2e4_thumb.jpg'),
        airedAt: DateTime.utc(1992, 1, 26),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
      Episode(
        id: 'pingu-s2e5',
        seriesId: 'pingu',
        seasonNumber: 2,
        episodeNumber: 5,
        title: 'Pingu fête son anniversaire',
        synopsis: 'Pingu invite ses amis à son anniversaire.',
        duration: const Duration(minutes: 5),
        thumbUrl: _img('pingu_s2e5_thumb.jpg'),
        airedAt: DateTime.utc(1992, 2, 2),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
    ];

    final pinguSpecials = <Episode>[
      Episode(
        id: 'pingu-special-1',
        seriesId: 'pingu',
        seasonNumber: 0,
        episodeNumber: 1,
        title: "Pingu's Lost Christmas",
        synopsis: 'Pingu cherche son cadeau de Noël perdu.',
        duration: const Duration(minutes: 25),
        thumbUrl: _img('pingu_special_1_thumb.jpg'),
        airedAt: DateTime.utc(1996, 12, 25),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
      Episode(
        id: 'pingu-special-2',
        seriesId: 'pingu',
        seasonNumber: 0,
        episodeNumber: 2,
        title: 'Pingu fête le nouvel an',
        synopsis: 'Pingu fête le nouvel an avec sa famille.',
        duration: const Duration(minutes: 15),
        thumbUrl: _img('pingu_special_2_thumb.jpg'),
        airedAt: DateTime.utc(1997, 1, 1),
        ageCategory: AgeCategory.enfant,
        addedAt: added(2),
      ),
    ];

    final pingu = Series(
      id: 'pingu',
      title: 'Pingu',
      originalTitle: 'Pingu',
      year: 1990,
      synopsis:
          "Les aventures d'un manchot espiègle dans une famille pleine "
          "de tendresse, sur la banquise.",
      tagline: null,
      posterUrl: _img('pingu_poster.jpg'),
      backdropUrl: _img('pingu_backdrop.jpg'),
      ageCategory: AgeCategory.enfant,
      genres: const ['Animation', 'Familial'],
      sagaId: null,
      sagaLabel: null,
      director: const [],
      cast: const [],
      addedAt: added(2),
      seasonsCount: 3, // 2 regular + Specials
      episodesCount:
          pinguEpisodes.length +
          pinguSeason2Episodes.length +
          pinguSpecials.length,
      seasons: [
        const Season(
          seasonNumber: 0,
          name: 'Specials',
          posterUrl: null,
          synopsis: null,
          episodes: [],
        ),
        const Season(
          seasonNumber: 1,
          name: null,
          posterUrl: null,
          synopsis: null,
          episodes: [],
        ),
        const Season(
          seasonNumber: 2,
          name: null,
          posterUrl: null,
          synopsis: null,
          episodes: [],
        ),
      ],
    );

    // Re-build the series with episodes injected into their seasons.
    // (The `Season` model's `episodes` is final, so we construct the
    // `Series` once with finished seasons.)
    return [
      Series(
        id: pingu.id,
        title: pingu.title,
        originalTitle: pingu.originalTitle,
        year: pingu.year,
        synopsis: pingu.synopsis,
        tagline: pingu.tagline,
        posterUrl: pingu.posterUrl,
        backdropUrl: pingu.backdropUrl,
        ageCategory: pingu.ageCategory,
        genres: pingu.genres,
        sagaId: pingu.sagaId,
        sagaLabel: pingu.sagaLabel,
        director: pingu.director,
        cast: pingu.cast,
        addedAt: pingu.addedAt,
        seasonsCount: pingu.seasonsCount,
        episodesCount: pingu.episodesCount,
        seasons: [
          Season(seasonNumber: 0, name: 'Specials', episodes: pinguSpecials),
          Season(seasonNumber: 1, episodes: pinguEpisodes),
          Season(seasonNumber: 2, episodes: pinguSeason2Episodes),
        ],
      ),
    ];
  }
}
