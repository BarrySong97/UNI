import 'package:flutter/material.dart';

import '../../../entities/annotation-entity.dart';
import '../models/reader_annotation_card_item.dart';
import 'reader_annotation_card.dart';
import 'reader_annotation_notes_sheet.dart';

enum ReaderAnnotationSheetActionType { openLocation, addNote }

enum ReaderAnnotationSortMode { recentActivity, newestMarks, oldestMarks }

class ReaderAnnotationSheetResult {
  const ReaderAnnotationSheetResult({
    required this.type,
    required this.annotation,
  });

  final ReaderAnnotationSheetActionType type;
  final AnnotationEntity annotation;
}

class ReaderAnnotationSheet extends StatefulWidget {
  const ReaderAnnotationSheet({super.key, required this.items});

  final List<ReaderAnnotationCardItem> items;

  static Future<ReaderAnnotationSheetResult?> show({
    required BuildContext context,
    required List<ReaderAnnotationCardItem> items,
    bool isTablet = false,
    bool showOnLeft = false,
  }) {
    final sheet = ReaderAnnotationSheet(items: items);
    final mediaQuery = MediaQuery.of(context);

    return showModalBottomSheet<ReaderAnnotationSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: const Color(0xFFF7F7F5),
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
  bool _isSearchVisible = false;
  ReaderAnnotationCardItem? _selectedItem;

  List<ReaderAnnotationCardItem> get _visibleItems {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = widget.items
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        if (_isSearchVisible) _buildSearchField(),
        Expanded(
          child: _selectedItem == null
              ? _buildListView(context)
              : ReaderAnnotationNotesSheet(
                  item: _selectedItem!,
                  onBack: () => setState(() => _selectedItem = null),
                  onAddNote: () => Navigator.of(context).pop(
                    ReaderAnnotationSheetResult(
                      type: ReaderAnnotationSheetActionType.addNote,
                      annotation: _selectedItem!.annotation,
                    ),
                  ),
                  onGoToLocation: () => Navigator.of(context).pop(
                    ReaderAnnotationSheetResult(
                      type: ReaderAnnotationSheetActionType.openLocation,
                      annotation: _selectedItem!.annotation,
                    ),
                  ),
                  formatTimestamp: _formatRelativeTime,
                ),
        ),
        if (_selectedItem == null) _buildBottomBar(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final title = _selectedItem == null ? 'Marks' : 'Mark Details';
    final subtitle = _selectedItem == null ? '${widget.items.length}' : null;
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
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
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
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search marks',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () => setState(() => _searchQuery = ''),
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildListView(BuildContext context) {
    final items = _visibleItems;
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No marks found.',
            style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = items[index];
        return ReaderAnnotationCard(
          item: item,
          timestampText: _formatRelativeTime(item.activityTime),
          onTap: () => setState(() => _selectedItem = item),
          onGoToLocation: () => Navigator.of(context).pop(
            ReaderAnnotationSheetResult(
              type: ReaderAnnotationSheetActionType.openLocation,
              annotation: item.annotation,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            _BottomAction(
              icon: Icons.sort_rounded,
              label: 'Sort',
              onTap: () => _openSortMenu(context),
            ),
            _buildDivider(),
            const _BottomAction(
              icon: Icons.file_upload_outlined,
              label: 'Export',
              enabled: false,
            ),
            _buildDivider(),
            _BottomAction(
              icon: Icons.search_rounded,
              label: 'Search',
              highlighted: _isSearchVisible,
              onTap: () => setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchQuery = '';
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 28, color: Colors.white24);
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

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (highlighted ? const Color(0xFF60A5FA) : Colors.white)
        : Colors.white38;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
