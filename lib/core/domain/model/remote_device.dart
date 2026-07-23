/// A Kidflix instance advertising itself as remote-controllable on the
/// local network.
///
/// Produced by the discovery service from an mDNS resolution. [id] is the
/// stable installation id of the advertising device (carried in the TXT
/// record), so a device that changes IP — or whose mDNS service name got
/// suffixed on a name conflict — is still recognised as the same target
/// and keeps its stored pairing token.
class RemoteDevice {
  /// Stable installation id of the advertising device.
  final String id;

  /// Human-readable name shown in the device picker ("iPad du salon").
  final String name;

  /// Address currently used to reach the device.
  final String host;

  /// Every address mDNS advertised, in the order it gave them.
  ///
  /// A machine running a VPN or a container runtime advertises several,
  /// and the first is regularly a virtual interface no other device can
  /// route to — an OrbStack bridge, say. Keeping the full list lets the
  /// client probe them and settle on one that actually answers instead
  /// of failing on a plausible-looking address.
  final List<String> hostCandidates;

  final int port;

  /// `android` / `ios` / `macos` / `linux` / `windows`. Drives the icon
  /// in the picker only — never behaviour.
  final String platform;

  /// Wire protocol version advertised by the host. A device advertising a
  /// version this build does not speak is listed but not connectable.
  final int protocolVersion;

  const RemoteDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.platform,
    required this.protocolVersion,
    this.hostCandidates = const [],
  });

  /// [host] first, then any other advertised address, without repeats.
  List<String> get allHosts => [
    host,
    for (final candidate in hostCandidates)
      if (candidate != host) candidate,
  ];

  RemoteDevice copyWith({String? host, int? port, String? name}) =>
      RemoteDevice(
        id: id,
        name: name ?? this.name,
        host: host ?? this.host,
        port: port ?? this.port,
        platform: platform,
        protocolVersion: protocolVersion,
        hostCandidates: hostCandidates,
      );

  /// Base URL of the host's HTTP surface (pairing + WebSocket upgrade).
  /// IPv6 literals are bracketed so they survive `Uri.parse`.
  String get baseUrl => baseUrlFor(host);

  String baseUrlFor(String candidate) {
    final literal = candidate.contains(':') ? '[$candidate]' : candidate;
    return 'http://$literal:$port';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteDevice &&
          other.id == id &&
          other.host == host &&
          other.port == port);

  @override
  int get hashCode => Object.hash(id, host, port);

  @override
  String toString() => 'RemoteDevice(id: $id, name: $name, at: $host:$port)';
}
