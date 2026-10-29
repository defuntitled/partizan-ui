import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partizan/core/link.dart';
import 'package:partizan/core/vpn_bridge.dart';

import 'fakes.dart';

Future<void> openAdd(WidgetTester tester) async {
  await tester.tap(find.text('Сервер не выбран'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Добавить сервер'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('A07-T1: a valid link becomes a profile named after its host', (
    tester,
  ) async {
    final bridge = FakeBridge();
    final store = MemoryProfileStore();
    await tester.pumpWidget(app(bridge, store));
    await tester.pumpAndSettle();
    await openAdd(tester);

    await tester.enterText(find.byKey(const Key('link-field')), testLink);
    await tester.pump();
    expect(find.text('Сервер vpn.example.org:8443'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(bridge.calls, ['check'], reason: 'the core checks before saving');
    expect(store.profiles.single.name, 'vpn.example.org');
    expect(store.links.values.single, testLink);
    expect(
      store.active,
      store.profiles.single.id,
      reason: 'the first is active',
    );
    // Back on the list, which shows the new profile.
    expect(find.text('СЕРВЕРЫ'), findsOneWidget);
    expect(find.text('vpn.example.org'), findsOneWidget);
  });

  testWidgets('a name given at import is kept', (tester) async {
    final store = MemoryProfileStore();
    await tester.pumpWidget(app(FakeBridge(), store));
    await tester.pumpAndSettle();
    await openAdd(tester);
    await tester.enterText(find.byKey(const Key('link-field')), testLink);
    await tester.enterText(find.byKey(const Key('name-field')), 'Работа');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(store.profiles.single.name, 'Работа');
  });

  testWidgets('A07-T3: a broken link is explained and creates nothing', (
    tester,
  ) async {
    final bridge = FakeBridge();
    final store = MemoryProfileStore();
    await tester.pumpWidget(app(bridge, store));
    await tester.pumpAndSettle();
    await openAdd(tester);

    // Not even the shape of a link: the app says so and does not ask the core.
    await tester.enterText(find.byKey(const Key('link-field')), 'https://x');
    await tester.pump();
    expect(find.text('Это не ссылка partizan://'), findsOneWidget);
    final save = find.byKey(const Key('save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    // The right shape, but the core finds it broken.
    bridge.checkFails = const LinkCheckException(
      LinkProblem.invalid,
      'bad pin',
    );
    await tester.enterText(find.byKey(const Key('link-field')), testLink);
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Ссылка некорректна: bad pin'), findsOneWidget);
    expect(find.byKey(const Key('save-unchecked')), findsNothing);
    expect(store.profiles, isEmpty);
  });

  testWidgets('an unreachable server can still be saved on purpose', (
    tester,
  ) async {
    final bridge = FakeBridge()
      ..checkFails = const LinkCheckException(
        LinkProblem.unreachable,
        'timeout',
      );
    final store = MemoryProfileStore();
    await tester.pumpWidget(app(bridge, store));
    await tester.pumpAndSettle();
    await openAdd(tester);
    await tester.enterText(find.byKey(const Key('link-field')), testLink);
    await tester.pump();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('Сервер не отвечает: timeout'), findsOneWidget);
    expect(store.profiles, isEmpty);
    await tester.tap(find.byKey(const Key('save-unchecked')));
    await tester.pumpAndSettle();
    expect(store.profiles, hasLength(1));
  });

  testWidgets('profiles are chosen, renamed and deleted from the list', (
    tester,
  ) async {
    final store = MemoryProfileStore();
    final info = LinkInfo.parse(testLink)!;
    await store.add(name: 'Первый', info: info, link: testLink);
    final second = await store.add(name: 'Второй', info: info, link: testLink);
    await tester.pumpWidget(app(FakeBridge(), store));
    await tester.pumpAndSettle();
    expect(find.text('Первый'), findsOneWidget, reason: 'the first is active');

    await tester.tap(find.text('Первый'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Второй'));
    await tester.pumpAndSettle();
    expect(store.active, second.id);
    expect(
      find.text('Второй'),
      findsOneWidget,
      reason: 'back on the main screen',
    );

    await tester.tap(find.text('Второй'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Действия').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переименовать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rename-field')), 'Офис');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(store.profiles.last.name, 'Офис');

    await tester.tap(find.byTooltip('Действия').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(store.profiles.map((p) => p.name), ['Офис']);
    expect(find.text('Первый'), findsNothing);
  });
}
