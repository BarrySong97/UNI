import 'package:flutter/material.dart';

import '../../../pages/reader/models/reader_annotation_card_item.dart';
import 'reader_mark_detail_view.dart';

class ReaderAnnotationNotesSheet extends StatefulWidget {
  const ReaderAnnotationNotesSheet({
    super.key,
    required this.item,
    required this.isComposing,
    required this.composerVersion,
    required this.onBack,
    required this.onStartAddNote,
    required this.onCancelAddNote,
    required this.onAddNote,
    required this.onShare,
    required this.onDelete,
    required this.onGoToLocation,
    required this.formatTimestamp,
  });

  final ReaderAnnotationCardItem item;
  final bool isComposing;
  final int composerVersion;
  final VoidCallback onBack;
  final VoidCallback onStartAddNote;
  final VoidCallback onCancelAddNote;
  final Future<ReaderAnnotationCardItem> Function(String noteText) onAddNote;
  final Future<void> Function() onShare;
  final Future<bool> Function() onDelete;
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
  }

  Future<void> _handleAddNote(String noteText) async {
    setState(() {
      _isSubmitting = true;
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
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save note.')));
    }
  }

  Future<bool> _handleDelete() async {
    final confirmed = await showMarkDeleteConfirmation(context);
    if (!confirmed) {
      return false;
    }
    return widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return ReaderMarkDetailView(
      chapterTitle: _item.chapterTitle,
      quoteText: _item.annotation.quoteText,
      notes: _item.notes,
      isComposing: widget.isComposing,
      isSubmitting: _isSubmitting,
      composerVersion: widget.composerVersion,
      onBack: widget.onBack,
      onStartAddNote: widget.onStartAddNote,
      onCancelAddNote: widget.onCancelAddNote,
      onSubmitNote: _handleAddNote,
      onShare: widget.onShare,
      onDelete: _handleDelete,
      onGoToMark: widget.onGoToLocation,
      formatTimestamp: widget.formatTimestamp,
      noteInputKey: const ValueKey('mark-detail-note-input'),
    );
  }
}
