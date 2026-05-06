## ADDED Requirements

### Requirement: SeriesRepository.findByIdForProfile

The system SHALL extend `SeriesRepository` with a profile-explicit
lookup method:

```dart
Future<Series> findByIdForProfile(String seriesId, String profileId);
```

The method SHALL return the [Series] identified by [seriesId] with
its full `seasons` / `episodes` hierarchy, on behalf of [profileId]
rather than the currently-active profile.

The method exists for the downloads manager: when a kid downloads an
episode of a series with `age_category` above the parent's, the
parent's `findById` call would fail with a `403 forbidden_age_category`
(per `API.md` § Détail d'une série). The manager calls
`findByIdForProfile` with the kid profile id — known via
`CatalogRepository.listCatalogForProfile` (cf. `catalog` capability
delta) — to get the full series tree.

* The HTTP implementation SHALL issue `GET /series/{seriesId}` with
  `X-Profile-Id: $profileId` pre-set on the per-call
  `Options.headers`. The `AuthInterceptor` SHALL preserve the
  override (cf. catalog capability delta).
* The in-memory implementation SHALL behave identically to
  `findById` (no profile filter at this layer).

#### Scenario: HTTP impl uses the per-call profile header

- **GIVEN** the active profile is `"parent"` (age `adulte`)
- **AND** series `"pingu"` has `age_category == bebe`, exposed only to profile `"marie"`
- **WHEN** `findByIdForProfile("pingu", "marie")` is called
- **THEN** the outbound `GET /series/pingu` carries `X-Profile-Id: marie`
- **AND** the response is parsed into a [Series] with seasons + episodes

#### Scenario: In-memory impl ignores the profile id

- **GIVEN** the in-memory repo is in use
- **WHEN** `findByIdForProfile("pingu", "any-id")` is called
- **THEN** the result is identical to `findById("pingu")`
