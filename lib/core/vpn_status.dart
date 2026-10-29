import 'package:flutter/foundation.dart';

/// Tunnel state; mirrors `VpnState` of the core.
enum VpnState { idle, connecting, connected, reconnecting, revoked, error }

/// Status snapshot from the core; mirrors `VpnStatus` of `client-ffi`.
@immutable
class VpnStatus {
  const VpnStatus({
    required this.state,
    this.transport,
    this.rttMs,
    this.txBytes = 0,
    this.rxBytes = 0,
    this.reconnects = 0,
    this.error,
  });

  static const idle = VpnStatus(state: VpnState.idle);

  final VpnState state;

  /// `quic` or `tls` while connected.
  final String? transport;
  final int? rttMs;

  /// Payload bytes through the tunnel since start.
  final int txBytes;
  final int rxBytes;
  final int reconnects;

  /// Why the state is [VpnState.error].
  final String? error;

  /// Decodes the map the platform channel carries; throws [FormatException] on anything else.
  factory VpnStatus.fromMap(Map<Object?, Object?> map) {
    final name = map['state'];
    final state = VpnState.values.where((s) => s.name == name).firstOrNull;
    if (state == null) {
      throw FormatException('unknown VPN state', name);
    }
    T? field<T>(String key) {
      final value = map[key];
      if (value is T?) return value;
      throw FormatException('bad $key', value);
    }

    return VpnStatus(
      state: state,
      transport: field<String>('transport'),
      rttMs: field<int>('rttMs'),
      txBytes: field<int>('txBytes') ?? 0,
      rxBytes: field<int>('rxBytes') ?? 0,
      reconnects: field<int>('reconnects') ?? 0,
      error: field<String>('error'),
    );
  }

  Map<String, Object?> toMap() => {
    'state': state.name,
    'transport': transport,
    'rttMs': rttMs,
    'txBytes': txBytes,
    'rxBytes': rxBytes,
    'reconnects': reconnects,
    'error': error,
  };

  @override
  bool operator ==(Object other) =>
      other is VpnStatus &&
      other.state == state &&
      other.transport == transport &&
      other.rttMs == rttMs &&
      other.txBytes == txBytes &&
      other.rxBytes == rxBytes &&
      other.reconnects == reconnects &&
      other.error == error;

  @override
  int get hashCode =>
      Object.hash(state, transport, rttMs, txBytes, rxBytes, reconnects, error);

  @override
  String toString() => 'VpnStatus(${toMap()})';
}
