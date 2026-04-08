import 'dart:math' as math;

import 'package:flutter/material.dart';

class ReaderAnnotationNoteComposer extends StatefulWidget {
  const ReaderAnnotationNoteComposer({
    super.key,
    required this.quoteText,
    this.initialText = '',
    this.isTablet = false,
  });

  final String quoteText;
  final String initialText;
  final bool isTablet;

  static Future<String?> show({
    required BuildContext context,
    required String quoteText,
    String initialText = '',
    bool isTablet = false,
  }) {
    final composer = ReaderAnnotationNoteComposer(
      quoteText: quoteText,
      initialText: initialText,
      isTablet: isTablet,
    );

    if (!isTablet) {
      return showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => composer,
      );
    }

    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss note composer',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) {
        final mq = MediaQuery.of(dialogContext);
        final width = math.min(560.0, mq.size.width * 0.52);
        final bottomInset = mq.viewInsets.bottom;
        final bottomPadding = math.max(mq.padding.bottom, 24.0);
        final bottomOffset = bottomInset > 0 ? bottomInset + 12 : bottomPadding;
        return Stack(
          children: [
            Positioned(
              left: (mq.size.width - width) / 2,
              bottom: bottomOffset,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Container(
                    width: width,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: composer,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ReaderAnnotationNoteComposer> createState() =>
      _ReaderAnnotationNoteComposerState();
}

class _ReaderAnnotationNoteComposerState
    extends State<ReaderAnnotationNoteComposer> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  String get _trimmedText => _controller.text.trim();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    _controller.addListener(_handleTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = widget.isTablet
        ? 16.0
        : math.max(16.0, mq.padding.bottom);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 22,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const ValueKey('note-composer-input'),
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Write down this moment...',
                      hintStyle: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 18,
                      ),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 18,
                      height: 1.4,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('note-composer-publish'),
                  onPressed: _trimmedText.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_trimmedText),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF60A5FA),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Publish'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Text(
                'Quote: ${widget.quoteText}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
