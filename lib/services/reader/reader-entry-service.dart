import 'package:flutter/material.dart';

/// Stub service for reader entry during reconstruction phase.
/// Shows "under reconstruction" dialog instead of opening reader.
class ReaderEntryService {
  Future<void> openBook(BuildContext context, String bookId) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reader Under Reconstruction'),
          content: const Text(
            'The reader is being rebuilt and will be available soon. '
            'Your reading progress has been preserved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
