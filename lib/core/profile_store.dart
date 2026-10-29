import 'link.dart';
import 'profile.dart';

/// The server list, in the user's order, and which one is active.
abstract interface class ProfileStore {
  Stream<List<ServerProfile>> watchAll();

  /// The active profile; `null` when none is chosen or it was deleted.
  Stream<ServerProfile?> watchActive();

  /// Saves `link` under a new profile at the end of the list. The first profile becomes
  /// active.
  Future<ServerProfile> add({
    required String name,
    required LinkInfo info,
    required String link,
  });

  Future<void> rename(int id, String name);

  /// Removes the profile and its link.
  Future<void> delete(int id);

  /// New order: every profile's id, first to last.
  Future<void> reorder(List<int> ids);

  Future<void> setActive(int id);

  /// The full link with the token, read from the secret store at the moment it is needed.
  Future<String?> link(int id);
}

/// Where links with tokens are kept: the Android Keystore in the app, memory in tests.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
