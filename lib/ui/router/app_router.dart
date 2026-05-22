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
import 'package:kidflix/ui/pages/settings/included_lower_ages_edit.page.dart';
import 'package:kidflix/ui/pages/settings/self_profile_edit.page.dart';
import 'package:kidflix/ui/pages/settings/settings.page.dart';
import 'package:kidflix/ui/pages/wishlist/wishlist.page.dart';
import 'package:kidflix/ui/pages/wishlist/wishlist_search.page.dart';
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
  ProfileSelected() => AppRoutes.home,
  ManagementPinRequired() => AppRoutes.managementPin,
  ManagingProfiles() => AppRoutes.manage,
};

bool _isManageSubRoute(String path) =>
    path == AppRoutes.manage ||
    path == AppRoutes.manageNew ||
    path == AppRoutes.manageMainPin ||
    (path.startsWith('/profiles/manage/') && path.endsWith('/edit'));

bool _isPlayerRoute(String path) => path.startsWith('/player/');

bool _isSettingsRoute(String path) =>
    path == AppRoutes.settings ||
    path == AppRoutes.settingsProfile ||
    path == AppRoutes.settingsAges ||
    path == AppRoutes.settingsDownloads ||
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
        builder: (_, s) =>
            PlayerPage.movie(movieId: s.pathParameters['movieId']!),
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
            episodeId: s.pathParameters['episodeId']!,
            seriesContext: seriesContext,
          );
        },
      ),
    ],
  );
}
