import 'package:flutter/material.dart';

import '../../../entities/annotation-entity.dart';
import '../../../shared/constants/common-design-tokens.dart';
import '../../../shared/constants/shelf-design-tokens.dart';
import '../models/reader_annotation_card_item.dart';
import 'reader_annotation_card.dart';
import 'reader_annotation_notes_sheet.dart';

enum ReaderAnnotationSheetActionType { openLocation }

enum ReaderAnnotationSortMode { recentActivity, newestMarks, oldestMarks }

class ReaderAnnotationSheetResult {
  const ReaderAnnotationSheetResult({
    required this.type,
    required this.annotation,
  });

  final ReaderAnnotationSheetActionType type;
  final AnnotationEntity annotation;
}

class _ChapterGroup {
  _ChapterGroup({
    required this.chapterTitle,
    required this.chapterIndex,
    required this.items,
  });

  final String chapterTitle;
  final int chapterIndex;
  final List<ReaderAnnotationCardItem> items;

  int get markCount => items.length;
}

class ReaderAnnotationSheet extends StatefulWidget {
  const ReaderAnnotationSheet({
    super.key,
    required this.items,
    required this.onAddNote,
  });

  final List<ReaderAnnotationCardItem> items;
  final Future<ReaderAnnotationCardItem> Function(
    ReaderAnnotationCardItem item,
    String noteText,
  )
  onAddNote;

  static Future<ReaderAnnotationSheetResult?> show({
    required BuildContext context,
    required List<ReaderAnnotationCardItem> items,
    required Future<ReaderAnnotationCardItem> Function(
      ReaderAnnotationCardItem item,
      String noteText,
    )
    onAddNote,
    bool isTablet = false,
    bool showOnLeft = false,
  }) {
    final sheet = ReaderAnnotationSheet(items: items, onAddNote: onAddNote);
    final mediaQuery = MediaQuery.of(context);

    return showModalBottomSheet<ReaderAnnotationSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: CommonDesignTokens.pageBackground,
      barrierColor: Colors.black26,
      constraints: BoxConstraints(maxWidth: mediaQuery.size.width),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetContext) {
        final mq = MediaQuery.of(sheetContext);
        return SizedBox(
          width: double.infinity,
          height: mq.size.height,
          child: sheet,
        );
      },
    );
  }

  @override
  State<ReaderAnnotationSheet> createState() => _ReaderAnnotationSheetState();
}

class _ReaderAnnotationSheetState extends State<ReaderAnnotationSheet> {
  ReaderAnnotationSortMode _sortMode = ReaderAnnotationSortMode.recentActivity;
  String _searchQuery = '';
  late final TextEditingController _searchController;
  late Set<int> _expandedChapters;
  late List<ReaderAnnotationCardItem> _items;
  ReaderAnnotationCardItem? _selectedItem;
  bool _isDetailComposerOpen = false;
  int _detailComposerVersion = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _items = List<ReaderAnnotationCardItem>.from(widget.items);
    _expandedChapters = _items.map((e) => e.chapterIndex).toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReaderAnnotationCardItem> get _filteredItems {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _items
        .where((item) {
          if (query.isEmpty) return true;
          if (item.annotation.quoteText.toLowerCase().contains(query)) {
            return true;
          }
          return item.notes.any(
            (note) => note.text.toLowerCase().contains(query),
          );
        })
        .toList(growable: false);

    filtered.sort((a, b) {
      switch (_sortMode) {
        case ReaderAnnotationSortMode.recentActivity:
          return b.activityTime.compareTo(a.activityTime);
        case ReaderAnnotationSortMode.newestMarks:
          return b.annotation.createdAt.compareTo(a.annotation.createdAt);
        case ReaderAnnotationSortMode.oldestMarks:
          return a.annotation.createdAt.compareTo(b.annotation.createdAt);
      }
    });
    return filtered;
  }

  List<_ChapterGroup> get _groupedItems {
    final items = _filteredItems;
    final Map<int, _ChapterGroup> groupMap = {};

    for (final item in items) {
      groupMap
          .putIfAbsent(
            item.chapterIndex,
            () => _ChapterGroup(
              chapterTitle: item.chapterTitle,
              chapterIndex: item.chapterIndex,
              items: [],
            ),
          )
          .items
          .add(item);
    }

    final groups = groupMap.values.toList();
    groups.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedItem == null) {
      return Column(
        children: [
          _buildHeader(context),
          _buildSearchField(),
          Expanded(child: _buildGroupedListView(context)),
        ],
      );
    }

    return ReaderAnnotationNotesSheet(
      item: _selectedItem!,
      searchController: _searchController,
      isComposing: _isDetailComposerOpen,
      composerVersion: _detailComposerVersion,
      onBack: () => setState(() {
        _selectedItem = null;
        _isDetailComposerOpen = false;
      }),
      onSearchChanged: (value) => setState(() => _searchQuery = value),
      onClearSearch: () {
        _searchController.clear();
        setState(() => _searchQuery = '');
      },
      onStartAddNote: () => setState(() {
        _isDetailComposerOpen = true;
        _detailComposerVersion += 1;
      }),
      onAddNote: (noteText) async {
        setState(() {
          _isDetailComposerOpen = false;
          _detailComposerVersion += 1;
        });
        final updated = await widget.onAddNote(_selectedItem!, noteText);
        if (!mounted) {
          return updated;
        }
        setState(() {
          final index = _items.indexWhere(
            (item) => item.annotation.id == updated.annotation.id,
          );
          if (index >= 0) {
            _items[index] = updated;
          }
          _selectedItem = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _selectedItem = updated;
          });
        });
        return updated;
      },
      onGoToLocation: () => Navigator.of(context).pop(
        ReaderAnnotationSheetResult(
          type: ReaderAnnotationSheetActionType.openLocation,
          annotation: _selectedItem!.annotation,
        ),
      ),
      formatTimestamp: _formatRelativeTime,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final title = _selectedItem == null ? 'Marks' : 'Mark Details';
    final subtitle = _selectedItem == null ? '${_items.length}' : null;
    final topInset = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: CommonDesignTokens.borderColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: CommonDesignTokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: CommonDesignTokens.headerLabelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              if (_selectedItem == null)
                IconButton(
                  onPressed: () => _openSortMenu(context),
                  icon: const Icon(Icons.sort_rounded),
                  color: CommonDesignTokens.textSecondary,
                ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                color: CommonDesignTokens.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: TextField(
        key: const ValueKey('marks-search-input'),
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search marks',
          hintStyle: const TextStyle(color: CommonDesignTokens.textSecondary),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: CommonDesignTokens.textSecondary,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: ShelfDesignTokens.statsCardBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: CommonDesignTokens.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: CommonDesignTokens.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: CommonDesignTokens.headerLabelColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedListView(BuildContext context) {
    final groups = _groupedItems;
    if (groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No marks found.',
            style: TextStyle(
              fontSize: 15,
              color: CommonDesignTokens.textSecondary,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final isExpanded = _expandedChapters.contains(group.chapterIndex);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChapterSectionHeader(
              title: group.chapterTitle,
              markCount: group.markCount,
              isExpanded: isExpanded,
              onToggle: () {
                setState(() {
                  if (isExpanded) {
                    _expandedChapters.remove(group.chapterIndex);
                  } else {
                    _expandedChapters.add(group.chapterIndex);
                  }
                });
              },
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: isExpanded
                  ? Column(
                      children: [
                        for (int i = 0; i < group.items.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          ReaderAnnotationCard(
                            item: group.items[i],
                            timestampText: _formatRelativeTime(
                              group.items[i].activityTime,
                            ),
                            onTap: () => setState(() {
                              _selectedItem = group.items[i];
                              _isDetailComposerOpen = false;
                            }),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSortMenu(BuildContext context) async {
    final selected = await showModalBottomSheet<ReaderAnnotationSortMode>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SortOptionTile(
                label: 'Recent activity',
                selected: _sortMode == ReaderAnnotationSortMode.recentActivity,
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(ReaderAnnotationSortMode.recentActivity),
              ),
              _SortOptionTile(
                label: 'Newest marks',
                selected: _sortMode == ReaderAnnotationSortMode.newestMarks,
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(ReaderAnnotationSortMode.newestMarks),
              ),
              _SortOptionTile(
                label: 'Oldest marks',
                selected: _sortMode == ReaderAnnotationSortMode.oldestMarks,
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(ReaderAnnotationSortMode.oldestMarks),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      setState(() => _sortMode = selected);
    }
  }
}

class _ChapterSectionHeader extends StatelessWidget {
  const _ChapterSectionHeader({
    required this.title,
    required this.markCount,
    required this.isExpanded,
    required this.onToggle,
  });

  final String title;
  final int markCount;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
        child: Row(
          children: [
            AnimatedRotation(
              turns: isExpanded ? 0.25 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.chevron_right,
                size: 20,
                color: CommonDesignTokens.headerLabelColor,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: CommonDesignTokens.headerLabelColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: ShelfDesignTokens.statsCardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$markCount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ShelfDesignTokens.statsNumberColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check_rounded) : null,
      onTap: onTap,
    );
  }
}

String _formatRelativeTime(DateTime value) {
  final now = DateTime.now();
  final diff = now.difference(value);
  if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
    return '$minutes min ago';
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }
  if (diff.inDays < 7) {
    final days = diff.inDays;
    return days == 1 ? '1 day ago' : '$days days ago';
  }
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}
