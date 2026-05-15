import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/infrastructure/series/in_memory.series.repository.dart';
import 'package:kidflix/shared/text_normalization.dart';

/// In-memory fake [CatalogRepository] used until the HTTP backend is ready.
///
/// Every seeded title is rights-free — Blender Open Movies, all released
/// under Creative Commons licences (CC-BY 2.5 → CC-BY 4.0) — so the
/// bundled fixtures can ship to the public stores without IP exposure.
/// The required CC-BY attribution is embedded in each [Movie.synopsis] so
/// the credit travels with the metadata everywhere the title is displayed.
///
/// Stub data is crafted to exercise every row type:
/// - At least 1 movie per [AgeCategory].
/// - Two sagas in the `enfant` category (Open Movies and Stylo 2D),
///   each with ≥ 2 movies, so the saga row assembly is exercised.
/// - Multiple distinct primary genres in `enfant` (Familial, Aventure,
///   Action, Musique, Comédie) so several genre rows are produced.
/// - Distinct [Movie.addedAt] dates so the "recently added" sort is
///   observable.
/// - One movie (Tears of Steel) with 7 cast members, exercising the
///   top-5 cap applied by `MovieDetailDto.fromDomain`.
///
/// Posters point to Wikimedia Commons URLs when an open-licence still is
/// available there; otherwise `null` is used (the UI falls back to a
/// neutral placeholder). The kDrive proxy will supply final artwork in
/// phase 2.
class InMemoryCatalogRepository implements CatalogRepository {
  static const String _wmBase =
      'https://upload.wikimedia.org/wikipedia/commons';
  static String _wm(String path) => '$_wmBase/$path';

  /// Standardised Blender Foundation attribution embedded in each
  /// [Movie.synopsis] to satisfy the CC-BY licence's credit requirement.
  /// Keeping it in the synopsis means the credit appears wherever the
  /// description does (detail modal, accessibility text, etc.).
  static String _credit(String projectUrl, String ccVersion) =>
      '\n\nCrédits : © Blender Foundation — $projectUrl — '
      'Licence Creative Commons CC-BY $ccVersion.';

  static final List<Movie> _movies = _seed();

  /// The seeded series projection in catalog form (no `seasons`, just
  /// metadata + counts). The full series tree is owned by
  /// [InMemorySeriesRepository] — this catalog projection deliberately
  /// matches what the backend returns on `/catalog`, where series are
  /// listed without their episode hierarchy (resolved separately via
  /// `GET /series/{id}`).
  static List<Series> _catalogProjectionOfSeries() => InMemorySeriesRepository
      .seed
      .map(
        (s) => Series(
          id: s.id,
          title: s.title,
          originalTitle: s.originalTitle,
          year: s.year,
          synopsis: s.synopsis,
          tagline: s.tagline,
          posterUrl: s.posterUrl,
          backdropUrl: s.backdropUrl,
          ageCategory: s.ageCategory,
          genres: s.genres,
          sagaId: s.sagaId,
          sagaLabel: s.sagaLabel,
          director: s.director,
          cast: s.cast,
          addedAt: s.addedAt,
          seasonsCount: s.seasonsCount,
          episodesCount: s.episodesCount,
          // Catalog projection: empty seasons.
          seasons: const [],
        ),
      )
      .toList(growable: false);

  @override
  Future<List<CatalogItem>> listCatalog() async {
    return <CatalogItem>[..._movies, ..._catalogProjectionOfSeries()];
  }

  @override
  Future<List<CatalogItem>> listCatalogForProfile(String profileId) =>
      listCatalog();

  @override
  Future<List<CatalogItem>> searchCatalog({required String query}) async {
    final needle = normalizeForSearch(query);
    bool matches(CatalogItem item) {
      if (normalizeForSearch(item.title).contains(needle)) return true;
      final original = item.originalTitle;
      if (original != null && normalizeForSearch(original).contains(needle)) {
        return true;
      }
      return false;
    }

    final all = <CatalogItem>[..._movies, ..._catalogProjectionOfSeries()];
    return all.where(matches).toList(growable: false);
  }

  static List<Movie> _seed() {
    final addedRef = DateTime(2026, 4, 22);
    DateTime added(int daysAgo) => addedRef.subtract(Duration(days: daysAgo));

    return [
      // bebe — Big Buck Bunny (Blender Foundation, CC-BY 3.0)
      Movie(
        id: 'big-buck-bunny',
        title: 'Big Buck Bunny',
        originalTitle: 'Big Buck Bunny',
        year: 2008,
        duration: const Duration(minutes: 10),
        synopsis:
            "Un grand lapin pacifique se promène dans une forêt idyllique "
            "lorsque trois petits rongeurs ne cessent de l'embêter. "
            "Sa patience a des limites — la vengeance approche. Court "
            "métrage open-source de la Blender Foundation."
            "${_credit('bigbuckbunny.org', '3.0')}",
        tagline: 'Un lapin pacifique, trois rongeurs, une revanche.',
        posterUrl: _wm('c/c5/Big_buck_bunny_poster_big.jpg'),
        backdropUrl: _wm('c/c5/Big_buck_bunny_poster_big.jpg'),
        ageCategory: AgeCategory.bebe,
        genres: const ['Familial', 'Comédie', 'Animation'],
        director: const ['Sacha Goedegebure'],
        cast: const [],
        addedAt: added(2),
      ),

      // enfant — saga "Open Movies" (Blender Foundation, CC-BY)
      Movie(
        id: 'spring',
        title: 'Spring',
        originalTitle: 'Spring',
        year: 2019,
        duration: const Duration(minutes: 8),
        synopsis:
            "Une jeune bergère et son chien fidèle réveillent l'esprit du "
            "printemps à travers une vallée enneigée. Court métrage "
            "Blender Studio en hommage à la nature."
            "${_credit('studio.blender.org/projects/spring', '4.0')}",
        tagline: "L'esprit du printemps s'éveille.",
        posterUrl: _wm('0/05/Spring2019PillarPosterBlender.jpg'),
        backdropUrl: _wm('0/05/Spring2019PillarPosterBlender.jpg'),
        ageCategory: AgeCategory.enfant,
        genres: const ['Aventure', 'Animation', 'Fantastique'],
        sagaId: 'open-movies',
        sagaLabel: 'Open Movies',
        director: const ['Andy Goralczyk'],
        cast: const [],
        addedAt: added(25),
      ),
      Movie(
        id: 'sintel',
        title: 'Sintel',
        originalTitle: 'Sintel',
        year: 2010,
        duration: const Duration(minutes: 15),
        synopsis:
            "Sintel, jeune guerrière solitaire, parcourt un monde "
            "hostile à la recherche du dragonneau qu'elle a recueilli "
            "puis perdu. Un récit épique signé Blender Foundation."
            "${_credit('durian.blender.org', '3.0')}",
        tagline: 'Un dragon, une promesse, un voyage sans retour.',
        posterUrl: _wm('8/8f/Sintel_poster.jpg'),
        backdropUrl: _wm('8/8f/Sintel_poster.jpg'),
        ageCategory: AgeCategory.enfant,
        genres: const ['Fantastique', 'Aventure', 'Animation', 'Drame'],
        sagaId: 'open-movies',
        sagaLabel: 'Open Movies',
        director: const ['Colin Levy'],
        cast: const [
          CastMember(name: 'Halina Reijn', role: 'Sintel'),
          CastMember(name: 'Thom Hoffman', role: 'Le Chamane'),
        ],
        addedAt: added(45),
      ),

      // enfant — saga "Stylo 2D" (shorts dessinés à la Grease Pencil)
      Movie(
        id: 'coffee-run',
        title: 'Coffee Run',
        originalTitle: 'Coffee Run',
        year: 2020,
        duration: const Duration(minutes: 4),
        synopsis:
            "Une course matinale pour un café, rythmée par une musique "
            "entraînante. Court métrage 2D Blender entièrement dessiné "
            "avec l'outil Grease Pencil."
            "${_credit('studio.blender.org/projects/coffee-run', '4.0')}",
        tagline: 'Une journée commence avec un sprint.',
        posterUrl: _wm('a/a7/Coffee_Run-movie_poster.png'),
        backdropUrl: _wm('a/a7/Coffee_Run-movie_poster.png'),
        ageCategory: AgeCategory.enfant,
        genres: const ['Musique', 'Animation', 'Drame'],
        sagaId: 'stylo-2d',
        sagaLabel: 'Stylo 2D',
        director: const ['Hjalti Hjalmarsson'],
        cast: const [],
        addedAt: added(15),
      ),
      Movie(
        id: 'hero',
        title: 'Hero',
        originalTitle: 'Hero',
        year: 2018,
        duration: const Duration(minutes: 4),
        synopsis:
            "Un héros au style 2D s'élance à travers un univers dessiné "
            "à la main, démonstration éclatante de l'outil Grease Pencil "
            "de Blender."
            "${_credit('studio.blender.org/projects/hero', '4.0')}",
        tagline: 'Un trait de crayon, mille mouvements.',
        posterUrl: null,
        backdropUrl: null,
        ageCategory: AgeCategory.enfant,
        genres: const ['Action', 'Animation'],
        sagaId: 'stylo-2d',
        sagaLabel: 'Stylo 2D',
        director: const ['Daniel Martinez Lara'],
        cast: const [],
        addedAt: added(40),
      ),
      Movie(
        id: 'glass-half',
        title: 'Glass Half',
        originalTitle: 'Glass Half',
        year: 2019,
        duration: const Duration(minutes: 4),
        synopsis:
            "Dans un musée, deux visiteurs se querellent sur la nature "
            "d'un mystérieux artefact. Court métrage 2D Blender plein "
            "d'humour absurde."
            "${_credit('studio.blender.org/projects/glass-half', '4.0')}",
        tagline: 'À moitié plein ou à moitié vide ?',
        posterUrl: null,
        backdropUrl: null,
        ageCategory: AgeCategory.enfant,
        genres: const ['Comédie', 'Animation', 'Drame'],
        sagaId: 'stylo-2d',
        sagaLabel: 'Stylo 2D',
        director: const ['Beorn Leonard'],
        cast: const [],
        addedAt: added(30),
      ),

      // enfant — standalone
      Movie(
        id: 'agent-327-barbershop',
        title: 'Agent 327 : Opération Barbershop',
        originalTitle: 'Agent 327: Operation Barbershop',
        year: 2017,
        duration: const Duration(minutes: 4),
        synopsis:
            "Le célèbre espion néerlandais Agent 327 infiltre un salon "
            "de coiffure pour confronter Boris Kloris. Démo technique "
            "de Blender Studio pour un long métrage en préparation."
            "${_credit('studio.blender.org/projects/agent-327', '4.0')}",
        tagline: 'Mission : éviter une mauvaise coupe.',
        posterUrl: null,
        backdropUrl: null,
        ageCategory: AgeCategory.enfant,
        genres: const ['Action', 'Comédie', 'Animation'],
        director: const ['Colin Levy', 'Hjalti Hjalmarsson'],
        cast: const [],
        addedAt: added(12),
      ),

      // ado
      Movie(
        id: 'tears-of-steel',
        title: 'Tears of Steel',
        originalTitle: 'Tears of Steel',
        year: 2012,
        duration: const Duration(minutes: 12),
        synopsis:
            "Dans un futur dystopique, un groupe de combattants tente "
            "de sauver le monde des machines en intervenant dans le "
            "passé du créateur des androïdes. Court métrage VFX "
            "Blender Foundation."
            "${_credit('mango.blender.org', '3.0')}",
        tagline: 'Le passé est notre dernière chance.',
        posterUrl: _wm('7/70/Tos-poster.png'),
        backdropUrl: _wm('7/70/Tos-poster.png'),
        ageCategory: AgeCategory.ado,
        genres: const ['Science-fiction', 'Action'],
        director: const ['Ian Hubert'],
        cast: const [
          CastMember(name: 'Derek de Lint', role: 'Thom'),
          CastMember(name: 'Sergio Hasselbaink', role: 'Sergio'),
          CastMember(name: 'Vanja Rukavina', role: 'Janot'),
          CastMember(name: 'Jody Bhe', role: 'Jody'),
          CastMember(name: 'Rogier Schippers', role: 'Rogier'),
          CastMember(name: 'Chris Haley', role: 'Voix androïde'),
          CastMember(name: 'Ben Dair', role: 'Ben'),
        ],
        addedAt: added(55),
      ),

      // jeuneAdulte
      Movie(
        id: 'cosmos-laundromat',
        title: 'Cosmos Laundromat : Premier Cycle',
        originalTitle: 'Cosmos Laundromat: First Cycle',
        year: 2015,
        duration: const Duration(minutes: 12),
        synopsis:
            "Franck, un mouton mélancolique sur une île désolée, "
            "rencontre Victor, un vendeur de réalités alternatives qui "
            "va bouleverser son existence. Pilote du premier long "
            "métrage open-source de Blender."
            "${_credit('studio.blender.org/projects/cosmos-laundromat', '4.0')}",
        tagline: 'Une seconde chance, à n\'importe quel prix.',
        posterUrl: _wm('c/c5/CosmosLaundromatPoster.jpg'),
        backdropUrl: _wm('c/c5/CosmosLaundromatPoster.jpg'),
        ageCategory: AgeCategory.jeuneAdulte,
        genres: const ['Drame', 'Animation', 'Comédie'],
        director: const ['Mathieu Auvray'],
        cast: const [
          CastMember(name: 'Pierre Bokma', role: 'Victor'),
          CastMember(name: 'Reinout Scholten van Aschat', role: 'Franck'),
        ],
        addedAt: added(60),
      ),
      Movie(
        id: 'elephants-dream',
        title: 'Elephants Dream',
        originalTitle: 'Elephants Dream',
        year: 2006,
        duration: const Duration(minutes: 11),
        synopsis:
            "Proog et Emo arpentent une étrange machinerie aux décors "
            "kafkaïens, dans le tout premier court métrage entièrement "
            "produit par la Blender Foundation avec des logiciels libres."
            "${_credit('orange.blender.org', '4.0')}",
        tagline: 'Un voyage dans une machine sans fin.',
        posterUrl: _wm('0/0c/ElephantsDreamPoster.jpg'),
        backdropUrl: _wm('0/0c/ElephantsDreamPoster.jpg'),
        ageCategory: AgeCategory.jeuneAdulte,
        genres: const ['Animation', 'Science-fiction', 'Drame'],
        director: const ['Bassam Kurdali'],
        cast: const [
          CastMember(name: 'Tygo Gernandt', role: 'Proog'),
          CastMember(name: 'Cas Jansen', role: 'Emo'),
        ],
        addedAt: added(70),
      ),

      // adulte
      Movie(
        id: 'sprite-fright',
        title: 'Sprite Fright',
        originalTitle: 'Sprite Fright',
        year: 2021,
        duration: const Duration(minutes: 10),
        synopsis:
            "Un groupe d'adolescents en randonnée dans la forêt anglaise "
            "tombe sur de mystérieuses petites créatures. Hommage "
            "horrifique aux films des années 1980 par Blender Studio."
            "${_credit('studio.blender.org/projects/sprite-fright', '4.0')}",
        tagline: 'Ne jamais sous-estimer les petites créatures.',
        posterUrl: _wm('e/e5/Sprite_Fright-movie_poster.jpg'),
        backdropUrl: _wm('e/e5/Sprite_Fright-movie_poster.jpg'),
        ageCategory: AgeCategory.adulte,
        genres: const ['Horreur', 'Comédie', 'Animation'],
        director: const ['Matthew Luhn'],
        cast: const [],
        addedAt: added(50),
      ),
    ];
  }
}
