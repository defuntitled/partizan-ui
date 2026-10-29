import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partizan/core/link.dart';
import 'package:partizan/core/profile_store.dart';
import 'package:partizan/core/split.dart';
import 'package:partizan/data/database.dart';
import 'package:partizan/data/local_profile_store.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

const token = 'SECRETTOKENSECRETTOKENSECRETTOKENSECRETTOK';

String link(String host) =>
    'partizan://00112233445566778899aabbccddeeff:$token@$host?path=/sync&transport=quic';

LinkInfo info(String host) => LinkInfo.parse(link(host))!;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late MemorySecrets secrets;
  late LocalProfileStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    secrets = MemorySecrets();
    store = LocalProfileStore(db, secrets);
  });
  tearDown(() => db.close());

  test('profiles keep the user\'s order; the first becomes active', () async {
    final a = await store.add(
      name: 'A',
      info: info('a.example:443'),
      link: link('a.example:443'),
    );
    final b = await store.add(
      name: 'B',
      info: info('b.example:8443'),
      link: link('b.example:8443'),
    );
    final c = await store.add(
      name: 'C',
      info: info('[2001:db8::1]:443'),
      link: link('[2001:db8::1]:443'),
    );
    expect((await store.watchAll().first).map((p) => p.name), ['A', 'B', 'C']);
    expect(await store.watchActive().first, a);
    expect(b.port, 8443);
    expect(c.address, '[2001:db8::1]:443');

    await store.reorder([c.id, a.id, b.id]);
    expect((await store.watchAll().first).map((p) => p.name), ['C', 'A', 'B']);
    await store.setActive(b.id);
    expect((await store.watchActive().first)?.name, 'B');
  });

  test(
    'rename and delete; deleting the active profile clears the choice',
    () async {
      final a = await store.add(
        name: 'A',
        info: info('a.example'),
        link: link('a.example'),
      );
      await store.rename(a.id, 'Работа');
      expect((await store.watchAll().first).single.name, 'Работа');
      await store.delete(a.id);
      expect(await store.watchAll().first, isEmpty);
      expect(await store.watchActive().first, isNull);
      expect(secrets.values, isEmpty, reason: 'the link goes with the profile');
    },
  );

  test('A07-T4: renames and deletions survive a restart', () async {
    final dir = await Directory.systemTemp.createTemp('partizan-db');
    final file = File('${dir.path}/partizan.sqlite');
    var disk = AppDatabase(NativeDatabase(file));
    var onDisk = LocalProfileStore(disk, secrets);
    final a = await onDisk.add(
      name: 'A',
      info: info('a.example'),
      link: link('a.example'),
    );
    final b = await onDisk.add(
      name: 'B',
      info: info('b.example'),
      link: link('b.example'),
    );
    await onDisk.rename(a.id, 'Дом');
    await onDisk.delete(b.id);
    await disk.close();

    disk = AppDatabase(NativeDatabase(file));
    onDisk = LocalProfileStore(disk, secrets);
    final after = await onDisk.watchAll().first;
    expect(after.map((p) => p.name), ['Дом']);
    expect((await onDisk.watchActive().first)?.id, a.id);
    expect(await onDisk.link(a.id), link('a.example'));
    await disk.close();
    await dir.delete(recursive: true);
  });

  test('A07-T5: the token is in the secret store, not in SQLite', () async {
    final dir = await Directory.systemTemp.createTemp('partizan-db');
    final file = File('${dir.path}/partizan.sqlite');
    final disk = AppDatabase(NativeDatabase(file));
    final onDisk = LocalProfileStore(disk, secrets);
    final p = await onDisk.add(
      name: 'A',
      info: info('a.example'),
      link: link('a.example'),
    );
    await disk.close();

    final bytes = String.fromCharCodes(await file.readAsBytes());
    expect(bytes, contains('a.example'), reason: 'the file is the right one');
    expect(bytes, isNot(contains(token)));
    expect(bytes, isNot(contains('partizan://')));
    expect(
      secrets.values[LocalProfileStore.secretKey(p.id)],
      link('a.example'),
    );
    await dir.delete(recursive: true);
  });

  test('shared rules apply until a server takes its own', () async {
    final a = await store.add(
      name: 'A',
      info: info('a.example'),
      link: link('a.example'),
    );
    expect(
      await store.rulesFor(a),
      SplitRules.all,
      reason: 'default tunnels everything',
    );
    final shared = SplitRules(
      mode: SplitMode.include,
      routes: parseRoutes('99.84.0.0/16, 2606:4700::/32').routes,
    );
    await store.saveRules(null, shared);
    expect(await store.rulesFor(a), shared);

    // Its own rules start as a copy of the shared ones, then go their way.
    await store.setOwnRules(a.id, true);
    final own = (await store.watchAll().first).single;
    expect(own.ownRules, isTrue);
    expect(await store.rulesFor(own), shared);
    final narrower = shared.copyWith(routes: parseRoutes('203.0.113.7').routes);
    await store.saveRules(a.id, narrower);
    expect(await store.rulesFor(own), narrower);
    expect(
      await store.watchRules(null).first,
      shared,
      reason: 'shared untouched',
    );

    // Back to shared: the own set is kept for later but no longer used.
    await store.setOwnRules(a.id, false);
    final back = (await store.watchAll().first).single;
    expect(await store.rulesFor(back), shared);
    expect(await store.watchRules(a.id).first, narrower);
  });

  test(
    'A09-T4: the shared/own choice and the rules survive a restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('partizan-db');
      final file = File('${dir.path}/partizan.sqlite');
      var disk = AppDatabase(NativeDatabase(file));
      var onDisk = LocalProfileStore(disk, secrets);
      final a = await onDisk.add(
        name: 'A',
        info: info('a.example'),
        link: link('a.example'),
      );
      await onDisk.setOwnRules(a.id, true);
      final rules = SplitRules(
        mode: SplitMode.exclude,
        routes: parseRoutes('192.168.0.0/16').routes,
      );
      await onDisk.saveRules(a.id, rules);
      await disk.close();

      disk = AppDatabase(NativeDatabase(file));
      onDisk = LocalProfileStore(disk, secrets);
      final after = (await onDisk.watchAll().first).single;
      expect(after.ownRules, isTrue);
      expect(await onDisk.rulesFor(after), rules);
      await disk.close();
      await dir.delete(recursive: true);
    },
  );

  test(
    'the Kill Switch is off until switched on, and survives a restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('partizan-db');
      final file = File('${dir.path}/partizan.sqlite');
      var disk = AppDatabase(NativeDatabase(file));
      var onDisk = LocalProfileStore(disk, secrets);
      expect(await onDisk.watchKillSwitch().first, isFalse);
      await onDisk.setKillSwitch(true);
      expect(await onDisk.watchKillSwitch().first, isTrue);
      await disk.close();

      disk = AppDatabase(NativeDatabase(file));
      onDisk = LocalProfileStore(disk, secrets);
      expect(await onDisk.watchKillSwitch().first, isTrue);
      await onDisk.setKillSwitch(false);
      expect(await onDisk.watchKillSwitch().first, isFalse);
      await disk.close();
      await dir.delete(recursive: true);
    },
  );

  test('deleting a server deletes its rules', () async {
    final a = await store.add(
      name: 'A',
      info: info('a.example'),
      link: link('a.example'),
    );
    await store.setOwnRules(a.id, true);
    await store.delete(a.id);
    final rows = await db.select(db.splitRuleSets).get();
    expect(rows.map((r) => r.scope), isNot(contains('profile.${a.id}')));
  });

  test('a v1 database is migrated', () async {
    final dir = await Directory.systemTemp.createTemp('partizan-db');
    final file = File('${dir.path}/partizan.sqlite');
    // The v1 schema, as A07 shipped it.
    final v1 = NativeDatabase(
      file,
      setup: (raw) {
        raw.execute(
          'CREATE TABLE profiles (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
          'position INTEGER NOT NULL, host TEXT NOT NULL, port INTEGER NOT NULL, '
          'transport TEXT NOT NULL)',
        );
        raw.execute(
          'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
        );
        raw.execute(
          "INSERT INTO profiles (name, position, host, port, transport) VALUES ('Old', 0, 'old.example', 443, 'auto')",
        );
        raw.execute('PRAGMA user_version = 1');
      },
    );
    final disk = AppDatabase(v1);
    final migrated = LocalProfileStore(disk, secrets);
    final old = (await migrated.watchAll().first).single;
    expect((old.name, old.ownRules), ('Old', false));
    expect(await migrated.rulesFor(old), SplitRules.all);
    await disk.close();
    await dir.delete(recursive: true);
  });

  test('a profile whose link cannot be stored is not kept', () async {
    final failing = LocalProfileStore(db, _FailingSecrets());
    await expectLater(
      failing.add(name: 'A', info: info('a.example'), link: link('a.example')),
      throwsStateError,
    );
    expect(await failing.watchAll().first, isEmpty);
  });
}

class _FailingSecrets extends MemorySecrets {
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('keystore');
}
