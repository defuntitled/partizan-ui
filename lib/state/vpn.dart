import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/vpn_bridge.dart';
import '../core/vpn_status.dart';

/// The platform's bridge; set in `main` with an override, faked in tests.
final vpnBridgeProvider = Provider<VpnBridge>(
  (ref) => throw UnimplementedError('override vpnBridgeProvider'),
);

/// Status of the tunnel: the current one first, then every change.
final vpnStatusProvider = StreamProvider<VpnStatus>((ref) async* {
  final bridge = ref.watch(vpnBridgeProvider);
  yield await bridge.status();
  yield* bridge.statusChanges();
});

/// The link of the one server until profiles exist (A07). Kept in memory only, never written
/// anywhere: the token in it may live only in the Keystore.
final sessionLinkProvider = NotifierProvider<SessionLink, String?>(
  SessionLink.new,
);

class SessionLink extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? link) => state = link;
}

/// States in which the tunnel exists and the toggle takes it down.
bool isActive(VpnState state) => switch (state) {
  VpnState.connecting || VpnState.connected || VpnState.reconnecting => true,
  VpnState.idle || VpnState.revoked || VpnState.error => false,
};
