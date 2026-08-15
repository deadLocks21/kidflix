import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Makes `Escape` walk back up the navigation stack.
///
/// Remaps the key rather than reusing [DismissIntent], because every route
/// — pages included — already installs a `DismissIntent` handler that is
/// *disabled* for anything with `barrierDismissible == false`. A disabled
/// action makes `ShortcutManager` give up on the key instead of looking
/// further up the tree, so a root-level `DismissIntent` override would
/// simply never run on a page.
///
/// Going through a private intent keeps both behaviours intact and layered
/// in the right order:
///
/// - on a pushed page → [_PopRouteAction] pops it;
/// - on a root page (home, profile selection) → nothing can be popped, the
///   action reports itself disabled, the key falls through to
///   `DismissIntent`, whose page-level handler is disabled too. `Escape`
///   is inert, so a child mashing keys cannot leave their profile;
/// - inside a dialog or a bottom sheet → the action stays out of the way
///   and the framework's own dismissal applies, which is what keeps
///   `barrierDismissible: false` modals (resume prompt, kids-lock PIN)
///   sealed.
class EscapeToPop extends StatelessWidget {
  final Widget child;

  const EscapeToPop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): PopRouteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{PopRouteIntent: _PopRouteAction()},
        child: child,
      ),
    );
  }
}

/// Public so the remote-control D-pad's "Retour" can dispatch the very
/// same intent instead of re-deriving what `Escape` means — see
/// `applyRemoteNavigation`.
class PopRouteIntent extends Intent {
  const PopRouteIntent();
}

class _PopRouteAction extends ContextAction<PopRouteIntent> {
  @override
  bool isEnabled(PopRouteIntent intent, [BuildContext? context]) {
    if (context == null) return false;
    final route = ModalRoute.of(context);
    // Popups own their dismissal; only real pages are ours to pop.
    if (route is! PageRoute) return false;
    return route.isCurrent && Navigator.of(context).canPop();
  }

  @override
  void invoke(PopRouteIntent intent, [BuildContext? context]) {
    if (context == null) return;
    // `maybePop`, not `pop`: a page that guards its exit with a [PopScope]
    // keeps the last word.
    Navigator.of(context).maybePop();
  }
}
