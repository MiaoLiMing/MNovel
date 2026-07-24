import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/bookstore/bookstore_page.dart';
import '../features/category/category_page.dart';
import '../features/profile/profile_page.dart';
import '../features/shelf/shelf_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex.clamp(0, 3);

  void setIndex(int value) {
    if (value == _index || value < 0 || value > 3) return;
    setState(() => _index = value);
  }

  final _pages = const <Widget>[
    ShelfPage(),
    BookstorePage(),
    CategoryPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _index, children: _pages),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: .7)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 58,
          selectedIndex: _index,
          onDestinationSelected: setIndex,
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          indicatorColor: AppColors.coralSoft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined, size: 21),
              selectedIcon: Icon(Icons.menu_book_rounded, size: 21),
              label: '书架',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined, size: 21),
              selectedIcon: Icon(Icons.auto_stories_rounded, size: 21),
              label: '书城',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined, size: 20),
              selectedIcon: Icon(Icons.grid_view_rounded, size: 20),
              label: '分类',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 21),
              selectedIcon: Icon(Icons.person_rounded, size: 21),
              label: '我的',
            ),
          ],
        ),
      ),
    ),
  );
}
