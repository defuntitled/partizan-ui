import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/link.dart';
import '../core/profile.dart';
import '../core/profile_store.dart';
import '../core/split.dart';
import 'database.dart';

const _activeKey = 'active_profile';
const _killSwitchKey = 'kill_switch';
const _sharedScope = 'shared';

String _scope(int? profileId) =>
    profileId == null ? _sharedScope : 'profile.$profileId';

/// Profiles in SQLite, their links in the [SecretStore].
class LocalProfileStore implements ProfileStore {
  LocalProfileStore(this._db, this._secrets);

  final AppDatabase _db;
  final SecretStore _secrets;

  static String secretKey(int id) => 'profile.$id.link';

  ServerProfile _profile(ProfileRow row) => ServerProfile(
    id: row.id,
    name: row.name,
    host: row.host,
    port: row.port,
    transport: row.transport,
    ownRules: row.ownRules,
  );

  SimpleSelectStatement<$ProfilesTable, ProfileRow> get _ordered =>
      _db.select(_db.profiles)..orderBy([(p) => OrderingTerm.asc(p.position)]);

  @override
  Stream<List<ServerProfile>> watchAll() =>
      _ordered.watch().map((rows) => rows.map(_profile).toList());

  @override
  Stream<ServerProfile?> watchActive() {
    final query = _db.select(_db.profiles).join([
      innerJoin(
        _db.settings,
        _db.settings.value.equalsExp(_db.profiles.id.cast<String>()) &
            _db.settings.key.equals(_activeKey),
      ),
    ]);
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _profile(row.readTable(_db.profiles)),
    );
  }

  @override
  Future<ServerProfile> add({
    required String name,
    required LinkInfo info,
    required String link,
  }) async {
    final row = await _db.transaction(() async {
      final last = _db.profiles.position.max();
      final top = await (_db.selectOnly(
        _db.profiles,
      )..addColumns([last])).map((r) => r.read(last)).getSingle();
      final id = await _db
          .into(_db.profiles)
          .insert(
            ProfilesCompanion.insert(
              name: name,
              position: (top ?? -1) + 1,
              host: info.host,
              port: info.port,
              transport: info.transport,
            ),
          );
      final active = await _activeId();
      if (active == null) await _setActive(id);
      return (_db.select(
        _db.profiles,
      )..where((p) => p.id.equals(id))).getSingle();
    });
    try {
      await _secrets.write(secretKey(row.id), link);
    } catch (_) {
      // A profile without its link cannot connect: do not keep it.
      await delete(row.id);
      rethrow;
    }
    return _profile(row);
  }

  @override
  Future<void> rename(int id, String name) => (_db.update(
    _db.profiles,
  )..where((p) => p.id.equals(id))).write(ProfilesCompanion(name: Value(name)));

  @override
  Future<void> delete(int id) async {
    await _secrets.delete(secretKey(id));
    await _db.transaction(() async {
      await (_db.delete(_db.profiles)..where((p) => p.id.equals(id))).go();
      await (_db.delete(
        _db.splitRuleSets,
      )..where((r) => r.scope.equals(_scope(id)))).go();
      if (await _activeId() == id) {
        await (_db.delete(
          _db.settings,
        )..where((s) => s.key.equals(_activeKey))).go();
      }
    });
  }

  @override
  Future<void> reorder(List<int> ids) => _db.transaction(() async {
    for (final (position, id) in ids.indexed) {
      await (_db.update(_db.profiles)..where((p) => p.id.equals(id))).write(
        ProfilesCompanion(position: Value(position)),
      );
    }
  });

  @override
  Future<void> setActive(int id) => _setActive(id);

  @override
  Future<String?> link(int id) => _secrets.read(secretKey(id));

  @override
  Stream<SplitRules> watchRules(int? profileId) =>
      (_db.select(_db.splitRuleSets)
            ..where((r) => r.scope.equals(_scope(profileId))))
          .watchSingleOrNull()
          .map(_rules);

  @override
  Future<void> saveRules(int? profileId, SplitRules rules) => _db
      .into(_db.splitRuleSets)
      .insertOnConflictUpdate(
        SplitRuleSetsCompanion.insert(
          scope: _scope(profileId),
          mode: rules.mode.name,
          routes: formatRoutes(rules.routes),
        ),
      );

  @override
  Future<void> setOwnRules(int id, bool own) => _db.transaction(() async {
    if (own && await _read(id) == null) {
      await saveRules(id, await _read(null) ?? SplitRules.all);
    }
    await (_db.update(_db.profiles)..where((p) => p.id.equals(id))).write(
      ProfilesCompanion(ownRules: Value(own)),
    );
  });

  @override
  Future<SplitRules> rulesFor(ServerProfile profile) async =>
      await _read(profile.ownRules ? profile.id : null) ?? SplitRules.all;

  Future<SplitRules?> _read(int? profileId) async {
    final row = await (_db.select(
      _db.splitRuleSets,
    )..where((r) => r.scope.equals(_scope(profileId)))).getSingleOrNull();
    return row == null ? null : _rules(row);
  }

  static SplitRules _rules(SplitRuleRow? row) {
    if (row == null) return SplitRules.all;
    final mode = SplitMode.values.firstWhere(
      (m) => m.name == row.mode,
      orElse: () => SplitMode.exclude,
    );
    return SplitRules(mode: mode, routes: parseRoutes(row.routes).routes);
  }

  @override
  Stream<bool> watchKillSwitch() =>
      (_db.select(_db.settings)..where((s) => s.key.equals(_killSwitchKey)))
          .watchSingleOrNull()
          .map((row) => row?.value == 'on');

  @override
  Future<void> setKillSwitch(bool on) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: _killSwitchKey, value: on ? 'on' : 'off'),
      );

  Future<int?> _activeId() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(_activeKey))).getSingleOrNull();
    return row == null ? null : int.tryParse(row.value);
  }

  Future<void> _setActive(int id) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: _activeKey, value: '$id'),
      );
}

/// [SecretStore] in the Android Keystore (encrypted with a hardware-backed key). Excluded
/// from backups by the manifest.
class KeystoreSecretStore implements SecretStore {
  const KeystoreSecretStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
