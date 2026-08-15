import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'popup_route_observer.g.dart';

/// Tracks whether a popup — dialog, bottom sheet, menu — is on top of the
/// navigator.
///
/// Exists for remote control: a host showing the resume prompt is waiting
/// for an answer it cannot get from a phone that only offers transport
/// controls. Knowing a popup is up is what lets the remote put its D-pad
/// back on screen at the one moment it is needed most.
///
/// Counts rather than flags: a dialog opened over a bottom sheet must not
/// clear the state when only the topmost one closes.
class PopupRouteObserver extends NavigatorObserver {
  final ValueNotifier<bool> isOpen = ValueNotifier<bool>(false);

  int _depth = 0;

  /// Pages are not popups. Everything else the navigator carries —
  /// `DialogRoute`, `ModalBottomSheetRoute`, `PopupMenuRoute` — is
  /// something the user has to answer before the page underneath
  /// responds again.
  bool _isPopup(Route<dynamic> route) => route is! PageRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPopup(route)) _update(_depth + 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPopup(route)) _update(_depth - 1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPopup(route)) _update(_depth - 1);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    var next = _depth;
    if (oldRoute != null && _isPopup(oldRoute)) next--;
    if (newRoute != null && _isPopup(newRoute)) next++;
    _update(next);
  }

  void _update(int depth) {
    // Clamped: a route removed without ever being observed (one pushed
    // before this observer was attached) would otherwise drive the count
    // negative and leave the flag stuck.
    _depth = depth < 0 ? 0 : depth;
    isOpen.value = _depth > 0;
  }
}

@Riverpod(keepAlive: true)
PopupRouteObserver popupRouteObserver(Ref ref) {
  final observer = PopupRouteObserver();
  ref.onDispose(observer.isOpen.dispose);
  return observer;
}
