import 'dart:async';

import 'link.dart';
import 'profile.dart';
import 'split.dart';

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

  /// Rules of a server (`profileId`), or the shared ones (`null`). A set never saved is
  /// [SplitRules.all].
  Stream<SplitRules> watchRules(int? profileId);

  Future<void> saveRules(int? profileId, SplitRules rules);

  /// Switches a server between its own rules and the shared ones. Its own start as a copy
  /// of the shared ones the first time.
  Future<void> setOwnRules(int id, bool own);

  /// The rules the tunnel uses for `profile`.
  Future<SplitRules> rulesFor(ServerProfile profile);

  /// Kill Switch: when the tunnel fails on its own, the internet stays blocked until the user
  /// disconnects. Off unless switched on.
  Stream<bool> watchKillSwitch();

  Future<void> setKillSwitch(bool on);
}

/// Where links with tokens are kept: the Android Keystore in the app, memory in tests.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The active profile with the rules it uses, again whenever either changes; `null` while
/// no profile is active.
Stream<(ServerProfile, SplitRules)?> watchLaunch(ProfileStore store) {
  late StreamController<(ServerProfile, SplitRules)?> controller;
  StreamSubscription<ServerProfile?>? outer;
  StreamSubscription<SplitRules>? inner;
  controller = StreamController(
    onListen: () {
      outer = store.watchActive().listen((profile) {
        inner?.cancel();
        inner = null;
        if (profile == null) {
          controller.add(null);
          return;
        }
        inner = store
            .watchRules(profile.ownRules ? profile.id : null)
            .listen((rules) => controller.add((profile, rules)));
      }, onError: controller.addError);
    },
    onCancel: () async {
      await inner?.cancel();
      await outer?.cancel();
    },
  );
  return controller.stream;
}
