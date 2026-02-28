import 'package:flutter/material.dart';

import '../../shared/constants/library-design-tokens.dart';
import '../discover/discover-page.dart';
import '../library/library-page.dart';
import '../read/read-page.dart';

class MainTabShellPage extends StatefulWidget {
  const MainTabShellPage({
    this.initialIndex = 0,
    this.pages,
    super.key,
  });

  final int initialIndex;
  final List<Widget>? pages;

  @override
  State<MainTabShellPage> createState() => _MainTabShellPageState();
}

class _MainTabShellPageState extends State<MainTabShellPage> {
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages ?? const <Widget>[LibraryPage(), DiscoverPage(), ReadPage()];

    return Scaffold(
      backgroundColor: LibraryDesignTokens.pageBackground,
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFF0F0F0),
        selectedItemColor: LibraryDesignTokens.textPrimary,
        unselectedItemColor: LibraryDesignTokens.tabInactiveText,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.library_books_outlined), label: 'LIBRARY'),
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'DISCOVER'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), label: 'READ'),
        ],
      ),
    );
  }
}
