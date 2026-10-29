// A06 on a device: the VPN service builds the TUN interface, hands it to the core and takes
// everything down on stop. The server is a TEST-NET address that nothing answers, so the
// tunnel stays in Connecting and no traffic leaves. The VPN permission must be granted first:
// `adb shell appops set partizan.client ACTIVATE_VPN allow`.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:partizan/core/vpn_status.dart';
import 'package:partizan/platform/channel_vpn_bridge.dart';

const _unreachable =
    'partizan://00000000000000000000000000000000:'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA@192.0.2.1:443?path=/sync&transport=quic';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the service brings the core up and takes it down', (_) async {
    const bridge = ChannelVpnBridge();
    expect((await bridge.status()).state, VpnState.idle);
    final seen = <VpnState>[];
    final subscription = bridge.statusChanges().listen(
      (s) => seen.add(s.state),
    );

    await bridge.start(uri: _unreachable);
    await _until(() => seen.contains(VpnState.connecting));
    expect((await bridge.status()).state, VpnState.connecting);

    await bridge.stop();
    await _until(() => seen.last == VpnState.idle);
    expect((await bridge.status()).state, VpnState.idle);
    await subscription.cancel();
  });

  testWidgets('a malformed link fails in the core, not in the app', (_) async {
    const bridge = ChannelVpnBridge();
    final seen = <VpnStatus>[];
    final subscription = bridge.statusChanges().listen(seen.add);
    await bridge.start(uri: 'partizan://broken');
    await _until(() => seen.any((s) => s.state == VpnState.error));
    final error = seen.firstWhere((s) => s.state == VpnState.error).error;
    expect(error, isNotNull);
    expect((await bridge.status()).state, VpnState.idle);
    await subscription.cancel();
  });
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 200; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('condition not reached in 10 s');
}
