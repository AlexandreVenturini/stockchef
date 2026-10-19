import 'package:flutter/material.dart';

import 'app.dart';
import 'core/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance;
  runApp(const StockChefApp());
}
