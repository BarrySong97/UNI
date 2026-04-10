import 'package:flutter/material.dart';

import '../models/reader_tooltip_action_spec.dart';

class ReaderTooltipActionsBar extends StatelessWidget {
  const ReaderTooltipActionsBar({
    super.key,
    required this.actionSpec,
    this.onPrimaryPressed,
    this.onPhoneticsPressed,
    this.onExplainPressed,
    this.onNotePressed,
    this.onUnmarkPressed,
    this.onReadAloudPressed,
  });

  final ReaderTooltipActionSpec actionSpec;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onPhoneticsPressed;
  final VoidCallback? onExplainPressed;
  final VoidCallback? onNotePressed;
  final VoidCallback? onUnmarkPressed;
  final VoidCallback? onReadAloudPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actionSpec.showAuxiliaryActions) ...[
              _TooltipButton(
                key: const ValueKey('reader-tooltip-phonetics'),
                label: 'Phonetics',
                onPressed: onPhoneticsPressed,
              ),
              const _TooltipDivider(),
              _TooltipButton(
                key: const ValueKey('reader-tooltip-explain'),
                label: 'Explain',
                onPressed: onExplainPressed,
              ),
              if (actionSpec.showPrimaryAction ||
                  actionSpec.showNoteAction ||
                  actionSpec.showUnmarkAction)
                const _TooltipDivider(),
            ],
            if (actionSpec.showPrimaryAction)
              _TooltipButton(
                key: const ValueKey('reader-tooltip-primary'),
                label: actionSpec.actionLabel,
                onPressed: onPrimaryPressed,
              ),
            if (actionSpec.showPrimaryAction && actionSpec.showNoteAction) ...[
              const _TooltipDivider(),
            ],
            if (actionSpec.showNoteAction)
              _TooltipButton(
                key: const ValueKey('reader-tooltip-note'),
                label: 'Note',
                onPressed: onNotePressed,
              ),
            if ((actionSpec.showPrimaryAction || actionSpec.showNoteAction) &&
                actionSpec.showUnmarkAction) ...[
              const _TooltipDivider(),
              _TooltipButton(
                key: const ValueKey('reader-tooltip-unmark'),
                label: 'Unmark',
                onPressed: onUnmarkPressed,
              ),
            ],
            if (actionSpec.showAuxiliaryActions) ...[
              if (actionSpec.showPrimaryAction ||
                  actionSpec.showNoteAction ||
                  actionSpec.showUnmarkAction)
                const _TooltipDivider(),
              _TooltipButton(
                key: const ValueKey('reader-tooltip-read-aloud'),
                label: 'Read Aloud',
                onPressed: onReadAloudPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TooltipDivider extends StatelessWidget {
  const _TooltipDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 20, color: Colors.white24);
  }
}

class _TooltipButton extends StatelessWidget {
  const _TooltipButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
