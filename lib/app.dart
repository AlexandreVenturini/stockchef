import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/ingredients/ingredients_page.dart';
import 'features/preparations/preparations_page.dart';
import 'features/production/production_history_page.dart';
import 'features/recipes/recipes_page.dart';

class StockChefApp extends StatelessWidget {
  const StockChefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockChef',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _navigateToTab(int index) => setState(() => _selectedIndex = index);

  List<Widget> get _pages => [
    DashboardPage(onNavigateToTab: _navigateToTab),
    const IngredientsPage(),
    const PreparationsPage(),
    const RecipesPage(),
    const ProductionHistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Ingredientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.blender_outlined),
            selectedIcon: Icon(Icons.blender),
            label: 'Preparos',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Receitas',
          ),
          NavigationDestination(
            icon: Icon(Icons.soup_kitchen_outlined),
            selectedIcon: Icon(Icons.soup_kitchen),
            label: 'Produção',
          ),
        ],
      ),
    );
  }
}
