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

  /// Has the core parse `uri` and try both transports, without the tunnel. Takes seconds.
  /// Throws [LinkCheckException].
  Future<CheckResult> checkUri(String uri);
}

/// What [VpnBridge.checkUri] found: setup times of the transports that work.
class CheckResult {
  const CheckResult({
    required this.host,
    required this.port,
    this.quicMs,
    this.tlsMs,
  });

  final String host;
  final int port;
  final int? quicMs;
  final int? tlsMs;
}

enum LinkProblem {
  /// The link is malformed; saving it is pointless.
  invalid,

  /// Well-formed, but the server did not answer over the configured transport.
  unreachable,
}

class LinkCheckException implements Exception {
  const LinkCheckException(this.problem, this.message);

  final LinkProblem problem;
  final String message;

  @override
  String toString() => message;
}
