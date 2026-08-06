import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Tracks whether the user is currently driving the app with the keyboard.
///
/// Kidflix paints a focus ring **only** in keyboard mode: someone using the
/// mouse never sees one, and the first press of an arrow / Tab reveals the
/// ring on whatever already holds focus instead of moving away from it.
///
/// That first press is deliberately swallowed. Every page hands focus to a
/// sensible element on mount (see the `autofocus` calls across `ui/pages`),
/// so without the swallow the ring would appear one element *past* the one
/// the user expected to start from — pressing `→` on a freshly opened home
/// would light up the second poster, never the first.
///
/// Install it once, above the router, through `MaterialApp.builder`: it has
/// to sit *below* [WidgetsApp]'s own `Shortcuts`/`Actions` for its action
/// overrides to shadow the framework defaults.
class KeyboardModeScope extends StatefulWidget {
  final Widget child;

  const KeyboardModeScope({super.key, required this.child});

  /// The ambient keyboard-mode flag, or `null` when no scope is installed
  /// (widget tests that pump a bare widget). Callers treat `null` as "never
  /// show a ring" rather than crashing.
  static ValueListenable<bool>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_KeyboardModeMarker>()?.mode;

  /// Enters keyboard mode, and reports whether the caller must swallow the
  /// key press that got it here rather than acting on it.
  ///
  /// Any traversal action installed *below* this scope shadows the ones
  /// wired up here, so it has to run the same reveal check first — see
  /// `CatalogFocusScope`.
  static bool revealOnly(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<_KeyboardModeMarker>()
          ?.revealOnly() ??
      false;

  @override
  State<KeyboardModeScope> createState() => _KeyboardModeScopeState();
}

class _KeyboardModeScopeState extends State<KeyboardModeScope> {
  final ValueNotifier<bool> _mode = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _mode.dispose();
    super.dispose();
  }

  /// Enters keyboard mode. Returns `true` when this very key press was
  /// consumed to reveal the ring, meaning the caller must **not** move
  /// focus.
  bool _revealOnly() {
    if (_mode.value) return false;
    _mode.value = true;
    // Swallowing only makes sense when there is something to reveal. On a
    // page that hands out no initial focus, the primary focus is still a
    // bare scope: eating the press would light up nothing at all and cost
    // the user a keystroke, so let it fall through and traverse instead.
    final focus = FocusManager.instance.primaryFocus;
    return focus != null && focus is! FocusScopeNode;
  }

  @override
  Widget build(BuildContext context) {
    return _KeyboardModeMarker(
      mode: _mode,
      revealOnly: _revealOnly,
      child: Listener(
        // Any pointer press means the user is back on the mouse — hide the
        // ring, but leave the focus where it is so a later key press picks
        // up from there.
        onPointerDown: (_) => _mode.value = false,
        child: Actions(
          actions: <Type, Action<Intent>>{
            DirectionalFocusIntent: _RevealFirstDirectionalFocusAction(
              _revealOnly,
            ),
            NextFocusIntent: _RevealFirstNextFocusAction(_revealOnly),
            PreviousFocusIntent: _RevealFirstPreviousFocusAction(_revealOnly),
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _KeyboardModeMarker extends InheritedWidget {
  final ValueListenable<bool> mode;
  final _RevealOnly revealOnly;

  const _KeyboardModeMarker({
    required this.mode,
    required this.revealOnly,
    required super.child,
  });

  @override
  bool updateShouldNotify(_KeyboardModeMarker oldWidget) =>
      mode != oldWidget.mode;
}

/// Signature of [_KeyboardModeScopeState._revealOnly].
typedef _RevealOnly = bool Function();

/// The three traversal actions below all follow the same rule: swallow the
/// press that turns the ring on, forward every later one to the framework's
/// own behaviour.
///
/// Subclassing the concrete default actions (rather than re-implementing
/// them) keeps every subtlety we don't want to own — most notably
/// [DirectionalFocusAction]'s text-field variant, which `EditableText`
/// installs in its own subtree so arrows move the caret instead of the
/// focus. That override sits deeper than ours and still wins.
class _RevealFirstDirectionalFocusAction extends DirectionalFocusAction {
  final _RevealOnly _revealOnly;

  _RevealFirstDirectionalFocusAction(this._revealOnly);

  @override
  void invoke(DirectionalFocusIntent intent) {
    if (_revealOnly()) return;
    super.invoke(intent);
  }
}

class _RevealFirstNextFocusAction extends NextFocusAction {
  final _RevealOnly _revealOnly;

  _RevealFirstNextFocusAction(this._revealOnly);

  @override
  bool invoke(NextFocusIntent intent) {
    if (_revealOnly()) return true;
    return super.invoke(intent);
  }
}

class _RevealFirstPreviousFocusAction extends PreviousFocusAction {
  final _RevealOnly _revealOnly;

  _RevealFirstPreviousFocusAction(this._revealOnly);

  @override
  bool invoke(PreviousFocusIntent intent) {
    if (_revealOnly()) return true;
    return super.invoke(intent);
  }
}
