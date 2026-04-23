import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/home/home.page.dart';
import 'package:kidflix/ui/pages/otp_verify/otp_verify.page.dart';
import 'package:kidflix/ui/pages/phone_entry/phone_entry.page.dart';
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
}

String _targetRouteFor(SessionState state) => switch (state) {
  Anonymous() => AppRoutes.phone,
  OtpRequested() => AppRoutes.otp,
  Authenticated() => AppRoutes.profiles,
  PinRequired() => AppRoutes.profilePin,
  ProfileSelected() => AppRoutes.home,
};

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
      final target = _targetRouteFor(ref.read(sessionControllerProvider));
      return routerState.matchedLocation == target ? null : target;
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
    ],
  );
}
