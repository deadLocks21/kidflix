import 'package:flutter/material.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/ui/focus/escape_to_pop.dart';

/// Applies a remote's D-pad press to the host's focus tree.
///
/// Goes through intents rather than synthesising key events: the whole
/// keyboard layer (`KeyboardModeScope`, `CatalogFocusScope`, the focus
/// fences) is built on `DirectionalFocusIntent` / `ActivateIntent`, so
/// dispatching those gives the remote *exactly* the keyboard behaviour —
/// including the first press that only reveals the ring — instead of a
/// second, subtly different navigation model to keep in sync.
///
/// [fallbackContext] is used when nothing holds focus yet (a page that
/// hands out no autofocus, or a host that has never been touched): the
/// dispatch then starts from the navigator, which still sits below the
/// keyboard scope.
void applyRemoteNavigation(
  RemoteNavigationDirection direction, {
  BuildContext? fallbackContext,
}) {
  // The focused element is what a real key press would dispatch from, so
  // per-widget overrides (a text field's caret moves, a slider's value)
  // win here the same way they do on the keyboard.
  final context =
      FocusManager.instance.primaryFocus?.context ?? fallbackContext;
  if (context == null || !context.mounted) return;

  if (direction == RemoteNavigationDirection.select) {
    Actions.maybeInvoke(context, const ActivateIntent());
    return;
  }

  if (direction == RemoteNavigationDirection.back) {
    _goBack(context);
    return;
  }

  // A host sitting in a text field (the search bar) installs
  // `EditableText`'s own directional action, which moves the caret
  // instead of the focus — right for a keyboard, wrong for a remote,
  // whose arrows are the only way out of the field. Dispatching from
  // above the field skips that override; traversal still starts from the
  // focused node, so it lands on whatever is below the bar.
  final directionalContext =
      context.findAncestorWidgetOfExactType<EditableText>() == null
      ? context
      : (fallbackContext ?? context);

  Actions.maybeInvoke(
    directionalContext,
    DirectionalFocusIntent(switch (direction) {
      RemoteNavigationDirection.up => TraversalDirection.up,
      RemoteNavigationDirection.down => TraversalDirection.down,
      RemoteNavigationDirection.left => TraversalDirection.left,
      RemoteNavigationDirection.right => TraversalDirection.right,
      RemoteNavigationDirection.select ||
      RemoteNavigationDirection.back ||
      // Handled by the caller, which owns the router.
      RemoteNavigationDirection.search => TraversalDirection.down,
    }),
  );
}

/// Reproduces what `Escape` does, popup fallback included.
///
/// [PopRouteIntent] only claims real pages; on a dialog or a bottom sheet
/// its action reports itself disabled and the key would fall through to
/// the framework's own [DismissIntent] handler. `Actions.maybeInvoke`
/// does that fall-through for us for keys, not for direct dispatch — so
/// the disabled case is checked here, otherwise a remote could never
/// close a dialog it opened.
void _goBack(BuildContext context) {
  const intent = PopRouteIntent();
  final action = Actions.maybeFind<PopRouteIntent>(context);
  final enabled = switch (action) {
    final ContextAction<PopRouteIntent> a => a.isEnabled(intent, context),
    final Action<PopRouteIntent> a => a.isEnabled(intent),
    _ => false,
  };
  if (enabled) {
    Actions.of(context).invokeAction(action!, intent, context);
    return;
  }
  Actions.maybeInvoke(context, const DismissIntent());
}
