import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'units.dart';

class AppDatabase {
  AppDatabase._();

  static const fileName = 'stockchef.db';
  static const version = 1;

  static Future<Database>? _opening;

  static Future<Database> get instance => _opening ??= _open();

  static OpenDatabaseOptions get options => OpenDatabaseOptions(
    version: version,
    onConfigure: _onConfigure,
    onCreate: _onCreate,
  );

  static Future<Database> _open() async {
    final factory = _factory();
    final path = join(await factory.getDatabasesPath(), fileName);
    return factory.openDatabase(path, options: options);
  }

  static DatabaseFactory _factory() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactorySqflitePlugin;
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    for (final statement in _schema) {
      await db.execute(statement);
    }
  }
}

final _units = Unit.values.map((unit) => "'${unit.name}'").join(', ');

final _schema = [
  '''
  CREATE TABLE ingredients (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    unit TEXT NOT NULL CHECK (unit IN ($_units)),
    stock REAL NOT NULL DEFAULT 0,
    min_stock REAL,
    price REAL
  )
  ''',
  '''
  CREATE TABLE recipes (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    yield_qty REAL NOT NULL CHECK (yield_qty > 0),
    yield_unit TEXT NOT NULL CHECK (yield_unit IN ($_units)),
    output_ingredient_id INTEGER REFERENCES ingredients (id) ON DELETE SET NULL
  )
  ''',
  '''
  CREATE TABLE recipe_items (
    id INTEGER PRIMARY KEY,
    recipe_id INTEGER NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    ingredient_id INTEGER NOT NULL REFERENCES ingredients (id) ON DELETE RESTRICT,
    quantity REAL NOT NULL CHECK (quantity > 0),
    unit TEXT NOT NULL CHECK (unit IN ($_units)),
    UNIQUE (recipe_id, ingredient_id)
  )
  ''',
  '''
  CREATE TABLE productions (
    id INTEGER PRIMARY KEY,
    recipe_id INTEGER REFERENCES recipes (id) ON DELETE SET NULL,
    recipe_name TEXT NOT NULL,
    date TEXT NOT NULL,
    quantity REAL NOT NULL CHECK (quantity > 0),
    unit TEXT NOT NULL CHECK (unit IN ($_units)),
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE production_items (
    id INTEGER PRIMARY KEY,
    production_id INTEGER NOT NULL REFERENCES productions (id) ON DELETE CASCADE,
    ingredient_id INTEGER REFERENCES ingredients (id) ON DELETE SET NULL,
    ingredient_name TEXT NOT NULL,
    quantity REAL NOT NULL,
    unit TEXT NOT NULL CHECK (unit IN ($_units))
  )
  ''',
];
