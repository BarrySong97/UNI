import 'package:flutter/material.dart';

import '../../entities/highlight-entity.dart';

class HighlightItem extends StatelessWidget {
  const HighlightItem({
    required this.highlight,
    required this.onDelete,
    super.key,
  });

  final HighlightEntity highlight;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(highlight.selectedText),
        subtitle: Text('${highlight.chapterId} ${highlight.startOffset}-${highlight.endOffset}'),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
      ),
    );
  }
}
