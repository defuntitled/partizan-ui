import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partizan/app.dart';
import 'package:partizan/core/link.dart';
import 'package:partizan/core/profile.dart';
import 'package:partizan/core/profile_store.dart';
import 'package:partizan/core/vpn_bridge.dart';
import 'package:partizan/core/vpn_status.dart';
import 'package:partizan/state/profiles.dart';
import 'package:partizan/state/vpn.dart';

class FakeBridge implements VpnBridge {
  FakeBridge([this.initial = VpnStatus.idle]);

  final VpnStatus initial;
  final changes = StreamController<VpnStatus>();
  final calls = <String>[];

  /// What `checkUri` answers; `null` means the link is fine.
  LinkCheckException? checkFails;

  @override
  Future<VpnStatus> status() async => initial;

  @override
  Stream<VpnStatus> statusChanges() => changes.stream;

  @override
  Future<void> start({required String uri, int mtu = 1400}) async =>
      calls.add('start $uri $mtu');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<CheckResult> checkUri(String uri) async {
    calls.add('check');
    if (checkFails case final e?) throw e;
    final info = LinkInfo.parse(uri)!;
    return CheckResult(host: info.host, port: info.port, quicMs: 20);
  }
}

/// [ProfileStore] in memory, with the same rules as the real one.
class MemoryProfileStore implements ProfileStore {
  final profiles = <ServerProfile>[];
  final links = <int, String>{};
  int? active;
  int _next = 1;
  final _changed = StreamController<void>.broadcast();

  void _emit() => _changed.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changed.stream.map((_) => read());
  }

  @override
  Stream<List<ServerProfile>> watchAll() => _watch(() => List.of(profiles));

  @override
  Stream<ServerProfile?> watchActive() =>
      _watch(() => profiles.where((p) => p.id == active).firstOrNull);

  @override
  Future<ServerProfile> add({
    required String name,
    required LinkInfo info,
    required String link,
  }) async {
    final p = ServerProfile(
      id: _next++,
      name: name,
      host: info.host,
      port: info.port,
      transport: info.transport,
    );
    profiles.add(p);
    links[p.id] = link;
    active ??= p.id;
    _emit();
    return p;
  }

  @override
  Future<void> rename(int id, String name) async {
    final i = profiles.indexWhere((p) => p.id == id);
    final p = profiles[i];
    profiles[i] = ServerProfile(
      id: p.id,
      name: name,
      host: p.host,
      port: p.port,
      transport: p.transport,
    );
    _emit();
  }

  @override
  Future<void> delete(int id) async {
    profiles.removeWhere((p) => p.id == id);
    links.remove(id);
    if (active == id) active = null;
    _emit();
  }

  @override
  Future<void> reorder(List<int> ids) async {
    final byId = {for (final p in profiles) p.id: p};
    profiles
      ..clear()
      ..addAll(ids.map((id) => byId[id]!));
    _emit();
  }

  @override
  Future<void> setActive(int id) async {
    active = id;
    _emit();
  }

  @override
  Future<String?> link(int id) async => links[id];
}

Widget app(VpnBridge bridge, [ProfileStore? store]) => ProviderScope(
  overrides: [
    vpnBridgeProvider.overrideWithValue(bridge),
    profileStoreProvider.overrideWithValue(store ?? MemoryProfileStore()),
  ],
  child: const PartizanApp(),
);

const testLink =
    'partizan://00112233445566778899aabbccddeeff:'
    'BgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgY@vpn.example.org:8443?path=/sync';
