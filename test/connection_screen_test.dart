import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partizan/core/vpn_status.dart';
import 'package:partizan/core/link.dart';

import 'fakes.dart';

String stateText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('vpn-state'))).data!;

void main() {
  testWidgets('A05-T3: state changes reach the model and redraw the screen', (
    tester,
  ) async {
    final bridge = FakeBridge(VpnStatus.idle);
    // A change crosses the stream, the provider and a rebuild: let it all settle.
    Future<void> emit(VpnStatus status) async {
      bridge.changes.add(status);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(app(bridge));
    await tester.pumpAndSettle();
    expect(stateText(tester), 'ПОДКЛЮЧИТЬСЯ');
    expect(find.byKey(const Key('vpn-transport')), findsNothing);

    await emit(const VpnStatus(state: VpnState.connecting));
    expect(stateText(tester), 'ПОДКЛЮЧЕНИЕ');

    await emit(const VpnStatus(state: VpnState.connected, transport: 'quic'));
    expect(stateText(tester), 'ПОДКЛЮЧЕНО');
    expect(find.text('QUIC'), findsOneWidget);

    await emit(const VpnStatus(state: VpnState.reconnecting));
    expect(stateText(tester), 'ПЕРЕПОДКЛЮЧЕНИЕ');
    expect(find.text('QUIC'), findsNothing);

    await emit(const VpnStatus(state: VpnState.revoked));
    expect(stateText(tester), 'ДОСТУП ОТОЗВАН');
  });

  testWidgets('the toggle starts the active profile and stops the tunnel', (
    tester,
  ) async {
    final bridge = FakeBridge();
    final store = MemoryProfileStore();
    await store.add(
      name: 'Дом',
      info: LinkInfo.parse(testLink)!,
      link: testLink,
    );
    await tester.pumpWidget(app(bridge, store));
    await tester.pumpAndSettle();
    expect(find.text('Дом'), findsOneWidget);
    expect(find.text('vpn.example.org:8443'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vpn-toggle')));
    await tester.pumpAndSettle();
    expect(bridge.calls, ['start $testLink 1400']);

    bridge.changes.add(
      const VpnStatus(state: VpnState.connected, transport: 'quic'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vpn-toggle')));
    await tester.pumpAndSettle();
    expect(bridge.calls.last, 'stop');
  });

  testWidgets('without a server the toggle opens the list', (tester) async {
    final bridge = FakeBridge();
    await tester.pumpWidget(app(bridge));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vpn-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('СЕРВЕРЫ'), findsOneWidget);
    expect(bridge.calls, isEmpty);
  });

  testWidgets('a failing core is shown, not swallowed', (tester) async {
    final bridge = _FailingBridge();
    await tester.pumpWidget(app(bridge));
    await tester.pump();
    expect(find.byKey(const Key('core-error')), findsOneWidget);
  });

  testWidgets('stub screens are reachable', (tester) async {
    await tester.pumpWidget(app(FakeBridge()));
    await tester.pump();

    await tester.tap(find.text('Сервер не выбран'));
    await tester.pumpAndSettle();
    expect(find.text('СЕРВЕРЫ'), findsOneWidget);
    await tester.tap(find.byTooltip('Добавить сервер'));
    await tester.pumpAndSettle();
    expect(find.text('ДОБАВИТЬ СЕРВЕР'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Раздельное туннелирование'));
    await tester.pumpAndSettle();
    expect(find.text('РАЗДЕЛЬНОЕ ТУННЕЛИРОВАНИЕ'), findsOneWidget);
  });
}

class _FailingBridge extends FakeBridge {
  @override
  Future<VpnStatus> status() => Future.error(StateError('no core'));
}
