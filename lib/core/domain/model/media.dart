import 'package:kidflix/core/domain/model/profile.dart';

/// A heterogeneous tile shown on the homepage catalog rows.
///
/// Sourced from the backend (or the in-memory fake during MVP) after being
/// normalized from the tinyMediaManager NFO metadata produced by the local
/// conversion script.
///
/// Every [CatalogItem] is either a [Movie] or a [Series] — the sealed
/// modifier guarantees exhaustive switching at compile time. The two
/// subtypes share the metadata projected on a homepage card (title, poster,
/// genres, etc.) but diverge on what is renderable beyond the card:
///
/// * [Movie] is itself a [PlayableMedia] (it can be opened in the player).
/// * [Series] is not playable — it is a container of seasons / episodes
///   resolved through `SeriesRepository.findById` and rendered as a list.
///
/// All sealed subtypes live in this same library because Dart constraints
/// require sealed sub-types to share their parent's library.
sealed class CatalogItem {
  String get id;
  String get title;
  String? get originalTitle;
  int? get year;
  String get synopsis;
  String? get tagline;
  String? get posterUrl;
  String? get backdropUrl;
  AgeCategory get ageCategory;
  List<String> get genres;
  String? get sagaId;
  String? get sagaLabel;
  List<String> get director;
  List<CastMember> get cast;
  DateTime get addedAt;
}

/// A direct-playback resource that can be opened in the video player.
///
/// Either a [Movie] (in which case it is also a [CatalogItem]) or an
/// [Episode] (in which case it is owned by a parent [Series] and not
/// itself a [CatalogItem]).
///
/// `PlayableMedia` is implicitly abstract (sealed). [Movie] does not
/// `extends PlayableMedia` because it already extends [CatalogItem]; it
/// `implements PlayableMedia` and provides the getters via its own fields.
/// [Episode] `extends PlayableMedia` directly.
sealed class PlayableMedia {
  String get id;
  Duration get duration;
  AgeCategory get ageCategory;
}

/// A movie available in the family catalog.
///
/// Immutable and equatable by [id]. Participates in two sealed
/// hierarchies: it is a [CatalogItem] (homepage tile) and a [PlayableMedia]
/// (player input).
class Movie extends CatalogItem implements PlayableMedia {
  @override
  final String id;
  @override
  final String title;
  @override
  final String? originalTitle;
  @override
  final int? year;
  @override
  final Duration duration;
  @override
  final String synopsis;
  @override
  final String? tagline;
  @override
  final String? posterUrl;
  @override
  final String? backdropUrl;
  @override
  final AgeCategory ageCategory;
  @override
  final List<String> genres;
  @override
  final String? sagaId;
  @override
  final String? sagaLabel;
  @override
  final List<String> director;
  @override
  final List<CastMember> cast;
  @override
  final DateTime addedAt;

  Movie({
    required this.id,
    required this.title,
    required this.duration,
    required this.synopsis,
    required this.ageCategory,
    required this.genres,
    required this.director,
    required this.cast,
    required this.addedAt,
    this.originalTitle,
    this.year,
    this.tagline,
    this.posterUrl,
    this.backdropUrl,
    this.sagaId,
    this.sagaLabel,
  });

  /// `true` when the movie is part of a saga.
  bool get hasSaga => sagaId != null && sagaId!.isNotEmpty;

  /// First genre in [genres], used for row grouping. Null when [genres] is
  /// empty.
  String? get primaryGenre => genres.isEmpty ? null : genres.first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Movie && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Movie(id: $id, title: $title)';
}

/// A TV series available in the family catalog.
///
/// Carries the catalog-level metadata plus server-computed counts
/// ([seasonsCount], [episodesCount]). The hierarchical [seasons] structure
/// is empty when the [Series] instance is projected from `/catalog`, and
/// populated when it comes from `SeriesRepository.findById`. Both
/// projections share the same identity (equality by [id]).
class Series extends CatalogItem {
  @override
  final String id;
  @override
  final String title;
  @override
  final String? originalTitle;
  @override
  final int? year;
  @override
  final String synopsis;
  @override
  final String? tagline;
  @override
  final String? posterUrl;
  @override
  final String? backdropUrl;
  @override
  final AgeCategory ageCategory;
  @override
  final List<String> genres;
  @override
  final String? sagaId;
  @override
  final String? sagaLabel;
  @override
  final List<String> director;
  @override
  final List<CastMember> cast;
  @override
  final DateTime addedAt;

  /// Total non-deleted seasons known to the backend (server-computed).
  /// May differ from `seasons.length` when the local [seasons] is empty
  /// (catalog projection) or partially loaded.
  final int seasonsCount;

  /// Total non-deleted episodes across all seasons (server-computed).
  final int episodesCount;

  /// Hierarchical structure. Empty when the [Series] is a catalog
  /// projection ; populated by `SeriesRepository.findById`.
  final List<Season> seasons;

  Series({
    required this.id,
    required this.title,
    required this.synopsis,
    required this.ageCategory,
    required this.genres,
    required this.director,
    required this.cast,
    required this.addedAt,
    required this.seasonsCount,
    required this.episodesCount,
    this.seasons = const [],
    this.originalTitle,
    this.year,
    this.tagline,
    this.posterUrl,
    this.backdropUrl,
    this.sagaId,
    this.sagaLabel,
  });

  bool get hasSaga => sagaId != null && sagaId!.isNotEmpty;

  String? get primaryGenre => genres.isEmpty ? null : genres.first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Series && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Series(id: $id, title: $title)';
}

/// One season of a [Series].
///
/// Value object owned by its parent series — there is no stable identifier
/// of its own beyond the `(seriesId, seasonNumber)` composite. The TMM
/// convention for "Specials" is `seasonNumber == 0`.
class Season {
  final int seasonNumber;
  final String? name;
  final String? posterUrl;
  final String? synopsis;
  final List<Episode> episodes;

  const Season({
    required this.seasonNumber,
    required this.episodes,
    this.name,
    this.posterUrl,
    this.synopsis,
  });

  /// `true` when this season is the TMM "Specials" container.
  bool get isSpecials => seasonNumber == 0;
}

/// One episode of a [Series].
///
/// Implements [PlayableMedia] : the player accepts an [Episode] directly,
/// uses its [duration] for progress bounds and its [id] for the download
/// stream key.
///
/// [seriesId], [seasonNumber] and [ageCategory] are denormalized from the
/// parent series — the wire payload of `/series/{id}` does not repeat them
/// on each episode entry, so the DTO injects them at parse time.
class Episode extends PlayableMedia {
  @override
  final String id;
  final String seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final String? originalTitle;
  final String? synopsis;
  @override
  final Duration duration;
  final String? thumbUrl;
  final DateTime? airedAt;
  @override
  final AgeCategory ageCategory;
  final DateTime addedAt;

  Episode({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    required this.duration,
    required this.ageCategory,
    required this.addedAt,
    this.originalTitle,
    this.synopsis,
    this.thumbUrl,
    this.airedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Episode && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Episode(id: $id, seriesId: $seriesId, S${seasonNumber}E$episodeNumber)';
}

/// A cast member of a [Movie] or a [Series], ordered by billing importance
/// in the source metadata.
class CastMember {
  final String name;
  final String? role;
  final String? photoUrl;

  const CastMember({required this.name, this.role, this.photoUrl});
}
