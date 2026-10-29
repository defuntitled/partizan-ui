import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Server profiles without their links: the token never reaches SQLite.
@DataClassName('ProfileRow')
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Place in the user's order, ascending.
  IntColumn get position => integer()();
  TextColumn get host => text()();
  IntColumn get port => integer()();
  TextColumn get transport => text()();

  /// Uses its own split tunneling rules instead of the shared ones (A09).
  BoolColumn get ownRules => boolean().withDefault(const Constant(false))();
}

/// Small app state: `active_profile`.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Split tunneling rules: `shared`, or `profile.<id>` for a server with its own.
@DataClassName('SplitRuleRow')
class SplitRuleSets extends Table {
  TextColumn get scope => text()();

  /// `include` or `exclude`.
  TextColumn get mode => text()();

  /// The routes in the file format: `99.84.0.0/16, 203.0.113.7/32`.
  TextColumn get routes => text()();

  @override
  Set<Column> get primaryKey => {scope};
}

@DriftDatabase(tables: [Profiles, Settings, SplitRuleSets])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The app's database file.
  AppDatabase.open() : super(driftDatabase(name: 'partizan'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(profiles, profiles.ownRules);
        await m.createTable(splitRuleSets);
      }
    },
  );
}
