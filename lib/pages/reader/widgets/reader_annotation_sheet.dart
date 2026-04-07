import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../entities/annotation-entity.dart';
import '../../../services/reader/annotation/annotation_models.dart';

class ReaderAnnotationSheet extends StatelessWidget {
  const ReaderAnnotationSheet({
    super.key,
    required this.annotations,
    required this.chapterTitleAt,
  });

  final List<AnnotationEntity> annotations;
  final String Function(int chapterIndex) chapterTitleAt;

  static Future<AnnotationEntity?> show({
    required BuildContext context,
    required List<AnnotationEntity> annotations,
    required String Function(int chapterIndex) chapterTitleAt,
    bool isTablet = false,
    bool showOnLeft = false,
  }) {
    final sorted = List<AnnotationEntity>.from(annotations)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final sheet = ReaderAnnotationSheet(
      annotations: sorted,
      chapterTitleAt: chapterTitleAt,
    );

    return showGeneralDialog<AnnotationEntity?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss marks',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) {
        final mq = MediaQuery.of(dialogContext);
        const panelMargin = 20.0;
        final panelWidth = isTablet
            ? math.min(420.0, mq.size.width * 0.4)
            : math.min(420.0, mq.size.width * 0.88);

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
              borderRadius: BorderRadius.circular(16),
              elevation: 12,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: panelWidth,
                height: mq.size.height - panelMargin * 2,
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
          child: Row(
            children: [
              Text(
                'Marks',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${annotations.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: annotations.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No marks yet.',
                      style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: annotations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final annotation = annotations[index];
                    final anchor = AnnotationAnchorV1.tryParse(
                      annotation.anchorJson,
                    );
                    final chapterTitle = anchor == null
                        ? 'Unknown chapter'
                        : chapterTitleAt(anchor.jumpTarget.chapterIndex);
                    final note = annotation.note?.trim();

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).pop(annotation),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapterTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              annotation.quoteText,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: Color(0xFF111827),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (note != null && note.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                note,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              _formatTimestamp(annotation.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

String _formatTimestamp(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}
