import 'package:flutter_test/flutter_test.dart';
import 'package:partizan/core/vpn_status.dart';

void main() {
  test('a status survives the channel map both ways', () {
    const status = VpnStatus(
      state: VpnState.connected,
      transport: 'quic',
      rttMs: 42,
      txBytes: 1 << 40,
      rxBytes: 7,
      reconnects: 2,
    );
    expect(VpnStatus.fromMap(status.toMap()), status);
  });

  test('missing counters default to zero', () {
    expect(VpnStatus.fromMap({'state': 'idle'}), VpnStatus.idle);
  });

  test('unknown states and mistyped fields are refused', () {
    expect(() => VpnStatus.fromMap({'state': 'flying'}), throwsFormatException);
    expect(() => VpnStatus.fromMap({}), throwsFormatException);
    expect(
      () => VpnStatus.fromMap({'state': 'connected', 'rttMs': 'fast'}),
      throwsFormatException,
    );
  });
}
