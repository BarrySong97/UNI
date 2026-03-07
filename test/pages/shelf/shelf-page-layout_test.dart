import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/pages/shelf/shelf-page-layout.dart';

void main() {
  testWidgets('shows empty state button when shelf has no books', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShelfPageLayout(
            books: const <BookEntity>[],
            isImporting: false,
            emptyMessage: 'No books yet',
            importingMessage: 'Importing...',
            onBookTap: (_) {},
            onImportTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Add Your First Book'), findsOneWidget);
  });

  testWidgets('shows loading overlay while importing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShelfPageLayout(
            books: const <BookEntity>[],
            isImporting: true,
            emptyMessage: 'No books yet',
            importingMessage: 'Importing...',
            onBookTap: (_) {},
            onImportTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Importing...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
