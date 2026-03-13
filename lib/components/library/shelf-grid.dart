import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import 'book-card.dart';

class ShelfGrid extends StatelessWidget {
  const ShelfGrid({required this.books, required this.onOpenBook, super.key});

  final List<BookEntity> books;
  final void Function(BookEntity book) onOpenBook;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookCard(book: book, onTap: () => onOpenBook(book));
      },
    );
  }
}
