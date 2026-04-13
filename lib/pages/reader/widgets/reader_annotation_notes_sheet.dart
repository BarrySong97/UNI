import 'package:flutter/material.dart';

import '../../../pages/reader/models/reader_annotation_card_item.dart';
import '../../../shared/constants/common-design-tokens.dart';
import '../../../shared/constants/shelf-design-tokens.dart';
import 'reader_annotation_note_composer.dart';

class ReaderAnnotationNotesSheet extends StatefulWidget {
  const ReaderAnnotationNotesSheet({
    super.key,
    required this.item,
    required this.isComposing,
    required this.composerVersion,
    required this.onBack,
    required this.onStartAddNote,
    required this.onAddNote,
    required this.onGoToLocation,
    required this.formatTimestamp,
  });

  final ReaderAnnotationCardItem item;
  final bool isComposing;
  final int composerVersion;
  final VoidCallback onBack;
  final VoidCallback onStartAddNote;
  final Future<ReaderAnnotationCardItem> Function(String noteText) onAddNote;
  final VoidCallback onGoToLocation;
  final String Function(DateTime value) formatTimestamp;

  @override
  State<ReaderAnnotationNotesSheet> createState() =>
      _ReaderAnnotationNotesSheetState();
}

class _ReaderAnnotationNotesSheetState
    extends State<ReaderAnnotationNotesSheet> {
  late ReaderAnnotationCardItem _item;
  bool _isSubmitting = false;
  bool _hideComposerAfterSubmit = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  @override
  void didUpdateWidget(covariant ReaderAnnotationNotesSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.annotation.id != oldWidget.item.annotation.id ||
        widget.item.annotation.updatedAt !=
            oldWidget.item.annotation.updatedAt ||
        widget.item.notes.length != oldWidget.item.notes.length) {
      _item = widget.item;
    }
    if (widget.isComposing && !oldWidget.isComposing) {
      _hideComposerAfterSubmit = false;
    }
  }

  Future<void> _handleAddNote(String noteText) async {
    setState(() {
      _isSubmitting = true;
      _hideComposerAfterSubmit = true;
    });
    try {
      final updated = await widget.onAddNote(noteText);
      if (!mounted) {
        return;
      }
      FocusScope.of(context).unfocus();
      setState(() {
        _item = updated;
        _isSubmitting = false;
        _hideComposerAfterSubmit = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _hideComposerAfterSubmit = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save note.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: CommonDesignTokens.textPrimary,
              ),
              Expanded(
                child: Text(
                  _item.chapterTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: CommonDesignTokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              Container(
                key: const ValueKey('mark-detail-quote-card'),
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
                          text: _item.annotation.quoteText,
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
              ),
              const SizedBox(height: 18),
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
                for (final note in _item.notes) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ShelfDesignTokens.statsCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CommonDesignTokens.borderColor),
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
                ],
              const SizedBox(height: 8),
              Offstage(
                offstage: !(widget.isComposing && !_hideComposerAfterSubmit),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: CommonDesignTokens.borderColor),
                  ),
                  child: ReaderAnnotationNoteEditor(
                    key: ValueKey<String>(
                      'mark-detail-note-editor-${widget.composerVersion}',
                    ),
                    inputKey: const ValueKey('mark-detail-note-input'),
                    quoteText: _item.annotation.quoteText,
                    isSubmitting: _isSubmitting,
                    onSubmit: _handleAddNote,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : widget.onStartAddNote,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CommonDesignTokens.textPrimary,
                    side: const BorderSide(
                      color: CommonDesignTokens.borderColor,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Add Note'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: _isSubmitting ? null : widget.onGoToLocation,
                  style: TextButton.styleFrom(
                    backgroundColor: ShelfDesignTokens.statsCardBg,
                    foregroundColor: ShelfDesignTokens.statsNumberColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Go to mark'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
