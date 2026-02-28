import 'package:flutter/material.dart';

class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    required this.onOpenHighlights,
    required this.onOpenSettings,
    super.key,
  });

  final VoidCallback onOpenHighlights;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        IconButton(onPressed: onOpenHighlights, icon: const Icon(Icons.edit_note_outlined)),
        IconButton(onPressed: onOpenSettings, icon: const Icon(Icons.tune)),
      ],
    );
  }
}
