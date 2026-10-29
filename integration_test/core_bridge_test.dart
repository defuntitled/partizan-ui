// A05-T2: on a device, Dart gets `VpnStatus` from the Rust core through the platform channel
// and the UniFFI bindings. `flutter test integration_test -d <device>`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:partizan/app.dart';
import 'package:partizan/core/vpn_status.dart';
import 'package:partizan/platform/channel_vpn_bridge.dart';
import 'package:partizan/state/vpn.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the core answers status through the bridge', (tester) async {
    const bridge = ChannelVpnBridge();
    expect(await bridge.status(), VpnStatus.idle);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vpnBridgeProvider.overrideWithValue(bridge)],
        child: const PartizanApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vpn-state')), findsOneWidget);
    expect(find.text('ПОДКЛЮЧИТЬСЯ'), findsOneWidget);
  });
}
