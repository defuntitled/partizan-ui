import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partizan/core/vpn_status.dart';
import 'package:partizan/platform/channel_vpn_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(ChannelVpnBridge.methods, null);
    messenger.setMockStreamHandler(ChannelVpnBridge.events, null);
  });

  test('status is asked for over the method channel', () async {
    messenger.setMockMethodCallHandler(ChannelVpnBridge.methods, (call) async {
      expect(call.method, 'status');
      return {'state': 'connecting', 'txBytes': 3};
    });
    expect(
      await const ChannelVpnBridge().status(),
      const VpnStatus(state: VpnState.connecting, txBytes: 3),
    );
  });

  test('start and stop are passed on with their arguments', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(ChannelVpnBridge.methods, (call) async {
      calls.add(call);
      return null;
    });
    const bridge = ChannelVpnBridge();
    await bridge.start(uri: 'partizan://x', mtu: 1280);
    await bridge.stop();
    expect(calls.map((c) => c.method), ['start', 'stop']);
    expect(calls.first.arguments, {'uri': 'partizan://x', 'mtu': 1280});
  });

  test('changes arrive over the event channel', () async {
    messenger.setMockStreamHandler(
      ChannelVpnBridge.events,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          sink.success({'state': 'connecting'});
          sink.success({'state': 'connected', 'transport': 'tls'});
          sink.endOfStream();
        },
      ),
    );
    expect(await const ChannelVpnBridge().statusChanges().toList(), const [
      VpnStatus(state: VpnState.connecting),
      VpnStatus(state: VpnState.connected, transport: 'tls'),
    ]);
  });
}
