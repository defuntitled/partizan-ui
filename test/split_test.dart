import 'package:flutter_test/flutter_test.dart';
import 'package:partizan/core/split.dart';

List<String> names(Iterable<IpNet> nets) => nets.map((n) => '$n').toList();

void main() {
  test('A09-T6: two networks, IPv6 and a single address are read', () {
    expect(names(parseRoutes('99.84.0.0/16, 99.86.0.0/16').routes), [
      '99.84.0.0/16',
      '99.86.0.0/16',
    ]);
    final mixed = parseRoutes(
      '99.84.0.0/16, 99.86.0.0/16, 203.0.113.7, 2606:4700::/32',
    );
    expect(names(mixed.routes), [
      '99.84.0.0/16',
      '99.86.0.0/16',
      '203.0.113.7/32',
      '2606:4700::/32',
    ]);
    expect(mixed.rejected, isEmpty);
    expect(IpNet.tryParse('2001:db8::1')?.prefix, 128);
  });

  test('networks are normalized', () {
    expect('${IpNet.tryParse('99.84.1.2/16')}', '99.84.0.0/16');
    expect('${IpNet.tryParse('10.1.2.3/0')}', '0.0.0.0/0');
    expect('${IpNet.tryParse('2606:4700:1:2::5/32')}', '2606:4700::/32');
    expect(IpNet.tryParse('10.0.0.1/8'), IpNet.tryParse('10.255.0.0/8'));
  });

  test('A09-T7: junk does not fail the import and comes back as rejected', () {
    final result = parseRoutes(
      ' 10.0.0.0/8 ,, garbage, 1.2.3.4/33, \n 192.168.1.1\n,2001:db8::/129, 1.2.3, '
      'fe80::/10, 300.1.1.1, 8.8.8.8/+8, 1.1.1.1 2.2.2.2',
    );
    expect(names(result.routes), ['10.0.0.0/8', '192.168.1.1/32', 'fe80::/10']);
    expect(result.rejected, [
      'garbage',
      '1.2.3.4/33',
      '2001:db8::/129',
      '1.2.3',
      '300.1.1.1',
      '8.8.8.8/+8',
      '1.1.1.1 2.2.2.2',
    ]);
  });

  test('duplicates are dropped, in the file and when merging', () {
    final parsed = parseRoutes('10.0.0.0/8, 10.1.0.0/8, 10.0.0.0/8');
    expect(names(parsed.routes), ['10.0.0.0/8']);
    final merged = mergeRoutes(
      parseRoutes('10.0.0.0/8, 1.1.1.1').routes,
      parseRoutes('1.1.1.1, 2606:4700::/32').routes,
    );
    expect(names(merged), ['10.0.0.0/8', '1.1.1.1/32', '2606:4700::/32']);
  });

  test('A09-T8: export and import again give the same list', () {
    final routes = parseRoutes(
      '99.84.0.0/16, 203.0.113.7, 2606:4700::/32, ::/0, 0.0.0.0/0',
    ).routes;
    final again = parseRoutes(formatRoutes(routes));
    expect(again.routes, routes);
    expect(again.rejected, isEmpty);
    expect(
      formatRoutes(routes),
      '99.84.0.0/16, 203.0.113.7/32, 2606:4700::/32, ::/0, 0.0.0.0/0',
    );
  });
}
