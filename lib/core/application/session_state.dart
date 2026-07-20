import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';

/// Machine d'états de la session. Pilote la navigation via go_router.
///
/// Transitions autorisées :
/// - Anonymous             → OtpRequested           (requestOtp)
/// - OtpRequested          → Authenticated          (verifyOtp success)
/// - OtpRequested          → OtpRequested           (resendOtp)
/// - any (avec session)    → OtpRequested           (handleExpiredToken, 401 invalid_token)
/// - any (avec session)    → Anonymous              (handleExpiredToken sans numéro connu / SMS KO)
/// - Authenticated         → PinRequired            (selectProfile avec PIN)
/// - Authenticated         → ProfileSelected        (selectProfile sans PIN)
/// - Authenticated         → ManagementPinRequired  (enterManagementMode)
/// - PinRequired           → ProfileSelected        (verifyPin success)
/// - PinRequired           → Authenticated          (cancelPinEntry)
/// - ProfileSelected       → Authenticated          (deselectProfile)
/// - ProfileSelected       → ManagementPinRequired  (enterManagementMode, retour mémorisé)
/// - ManagementPinRequired → ManagingProfiles       (verifyManagementPin OK)
/// - ManagementPinRequired → Authenticated          (cancelManagementPinEntry, retour par défaut)
/// - ManagementPinRequired → ProfileSelected        (cancelManagementPinEntry, retour vers profil d'origine)
/// - ManagingProfiles      → Authenticated          (exitManagementMode, retour par défaut)
/// - ManagingProfiles      → ProfileSelected        (exitManagementMode, retour vers profil d'origine)
/// - any                   → Anonymous              (logout)
sealed class SessionState {
  const SessionState();
}

/// Aucun token en storage : l'utilisateur doit saisir son numéro.
class Anonymous extends SessionState {
  const Anonymous();
}

/// Un OTP a été demandé pour [phone]. Volatile : non persisté.
class OtpRequested extends SessionState {
  final PhoneNumber phone;
  final DateTime expiresAt;

  /// `true` quand l'OTP a été déclenché automatiquement par l'expiration du
  /// JWT (`401 invalid_token`) et non par une saisie volontaire du numéro.
  /// L'écran OTP s'en sert pour expliquer la déconnexion et masquer le
  /// retour arrière (il n'y a pas d'écran de saisie à retrouver derrière).
  final bool sessionExpired;

  const OtpRequested({
    required this.phone,
    required this.expiresAt,
    this.sessionExpired = false,
  });
}

/// Session authentifiée, aucun profil actif.
class Authenticated extends SessionState {
  final Session session;

  const Authenticated(this.session);
}

/// Un profil a été tappé, son PIN doit être vérifié.
class PinRequired extends SessionState {
  final Profile profile;
  final Session session;

  const PinRequired({required this.profile, required this.session});
}

/// Profil actif, flow complet. État volatile : non persisté.
class ProfileSelected extends SessionState {
  final Profile profile;
  final Session session;

  const ProfileSelected({required this.profile, required this.session});
}

/// Le code du profil principal doit être saisi pour entrer en mode gestion.
/// État volatile : non persisté.
class ManagementPinRequired extends SessionState {
  final Session session;

  const ManagementPinRequired(this.session);
}

/// Mode gestion actif : l'utilisateur peut ajouter / modifier / supprimer
/// des profils jusqu'à sortie manuelle. État volatile : non persisté.
class ManagingProfiles extends SessionState {
  final Session session;

  const ManagingProfiles(this.session);
}
