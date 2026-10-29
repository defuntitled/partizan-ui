import 'dart:async';

import 'package:flutter/services.dart';

import '../core/profile.dart';
import '../core/split.dart';
import '../core/vpn_bridge.dart';
import '../core/vpn_status.dart';

/// [VpnBridge] over platform channels; the Android side is `VpnChannel.kt`.
class ChannelVpnBridge implements VpnBridge {
  const ChannelVpnBridge();

  static const methods = MethodChannel('partizan/vpn');
  static const events = EventChannel('partizan/vpn/status');
  static const nav = MethodChannel('partizan/nav');

  @override
  Future<VpnStatus> status() async {
    final map = await methods.invokeMapMethod<Object?, Object?>('status');
    if (map == null) {
      throw PlatformException(
        code: 'empty',
        message: 'no status from the core',
      );
    }
    return VpnStatus.fromMap(map);
  }

  @override
  Future<void> start({
    required String uri,
    SplitRules split = SplitRules.all,
    int mtu = 1400,
  }) => methods.invokeMethod<void>('start', {
    'uri': uri,
    'mtu': mtu,
    'mode': split.mode.name,
    'routes': [for (final net in split.routes) '$net'],
  });

  @override
  Future<void> stop() => methods.invokeMethod<void>('stop');

  @override
  Future<void> publishLaunch(
    ServerProfile? profile,
    SplitRules rules, {
    bool killSwitch = false,
  }) => methods.invokeMethod<void>('setLaunch', {
    'killSwitch': killSwitch,
    if (profile != null) ...{
      'profileId': profile.id,
      'name': profile.name,
      'mode': rules.mode.name,
      'routes': [for (final net in rules.routes) '$net'],
    },
  });

  @override
  Future<void> openSystemVpnSettings() =>
      methods.invokeMethod<void>('openVpnSettings');

  @override
  Stream<AppTarget> targets() {
    final controller = StreamController<AppTarget>();
    void add(Object? name) {
      final target = AppTarget.values.where((t) => t.name == name).firstOrNull;
      if (target != null) controller.add(target);
    }

    nav.setMethodCallHandler((call) async {
      if (call.method == 'target') add(call.arguments);
    });
    nav.invokeMethod<String>('takeTarget').then(add, onError: (_) {});
    controller.onCancel = () => nav.setMethodCallHandler(null);
    return controller.stream;
  }

  @override
  Future<CheckResult> checkUri(String uri) async {
    try {
      final map = await methods.invokeMapMethod<String, Object?>('checkUri', {
        'uri': uri,
      });
      return CheckResult(
        host: map!['host']! as String,
        port: map['port']! as int,
        quicMs: map['quicMs'] as int?,
        tlsMs: map['tlsMs'] as int?,
      );
    } on PlatformException catch (e) {
      final problem = e.code == 'invalid_uri'
          ? LinkProblem.invalid
          : LinkProblem.unreachable;
      throw LinkCheckException(problem, e.message ?? e.code);
    }
  }

  @override
  Stream<VpnStatus> statusChanges() => events.receiveBroadcastStream().map(
    (event) => VpnStatus.fromMap(event as Map<Object?, Object?>),
  );
}
