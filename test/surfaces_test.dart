import 'package:flutter_test/flutter_test.dart';
import 'package:partizan/core/link.dart';
import 'package:partizan/core/split.dart';
import 'package:partizan/core/vpn_bridge.dart';
import 'package:partizan/platform/vault_store.dart';

import 'fakes.dart';
import 'profile_store_test.dart' show MemorySecrets;

void main() {
  test('links move to the vault once; one already there is kept', () async {
    final old = MemorySecrets()
      ..values['profile.1.link'] = 'partizan://a'
      ..values['profile.2.link'] = 'partizan://old';
    final vault = MemorySecrets()..values['profile.2.link'] = 'partizan://new';
    final moved = await migrateLinks(
      from: old,
      to: vault,
      keys: ['profile.1.link', 'profile.2.link', 'profile.3.link'],
    );
    expect(moved, 1);
    expect(vault.values, {
      'profile.1.link': 'partizan://a',
      'profile.2.link': 'partizan://new',
    });
    expect(old.values, isEmpty, reason: 'nothing left behind');
    expect(
      await migrateLinks(from: old, to: vault, keys: ['profile.1.link']),
      0,
    );
  });

  testWidgets('the platform hears of every active profile and rules change', (
    tester,
  ) async {
    final bridge = FakeBridge();
    final store = MemoryProfileStore();
    await tester.pumpWidget(app(bridge, store));
    await tester.pumpAndSettle();
    expect(bridge.launches.last.$1, isNull, reason: 'no profile yet');

    final info = LinkInfo.parse(testLink)!;
    final a = await store.add(name: 'Дом', info: info, link: testLink);
    await tester.pumpAndSettle();
    expect(bridge.launches.last, ('Дом', SplitRules.all));

    final rules = SplitRules(
      mode: SplitMode.include,
      routes: parseRoutes('99.84.0.0/16').routes,
    );
    await store.saveRules(null, rules);
    await tester.pumpAndSettle();
    expect(bridge.launches.last, ('Дом', rules));

    await store.setOwnRules(a.id, true);
    await store.saveRules(a.id, SplitRules.all);
    await tester.pumpAndSettle();
    expect(bridge.launches.last, (
      'Дом',
      SplitRules.all,
    ), reason: 'own rules now');

    await store.delete(a.id);
    await tester.pumpAndSettle();
    expect(bridge.launches.last.$1, isNull);
  });

  testWidgets(
    'A10-T4: no profile — the tile sends the user to the server list',
    (tester) async {
      final bridge = FakeBridge();
      await tester.pumpWidget(app(bridge));
      await tester.pumpAndSettle();
      bridge.appTargets.add(AppTarget.servers);
      await tester.pumpAndSettle();
      expect(find.text('СЕРВЕРЫ'), findsOneWidget);
    },
  );

  testWidgets(
    'A10-T5: no VPN permission — the app connects and so asks for it',
    (tester) async {
      final bridge = FakeBridge();
      final store = MemoryProfileStore();
      await store.add(
        name: 'Дом',
        info: LinkInfo.parse(testLink)!,
        link: testLink,
      );
      await tester.pumpWidget(app(bridge, store));
      await tester.pumpAndSettle();
      bridge.appTargets.add(AppTarget.connect);
      await tester.pumpAndSettle();
      expect(bridge.calls, ['start $testLink 1400']);
    },
  );
}
