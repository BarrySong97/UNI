import 'dart:math' as math;

import 'package:flutter/material.dart';

class ReaderSelectionNoteSheet extends StatefulWidget {
  const ReaderSelectionNoteSheet({
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
    bool selectionOnRightPage = false,
  }) {
    final sheet = ReaderSelectionNoteSheet(
      quoteText: quoteText,
      initialText: initialText,
      isTablet: isTablet,
    );

    if (!isTablet) {
      return showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        backgroundColor: Colors.transparent,
        builder: (_) => sheet,
      );
    }

    final showOnLeft = selectionOnRightPage;
    const panelMargin = 20.0;

    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss selection note sheet',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, _, __) {
        final mq = MediaQuery.of(dialogContext);
        final panelWidth = mq.size.width / 2 - panelMargin * 2;
        final panelHeight = math.max(440.0, mq.size.height * 0.82);
        return AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: Align(
            alignment: showOnLeft
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                left: showOnLeft ? panelMargin : 0,
                right: showOnLeft ? 0 : panelMargin,
                top: panelMargin,
                bottom: panelMargin,
              ),
              child: Material(
                key: const ValueKey('selection-note-panel'),
                color: Colors.transparent,
                child: SizedBox(
                  width: panelWidth,
                  height: math.min(panelHeight, mq.size.height - 40),
                  child: sheet,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(showOnLeft ? -1 : 1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  State<ReaderSelectionNoteSheet> createState() =>
      _ReaderSelectionNoteSheetState();
}

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

class ReaderAnnotationNoteEditor extends StatefulWidget {
  const ReaderAnnotationNoteEditor({
    super.key,
    required this.quoteText,
    required this.onSubmit,
    this.inputKey = const ValueKey('note-composer-input'),
    this.initialText = '',
    this.autoFocus = true,
    this.isSubmitting = false,
    this.showQuote = true,
    this.bottomPadding = 16,
  });

  final String quoteText;
  final Future<void> Function(String noteText) onSubmit;
  final Key inputKey;
  final String initialText;
  final bool autoFocus;
  final bool isSubmitting;
  final bool showQuote;
  final double bottomPadding;

  @override
  State<ReaderAnnotationNoteEditor> createState() =>
      _ReaderAnnotationNoteEditorState();
}

class _ReaderAnnotationNoteEditorState
    extends State<ReaderAnnotationNoteEditor> {
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
      if (mounted && widget.autoFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ReaderAnnotationNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialText != oldWidget.initialText &&
        widget.initialText != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialText,
        selection: TextSelection.collapsed(offset: widget.initialText.length),
      );
    }
    if (widget.autoFocus && !oldWidget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
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

  Future<void> _submit() async {
    if (_trimmedText.isEmpty || widget.isSubmitting) {
      return;
    }
    await widget.onSubmit(_trimmedText);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomPadding),
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
                    key: widget.inputKey,
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !widget.isSubmitting,
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
                  onPressed: _trimmedText.isEmpty || widget.isSubmitting
                      ? null
                      : _submit,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF60A5FA),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: widget.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Publish'),
                ),
              ],
            ),
            if (widget.showQuote) ...[
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
          ],
        ),
      ),
    );
  }
}

class _ReaderAnnotationNoteComposerState
    extends State<ReaderAnnotationNoteComposer> {
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = widget.isTablet
        ? 16.0
        : math.max(16.0, mq.padding.bottom);

    return ReaderAnnotationNoteEditor(
      quoteText: widget.quoteText,
      initialText: widget.initialText,
      bottomPadding: bottomPadding,
      onSubmit: (noteText) async {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(noteText);
      },
    );
  }
}

class _ReaderSelectionNoteSheetState extends State<ReaderSelectionNoteSheet> {
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

  Future<void> _submit() async {
    if (_trimmedText.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(_trimmedText);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height;
    final containerHeight = widget.isTablet
        ? double.infinity
        : math.max(420.0, screenHeight * 0.74);
    final bottomInset = mq.viewInsets.bottom;
    final bottomSafePadding = widget.isTablet
        ? 20.0
        : math.max(20.0, mq.padding.bottom);

    final panel = AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: widget.isTablet ? 0 : bottomInset),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: widget.isTablet
              ? Alignment.center
              : Alignment.bottomCenter,
          child: Container(
            key: const ValueKey('selection-note-sheet'),
            width: double.infinity,
            height: containerHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(24),
                bottom: Radius.circular(widget.isTablet ? 24 : 0),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Add Note',
                              style: TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected text',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.quoteText,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          key: const ValueKey('note-composer-input'),
                          controller: _controller,
                          focusNode: _focusNode,
                          expands: true,
                          minLines: null,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Write down this moment...',
                            hintStyle: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 17,
                            ),
                          ),
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 17,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottomSafePadding),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('note-composer-publish'),
                      onPressed: _trimmedText.isEmpty ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Publish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.isTablet) {
      return panel;
    }
    return Material(color: Colors.transparent, child: panel);
  }
}
