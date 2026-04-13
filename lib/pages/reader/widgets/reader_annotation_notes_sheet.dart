import 'package:flutter/material.dart';

import '../../../pages/reader/models/reader_annotation_card_item.dart';
import '../../../shared/constants/common-design-tokens.dart';
import '../../../shared/constants/shelf-design-tokens.dart';
import 'reader_annotation_note_composer.dart';

class ReaderAnnotationNotesSheet extends StatefulWidget {
  const ReaderAnnotationNotesSheet({
    super.key,
    required this.item,
    required this.searchController,
    required this.isComposing,
    required this.composerVersion,
    required this.onBack,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onStartAddNote,
    required this.onAddNote,
    required this.onGoToLocation,
    required this.formatTimestamp,
  });

  final ReaderAnnotationCardItem item;
  final TextEditingController searchController;
  final bool isComposing;
  final int composerVersion;
  final VoidCallback onBack;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            MediaQuery.paddingOf(context).top + 12,
            12,
            8,
          ),
          child: Row(
            children: [
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
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.close),
                color: CommonDesignTokens.textPrimary,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 140),
            children: [
              Container(
                key: const ValueKey('mark-detail-quote-card'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CommonDesignTokens.borderColor),
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
                    autoFocus: widget.isComposing && !_hideComposerAfterSubmit,
                    isSubmitting: _isSubmitting,
                    onSubmit: _handleAddNote,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, bottomInset > 0 ? 12 : 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.82),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 15,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: ShelfDesignTokens.statsCardBg,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          key: const ValueKey('mark-detail-search-input'),
                          controller: widget.searchController,
                          onChanged: widget.onSearchChanged,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            hintText: 'Search',
                            hintStyle: const TextStyle(
                              color: CommonDesignTokens.textSecondary,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: CommonDesignTokens.textSecondary,
                            ),
                            suffixIcon: widget.searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: widget.onClearSearch,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    color: CommonDesignTokens.textSecondary,
                                  ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(
                            color: CommonDesignTokens.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: 'Add Note',
                      onTap: _isSubmitting ? null : widget.onStartAddNote,
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: 'Go to mark',
                      onTap: _isSubmitting ? null : widget.onGoToLocation,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? Colors.black26 : CommonDesignTokens.tabActiveBg,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
