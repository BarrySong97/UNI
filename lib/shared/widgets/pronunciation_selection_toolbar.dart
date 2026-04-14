import 'package:flutter/material.dart';

import '../constants/common-design-tokens.dart';

class PronunciationSelectionToolbar extends StatelessWidget {
  const PronunciationSelectionToolbar({
    super.key,
    required this.anchors,
    this.ipaLabel,
    required this.buttonItems,
  });

  final TextSelectionToolbarAnchors anchors;
  final String? ipaLabel;
  final List<ContextMenuButtonItem> buttonItems;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTextSelectionToolbar(
      anchors: anchors,
      children: [
        if (ipaLabel != null && ipaLabel!.isNotEmpty)
          Container(
            key: const ValueKey('pronunciation-selection-ipa'),
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            alignment: Alignment.centerLeft,
            child: Text(
              ipaLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CommonDesignTokens.textPrimary,
              ),
            ),
          ),
        ...AdaptiveTextSelectionToolbar.getAdaptiveButtons(
          context,
          buttonItems,
        ),
      ],
    );
  }
}
