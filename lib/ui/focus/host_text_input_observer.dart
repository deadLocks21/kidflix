import 'package:flutter/material.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';

/// Watches whichever text field the host has focused and reports it.
///
/// Deliberately generic rather than wired to the search bar: any field
/// the app focuses — search, a profile name, a future one nobody has
/// written yet — becomes typable from a paired remote without either
/// side learning about it. The host has one keyboard focus at a time, so
/// one observer covers the whole app.
///
/// Reports `none` the moment focus leaves the field, which is what makes
/// the remote's keyboard disappear when someone dismisses the field on
/// the host.
class HostTextInputObserver {
  final ValueChanged<RemoteTextInputSnapshot> onChanged;

  /// The controller of the field currently focused, kept so its listener
  /// can be removed when focus moves on.
  TextEditingController? _watched;

  RemoteTextInputSnapshot _last = RemoteTextInputSnapshot.none;

  HostTextInputObserver({required this.onChanged});

  void start() {
    FocusManager.instance.addListener(_onFocusChanged);
    _onFocusChanged();
  }

  void stop() {
    FocusManager.instance.removeListener(_onFocusChanged);
    _unwatch();
    _emit(RemoteTextInputSnapshot.none);
  }

  void _onFocusChanged() {
    final editable = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (editable == null) {
      _unwatch();
      _emit(RemoteTextInputSnapshot.none);
      return;
    }

    final controller = editable.widget.controller;
    if (!identical(controller, _watched)) {
      _unwatch();
      _watched = controller..addListener(_onTextChanged);
    }
    _emit(
      RemoteTextInputSnapshot(
        active: true,
        value: controller.text,
        obscured: editable.widget.obscureText,
      ),
    );
  }

  /// Keeps the remote in step when the text changes without the focus
  /// moving — someone typing on the host, or a field clearing itself.
  void _onTextChanged() {
    final controller = _watched;
    if (controller == null) return;
    _emit(_last.copyWithValue(controller.text));
  }

  void _unwatch() {
    _watched?.removeListener(_onTextChanged);
    _watched = null;
  }

  /// Pushes only real changes: the focus manager notifies on every
  /// traversal, and re-broadcasting an identical snapshot would wake
  /// every connected remote for nothing.
  void _emit(RemoteTextInputSnapshot next) {
    if (next == _last) return;
    _last = next;
    onChanged(next);
  }
}

extension on RemoteTextInputSnapshot {
  RemoteTextInputSnapshot copyWithValue(String value) =>
      RemoteTextInputSnapshot(active: active, value: value, obscured: obscured);
}

/// Types [text] into the host's focused field, as if it had been entered
/// on the device.
///
/// Goes through [EditableTextState.userUpdateTextEditingValue] rather
/// than the controller, so the field's own `onChanged` runs — which is
/// what every page hangs its behaviour on (the search debounce, form
/// validation) and what the controller alone would skip.
///
/// Returns false when nothing is focused, so the caller can say so
/// instead of dropping the keystroke in silence.
bool setHostTextInput(String text) {
  final editable = FocusManager.instance.primaryFocus?.context
      ?.findAncestorStateOfType<EditableTextState>();
  if (editable == null) return false;
  editable.userUpdateTextEditingValue(
    TextEditingValue(
      text: text,
      // Caret at the end: the remote sends the whole field, so there is
      // no meaningful selection to preserve, and leaving it at 0 would
      // make the host render the start of a long query.
      selection: TextSelection.collapsed(offset: text.length),
    ),
    SelectionChangedCause.keyboard,
  );
  return true;
}

/// Drops the host's keyboard focus, closing whatever field held it.
void dismissHostTextInput() => FocusManager.instance.primaryFocus?.unfocus();
