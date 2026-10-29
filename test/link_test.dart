import 'package:flutter_test/flutter_test.dart';
import 'package:partizan/core/link.dart';

void main() {
  const id = '00112233445566778899aabbccddeeff';
  const token = 'BgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgY';

  test('host, port and transport come out of the link', () {
    final full = LinkInfo.parse(
      'partizan://$id:$token@vpn.example.org:8443?path=/sync&transport=tls',
    )!;
    expect(
      (full.host, full.port, full.transport),
      ('vpn.example.org', 8443, 'tls'),
    );
    final defaults = LinkInfo.parse(
      'partizan://$id:$token@vpn.example.org?path=/sync',
    )!;
    expect((defaults.port, defaults.transport), (443, 'auto'));
    final v6 = LinkInfo.parse(
      'partizan://$id:$token@[2001:db8::1]:443?path=/x',
    )!;
    expect((v6.host, v6.address), ('2001:db8::1', '[2001:db8::1]:443'));
    expect(LinkInfo.parse('  partizan://$id:$token@h?path=/x\n')?.host, 'h');
  });

  test('anything else is refused', () {
    for (final bad in [
      '',
      'https://vpn.example.org',
      'partizan://vpn.example.org',
      'partizan://$id@host?path=/x',
      'partizan://$id:$token@?path=/x',
      'partizan://$id:$token@host:0?path=/x',
      'partizan://$id:$token@host:99999?path=/x',
      'partizan://$id:$token@[2001:db8::1?path=/x',
    ]) {
      expect(LinkInfo.parse(bad), isNull, reason: bad);
    }
  });
}
