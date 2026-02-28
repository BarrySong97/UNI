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

  testWidgets('LibraryBookTile renders title only with compact gray style', (tester) async {
    final book = createBook();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
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

    expect(find.text('My Title'), findsOneWidget);
    expect(find.text('Unknown'), findsNothing);

    final titleWidget = tester.widget<Text>(find.text('My Title'));
    expect(titleWidget.style?.fontSize, 12);
    expect(titleWidget.style?.fontWeight, FontWeight.w500);
    expect(titleWidget.style?.color, const Color(0xFF666666));
  });

  testWidgets('LibraryBookTile uses BoxFit.cover for real cover image', (tester) async {
    const coverDataUrl =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+3xkAAAAASUVORK5CYII=';
    final book = createBook(coverUrl: coverDataUrl);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
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

  testWidgets('LibraryBookGrid keeps 3 columns with larger spacing', (tester) async {
    final books = <BookEntity>[createBook()];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryBookGrid(
            books: books,
            onBookTap: (_) {},
          ),
        ),
      ),
    );

    final gridView = tester.widget<GridView>(find.byType(GridView));
    final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(delegate.crossAxisSpacing, 20);
    expect(delegate.mainAxisSpacing, 14);
  });
}
