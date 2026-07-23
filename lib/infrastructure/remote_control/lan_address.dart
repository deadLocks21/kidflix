import 'dart:io';

/// True when [address] belongs to a range that only exists inside a local
/// network.
///
/// The control server binds to every interface, so this is the guard that
/// keeps it a *LAN* server: a request arriving from a routable address
/// means the device is exposed (port-forwarded, or on a network handing
/// out public addresses) and is refused rather than trusted.
bool isPrivateAddress(InternetAddress? address) {
  if (address == null) return false;
  if (address.isLoopback) return true;
  return switch (address.type) {
    InternetAddressType.IPv4 => _isPrivateIPv4(address.rawAddress),
    InternetAddressType.IPv6 => _isPrivateIPv6(address.rawAddress),
    _ => false,
  };
}

bool _isPrivateIPv4(List<int> b) {
  if (b.length != 4) return false;
  return switch (b[0]) {
    10 => true, // 10.0.0.0/8
    127 => true, // loopback
    172 => b[1] >= 16 && b[1] <= 31, // 172.16.0.0/12
    192 => b[1] == 168, // 192.168.0.0/16
    169 => b[1] == 254, // link-local (169.254.0.0/16)
    100 => b[1] >= 64 && b[1] <= 127, // CGNAT (100.64.0.0/10) — Tailscale
    _ => false,
  };
}

bool _isPrivateIPv6(List<int> b) {
  if (b.length != 16) return false;
  // Unique local fc00::/7 and link-local fe80::/10.
  if ((b[0] & 0xFE) == 0xFC) return true;
  if (b[0] == 0xFE && (b[1] & 0xC0) == 0x80) return true;
  // IPv4-mapped ::ffff:a.b.c.d — judge the embedded IPv4.
  final isV4Mapped =
      b.take(10).every((byte) => byte == 0) && b[10] == 0xFF && b[11] == 0xFF;
  if (isV4Mapped) return _isPrivateIPv4(b.sublist(12));
  return false;
}

/// IPv4 addresses this device is reachable at on the local network.
///
/// Shown in the UI as the manual-pairing fallback for networks where
/// mDNS does not survive (client isolation on guest Wi-Fi, some mesh
/// routers). Loopback is excluded — typing `127.0.0.1` on the other
/// device would reach that device, not this one.
Future<List<String>> localNetworkAddresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    return [
      for (final interface in interfaces)
        for (final address in interface.addresses)
          if (!address.isLoopback) address.address,
    ];
  } on SocketException {
    // Enumerating interfaces is blocked on some sandboxed desktop
    // configurations. The server still works; only the hint is missing.
    return const [];
  }
}
