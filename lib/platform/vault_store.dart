import 'package:flutter/services.dart';

import '../core/profile_store.dart';

/// [SecretStore] in the app's Android Keystore vault (`SecretVault.kt`), which the tile and
/// the widget read too.
class VaultStore implements SecretStore {
  const VaultStore();

  static const channel = MethodChannel('partizan/secrets');

  @override
  Future<String?> read(String key) =>
      channel.invokeMethod<String>('read', {'key': key});

  @override
  Future<void> write(String key, String value) =>
      channel.invokeMethod<void>('write', {'key': key, 'value': value});

  @override
  Future<void> delete(String key) =>
      channel.invokeMethod<void>('delete', {'key': key});
}

/// Moves the links of `keys` from `from` to `to`, once: a key already in `to` is left alone,
/// a moved one is deleted from `from`. Up to A09 the links lived in `flutter_secure_storage`.
Future<int> migrateLinks({
  required SecretStore from,
  required SecretStore to,
  required Iterable<String> keys,
}) async {
  var moved = 0;
  for (final key in keys) {
    final old = await from.read(key);
    if (old == null) continue;
    if (await to.read(key) == null) {
      await to.write(key, old);
      moved++;
    }
    await from.delete(key);
  }
  return moved;
}
