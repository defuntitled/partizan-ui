// A07-T4, A07-T5 on a device: profiles in the app's SQLite file survive reopening, the link
// with its token is in the Keystore and nowhere in that file.

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:partizan/core/link.dart';
import 'package:partizan/data/database.dart';
import 'package:partizan/data/local_profile_store.dart';
import 'package:path_provider/path_provider.dart';

const _token = 'ZZTOKENZZTOKENZZTOKENZZTOKENZZTOKENZZTOKENZ';
const _link =
    'partizan://00112233445566778899aabbccddeeff:$_token@vpn.example.org:443?path=/sync';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('profiles persist, tokens stay in the Keystore', (_) async {
    const secrets = KeystoreSecretStore();
    var db = AppDatabase.open();
    var store = LocalProfileStore(db, secrets);
    final p = await store.add(
      name: 'A07',
      info: LinkInfo.parse(_link)!,
      link: _link,
    );
    await store.rename(p.id, 'A07 renamed');
    await db.close();

    // A07-T4: a fresh database on the same file still has it.
    db = AppDatabase.open();
    store = LocalProfileStore(db, secrets);
    final after = await store.watchAll().first;
    expect(after.where((x) => x.id == p.id).single.name, 'A07 renamed');
    expect(await store.link(p.id), _link);

    // A07-T5: the token is nowhere in the database file.
    final docs = await getApplicationDocumentsDirectory();
    final files = docs.listSync().whereType<File>().where(
      (f) => f.path.contains('partizan'),
    );
    expect(files, isNotEmpty);
    for (final file in files) {
      final bytes = String.fromCharCodes(await file.readAsBytes());
      expect(bytes, isNot(contains(_token)), reason: file.path);
    }

    await store.delete(p.id);
    expect(await secrets.read(LocalProfileStore.secretKey(p.id)), isNull);
    await db.close();
  });
}
