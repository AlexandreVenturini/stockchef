import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'units.dart';

class AppDatabase {
  AppDatabase._();

  static const fileName = 'stockchef.db';
  static const version = 4;

  static Future<Database>? _opening;

  static Future<Database> get instance => _opening ??= _open();

  @visibleForTesting
  static void useForTesting(Database? database) {
    _opening = database == null ? null : Future.value(database);
  }

  static OpenDatabaseOptions get options => OpenDatabaseOptions(
    version: version,
    onConfigure: _onConfigure,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
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

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE ingredients ADD COLUMN brand TEXT');
      await db.execute(
        'ALTER TABLE ingredients '
        'ADD COLUMN is_preparation INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE productions '
        'ADD COLUMN affects_stock INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(_shoppingListsTable);
      await db.execute(_shoppingListItemsTable);
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE recipes ADD COLUMN prep_time_minutes INTEGER',
      );
      await db.execute(
        'ALTER TABLE shopping_list_items ADD COLUMN price_paid REAL',
      );
      await db.execute(_recipeStepsTable);
    }
  }
}

final _units = Unit.values.map((unit) => "'${unit.name}'").join(', ');

const _shoppingListsTable = '''
  CREATE TABLE shopping_lists (
    id INTEGER PRIMARY KEY,
    created_at TEXT NOT NULL,
    closed_at TEXT
  )
  ''';

final _shoppingListItemsTable =
    '''
  CREATE TABLE shopping_list_items (
    id INTEGER PRIMARY KEY,
    list_id INTEGER NOT NULL REFERENCES shopping_lists (id) ON DELETE CASCADE,
    ingredient_id INTEGER REFERENCES ingredients (id) ON DELETE SET NULL,
    ingredient_name TEXT NOT NULL,
    quantity REAL NOT NULL CHECK (quantity > 0),
    unit TEXT NOT NULL CHECK (unit IN ($_units)),
    checked INTEGER NOT NULL DEFAULT 0,
    checked_at TEXT,
    price_paid REAL
  )
  ''';

const _recipeStepsTable = '''
  CREATE TABLE recipe_steps (
    id INTEGER PRIMARY KEY,
    recipe_id INTEGER NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    description TEXT NOT NULL
  )
  ''';

final _schema = [
  '''
  CREATE TABLE ingredients (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    unit TEXT NOT NULL CHECK (unit IN ($_units)),
    stock REAL NOT NULL DEFAULT 0,
    min_stock REAL,
    price REAL,
    brand TEXT,
    is_preparation INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE recipes (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    yield_qty REAL NOT NULL CHECK (yield_qty > 0),
    yield_unit TEXT NOT NULL CHECK (yield_unit IN ($_units)),
    output_ingredient_id INTEGER REFERENCES ingredients (id) ON DELETE SET NULL,
    prep_time_minutes INTEGER
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
    created_at TEXT NOT NULL,
    affects_stock INTEGER NOT NULL DEFAULT 1
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
  _shoppingListsTable,
  _shoppingListItemsTable,
  _recipeStepsTable,
];
