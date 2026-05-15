import 'package:flutter/material.dart';

import '../../../entities/annotation-note-entity.dart';
import '../../../shared/constants/common-design-tokens.dart';
import '../../../shared/constants/shelf-design-tokens.dart';
import 'reader_annotation_note_composer.dart';

class ReaderMarkDetailView extends StatelessWidget {
  const ReaderMarkDetailView({
    super.key,
    required this.chapterTitle,
    required this.quoteText,
    required this.notes,
    required this.isComposing,
    required this.isSubmitting,
    required this.composerVersion,
    required this.onBack,
    required this.onStartAddNote,
    required this.onCancelAddNote,
    required this.onSubmitNote,
    required this.onShare,
    required this.onDelete,
    required this.onGoToMark,
    required this.formatTimestamp,
    required this.noteInputKey,
  });

  final String chapterTitle;
  final String quoteText;
  final List<AnnotationNoteEntity> notes;
  final bool isComposing;
  final bool isSubmitting;
  final int composerVersion;
  final VoidCallback onBack;
  final VoidCallback onStartAddNote;
  final VoidCallback onCancelAddNote;
  final Future<void> Function(String noteText) onSubmitNote;
  final Future<void> Function() onShare;
  final Future<bool> Function() onDelete;
  final VoidCallback onGoToMark;
  final String Function(DateTime value) formatTimestamp;
  final Key noteInputKey;

  static const List<String> _serifFallback = <String>[
    'Georgia',
    'Times New Roman',
    'Noto Serif',
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final orderedNotes = List<AnnotationNoteEntity>.from(notes)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final latestNote = orderedNotes.isEmpty ? null : orderedNotes.last;
    final olderNotes = orderedNotes.length <= 1
        ? const <AnnotationNoteEntity>[]
        : orderedNotes.reversed.skip(1).toList(growable: false);
    final visibleOlderNotes = isComposing && olderNotes.isNotEmpty
        ? olderNotes.skip(1).toList(growable: false)
        : olderNotes;

    return ColoredBox(
      color: ShelfDesignTokens.statsCardBg,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 14,
                20,
                132,
              ),
              children: [
                _MarkDetailHeader(chapterTitle: chapterTitle, onBack: onBack),
                const SizedBox(height: 26),
                _EditorialQuoteBlock(quoteText: quoteText),
                const SizedBox(height: 18),
                _GoToMarkRow(onTap: onGoToMark),
                const SizedBox(height: 28),
                _ThoughtHeader(
                  isComposing: isComposing,
                  onAdd: onStartAddNote,
                  onCancel: onCancelAddNote,
                ),
                const SizedBox(height: 14),
                if (isComposing)
                  Container(
                    decoration: BoxDecoration(
                      color: CommonDesignTokens.cardBg,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ReaderAnnotationNoteEditor(
                      key: ValueKey<String>(
                        'mark-detail-note-editor-$composerVersion',
                      ),
                      inputKey: noteInputKey,
                      quoteText: quoteText,
                      autoFocus: true,
                      isSubmitting: isSubmitting,
                      onSubmit: onSubmitNote,
                    ),
                  )
                else if (latestNote != null)
                  _LatestThoughtCard(
                    note: latestNote,
                    timestampText: formatTimestamp(latestNote.createdAt),
                  )
                else
                  const _EmptyThoughtCard(),
                if (visibleOlderNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...visibleOlderNotes.map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ThoughtHistoryCard(
                        note: note,
                        timestampText: formatTimestamp(note.createdAt),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              bottomInset > 0 ? bottomInset + 12 : 16,
            ),
            child: _FloatingActionBar(
              isComposing: isComposing,
              onAdd: onStartAddNote,
              onCancel: onCancelAddNote,
              onShare: onShare,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> showMarkDeleteConfirmation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete mark?'),
        content: const Text('This removes the highlight and all of its notes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEA5A5A),
            ),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

class _MarkDetailHeader extends StatelessWidget {
  const _MarkDetailHeader({required this.chapterTitle, required this.onBack});

  final String chapterTitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: CommonDesignTokens.cardBg,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: CommonDesignTokens.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MARK DETAIL',
                key: ValueKey('mark-detail-title'),
                style: TextStyle(
                  color: Color(0xFF9AA4B5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                chapterTitle,
                key: const ValueKey('mark-detail-subtitle'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF556173),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorialQuoteBlock extends StatelessWidget {
  const _EditorialQuoteBlock({required this.quoteText});

  final String quoteText;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('mark-detail-editorial-quote'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '“',
            style: TextStyle(
              color: Color(0xFFD6CEC3),
              fontSize: 46,
              height: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            quoteText,
            style: const TextStyle(
              color: Color(0xFF2F2A24),
              fontSize: 27,
              height: 1.36,
              fontWeight: FontWeight.w500,
              fontFamilyFallback: ReaderMarkDetailView._serifFallback,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoToMarkRow extends StatelessWidget {
  const _GoToMarkRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('mark-detail-go-to-mark'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Expanded(
              child: Divider(thickness: 0.8, color: Color(0xFFD9D2C9)),
            ),
            const SizedBox(width: 14),
            Text(
              'GO TO THE MARK',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF9AA4B5),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThoughtHeader extends StatelessWidget {
  const _ThoughtHeader({
    required this.isComposing,
    required this.onAdd,
    required this.onCancel,
  });

  final bool isComposing;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'YOUR THOUGHT',
            style: TextStyle(
              color: Color(0xFF556173),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('mark-detail-header-add'),
          onPressed: isComposing ? onCancel : onAdd,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF9A744D),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(isComposing ? 'Cancel' : 'Add'),
        ),
      ],
    );
  }
}

class _LatestThoughtCard extends StatelessWidget {
  const _LatestThoughtCard({required this.note, required this.timestampText});

  final AnnotationNoteEntity note;
  final String timestampText;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('mark-detail-latest-note-card'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.text,
            style: const TextStyle(
              color: Color(0xFF49566A),
              fontSize: 18,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            timestampText,
            style: const TextStyle(
              color: Color(0xFFC5BEB3),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyThoughtCard extends StatelessWidget {
  const _EmptyThoughtCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('mark-detail-empty-note-card'),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Text(
        'No thoughts yet. Add one to capture why this line matters.',
        style: TextStyle(
          color: CommonDesignTokens.textSecondary,
          fontSize: 16,
          height: 1.55,
        ),
      ),
    );
  }
}

class _ThoughtHistoryCard extends StatelessWidget {
  const _ThoughtHistoryCard({required this.note, required this.timestampText});

  final AnnotationNoteEntity note;
  final String timestampText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4EF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5DED4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.text,
            style: const TextStyle(
              color: Color(0xFF5B6678),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            timestampText,
            style: const TextStyle(
              color: Color(0xFFB1A89A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingActionBar extends StatelessWidget {
  const _FloatingActionBar({
    required this.isComposing,
    required this.onAdd,
    required this.onCancel,
    required this.onShare,
    required this.onDelete,
  });

  final bool isComposing;
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  final Future<void> Function() onShare;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFEAE3D8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _BarAction(
              key: const ValueKey('mark-detail-action-add'),
              icon: isComposing
                  ? Icons.close_rounded
                  : Icons.add_circle_outline_rounded,
              label: isComposing ? 'Cancel' : 'Add',
              color: const Color(0xFF94A0B1),
              onTap: isComposing ? onCancel : onAdd,
            ),
          ),
          Expanded(
            child: _BarAction(
              key: const ValueKey('mark-detail-action-share'),
              icon: Icons.ios_share_rounded,
              label: 'Share',
              color: const Color(0xFF94A0B1),
              onTap: () {
                onShare();
              },
            ),
          ),
          Expanded(
            child: _BarAction(
              key: const ValueKey('mark-detail-action-delete'),
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: const Color(0xFFF27C72),
              onTap: () {
                onDelete();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
