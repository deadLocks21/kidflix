import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/home/home.page.dart';
import 'package:kidflix/ui/pages/otp_verify/otp_verify.page.dart';
import 'package:kidflix/ui/pages/phone_entry/phone_entry.page.dart';
import 'package:kidflix/ui/pages/profile_management/change_main_pin.page.dart';
import 'package:kidflix/ui/pages/profile_management/management_list.page.dart';
import 'package:kidflix/ui/pages/profile_management/management_pin.page.dart';
import 'package:kidflix/ui/pages/profile_management/profile_form.page.dart';
import 'package:kidflix/ui/pages/player/player.page.dart';
import 'package:kidflix/ui/pages/profile_pin/profile_pin.page.dart';
import 'package:kidflix/ui/pages/profile_selection/profile_selection.page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

abstract final class AppRoutes {
  static const phone = '/phone';
  static const otp = '/otp';
  static const profiles = '/profiles';
  static const profilePin = '/profiles/pin';
  static const home = '/home';
  static const managementPin = '/profiles/manage/pin';
  static const manage = '/profiles/manage';
  static const manageNew = '/profiles/manage/new';
  static const manageEdit = '/profiles/manage/:id/edit';
  static const manageMainPin = '/profiles/manage/main/pin';
  static const player = '/player/:movieId';
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

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen<SessionState>(sessionControllerProvider, (_, _) {
    refresh.value++;
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
      if (sessionState is ProfileSelected && _isPlayerRoute(current)) {
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
        builder: (_, s) => PlayerPage(movieId: s.pathParameters['movieId']!),
      ),
    ],
  );
}
