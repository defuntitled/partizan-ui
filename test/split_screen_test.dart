import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partizan/core/link.dart';
import 'package:partizan/core/split.dart';

import 'fakes.dart';

Future<void> openRules(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Настройки'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Раздельное туннелирование'));
  await tester.pumpAndSettle();
}

List<String> routes(SplitRules? rules) =>
    rules?.routes.map((r) => '$r').toList() ?? [];

void main() {
  testWidgets('mode, entries and deletion are saved as shared rules', (
    tester,
  ) async {
    final store = MemoryProfileStore();
    await tester.pumpWidget(app(FakeBridge(), store));
    await tester.pumpAndSettle();
    await openRules(tester);
    expect(
      find.byKey(const Key('rules-scope')),
      findsNothing,
      reason: 'no server',
    );
    expect(
      find.text('Список пуст: через VPN идёт весь трафик.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Только список'));
    await tester.pumpAndSettle();
    expect(store.rules[null]?.mode, SplitMode.include);

    await tester.enterText(
      find.byKey(const Key('route-field')),
      '99.84.1.1/16, nonsense, 2606:4700::/32',
    );
    await tester.tap(find.byTooltip('Добавить'));
    await tester.pumpAndSettle();
    expect(routes(store.rules[null]), ['99.84.0.0/16', '2606:4700::/32']);
    expect(find.text('Не распознано: nonsense'), findsOneWidget);
    // The rejected entry stays in the field to be fixed.
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('route-field')))
          .controller!
          .text,
      'nonsense',
    );

    await tester.tap(find.byTooltip('Удалить 99.84.0.0/16'));
    await tester.pumpAndSettle();
    expect(routes(store.rules[null]), ['2606:4700::/32']);
  });

  testWidgets('import adds or replaces and reports rejected lines', (
    tester,
  ) async {
    final store = MemoryProfileStore();
    await store.saveRules(
      null,
      SplitRules(
        mode: SplitMode.include,
        routes: parseRoutes('10.0.0.0/8').routes,
      ),
    );
    final files = FakeRouteFiles()
      ..toOpen = '99.84.0.0/16, 99.86.0.0/16,\nbroken entry, 10.0.0.0/8';
    await tester.pumpWidget(app(FakeBridge(), store, files));
    await tester.pumpAndSettle();
    await openRules(tester);

    await tester.tap(find.byTooltip('Импорт из файла'));
    await tester.pumpAndSettle();
    expect(find.text('Распознано записей: 3'), findsOneWidget);
    expect(find.text('broken entry'), findsOneWidget);
    await tester.tap(find.text('Добавить').last);
    await tester.pumpAndSettle();
    expect(routes(store.rules[null]), [
      '10.0.0.0/8',
      '99.84.0.0/16',
      '99.86.0.0/16',
    ]);

    files.toOpen = '203.0.113.7';
    await tester.tap(find.byTooltip('Импорт из файла'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Заменить'));
    await tester.pumpAndSettle();
    expect(routes(store.rules[null]), ['203.0.113.7/32']);
    expect(
      store.rules[null]?.mode,
      SplitMode.include,
      reason: 'the mode stays',
    );
  });

  testWidgets('export writes the list in the import format', (tester) async {
    final store = MemoryProfileStore();
    await store.saveRules(
      null,
      SplitRules(
        mode: SplitMode.exclude,
        routes: parseRoutes('192.168.0.0/16, 2606:4700::/32').routes,
      ),
    );
    final files = FakeRouteFiles();
    await tester.pumpWidget(app(FakeBridge(), store, files));
    await tester.pumpAndSettle();
    await openRules(tester);
    await tester.tap(find.byTooltip('Экспорт в файл'));
    await tester.pumpAndSettle();
    final text = files.saved['partizan-routes.txt']!;
    expect(text.trim(), '192.168.0.0/16, 2606:4700::/32');
    expect(parseRoutes(text).routes, store.rules[null]!.routes);
  });

  testWidgets('A09-T4: a server switches to its own rules and back', (
    tester,
  ) async {
    final store = MemoryProfileStore();
    final shared = SplitRules(
      mode: SplitMode.include,
      routes: parseRoutes('10.0.0.0/8').routes,
    );
    await store.saveRules(null, shared);
    final p = await store.add(
      name: 'Дом',
      info: LinkInfo.parse(testLink)!,
      link: testLink,
    );
    await tester.pumpWidget(app(FakeBridge(), store));
    await tester.pumpAndSettle();
    await openRules(tester);

    await tester.tap(find.text('Для «Дом»'));
    await tester.pumpAndSettle();
    expect(store.profiles.single.ownRules, isTrue);
    await tester.enterText(find.byKey(const Key('route-field')), '203.0.113.7');
    await tester.tap(find.byTooltip('Добавить'));
    await tester.pumpAndSettle();
    expect(routes(store.rules[p.id]), ['10.0.0.0/8', '203.0.113.7/32']);
    expect(store.rules[null], shared, reason: 'shared rules untouched');
    expect(await store.rulesFor(store.profiles.single), store.rules[p.id]);

    await tester.tap(find.text('Общие'));
    await tester.pumpAndSettle();
    expect(store.profiles.single.ownRules, isFalse);
    expect(await store.rulesFor(store.profiles.single), shared);
    expect(find.text('10.0.0.0/8'), findsOneWidget);
    expect(find.text('203.0.113.7/32'), findsNothing);
  });
}
