import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/components/library/library-book-grid.dart';
import 'package:uni/components/library/library-book-tile.dart';
import 'package:uni/entities/book-entity.dart';

void main() {
  BookEntity createBook({String? coverUrl}) {
    final now = DateTime.now();
    return BookEntity(
      id: 'book-1',
      title: 'My Title',
      author: 'Unknown',
      sourceType: 'local_epub',
      createdAt: now,
      updatedAt: now,
      coverUrl: coverUrl,
    );
  }

  testWidgets('LibraryBookTile renders fallback cover with book title', (
    tester,
  ) async {
    final book = createBook();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 200,
              child: LibraryBookTile(
                book: book,
                coverColor: Colors.blue,
                coverMark: 'M',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    // Fallback cover shows the full book title
    expect(find.text('My Title'), findsOneWidget);
  });

  testWidgets('LibraryBookTile uses BoxFit.cover for real cover image', (
    tester,
  ) async {
    const coverDataUrl =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+3xkAAAAASUVORK5CYII=';
    final book = createBook(coverUrl: coverDataUrl);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 200,
              child: LibraryBookTile(
                book: book,
                coverColor: Colors.blue,
                coverMark: 'M',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final imageWidget = tester.widget<Image>(find.byType(Image).first);
    expect(imageWidget.fit, BoxFit.cover);
  });

  testWidgets('LibraryBookGrid renders 2-column grid with category tabs', (
    tester,
  ) async {
    final now = DateTime.now();
    final books = <BookEntity>[
      BookEntity(
        id: 'b1',
        title: 'Book A',
        author: 'Author A',
        sourceType: 'local_epub',
        createdAt: now,
        updatedAt: now,
      ),
      BookEntity(
        id: 'b2',
        title: 'Book B',
        author: 'Author B',
        sourceType: 'local_epub',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LibraryBookGrid(
              books: books,
              onBookTap: (_) {},
              categories: const <String>['All', 'Reading', 'Finished'],
              activeCategory: 'All',
              onCategoryTap: (_) {},
            ),
          ),
        ),
      ),
    );

    // Category tabs are rendered
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
    // Both book titles visible (once in fallback cover, once in label below)
    expect(find.text('Book A'), findsNWidgets(2));
    expect(find.text('Book B'), findsNWidgets(2));
  });

  testWidgets('LibraryBookGrid shows progress badge from progressMap', (
    tester,
  ) async {
    final now = DateTime.now();
    final books = <BookEntity>[
      BookEntity(
        id: 'b1',
        title: 'Book A',
        author: 'Author A',
        sourceType: 'local_epub',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LibraryBookGrid(
              books: books,
              onBookTap: (_) {},
              categories: const <String>['All'],
              activeCategory: 'All',
              onCategoryTap: (_) {},
              progressMap: const <String, double>{'b1': 0.34},
            ),
          ),
        ),
      ),
    );

    expect(find.text('34%'), findsOneWidget);
  });
}
