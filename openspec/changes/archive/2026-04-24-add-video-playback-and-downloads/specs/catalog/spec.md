## REMOVED Requirements

### Requirement: Play button is visible but disabled in MVP

**Reason** : le player vidéo est désormais implémenté par la capability
`video-playback` introduite dans ce change. Le bouton "Lire" de la
modale de détails devient actif et navigue vers la `PlayerPage` via
`/player/:movieId`. Ce comportement est désormais couvert par le
requirement "Play button in the movie detail modal navigates to the
player page" de la capability `video-playback`.

**Migration** : aucune migration nécessaire côté données. Côté code, la
modification est localisée dans
`lib/ui/pages/home/widgets/movie_detail_modal.widget.dart` — le
`onPressed: null` du widget `_PlayButton` devient un callback qui
dismiss la modale et navigue vers la route player. Le tooltip
`"Lecture bientôt disponible"` est supprimé.
