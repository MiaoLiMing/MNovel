import 'package:flutter/material.dart';

import '../features/bookstore/bookstore_page.dart';
import '../features/category/category_page.dart';
import '../features/profile/profile_page.dart';
import '../features/shelf/shelf_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  final _pages = const <Widget>[
    ShelfPage(),
    BookstorePage(),
    CategoryPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (value) => setState(() => _index = value),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.library_books_outlined),
                activeIcon: Icon(Icons.library_books),
                label: '书架',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_book_outlined),
                activeIcon: Icon(Icons.menu_book),
                label: '书城',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_outlined),
                activeIcon: Icon(Icons.grid_view_rounded),
                label: '分类',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
