import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/pages/library/library-page-layout.dart';

void main() {
  testWidgets('shows empty state message when shelf has no books', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryPageLayout(
            books: const <BookEntity>[],
            categories: const <String>['ALL'],
            activeCategory: 'ALL',
            isImporting: false,
            emptyMessage: 'No books yet',
            importingMessage: 'Importing...',
            onCategoryTap: (_) {},
            onBookTap: (_) {},
            onImportTap: () {},
            onSearchTap: () {},
            onMenuTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('No books yet'), findsOneWidget);
  });

  testWidgets('shows loading overlay while importing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryPageLayout(
            books: const <BookEntity>[],
            categories: const <String>['ALL'],
            activeCategory: 'ALL',
            isImporting: true,
            emptyMessage: 'No books yet',
            importingMessage: 'Importing...',
            onCategoryTap: (_) {},
            onBookTap: (_) {},
            onImportTap: () {},
            onSearchTap: () {},
            onMenuTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Importing...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
