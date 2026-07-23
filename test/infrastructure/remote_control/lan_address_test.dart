import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/remote_control/lan_address.dart';

void main() {
  group('isPrivateAddress accepts LAN ranges', () {
    const private = [
      '10.0.0.1',
      '10.255.255.254',
      '172.16.0.1',
      '172.31.255.254',
      '192.168.1.42',
      '169.254.1.1', // link-local
      '127.0.0.1', // loopback
      '100.64.0.1', // CGNAT — Tailscale and friends
    ];

    for (final address in private) {
      test(address, () {
        expect(isPrivateAddress(InternetAddress(address)), isTrue);
      });
    }
  });

  group('isPrivateAddress refuses routable addresses', () {
    // The server binds every interface, so this is what stops it being a
    // public server when the device sits on a network handing out
    // routable addresses.
    const public = [
      '8.8.8.8',
      '1.1.1.1',
      '172.15.0.1', // just below the private block
      '172.32.0.1', // just above it
      '192.169.0.1', // adjacent to 192.168/16 but public
      '100.128.0.1', // just above the CGNAT block
      '93.184.216.34',
    ];

    for (final address in public) {
      test(address, () {
        expect(isPrivateAddress(InternetAddress(address)), isFalse);
      });
    }
  });

  group('IPv6', () {
    test('unique-local fc00::/7 is private', () {
      expect(isPrivateAddress(InternetAddress('fd12:3456::1')), isTrue);
    });

    test('link-local fe80::/10 is private', () {
      expect(isPrivateAddress(InternetAddress('fe80::1')), isTrue);
    });

    test('loopback ::1 is private', () {
      expect(isPrivateAddress(InternetAddress('::1')), isTrue);
    });

    test('a global unicast address is not private', () {
      expect(isPrivateAddress(InternetAddress('2001:4860:4860::8888')), isFalse);
    });

    test('an IPv4-mapped private address is judged on its IPv4 part', () {
      // Dual-stack sockets report IPv4 peers this way; missing the
      // mapping would refuse every LAN client on such a socket.
      expect(isPrivateAddress(InternetAddress('::ffff:192.168.1.5')), isTrue);
    });

    test('an IPv4-mapped public address is refused', () {
      expect(isPrivateAddress(InternetAddress('::ffff:8.8.8.8')), isFalse);
    });
  });

  test('a null address is refused', () {
    expect(isPrivateAddress(null), isFalse);
  });
}
