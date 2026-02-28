import 'package:flutter/material.dart';

class LibraryNewBadge extends StatelessWidget {
  const LibraryNewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'NEW',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111111),
      ),
    );
  }
}
