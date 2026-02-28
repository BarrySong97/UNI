import 'package:flutter/material.dart';

class ChapterHeader extends StatelessWidget {
  const ChapterHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
