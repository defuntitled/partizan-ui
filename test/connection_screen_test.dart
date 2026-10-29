import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partizan/app.dart';
import 'package:partizan/core/vpn_bridge.dart';
import 'package:partizan/core/vpn_status.dart';
import 'package:partizan/state/vpn.dart';

class FakeBridge implements VpnBridge {
  FakeBridge(this.initial);

  final VpnStatus initial;
  final changes = StreamController<VpnStatus>();
  final calls = <String>[];

  @override
  Future<VpnStatus> status() async => initial;

  @override
  Stream<VpnStatus> statusChanges() => changes.stream;

  @override
  Future<void> start({required String uri, int mtu = 1400}) async =>
      calls.add('start $uri $mtu');

  @override
  Future<void> stop() async => calls.add('stop');
}

Widget app(VpnBridge bridge) => ProviderScope(
  overrides: [vpnBridgeProvider.overrideWithValue(bridge)],
  child: const PartizanApp(),
);

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

  testWidgets('the toggle asks for a link once, starts and stops the tunnel', (
    tester,
  ) async {
    const link = 'partizan://id:token@vpn.example.org:443?path=/sync';
    final bridge = FakeBridge(VpnStatus.idle);
    await tester.pumpWidget(app(bridge));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vpn-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('link-field')), 'https://nope');
    await tester.pump();
    final connect = find.widgetWithText(FilledButton, 'Подключиться');
    expect(tester.widget<FilledButton>(connect).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('link-field')), link);
    await tester.pump();
    await tester.tap(connect);
    await tester.pumpAndSettle();
    expect(bridge.calls, ['start $link 1400']);
    // The card names the host, never the token.
    expect(find.text('vpn.example.org:443'), findsOneWidget);
    expect(find.textContaining('token'), findsNothing);

    bridge.changes.add(
      const VpnStatus(state: VpnState.connected, transport: 'quic'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vpn-toggle')));
    await tester.pumpAndSettle();
    expect(bridge.calls.last, 'stop');

    // The link is remembered for the session: no second dialog.
    bridge.changes.add(VpnStatus.idle);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vpn-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('link-field')), findsNothing);
    expect(bridge.calls.last, 'start $link 1400');
  });

  testWidgets('a failing core is shown, not swallowed', (tester) async {
    final bridge = _FailingBridge();
    await tester.pumpWidget(app(bridge));
    await tester.pump();
    expect(find.byKey(const Key('core-error')), findsOneWidget);
  });

  testWidgets('stub screens are reachable', (tester) async {
    await tester.pumpWidget(app(FakeBridge(VpnStatus.idle)));
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

class _FailingBridge implements VpnBridge {
  @override
  Future<VpnStatus> status() => Future.error(StateError('no core'));

  @override
  Stream<VpnStatus> statusChanges() => const Stream.empty();

  @override
  Future<void> start({required String uri, int mtu = 1400}) async {}

  @override
  Future<void> stop() async {}
}
