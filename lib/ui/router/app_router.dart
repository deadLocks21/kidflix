import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/dtos/series_playback_context.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/infrastructure/providers/download_management.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/home/home.page.dart';
import 'package:kidflix/ui/pages/otp_verify/otp_verify.page.dart';
import 'package:kidflix/ui/pages/phone_entry/phone_entry.page.dart';
import 'package:kidflix/ui/pages/downloads/downloads_page.dart';
import 'package:kidflix/ui/pages/profile_management/change_main_pin.page.dart';
import 'package:kidflix/ui/pages/profile_management/management_list.page.dart';
import 'package:kidflix/ui/pages/profile_management/management_pin.page.dart';
import 'package:kidflix/ui/pages/profile_management/profile_form.page.dart';
import 'package:kidflix/ui/pages/player/player.page.dart';
import 'package:kidflix/ui/pages/profile_pin/profile_pin.page.dart';
import 'package:kidflix/ui/pages/profile_selection/profile_selection.page.dart';
import 'package:kidflix/ui/pages/seen_setup/seen_setup.page.dart';
import 'package:kidflix/ui/pages/settings/included_lower_ages_edit.page.dart';
import 'package:kidflix/ui/pages/settings/self_profile_edit.page.dart';
import 'package:kidflix/ui/pages/settings/settings.page.dart';
import 'package:kidflix/ui/pages/wishlist/wishlist.page.dart';
import 'package:kidflix/ui/pages/wishlist/wishlist_search.page.dart';
import 'package:kidflix/ui/router/popup_route_observer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

abstract final class AppRoutes {
  static const phone = '/phone';
  static const otp = '/otp';
  static const profiles = '/profiles';
  static const profilePin = '/profiles/pin';
  static const home = '/home';
  static const settings = '/home/settings';
  static const settingsProfile = '/home/settings/profile';
  static const settingsAges = '/home/settings/ages';
  static const settingsDownloads = '/home/settings/downloads';
  static const settingsSeen = '/home/settings/seen';
  static const settingsWishlist = '/home/settings/wishlist';
  static const settingsWishlistAdd = '/home/settings/wishlist/add';
  static const managementPin = '/profiles/manage/pin';
  static const manage = '/profiles/manage';
  static const manageNew = '/profiles/manage/new';
  static const manageEdit = '/profiles/manage/:id/edit';
  static const manageMainPin = '/profiles/manage/main/pin';
  static const player = '/player/:movieId';
  static const playerEpisode = '/player/episode/:episodeId';
}

String _targetRouteFor(SessionState state) => switch (state) {
  Anonymous() => AppRoutes.phone,
  OtpRequested() => AppRoutes.otp,
  Authenticated() => AppRoutes.profiles,
  PinRequired() => AppRoutes.profilePin,
  ProfileSelected() =>
    kProbeMediaId.isEmpty || kProbeHomeDwellS > 0
        ? AppRoutes.home
        : '/player/$kProbeMediaId',
  ManagementPinRequired() => AppRoutes.managementPin,
  ManagingProfiles() => AppRoutes.manage,
};

/// Sends the app straight into the player for this id as soon as a
/// profile is selected, instead of to the home page.
///
/// Exists for the automated playback bench (`tools/playback_bench.sh`):
/// measuring frame drops means measuring the *same* film, from the same
/// point, over and over, and a human clicking through the catalogue is
/// both the slowest part of that loop and a source of variance — a
/// different film or a different scene changes the numbers.
///
/// Empty by default, so this branch is dead weight in every real build:
/// the constant folds away and the route resolves to home exactly as
/// before. Set with `--dart-define=PROBE_MEDIA_ID=<id>`.
const String kProbeMediaId = String.fromEnvironment('PROBE_MEDIA_ID');

/// Secondes passées sur la home avant que le bench ne lance le film,
/// via `--dart-define=PROBE_HOME_DWELL_S=<n>`. Zéro (défaut) : le banc
/// va droit au player.
///
/// Exister est tout l'intérêt : aller droit au player mesure un chemin
/// que personne n'emprunte. Un vrai spectateur traverse la home, où une
/// bande-annonce démarre son propre lecteur mpv, puis ouvre une modale
/// qui en démarre un second. Mesurer sans ce passage, c'est mesurer une
/// app qui n'a jamais rien fait d'autre que lire un fichier.
const int kProbeHomeDwellS = int.fromEnvironment('PROBE_HOME_DWELL_S');

/// Seconde du film où le bench démarre la lecture, via
/// `--dart-define=PROBE_START_S=<n>`.
///
/// Le générique d'ouverture est le passage le moins coûteux d'un film :
/// peu de mouvement, donc peu de travail pour le décodeur comme pour la
/// présentation. Mesurer là revient à mesurer le meilleur cas, alors que
/// le spectateur, lui, regarde le milieu du film.
const int kProbeStartS = int.fromEnvironment('PROBE_START_S');

/// Profil choisi automatiquement au démarrage pour le bench, via
/// `--dart-define=PROBE_PROFILE_ID=<id>`. Voir son usage dans
/// `bootstrap` : sans lui, l'app s'arrête sur l'écran de choix de profil
/// et [kProbeMediaId] ne sert à rien.
const String kProbeProfileId = String.fromEnvironment('PROBE_PROFILE_ID');

/// Code PIN du profil visé par [kProbeProfileId], quand il en a un.
/// Fourni par l'environnement au moment du build du bench et jamais
/// stocké dans le dépôt.
const String kProbeProfilePin = String.fromEnvironment('PROBE_PROFILE_PIN');

bool _isManageSubRoute(String path) =>
    path == AppRoutes.manage ||
    path == AppRoutes.manageNew ||
    path == AppRoutes.manageMainPin ||
    (path.startsWith('/profiles/manage/') && path.endsWith('/edit'));

bool _isPlayerRoute(String path) => path.startsWith('/player/');

/// Identity of a player page, derived from the **concrete** location.
///
/// GoRouter builds its page key from the route *pattern*
/// (`/player/:movieId`), so `/player/A` and `/player/B` share one page
/// key: Flutter would reuse the same `Element`, keep the existing
/// `PlayerPageState`, never re-run `initState`, and go on playing the
/// first film while the URL claims the second.
///
/// That never bit the app while the only way into the player was from
/// the catalogue — the page always unmounted in between. A remote
/// sending `playMedia` while a film is already up navigates player →
/// player directly, which is exactly the case the pattern-level key gets
/// wrong. Keying on the full URI (query string included, so a change of
/// series or shuffle mode also counts) forces a genuine remount.
ValueKey<String> playerPageKey(Uri location) =>
    ValueKey<String>(location.toString());

bool _isSettingsRoute(String path) =>
    path == AppRoutes.settings ||
    path == AppRoutes.settingsProfile ||
    path == AppRoutes.settingsAges ||
    path == AppRoutes.settingsDownloads ||
    path == AppRoutes.settingsSeen ||
    path == AppRoutes.settingsWishlist ||
    path == AppRoutes.settingsWishlistAdd;

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  // Single-shot per app lifetime: at the first transition into an
  // Authenticated/ProfileSelected/ManagingProfiles state, fire the
  // cache cleanup pass. Subsequent state changes (logout, profile
  // switch) do not retrigger. `unawaited(...)` keeps boot non-blocking.
  var didRunStartupCleanup = false;
  ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
    // Only refresh the router on state TYPE transitions: the redirect
    // logic branches solely on the runtime type of `SessionState`, so
    // same-type mutations (e.g. `ManagingProfiles(s1) → ManagingProfiles(s2)`
    // when a profile is created / edited) would otherwise trigger a
    // gratuitous re-resolution that races with imperative `context.pop()`
    // and re-pushes the form page on top of the manage list.
    if (previous?.runtimeType != next.runtimeType) {
      refresh.value++;
    }
    if (!didRunStartupCleanup &&
        (next is Authenticated ||
            next is ProfileSelected ||
            next is ManagingProfiles)) {
      didRunStartupCleanup = true;
      unawaited(ref.read(runStartupCacheCleanupUseCaseProvider).execute());
    }
  });
  return GoRouter(
    initialLocation: AppRoutes.phone,
    // Lets a remote know when the host is stuck behind a prompt.
    observers: [ref.read(popupRouteObserverProvider)],
    refreshListenable: refresh,
    redirect: (context, routerState) {
      final sessionState = ref.read(sessionControllerProvider);
      final target = _targetRouteFor(sessionState);
      final current = routerState.matchedLocation;
      if (sessionState is ManagingProfiles && _isManageSubRoute(current)) {
        return null;
      }
      if (sessionState is ProfileSelected &&
          (_isPlayerRoute(current) || _isSettingsRoute(current))) {
        return null;
      }
      return current == target ? null : target;
    },
    routes: [
      GoRoute(path: AppRoutes.phone, builder: (_, _) => const PhoneEntryPage()),
      GoRoute(path: AppRoutes.otp, builder: (_, _) => const OtpVerifyPage()),
      GoRoute(
        path: AppRoutes.profiles,
        builder: (_, _) => const ProfileSelectionPage(),
      ),
      GoRoute(
        path: AppRoutes.profilePin,
        builder: (_, _) => const ProfilePinPage(),
      ),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.settingsProfile,
        builder: (_, _) => const SelfProfileEditPage(),
      ),
      GoRoute(
        path: AppRoutes.settingsAges,
        builder: (_, _) => const IncludedLowerAgesEditPage(),
      ),
      GoRoute(
        path: AppRoutes.settingsDownloads,
        builder: (_, _) => const DownloadsPage(),
      ),
      GoRoute(
        path: AppRoutes.settingsSeen,
        builder: (_, _) => const SeenSetupPage(),
      ),
      GoRoute(
        path: AppRoutes.settingsWishlist,
        builder: (_, _) => const WishlistPage(),
      ),
      GoRoute(
        path: AppRoutes.settingsWishlistAdd,
        builder: (_, _) => const WishlistSearchPage(),
      ),
      GoRoute(
        path: AppRoutes.managementPin,
        builder: (_, _) => const ManagementPinPage(),
      ),
      GoRoute(
        path: AppRoutes.manage,
        builder: (_, _) => const ManagementListPage(),
      ),
      GoRoute(
        path: AppRoutes.manageNew,
        builder: (_, _) => const ProfileFormPage(),
      ),
      GoRoute(
        path: AppRoutes.manageEdit,
        builder: (_, s) => ProfileFormPage(profileId: s.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.manageMainPin,
        builder: (_, _) => const ChangeMainPinPage(),
      ),
      GoRoute(
        path: AppRoutes.player,
        builder: (_, s) => PlayerPage.movie(
          key: playerPageKey(s.uri),
          movieId: s.pathParameters['movieId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.playerEpisode,
        builder: (_, s) {
          final qp = s.uri.queryParameters;
          final seriesId = qp['series'];
          SeriesPlaybackContext? seriesContext;
          if (seriesId != null && seriesId.isNotEmpty) {
            final mode = qp['mode'] == 'shuffle'
                ? SeriesPlaybackMode.shuffle
                : SeriesPlaybackMode.linear;
            seriesContext = SeriesPlaybackContext(
              seriesId: seriesId,
              mode: mode,
            );
          }
          return PlayerPage.episode(
            key: playerPageKey(s.uri),
            episodeId: s.pathParameters['episodeId']!,
            seriesContext: seriesContext,
          );
        },
      ),
    ],
  );
}
