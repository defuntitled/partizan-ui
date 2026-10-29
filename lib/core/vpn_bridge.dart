import 'vpn_status.dart';

/// The tunnel as the UI sees it. The platform side implements it (Android: `VpnService` over
/// a platform channel; desktop later); screens and state depend only on this interface.
abstract interface class VpnBridge {
  /// Current status of the core.
  Future<VpnStatus> status();

  /// Every status change from now on.
  Stream<VpnStatus> statusChanges();

  /// Brings the tunnel up to the server of `uri` (a `partizan://` link, token included),
  /// asking for the system's VPN permission first if needed. Progress arrives through
  /// [statusChanges].
  Future<void> start({required String uri, int mtu = 1400});

  /// Takes the tunnel down.
  Future<void> stop();
}
