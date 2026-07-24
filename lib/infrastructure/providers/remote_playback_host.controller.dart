import 'dart:async';

import 'package:kidflix/core/application/remote/playback_remote_controls.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/select_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_profile_pin.usecase.dart';
import 'package:kidflix/core/application/remote/remote_query.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';
import 'package:kidflix/core/domain/model/remote_session.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/logger.service_provider.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';
import 'package:kidflix/infrastructure/providers/remote_host_query_handler.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/infrastructure/remote_control/remote_device_identity.dart';
import 'package:kidflix/ui/router/app_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_playback_host.controller.g.dart';

/// Wrong PINs a remote may submit before a cooldown kicks in.
const int _maxRemotePinAttempts = 5;

/// The application-side half of remote control on the *host* device.
///
/// Holds the state remotes see, and owns the only reference to the
/// mounted player's [PlaybackRemoteControls]. Everything above it (the
/// HTTP server) stays free of Flutter; everything below it (the player
/// page) stays free of networking.
@Riverpod(keepAlive: true)
class RemotePlaybackHost extends _$RemotePlaybackHost {
  PlaybackRemoteControls? _controls;

  /// Playback half of the snapshot, owned by the mounted player page.
  /// The session half is read fresh on every push, so it stays correct
  /// even when no player exists — which is exactly the situation a
  /// remote needs to see in order to fix it.
  RemotePlaybackState _playback = RemotePlaybackState.idle;

  /// Wrong PINs submitted by remotes since the last successful unlock.
  /// Only a success clears it — see [_submitPin].
  int _failedPinAttempts = 0;

  /// When remote PIN entry becomes possible again.
  DateTime? _pinRetryAfter;

  @override
  RemotePlaybackState build() {
    // Any session transition (profile picked, PIN accepted, logout) has
    // to reach the remotes; none of them go through [publish].
    ref.listen(sessionControllerProvider, (_, _) => _push());
    return RemotePlaybackState.idle;
  }

  /// Called by the player page once its engine is live.
  void attach(PlaybackRemoteControls controls) {
    _controls = controls;
  }

  /// Called by the player page on dispose.
  ///
  /// Takes the instance back so a *stale* detach cannot clear a fresh
  /// attach: when a remote starts a new title, GoRouter mounts the next
  /// page (which attaches) before disposing the previous one (which
  /// detaches), and an unconditional clear would leave the new player
  /// unreachable.
  void detach(PlaybackRemoteControls controls) {
    if (!identical(_controls, controls)) return;
    _controls = null;
    publish(RemotePlaybackState.idle);
  }

  /// Pushes a fresh snapshot to connected remotes.
  ///
  /// Forwards straight to the server rather than going through a provider
  /// listener: this is called on every position tick, and the server
  /// already coalesces position-only changes. Reading the host provider
  /// is cheap — it only constructs the service, binding happens in
  /// [RemoteHostController.enable].
  void publish(RemotePlaybackState next) {
    _playback = next;
    _push();
  }

  /// Recomputes and republishes the snapshot.
  ///
  /// Needed at start-up: [ref.listen] only fires on session *changes*, and
  /// the session is already restored by the time the host comes up — so
  /// without this the first frame every remote receives claims the host is
  /// signed out, and nothing ever corrects it.
  void refresh() => _push();

  /// Merges the current session situation into the playback snapshot and
  /// hands the result to the server.
  void _push() {
    final merged = _playback.copyWith(session: _readSession());
    state = merged;
    ref.read(remoteControlHostProvider).publishState(merged);
  }

  /// Projects the host's `SessionState` onto the wire model.
  ///
  /// Sends ids, names and avatars — never `pinHash`. The host is the only
  /// side that verifies a PIN.
  RemoteSessionSnapshot _readSession() {
    List<RemoteProfileOption> options(Session session) => [
      for (final p in session.profiles)
        RemoteProfileOption(
          id: p.id,
          name: p.name,
          avatarId: p.avatarId,
          requiresPin: p.hasPin,
          isMain: p.isMain,
        ),
    ];
    return switch (ref.read(sessionControllerProvider)) {
      Authenticated(:final session) => RemoteSessionSnapshot(
        stage: RemoteSessionStage.profileSelection,
        profiles: options(session),
      ),
      PinRequired(:final session, :final profile) => RemoteSessionSnapshot(
        stage: RemoteSessionStage.pinRequired,
        profiles: options(session),
        pendingProfileId: profile.id,
      ),
      ProfileSelected(:final session, :final profile) => RemoteSessionSnapshot(
        stage: RemoteSessionStage.ready,
        profiles: options(session),
        activeProfileId: profile.id,
      ),
      // Managing profiles is a local, keyboard-heavy mode; a remote has
      // nothing useful to do there, so it reads as "busy elsewhere".
      ManagingProfiles(:final session) ||
      ManagementPinRequired(:final session) => RemoteSessionSnapshot(
        stage: RemoteSessionStage.profileSelection,
        profiles: options(session),
      ),
      Anonymous() ||
      OtpRequested() => const RemoteSessionSnapshot(
        stage: RemoteSessionStage.anonymous,
      ),
    };
  }

  /// Routes one command from a remote to whatever can honour it.
  Future<void> apply(RemoteCommand command) async {
    // Session and launch commands are the ones that work with *no* player
    // mounted — they are what gets one mounted. Everything below needs a
    // live player.
    try {
      if (await _applyWithoutPlayer(command)) return;
    } catch (e, st) {
      unawaited(
        ref.read(loggerProvider).error(
          'remote.host.command_failed',
          attrs: {'command': command.type},
          error: e,
          stack: st,
        ),
      );
      _reportError('command_failed', "L'appareil n'a pas pu exécuter l'action.");
      return;
    }

    final controls = _controls;
    if (controls == null) {
      _reportError(
        'no_player',
        "Aucune lecture en cours sur l'appareil.",
      );
      return;
    }
    try {
      switch (command) {
        case RemotePlayCommand():
          await controls.play();
        case RemotePauseCommand():
          await controls.pause();
        case RemoteTogglePlayCommand():
          await controls.togglePlay();
        case RemoteSeekCommand(:final position):
          await controls.seek(position);
        case RemoteSeekRelativeCommand(:final delta):
          await controls.seekRelative(delta);
        case RemoteSetAudioTrackCommand(:final trackId):
          await controls.setAudioTrack(trackId);
        case RemoteSetSubtitleTrackCommand(:final trackId):
          await controls.setSubtitleTrack(trackId);
        case RemoteSetVolumeCommand(:final volume):
          await controls.setVolume(volume);
        case RemoteStopCommand():
          await controls.stop();
        case RemoteRetryDownloadCommand():
          await controls.retryDownload();
        case RemoteNextEpisodeCommand():
          await controls.nextEpisode();
        case RemotePreviousEpisodeCommand():
          await controls.previousEpisode();
        case RemotePlayMediaCommand():
        case RemoteSelectProfileCommand():
        case RemoteSubmitProfilePinCommand():
        case RemoteCancelProfilePinCommand():
          break; // Handled above, before the player check.
      }
    } catch (e, st) {
      unawaited(
        ref.read(loggerProvider).warn(
          'remote.host.command_failed',
          attrs: {'command': command.type},
          error: e,
          stack: st,
        ),
      );
    }
  }

  /// Handles the commands that do not need a mounted player. Returns
  /// true when [command] was one of them.
  Future<bool> _applyWithoutPlayer(RemoteCommand command) async {
    switch (command) {
      case RemotePlayMediaCommand():
        await _launch(command);
      case RemoteSelectProfileCommand(:final profileId):
        await _selectProfile(profileId);
      case RemoteSubmitProfilePinCommand(:final pin):
        await _submitPin(pin);
      case RemoteCancelProfilePinCommand():
        // Same reasoning as [_selectProfile]: backing out is free, so
        // clearing the budget here would make the cooldown a formality.
        ref.read(sessionControllerProvider.notifier).cancelPinEntry();
      case _:
        return false;
    }
    return true;
  }

  Future<void> _selectProfile(String profileId) async {
    final controller = ref.read(sessionControllerProvider.notifier);
    // `selectProfile` only accepts Authenticated / ProfileSelected, so a
    // pick made while a code is pending would come back as "unknown
    // profile" — which is both false and confusing. Backing out of the
    // prompt first makes tapping another profile mean what it looks like.
    // It does not refund the attempt budget: that one is time-based.
    if (ref.read(sessionControllerProvider) is PinRequired) {
      controller.cancelPinEntry();
    }
    // Deliberately does NOT touch the failed-attempt budget. Selecting a
    // PIN-less profile proves nothing, and clearing the counter here let
    // a remote loop `select(open profile)` → `select(locked profile)` to
    // buy five fresh guesses each round — unlimited tries at a 4-digit
    // code. Only [_submitPin] succeeding clears it.
    final result = await controller.selectProfile(profileId);
    switch (result) {
      case SelectProfileReady():
        unawaited(_logger.info('remote.host.profile_selected'));
      case SelectProfilePinRequired():
        unawaited(_logger.info('remote.host.profile_pin_required'));
      case SelectProfileUnknown():
        _reportError('not_found', "Ce profil n'existe pas sur cet appareil.");
    }
  }

  Future<void> _submitPin(String pin) async {
    if (ref.read(sessionControllerProvider) is! PinRequired) {
      _reportError('no_pin_pending', 'Aucun code demandé sur cet appareil.');
      return;
    }

    // A 4-digit code is 10 000 combinations. On the device that is hours
    // of thumb work; over a socket it is seconds, so remote entry needs a
    // real cost that guessing cannot shed. An attempt *counter* alone
    // could not provide one — every way of clearing it (re-selecting,
    // cancelling, bouncing to the picker) was itself free. Time is the
    // one budget a remote cannot refund itself.
    final now = DateTime.now();
    final retryAfter = _pinRetryAfter;
    if (retryAfter != null && now.isBefore(retryAfter)) {
      final seconds = retryAfter.difference(now).inSeconds + 1;
      _reportError('too_many_attempts', 'Trop d’essais. Attends $seconds s.');
      return;
    }

    final result = await ref
        .read(sessionControllerProvider.notifier)
        .verifyPin(pin);
    if (result is VerifyProfilePinSuccess) {
      _failedPinAttempts = 0;
      _pinRetryAfter = null;
      unawaited(_logger.info('remote.host.profile_unlocked'));
      return;
    }

    _failedPinAttempts++;
    if (_failedPinAttempts % _maxRemotePinAttempts == 0) {
      _pinRetryAfter = DateTime.now().add(_cooldownFor(_failedPinAttempts));
    }
    // Never logs the PIN itself — only that one was refused.
    unawaited(
      _logger.warn(
        'remote.host.profile_pin_rejected',
        attrs: {'attempts': _failedPinAttempts},
      ),
    );
    _reportError('invalid_pin', 'Code incorrect.');
  }

  /// Lockout applied after each block of [_maxRemotePinAttempts] misses,
  /// doubling per block so a sustained run slows to a crawl, capped so a
  /// genuine fat-fingering parent is never locked out for the evening.
  Duration _cooldownFor(int attempts) {
    final blocks = attempts ~/ _maxRemotePinAttempts;
    final seconds = 30 * (1 << (blocks - 1).clamp(0, 5));
    return Duration(seconds: seconds.clamp(30, 900));
  }

  LoggerApplicationService get _logger => ref.read(loggerProvider);

  Future<void> _launch(RemotePlayMediaCommand command) async {
    final session = ref.read(sessionControllerProvider);
    if (session is! ProfileSelected) {
      // The router's redirect guard would bounce the navigation anyway;
      // saying why beats a silent no-op on the remote.
      _reportError(
        'no_profile',
        "Choisis d'abord un profil sur l'appareil.",
      );
      return;
    }
    if (!command.isEpisode && !await _movieExists(command.mediaId)) {
      _reportError(
        'not_found',
        "Ce film n'est pas disponible sur cet appareil.",
      );
      return;
    }

    final target = command.isEpisode
        ? _episodeRoute(command)
        : '/player/${command.mediaId}';
    unawaited(
      ref.read(loggerProvider).info(
        'remote.host.play_media',
        attrs: {'content.id': command.mediaId, 'is_episode': command.isEpisode},
      ),
    );
    ref.read(appRouterProvider).go(target);
  }

  String _episodeRoute(RemotePlayMediaCommand command) {
    final buffer = StringBuffer('/player/episode/${command.mediaId}');
    final seriesId = command.seriesId;
    if (seriesId != null && seriesId.isNotEmpty) {
      buffer.write('?series=$seriesId');
      if (command.shuffle) buffer.write('&mode=shuffle');
    }
    return buffer.toString();
  }

  /// Best-effort catalogue check so an unknown id produces a readable
  /// message on the remote instead of a player that opens onto an error.
  ///
  /// Not a security boundary: content permissions are enforced by the
  /// backend on download, which is what actually gates what this device
  /// can play.
  Future<bool> _movieExists(String movieId) async {
    try {
      final catalog = await ref.read(catalogRepositoryProvider).listCatalog();
      return catalog.any((item) => item.id == movieId);
    } catch (_) {
      // Offline or catalogue unavailable — let the player try.
      return true;
    }
  }

  void _reportError(String code, String message) {
    ref.read(remoteControlHostProvider).reportError(code, message);
  }
}

/// Owns the lifecycle of the local control server and wires it to
/// [RemotePlaybackHost].
///
/// State is "is remote control accepted on this device", persisted so the
/// setting survives a restart — a device parked next to the TV should not
/// need re-enabling every launch.
@Riverpod(keepAlive: true)
class RemoteHostController extends _$RemoteHostController {
  StreamSubscription<RemoteCommand>? _commandSub;
  StreamSubscription<RemoteQuery>? _querySub;

  @override
  bool build() {
    ref.onDispose(() {
      unawaited(_commandSub?.cancel());
      unawaited(_querySub?.cancel());
    });
    return false;
  }

  /// Restores the persisted preference at startup.
  Future<void> restore() async {
    if (!await loadRemoteHostEnabled()) return;
    await enable(persist: false);
  }

  Future<void> enable({bool persist = true}) async {
    final host = ref.read(remoteControlHostProvider);
    // Wire before starting so a remote connecting immediately after the
    // socket opens cannot land a command into a void.
    _commandSub ??= host.commands.listen(
      (command) => unawaited(
        ref.read(remotePlaybackHostProvider.notifier).apply(command),
      ),
    );
    _querySub ??= host.queries.listen(
      (query) => unawaited(
        ref.read(remoteHostQueryHandlerProvider).handle(query),
      ),
    );
    await host.start();
    // Seed the server with whatever is on screen right now — including
    // who is signed in — so a remote that connects to an already-running
    // device is correct on frame one.
    ref.read(remotePlaybackHostProvider.notifier).refresh();
    if (persist) await saveRemoteHostEnabled(true);
    state = true;
  }

  Future<void> disable() async {
    await ref.read(remoteControlHostProvider).stop();
    await _commandSub?.cancel();
    _commandSub = null;
    await _querySub?.cancel();
    _querySub = null;
    await saveRemoteHostEnabled(false);
    state = false;
  }

  Future<void> toggle(bool enabled) =>
      enabled ? enable() : disable();
}
