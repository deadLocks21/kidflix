## MODIFIED Requirements

### Requirement: Search is orchestrated by an application service and a usecase

The system SHALL expose an Application-layer service
`SearchApplicationService` with a method:

```dart
Future<List<CatalogItem>> searchFor({
  required String query,
  required ProfileDto profile,
});
```

The return type is widened from `Future<List<Movie>>` to
`Future<List<CatalogItem>>` — search now returns a mixed list of
movies and series matching the query.

The service SHALL:

1. Call `CatalogRepository.searchCatalog(query: query)` to get the raw
   matches (the repository now exposes `searchCatalog` instead of
   `searchMovies` — see `catalog` capability).
2. Sort the result alphabetically by `title` (the `CatalogItem` getter
   exposes `title` for both `Movie` and `Series`).
3. Return the sorted list.

The `profile` parameter is preserved in the signature for API
stability with the existing usecase / controller, but is unused by
the service since age-scope filtering happens server-side.

The service SHALL NOT discriminate by `kind` — both movies and series
matching the query are returned in a single mixed list. The UI search
results screen SHALL render both kinds via the same `CatalogItemCard`
widget (see `catalog` capability and `series-viewing` capability for
the card switch logic).

#### Scenario: searchFor returns mixed kinds

- **GIVEN** the repository's `searchCatalog(query: "pi")` returns
  `[Movie("Pikachu"), Series("Pingu")]`
- **WHEN** `searchFor(query: "pi", profile: anyProfile)` is called
- **THEN** the returned list contains both items
- **AND** they are sorted alphabetically by title (`Pikachu, Pingu`)

#### Scenario: searchFor returns empty when no match

- **GIVEN** the repository's `searchCatalog(query: "xyz")` returns `[]`
- **WHEN** `searchFor(query: "xyz", profile: anyProfile)` is called
- **THEN** the returned list is empty

#### Scenario: searchFor sorts by title alphabetically

- **GIVEN** the repository returns
  `[Series("Zelda"), Movie("Astérix"), Series("Pingu")]`
- **WHEN** `searchFor(...)` is called
- **THEN** the returned list is `[Movie("Astérix"), Series("Pingu"),
  Series("Zelda")]` (alpha order across both kinds)

---

### Requirement: Results are rendered as a vertical list of tiles

The search results screen SHALL render every result via the same
`CatalogItemCard` widget used on the homepage rows (see `catalog`
capability). The widget switches on the sealed `CatalogItem` to
distinguish `Movie` and `Series`:

- A `Movie` result renders the existing card with caption `"{year} ·
  {humanizedDuration}"`.
- A `Series` result renders a card with caption `"{year} ·
  {seasonsCount} saison(s)"`.

Tapping a result SHALL open the corresponding detail modal (the same
modal entry point `showCatalogItemDetail(context, item)` for both
kinds).

#### Scenario: Tapping a series search result opens the series modal

- **GIVEN** the search results show a Pingu card
- **WHEN** the user taps the card
- **THEN** the series detail modal for Pingu opens (via
  `showCatalogItemDetail(context, pinguSeries)`)
- **AND** the modal triggers `seriesRepositoryProvider.findById("pingu")`
  on open

#### Scenario: Tapping a movie search result opens the movie modal

- **GIVEN** the search results show a Nemo card
- **WHEN** the user taps the card
- **THEN** the movie detail modal for Nemo opens
- **AND** the modal does NOT trigger any series-related call
