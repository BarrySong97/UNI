import 'package:flutter/material.dart';

import '../../shared/constants/library-design-tokens.dart';

class ReadPage extends StatefulWidget {
  const ReadPage({super.key});

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LibraryDesignTokens.pageBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Read',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: LibraryDesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text('State: $count'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  count++;
                });
              },
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
