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
}

/// Small app state: `active_profile`.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Profiles, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The app's database file.
  AppDatabase.open() : super(driftDatabase(name: 'partizan'));

  @override
  int get schemaVersion => 1;
}
