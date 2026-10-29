import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/profile.dart';
import '../core/profile_store.dart';
import '../platform/route_files.dart';

/// The profile store; set in `main` with an override, faked in tests.
final profileStoreProvider = Provider<ProfileStore>(
  (ref) => throw UnimplementedError('override profileStoreProvider'),
);

final profilesProvider = StreamProvider<List<ServerProfile>>(
  (ref) => ref.watch(profileStoreProvider).watchAll(),
);

final activeProfileProvider = StreamProvider<ServerProfile?>(
  (ref) => ref.watch(profileStoreProvider).watchActive(),
);

/// File access for importing and exporting route lists.
final routeFilesProvider = Provider<RouteFiles>(
  (ref) => const PickerRouteFiles(),
);
