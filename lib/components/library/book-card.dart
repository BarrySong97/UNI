import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';

class BookCard extends StatelessWidget {
  const BookCard({required this.book, required this.onTap, super.key});

  final BookEntity book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(book.title),
        subtitle: Text(book.author),
        onTap: onTap,
      ),
    );
  }
}
