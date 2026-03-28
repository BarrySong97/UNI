import 'package:flutter/material.dart';

import '../../shared/constants/common-design-tokens.dart';

class LibraryHeader extends StatefulWidget {
  const LibraryHeader({
    this.headerTitle = 'Shelf',
    this.onImportTap,
    this.isImporting = false,
    this.showImportButton = true,
    super.key,
  });

  final String headerTitle;
  final VoidCallback? onImportTap;
  final bool isImporting;
  final bool showImportButton;

  @override
  State<LibraryHeader> createState() => _LibraryHeaderState();
}

class _LibraryHeaderState extends State<LibraryHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isImporting) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(LibraryHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isImporting && !oldWidget.isImporting) {
      _rotationController.repeat();
    } else if (!widget.isImporting && oldWidget.isImporting) {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'IMMERSED',
              style: TextStyle(
                fontSize: CommonDesignTokens.headerLabelSize,
                fontWeight: FontWeight.w600,
                color: CommonDesignTokens.headerLabelColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.headerTitle,
              style: const TextStyle(
                fontSize: CommonDesignTokens.headerTitleSize,
                fontWeight: FontWeight.w700,
                color: CommonDesignTokens.textPrimary,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (widget.showImportButton)
          IconButton(
            icon: widget.isImporting
                ? RotationTransition(
                    turns: _rotationController,
                    child: const Icon(
                      Icons.hourglass_top,
                      color: CommonDesignTokens.textPrimary,
                      size: 22,
                    ),
                  )
                : const Icon(
                    Icons.add,
                    color: CommonDesignTokens.textPrimary,
                    size: 22,
                  ),
            onPressed: widget.isImporting ? null : widget.onImportTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
      ],
    );
  }
}
