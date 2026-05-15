import 'package:flutter/material.dart';

import '../../../pages/reader/models/reader_annotation_card_item.dart';
import '../../../shared/constants/shelf-design-tokens.dart';
import 'reader_mark_detail_view.dart';

class ReaderFocusedAnnotationSheet extends StatefulWidget {
  const ReaderFocusedAnnotationSheet({
    super.key,
    required this.item,
    required this.onAddNote,
    required this.onShare,
    required this.onDelete,
    required this.onGoToLocation,
    required this.formatTimestamp,
  });

  final ReaderAnnotationCardItem item;
  final Future<ReaderAnnotationCardItem> Function(String noteText) onAddNote;
  final Future<void> Function() onShare;
  final Future<bool> Function() onDelete;
  final VoidCallback onGoToLocation;
  final String Function(DateTime value) formatTimestamp;

  static Future<void> show({
    required BuildContext context,
    required ReaderAnnotationCardItem item,
    required Future<ReaderAnnotationCardItem> Function(String noteText)
    onAddNote,
    required Future<void> Function() onShare,
    required Future<bool> Function() onDelete,
    required VoidCallback onGoToLocation,
    required String Function(DateTime value) formatTimestamp,
    bool isTablet = false,
    bool showOnLeft = false,
  }) {
    final sheet = ReaderFocusedAnnotationSheet(
      item: item,
      onAddNote: onAddNote,
      onShare: onShare,
      onDelete: onDelete,
      onGoToLocation: onGoToLocation,
      formatTimestamp: formatTimestamp,
    );

    if (!isTablet) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        backgroundColor: ShelfDesignTokens.statsCardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => sheet,
      );
    }

    const panelMargin = 20.0;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss mark detail',
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
              color: ShelfDesignTokens.statsCardBg,
              borderRadius: BorderRadius.circular(28),
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
    final deleted = await widget.onDelete();
    if (!mounted || !deleted) {
      return deleted;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    return true;
  }

  void _handleGoToMark() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    widget.onGoToLocation();
  }

  @override
  Widget build(BuildContext context) {
    return ReaderMarkDetailView(
      chapterTitle: _item.chapterTitle,
      quoteText: _item.annotation.quoteText,
      notes: _item.notes,
      isComposing: _isComposing,
      isSubmitting: _isSubmittingNote,
      composerVersion: _isComposing ? 1 : 0,
      onBack: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      onStartAddNote: () => setState(() => _isComposing = true),
      onCancelAddNote: () => setState(() => _isComposing = false),
      onSubmitNote: _handleAddNote,
      onShare: widget.onShare,
      onDelete: _handleDelete,
      onGoToMark: _handleGoToMark,
      formatTimestamp: widget.formatTimestamp,
      noteInputKey: const ValueKey('focused-mark-note-input'),
    );
  }
}
