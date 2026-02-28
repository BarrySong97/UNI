import 'package:flutter/material.dart';

import '../../shared/ui/app-scaffold.dart';

class BookDetailPage extends StatelessWidget {
  const BookDetailPage({required this.bookId, super.key});

  final String bookId;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Book Detail',
      body: Center(child: Text('Book id: $bookId')),
    );
  }
}
