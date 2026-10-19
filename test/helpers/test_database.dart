import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/database.dart';

Future<Database> openTestDatabase() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: AppDatabase.options,
  );
  AppDatabase.useForTesting(db);
  return db;
}

Future<void> closeTestDatabase(Database db) async {
  AppDatabase.useForTesting(null);
  await db.close();
}

Future<void> pumpAndLoad(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 20));
  }
}
