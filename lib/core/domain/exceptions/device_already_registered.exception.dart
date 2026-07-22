/// Thrown when the device identifier presented at login is already
/// attached to another user account.
///
/// Un appareil ne peut appartenir qu'à un seul compte : la situation est
/// stable, réessayer ne la débloquera pas.
///
/// Ne porte pas de payload : le backend ne dit pas quel compte détient
/// l'appareil, et cette information désignerait le numéro d'un tiers.
class DeviceAlreadyRegisteredException implements Exception {
  const DeviceAlreadyRegisteredException();

  @override
  String toString() => 'DeviceAlreadyRegisteredException';
}
