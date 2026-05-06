import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/infrastructure/series/in_memory.series.repository.dart';
import 'package:kidflix/shared/text_normalization.dart';

/// In-memory fake [CatalogRepository] used until the HTTP backend is ready.
///
/// Stub data is crafted to exercise every row type:
/// - At least 1 movie per [AgeCategory].
/// - Two sagas in the `enfant` category (Astérix and Harry Potter), each
///   with 2 movies, so the saga row assembly is exercised (≥ 2 threshold).
/// - At least 4 distinct primary genres in `enfant` (Familial, Animation,
///   Aventure, Fantastique) so several genre rows are produced.
/// - Distinct [Movie.addedAt] dates so the "recently added" sort is
///   observable.
/// - One movie (Astérix Empire du Milieu) with 7 cast members, exercising
///   the top-5 cap applied by `MovieDetailDto.fromDomain`.
///
/// Posters and backdrops are real TMDB public URLs, fetched once during
/// the MVP implementation and hard-coded here. Production posters will
/// come from the kDrive proxy once phase 2 lands.
class InMemoryCatalogRepository implements CatalogRepository {
  static const String _tmdbImageBase = 'https://image.tmdb.org/t/p/original';
  static String _img(String hash) => '$_tmdbImageBase/$hash';

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
      // enfant — saga Astérix (2 films)
      Movie(
        id: 'asterix-empire-du-milieu',
        title: 'Astérix & Obélix : L\'Empire du Milieu',
        originalTitle: 'Astérix & Obélix : L\'Empire du Milieu',
        year: 2023,
        duration: const Duration(minutes: 112),
        synopsis:
            'Nous sommes en 50 avant J.C. L\'Impératrice de Chine est '
            'emprisonnée suite à un coup d\'État fomenté par Deng Tsin '
            'Quin, un prince félon. Aidée par Graindemaïs et Tat Han, la '
            'princesse Fu-Yi s\'enfuit en Gaule pour demander l\'aide '
            'd\'Astérix et Obélix.',
        tagline: 'Il y a très très longtemps dans un pays lointain…',
        posterUrl: _img('vchpiQLvXa4uyZhqdEwttrsFOOC.jpg'),
        backdropUrl: _img('pYHnIePp56sQhonIJJ9RRfBmAPU.jpg'),
        ageCategory: AgeCategory.enfant,
        genres: const ['Familial', 'Comédie', 'Aventure', 'Fantastique'],
        sagaId: 'asterix',
        sagaLabel: 'Astérix',
        director: const ['Guillaume Canet'],
        cast: const [
          CastMember(name: 'Guillaume Canet', role: 'Astérix'),
          CastMember(name: 'Gilles Lellouche', role: 'Obélix'),
          CastMember(name: 'Vincent Cassel', role: 'Jules César'),
          CastMember(name: 'Jonathan Cohen', role: 'Graindemaïs'),
          CastMember(name: 'Julie Chen', role: 'Princesse Fu Yi'),
          CastMember(name: 'Marion Cotillard', role: 'Cléopâtre / Bibine'),
          CastMember(name: 'Pierre Richard', role: 'Panoramix'),
        ],
        addedAt: added(2),
      ),
      Movie(
        id: 'asterix-potion-magique',
        title: 'Astérix : Le Secret de la Potion Magique',
        year: 2018,
        duration: const Duration(minutes: 85),
        synopsis:
            'À la suite d\'une chute lors de la cueillette du gui, le '
            'druide Panoramix décide qu\'il est temps d\'assurer l\'avenir '
            'du village. Accompagné d\'Astérix et Obélix, il entreprend '
            'de parcourir le monde gaulois à la recherche d\'un jeune '
            'druide talentueux à qui transmettre le Secret de la Potion '
            'Magique.',
        posterUrl: _img('jgu4HVfj9P2K4fByb90EivJg2AX.jpg'),
        backdropUrl: _img('8sb4aBST28vN3rBz704XJczS0Ld.jpg'),
        ageCategory: AgeCategory.enfant,
        genres: const ['Animation', 'Aventure', 'Comédie'],
        sagaId: 'asterix',
        sagaLabel: 'Astérix',
        director: const ['Alexandre Astier', 'Louis Clichy'],
        cast: const [
          CastMember(name: 'Christian Clavier', role: 'Astérix'),
          CastMember(name: 'Guillaume Briat', role: 'Obélix'),
          CastMember(name: 'Alexandre Astier', role: 'Panoramix'),
        ],
        addedAt: added(25),
      ),
      // enfant — saga Harry Potter (2 films)
      Movie(
        id: 'hp-ecole-des-sorciers',
        title: 'Harry Potter à l\'école des sorciers',
        originalTitle: 'Harry Potter and the Philosopher\'s Stone',
        year: 2001,
        duration: const Duration(minutes: 152),
        synopsis:
            'Le jour de ses onze ans, Harry Potter, un orphelin élevé par '
            'un oncle et une tante qui le détestent, voit son existence '
            'bouleversée. Un géant vient le chercher pour l\'emmener dans '
            'une école de sorcellerie, Poudlard.',
        posterUrl: _img('fbxQ44VRdM2PVzHSNajUseUteem.jpg'),
        backdropUrl: _img('1XAC6RPT01UX9EQGy2JVn5c8pgy.jpg'),
        ageCategory: AgeCategory.enfant,
        genres: const ['Fantastique', 'Aventure', 'Familial'],
        sagaId: 'harry-potter',
        sagaLabel: 'Harry Potter',
        director: const ['Chris Columbus'],
        cast: const [
          CastMember(name: 'Daniel Radcliffe', role: 'Harry Potter'),
          CastMember(name: 'Rupert Grint', role: 'Ron Weasley'),
          CastMember(name: 'Emma Watson', role: 'Hermione Granger'),
          CastMember(name: 'Robbie Coltrane', role: 'Rubeus Hagrid'),
        ],
        addedAt: added(40),
      ),
      Movie(
        id: 'hp-chambre-des-secrets',
        title: 'Harry Potter et la Chambre des Secrets',
        originalTitle: 'Harry Potter and the Chamber of Secrets',
        year: 2002,
        duration: const Duration(minutes: 161),
        synopsis:
            'Pendant les vacances d\'été, l\'elfe de maison Dobby rend '
            'visite à Harry pour le mettre en garde : s\'il retourne à '
            'Poudlard, il sera en grand danger. Mais Harry ignore la '
            'menace et découvre bientôt les secrets de la Chambre.',
        posterUrl: _img('8KpHRokGpiaqEGpjYe0rpywtvUx.jpg'),
        backdropUrl: _img('jbe4gVSfRlbPTdESXhEKpornsfu.jpg'),
        ageCategory: AgeCategory.enfant,
        genres: const ['Fantastique', 'Aventure', 'Familial'],
        sagaId: 'harry-potter',
        sagaLabel: 'Harry Potter',
        director: const ['Chris Columbus'],
        cast: const [
          CastMember(name: 'Daniel Radcliffe', role: 'Harry Potter'),
          CastMember(name: 'Rupert Grint', role: 'Ron Weasley'),
          CastMember(name: 'Emma Watson', role: 'Hermione Granger'),
        ],
        addedAt: added(38),
      ),
      // enfant — standalones, genres variés
      Movie(
        id: 'nemo',
        title: 'Le Monde de Nemo',
        originalTitle: 'Finding Nemo',
        year: 2003,
        duration: const Duration(minutes: 100),
        synopsis:
            'Nemo, un jeune poisson-clown, est capturé et se retrouve dans '
            'l\'aquarium d\'un dentiste de Sydney. Son père Marin '
            'entreprend alors un périple à travers l\'océan pour le '
            'retrouver.',
        posterUrl: _img('8zR2vXoXfdlknEYjfHvCbb1rJbI.jpg'),
        backdropUrl: _img('eCynaAOgYYiw5yN5lBwz3IxqvaW.jpg'),
        ageCategory: AgeCategory.enfant,
        genres: const ['Animation', 'Aventure', 'Familial'],
        director: const ['Andrew Stanton'],
        cast: const [
          CastMember(name: 'Albert Brooks', role: 'Marin'),
          CastMember(name: 'Ellen DeGeneres', role: 'Dory'),
        ],
        addedAt: added(10),
      ),
      Movie(
        id: 'totoro',
        title: 'Mon Voisin Totoro',
        originalTitle: 'となりのトトロ',
        year: 1988,
        duration: const Duration(minutes: 86),
        synopsis:
            'Deux sœurs s\'installent à la campagne avec leur père pour '
            'se rapprocher de leur mère hospitalisée. Elles découvrent la '
            'présence d\'esprits de la forêt, dont le grand Totoro.',
        posterUrl: _img('eEpy8IiR8N0S6mgkdAjDCMlMYQO.jpg'),
        backdropUrl: _img('6O1mOoTXuc1WqjKd2R7MFQHZ7Eb.jpg'),
        ageCategory: AgeCategory.enfant,
        genres: const ['Animation', 'Familial', 'Fantastique'],
        director: const ['Hayao Miyazaki'],
        cast: const [],
        addedAt: added(5),
      ),
      Movie(
        id: 'tintin-licorne',
        title: 'Les Aventures de Tintin : Le Secret de la Licorne',
        year: 2011,
        duration: const Duration(minutes: 107),
        synopsis:
            'Tintin, jeune reporter, acquiert la maquette d\'un bateau, '
            'la Licorne. Il ignore que ce modèle est convoité par un '
            'dangereux collectionneur et qu\'il renferme le secret d\'un '
            'fabuleux trésor.',
        posterUrl: _img('qCoaNNfH6lS7qkZDYhWkQpiQpnM.jpg'),
        backdropUrl: _img('4BS8tgBNWg2jPiDlBwM2iJe1xB7.jpg'),
        ageCategory: AgeCategory.enfant,
        genres: const ['Aventure', 'Animation', 'Familial'],
        director: const ['Steven Spielberg'],
        cast: const [
          CastMember(name: 'Jamie Bell', role: 'Tintin'),
          CastMember(name: 'Andy Serkis', role: 'Capitaine Haddock'),
        ],
        addedAt: added(15),
      ),
      Movie(
        id: 'kung-fu-panda',
        title: 'Kung Fu Panda',
        year: 2008,
        duration: const Duration(minutes: 92),
        synopsis:
            'Po, un panda gaffeur, rêve de devenir un maître du kung-fu. '
            'Désigné Guerrier Dragon, il doit faire ses preuves face au '
            'redoutable Tai Lung, qui vient de s\'échapper de prison.',
        posterUrl: _img('pxZNY88UWH0uic83QHBSh2yFEYL.jpg'),
        backdropUrl: _img('qdthf9WrRDSaIkGVQGhhJ9pz1hn.jpg'),
        ageCategory: AgeCategory.enfant,
        genres: const ['Animation', 'Comédie', 'Aventure'],
        director: const ['John Stevenson', 'Mark Osborne'],
        cast: const [
          CastMember(name: 'Jack Black', role: 'Po'),
          CastMember(name: 'Dustin Hoffman', role: 'Maître Shifu'),
        ],
        addedAt: added(30),
      ),
      // bebe
      Movie(
        id: 'shaun-le-mouton',
        title: 'Shaun le mouton, le film',
        originalTitle: 'Shaun the Sheep Movie',
        year: 2015,
        duration: const Duration(minutes: 85),
        synopsis:
            'Shaun et ses amis décident de s\'offrir une journée de '
            'vacances loin de la ferme. Mais leur escapade tourne court '
            'et ils se retrouvent bientôt en route pour la grande ville '
            'à la recherche du fermier.',
        posterUrl: _img('qmWlSdvzGp4tyJpI76JrEEmU0F2.jpg'),
        backdropUrl: _img('9qxBNfI1QFbiZS62fsgaUd563t2.jpg'),
        ageCategory: AgeCategory.bebe,
        genres: const ['Animation', 'Familial'],
        director: const ['Mark Burton', 'Richard Starzak'],
        cast: const [],
        addedAt: added(20),
      ),
      // ado
      Movie(
        id: 'goonies',
        title: 'Les Goonies',
        originalTitle: 'The Goonies',
        year: 1985,
        duration: const Duration(minutes: 114),
        synopsis:
            'Pour sauver leur quartier d\'une démolition, une bande '
            'd\'adolescents part à la recherche d\'un trésor enfoui '
            'autrefois par un pirate légendaire.',
        posterUrl: _img('7EcRgdCjQriST92SzIenogw77kJ.jpg'),
        backdropUrl: _img('jbe4gVSfRlbPTdESXhEKpornsfu.jpg'),
        ageCategory: AgeCategory.ado,
        genres: const ['Aventure', 'Comédie', 'Familial'],
        director: const ['Richard Donner'],
        cast: const [
          CastMember(name: 'Sean Astin', role: 'Mikey'),
          CastMember(name: 'Josh Brolin', role: 'Brand'),
        ],
        addedAt: added(50),
      ),
      // jeuneAdulte
      Movie(
        id: 'inception',
        title: 'Inception',
        year: 2010,
        duration: const Duration(minutes: 148),
        synopsis:
            'Dom Cobb est un voleur expérimenté, spécialisé dans '
            'l\'extraction de secrets enfouis au plus profond du '
            'subconscient pendant le rêve. Une dernière mission lui '
            'permettra peut-être de retrouver sa vie d\'avant.',
        posterUrl: _img('aej3LRUga5rhgkmRP6XMFw3ejbl.jpg'),
        backdropUrl: _img('8ZTVqvKDQ8emSGUEMjsS4yHAwrp.jpg'),
        ageCategory: AgeCategory.jeuneAdulte,
        genres: const ['Science-fiction', 'Action', 'Thriller'],
        director: const ['Christopher Nolan'],
        cast: const [
          CastMember(name: 'Leonardo DiCaprio', role: 'Cobb'),
          CastMember(name: 'Joseph Gordon-Levitt', role: 'Arthur'),
        ],
        addedAt: added(60),
      ),
      // adulte
      Movie(
        id: 'le-parrain',
        title: 'Le Parrain',
        originalTitle: 'The Godfather',
        year: 1972,
        duration: const Duration(minutes: 175),
        synopsis:
            'En 1945, à New York, les Corleone sont une des cinq plus '
            'puissantes familles de la mafia. Don Vito Corleone « parrain '
            '» de cette famille, marie sa fille à Carlo Rizzi.',
        posterUrl: _img('k3uIbYtiuK8pwbCcbma29nTqmgG.jpg'),
        backdropUrl: _img('tSPT36ZKlP2WVHJLM4cQPLSzv3b.jpg'),
        ageCategory: AgeCategory.adulte,
        genres: const ['Drame', 'Crime'],
        director: const ['Francis Ford Coppola'],
        cast: const [
          CastMember(name: 'Marlon Brando', role: 'Don Vito Corleone'),
          CastMember(name: 'Al Pacino', role: 'Michael Corleone'),
        ],
        addedAt: added(70),
      ),
    ];
  }
}
