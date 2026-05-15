import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';

/// In-memory fake [SeriesRepository] used until the HTTP backend is ready.
///
/// Seeds a single rights-free series — Caminandes — assembled from the
/// open-licence Blender Foundation shorts (CC-BY) about Koro the llama.
/// One regular season groups the three released episodes (Llama Drama,
/// Gran Dillama, Llamigos) and a Specials season carries the 2020 bonus
/// short "¡Oh, Deer!", so the modal detail UX is exercisable without a
/// backend.
///
/// `findById` returns the seed when the id matches, throws [StateError]
/// otherwise. No age filter is applied (consistent with the in-memory
/// `CatalogRepository`'s posture).
class InMemorySeriesRepository implements SeriesRepository {
  static const String _wmBase =
      'https://upload.wikimedia.org/wikipedia/commons';
  static String _wm(String path) => '$_wmBase/$path';

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

  @override
  Future<Series> findByIdForProfile(String seriesId, String profileId) =>
      findById(seriesId);

  /// Standardised Blender Foundation attribution embedded in the series
  /// [Series.synopsis] to satisfy the CC-BY licence's credit requirement.
  static const String _credit =
      '\n\nCrédits : © Blender Foundation — caminandes.com — '
      'Licence Creative Commons CC-BY 3.0 / 4.0.';

  static List<Series> _seed() {
    final addedRef = DateTime(2026, 5, 4);
    DateTime added(int daysAgo) => addedRef.subtract(Duration(days: daysAgo));

    // NOTE: the Llama Drama cover thumbnail
    // (`6/61/Pablo_Vazquez_-_Caminandes_-_Episode_1_-_Llama_Drama_-_Cover_thumbnail.png`)
    // is flagged on Wikimedia as having an undocumented source. We rely on
    // the unambiguous Gran Dillama still (CC-BY 3.0, no dispute) as the
    // Episode 1 thumbnail so every shipped image has clean provenance.
    const granDillamaCover =
        'a/a8/Blender_Foundation_-_Caminandes_-_Episode_2_-_Gran_Dillama_-_Cover_thumbnail.png';
    const llamigosCover =
        'a/aa/Blender_Foundation_-_Caminandes_-_Episode_3_-_Llamigos_-_Cover_thumbnail.png';
    const granDillamaStill = '1/14/Caminandes_gran_dillama.png';

    final caminandesSeason1Episodes = <Episode>[
      Episode(
        id: 'caminandes-s1e1',
        seriesId: 'caminandes',
        seasonNumber: 1,
        episodeNumber: 1,
        title: 'Llama Drama',
        originalTitle: 'Caminandes: Llama Drama',
        synopsis:
            "Koro le lama tente de traverser une route déserte de "
            "Patagonie sans se faire renverser.",
        duration: const Duration(minutes: 2),
        // Vignette : still Gran Dillama (Koro) — la cover Llama Drama
        // d'origine est sous CC-BY 3.0 mais signalée pour source
        // incomplète sur Wikimedia, on l'évite par prudence.
        thumbUrl: _wm(granDillamaStill),
        airedAt: DateTime.utc(2013, 4, 30),
        ageCategory: AgeCategory.enfant,
        addedAt: added(60),
      ),
      Episode(
        id: 'caminandes-s1e2',
        seriesId: 'caminandes',
        seasonNumber: 1,
        episodeNumber: 2,
        title: 'Gran Dillama',
        originalTitle: 'Caminandes: Gran Dillama',
        synopsis:
            "Koro découvre une herbe verdoyante de l'autre côté d'une "
            "clôture électrique. Il faudra plus qu'un peu de courant pour "
            "le décourager.",
        duration: const Duration(minutes: 3),
        thumbUrl: _wm(granDillamaCover),
        airedAt: DateTime.utc(2013, 11, 12),
        ageCategory: AgeCategory.enfant,
        addedAt: added(30),
      ),
      Episode(
        id: 'caminandes-s1e3',
        seriesId: 'caminandes',
        seasonNumber: 1,
        episodeNumber: 3,
        title: 'Llamigos',
        originalTitle: 'Caminandes: Llamigos',
        synopsis:
            "Sur les hauteurs enneigées des Andes, Koro se lie d'amitié "
            "avec Oti le manchot. Ensemble ils défient l'hiver et la "
            "faim.",
        duration: const Duration(minutes: 3),
        thumbUrl: _wm(llamigosCover),
        airedAt: DateTime.utc(2016, 2, 8),
        ageCategory: AgeCategory.enfant,
        addedAt: added(10),
      ),
    ];

    final caminandesSpecials = <Episode>[
      Episode(
        id: 'caminandes-special-1',
        seriesId: 'caminandes',
        seasonNumber: 0,
        episodeNumber: 1,
        title: '¡Oh, Deer!',
        originalTitle: 'Caminandes: ¡Oh, Deer!',
        synopsis:
            "Court métrage bonus dans lequel Koro croise la route "
            "d'un cerf imprévisible dans la pampa.",
        duration: const Duration(minutes: 2),
        thumbUrl: _wm(granDillamaStill),
        airedAt: DateTime.utc(2020, 12, 1),
        ageCategory: AgeCategory.enfant,
        addedAt: added(5),
      ),
    ];

    final caminandes = Series(
      id: 'caminandes',
      title: 'Caminandes',
      originalTitle: 'Caminandes',
      year: 2013,
      synopsis:
          "Les aventures de Koro, un lama au caractère bien trempé, dans "
          "les paysages grandioses de la Patagonie. Série de courts "
          "métrages 3D produits par Blender Studio sous licence "
          "Creative Commons.$_credit",
      tagline: null,
      posterUrl: _wm(llamigosCover),
      backdropUrl: _wm(granDillamaStill),
      ageCategory: AgeCategory.enfant,
      genres: const ['Animation', 'Comédie', 'Familial'],
      sagaId: null,
      sagaLabel: null,
      director: const ['Pablo Vázquez'],
      cast: const [],
      addedAt: added(10),
      seasonsCount: 2,
      episodesCount:
          caminandesSeason1Episodes.length + caminandesSpecials.length,
      seasons: [
        Season(seasonNumber: 0, name: 'Specials', episodes: caminandesSpecials),
        Season(seasonNumber: 1, episodes: caminandesSeason1Episodes),
      ],
    );

    return [caminandes];
  }
}
