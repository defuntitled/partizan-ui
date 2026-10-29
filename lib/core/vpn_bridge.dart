import 'profile.dart';
import 'split.dart';
import 'vpn_status.dart';

/// The tunnel as the UI sees it. The platform side implements it (Android: `VpnService` over
/// a platform channel; desktop later); screens and state depend only on this interface.
abstract interface class VpnBridge {
  /// Current status of the core.
  Future<VpnStatus> status();

  /// Every status change from now on.
  Stream<VpnStatus> statusChanges();

  /// Brings the tunnel up to the server of `uri` (a `partizan://` link, token included),
  /// asking for the system's VPN permission first if needed. `split` picks the traffic that
  /// goes through the tunnel. Progress arrives through [statusChanges].
  Future<void> start({
    required String uri,
    SplitRules split = SplitRules.all,
    int mtu = 1400,
  });

  /// Takes the tunnel down.
  Future<void> stop();

  /// Tells the platform which profile and rules a start outside the app (the tile, the
  /// widget) should use, `null` when no profile is active, and whether the Kill Switch is
  /// on. No secret crosses here.
  Future<void> publishLaunch(
    ServerProfile? profile,
    SplitRules rules, {
    bool killSwitch = false,
  });

  /// Requests from outside the app (the tile, the widget) to show a screen or connect. The
  /// one that launched the app comes first.
  Stream<AppTarget> targets();

  /// Opens the system VPN settings, where "Always-on VPN" and "Block connections without
  /// VPN" live: only the system can block traffic when the app is not running.
  Future<void> openSystemVpnSettings();

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

/// Where the tile or the widget sends the user.
enum AppTarget {
  /// The server list: there is no profile to start.
  servers,

  /// Connect the active profile; the app asks for the VPN permission.
  connect,
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
