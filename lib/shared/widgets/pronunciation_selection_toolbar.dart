import 'package:flutter/material.dart';

import '../constants/common-design-tokens.dart';

class PronunciationSelectionToolbar extends StatelessWidget {
  const PronunciationSelectionToolbar({
    super.key,
    required this.anchors,
    this.ipaLabel,
    this.aiButtonLabel,
    this.onAiPressed,
    this.isAiLoading = false,
    required this.buttonItems,
  });

  final TextSelectionToolbarAnchors anchors;
  final String? ipaLabel;
  final String? aiButtonLabel;
  final VoidCallback? onAiPressed;
  final bool isAiLoading;
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
        if ((ipaLabel == null || ipaLabel!.isEmpty) &&
            aiButtonLabel != null &&
            onAiPressed != null)
          Container(
            key: const ValueKey('pronunciation-selection-ai'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: TextButton(
              onPressed: isAiLoading ? null : onAiPressed,
              child: isAiLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(aiButtonLabel!),
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
