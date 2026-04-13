import 'package:flutter/material.dart';

import '../../../pages/reader/models/reader_annotation_card_item.dart';
import '../../../shared/constants/common-design-tokens.dart';
import '../../../shared/constants/shelf-design-tokens.dart';
import 'reader_annotation_note_composer.dart';

class ReaderFocusedAnnotationSheet extends StatefulWidget {
  const ReaderFocusedAnnotationSheet({
    super.key,
    required this.item,
    required this.onAddNote,
    required this.formatTimestamp,
  });

  final ReaderAnnotationCardItem item;
  final Future<ReaderAnnotationCardItem> Function(String noteText) onAddNote;
  final String Function(DateTime value) formatTimestamp;

  static Future<void> show({
    required BuildContext context,
    required ReaderAnnotationCardItem item,
    required Future<ReaderAnnotationCardItem> Function(String noteText)
    onAddNote,
    required String Function(DateTime value) formatTimestamp,
    bool isTablet = false,
    bool showOnLeft = false,
  }) {
    final sheet = ReaderFocusedAnnotationSheet(
      item: item,
      onAddNote: onAddNote,
      formatTimestamp: formatTimestamp,
    );

    if (!isTablet) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => sheet,
      );
    }

    const panelMargin = 20.0;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss mark actions',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, _, __) {
        final mq = MediaQuery.of(dialogContext);
        final panelWidth = mq.size.width / 2 - panelMargin * 2;
        final panelHeight = mq.size.height * 0.86;

        return Align(
          alignment: showOnLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(
              left: showOnLeft ? panelMargin : 0,
              right: showOnLeft ? 0 : panelMargin,
              top: panelMargin,
              bottom: panelMargin,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              elevation: 12,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: sheet,
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
  State<ReaderFocusedAnnotationSheet> createState() =>
      _ReaderFocusedAnnotationSheetState();
}

class _ReaderFocusedAnnotationSheetState
    extends State<ReaderFocusedAnnotationSheet> {
  late ReaderAnnotationCardItem _item;
  bool _isComposing = false;
  bool _isSubmittingNote = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _handleAddNote(String noteText) async {
    setState(() {
      _isSubmittingNote = true;
      _isComposing = false;
    });
    try {
      final updated = await widget.onAddNote(noteText);
      if (!mounted) {
        return;
      }
      FocusScope.of(context).unfocus();
      setState(() {
        _item = updated;
        _isSubmittingNote = false;
        _isComposing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmittingNote = false;
        _isComposing = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save note.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mark Notes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: CommonDesignTokens.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: CommonDesignTokens.textPrimary,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                _QuoteBlock(quoteText: _item.annotation.quoteText),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ActionChip(
                    label: _isComposing ? 'Close Note' : 'Add Note',
                    onTap: () => setState(() => _isComposing = !_isComposing),
                  ),
                ),
                if (_isComposing) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: CommonDesignTokens.borderColor),
                    ),
                    child: ReaderAnnotationNoteEditor(
                      inputKey: const ValueKey('focused-mark-note-input'),
                      quoteText: _item.annotation.quoteText,
                      isSubmitting: _isSubmittingNote,
                      onSubmit: _handleAddNote,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: CommonDesignTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (_item.notes.isEmpty)
                  const Text(
                    'No notes yet.',
                    style: TextStyle(
                      color: CommonDesignTokens.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  ..._item.notes.map(
                    (note) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ShelfDesignTokens.statsCardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: CommonDesignTokens.borderColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.text,
                            style: const TextStyle(
                              color: CommonDesignTokens.textPrimary,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.formatTimestamp(note.createdAt),
                            style: const TextStyle(
                              color: CommonDesignTokens.headerLabelColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.quoteText});

  final String quoteText;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('focused-mark-quote-card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CommonDesignTokens.borderColor),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: CommonDesignTokens.textSecondary,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
            children: <InlineSpan>[
              const TextSpan(text: '"'),
              TextSpan(
                text: quoteText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CommonDesignTokens.textPrimary,
                  backgroundColor: CommonDesignTokens.pageBackground,
                ),
              ),
              const TextSpan(text: '"'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
