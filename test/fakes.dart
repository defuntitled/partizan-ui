import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partizan/app.dart';
import 'package:partizan/core/link.dart';
import 'package:partizan/core/profile.dart';
import 'package:partizan/core/profile_store.dart';
import 'package:partizan/core/split.dart';
import 'package:partizan/core/vpn_bridge.dart';
import 'package:partizan/core/vpn_status.dart';
import 'package:partizan/platform/route_files.dart';
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
  Future<void> start({
    required String uri,
    SplitRules split = SplitRules.all,
    int mtu = 1400,
  }) async {
    calls.add('start $uri $mtu');
    starts.add(split);
  }

  /// The rules of every `start`.
  final starts = <SplitRules>[];

  @override
  Future<void> stop() async => calls.add('stop');

  /// Every `publishLaunch`: profile name (or null) and rules.
  final launches = <(String?, SplitRules)>[];

  /// The Kill Switch flag of every `publishLaunch`.
  final killSwitches = <bool>[];

  @override
  Future<void> publishLaunch(
    ServerProfile? profile,
    SplitRules rules, {
    bool killSwitch = false,
  }) async {
    launches.add((profile?.name, rules));
    killSwitches.add(killSwitch);
  }

  @override
  Future<void> openSystemVpnSettings() async => calls.add('vpn settings');

  final appTargets = StreamController<AppTarget>.broadcast();

  @override
  Stream<AppTarget> targets() => appTargets.stream;

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
    profiles[i] = profiles[i].copyWith(name: name);
    _emit();
  }

  /// Rules by scope: `null` for the shared ones.
  final rules = <int?, SplitRules>{};

  @override
  Stream<SplitRules> watchRules(int? profileId) =>
      _watch(() => rules[profileId] ?? SplitRules.all);

  @override
  Future<void> saveRules(int? profileId, SplitRules value) async {
    rules[profileId] = value;
    _emit();
  }

  @override
  Future<void> setOwnRules(int id, bool own) async {
    if (own) rules.putIfAbsent(id, () => rules[null] ?? SplitRules.all);
    final i = profiles.indexWhere((p) => p.id == id);
    profiles[i] = profiles[i].copyWith(ownRules: own);
    _emit();
  }

  bool killSwitch = false;

  @override
  Stream<bool> watchKillSwitch() => _watch(() => killSwitch);

  @override
  Future<void> setKillSwitch(bool on) async {
    killSwitch = on;
    _emit();
  }

  @override
  Future<SplitRules> rulesFor(ServerProfile profile) async =>
      rules[profile.ownRules ? profile.id : null] ?? SplitRules.all;

  @override
  Future<void> delete(int id) async {
    profiles.removeWhere((p) => p.id == id);
    links.remove(id);
    rules.remove(id);
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

Widget app(VpnBridge bridge, [ProfileStore? store, RouteFiles? files]) =>
    ProviderScope(
      overrides: [
        vpnBridgeProvider.overrideWithValue(bridge),
        profileStoreProvider.overrideWithValue(store ?? MemoryProfileStore()),
        routeFilesProvider.overrideWithValue(files ?? FakeRouteFiles()),
      ],
      child: const PartizanApp(),
    );

class FakeRouteFiles implements RouteFiles {
  /// What `open` returns.
  String? toOpen;

  /// What `save` received, by file name.
  final saved = <String, String>{};

  @override
  Future<String?> open() async => toOpen;

  @override
  Future<bool> save(String fileName, String text) async {
    saved[fileName] = text;
    return true;
  }
}

const testLink =
    'partizan://00112233445566778899aabbccddeeff:'
    'BgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgY@vpn.example.org:8443?path=/sync';
