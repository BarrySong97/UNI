import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../entities/annotation-entity.dart';
import '../../entities/annotation-note-entity.dart';
import '../../entities/book-entity.dart';
import '../../components/library/library-book-grid.dart';
import '../../components/library/library-header.dart';
import '../../services/library/book-profile-entry-service.dart';
import '../../services/reader/annotation/annotation_models.dart';
import '../../services/reader/reader_navigation_target.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';
import '../../shared/layout/responsive_layout.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool _isNavigating = false;
  _LibraryContentTab _selectedTab = _LibraryContentTab.books;
  Future<List<_LibraryNoteGroup>>? _notesFuture;
  String _notesBookSignature = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppProvidersScope.of(context).libraryStore.loadShelf();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = AppProvidersScope.of(context).libraryStore;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final state = store.state;
        final lastImportedBookId = state.lastImportedBookId;
        if (lastImportedBookId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            store.clearLastImportedBookId();
          });
        }

        if (state.isLoading) {
          return Container(
            color: CommonDesignTokens.pageBackground,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        _ensureNotesFuture(state.books);

        return Stack(
          children: <Widget>[
            Container(
              color: CommonDesignTokens.pageBackground,
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: 120,
                  ),
                  child: ResponsiveContentWrapper(
                    maxWidth: kWideContentMaxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        LibraryHeader(
                          headerTitle: 'Library',
                          showImportButton: true,
                          isImporting: state.isImporting,
                          onImportTap: () => _pickAndImportBook(context),
                        ),
                        const SizedBox(height: 18),
                        _LibraryContentTabs(
                          selectedTab: _selectedTab,
                          onChanged: (tab) {
                            if (_selectedTab == tab) {
                              return;
                            }
                            setState(() {
                              _selectedTab = tab;
                              if (tab == _LibraryContentTab.notes) {
                                _refreshNotesFuture(state.books);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        if (_selectedTab == _LibraryContentTab.books)
                          LibraryBookGrid(
                            books: state.filteredBooks,
                            progressMap: state.progressMap,
                            onBookTap: (book) => _openBook(book.id),
                            categories: state.categories,
                            activeCategory: state.activeCategory,
                            onCategoryTap: (category) =>
                                store.setCategory(category),
                            lastImportedBookId: lastImportedBookId,
                          )
                        else
                          _buildNotesView(state.books),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (state.isImporting)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: CommonDesignTokens.pageBackground,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      CommonDesignTokens.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNotesView(List<BookEntity> books) {
    final future =
        _notesFuture ??
        Future<List<_LibraryNoteGroup>>.value(const <_LibraryNoteGroup>[]);
    return FutureBuilder<List<_LibraryNoteGroup>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final entries = snapshot.data ?? const <_LibraryNoteGroup>[];
        if (books.isEmpty) {
          return const _LibraryNotesEmptyState(
            message: 'Import a book to start collecting notes.',
          );
        }
        if (entries.isEmpty) {
          return const _LibraryNotesEmptyState(
            message:
                'No notes yet. Add notes in Reader and they will appear here.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final cardWidth = constraints.maxWidth <= spacing
                ? constraints.maxWidth
                : (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final entry in entries)
                  SizedBox(
                    width: cardWidth,
                    child: _LibraryNoteCard(
                      group: entry,
                      onViewAll: () => _openNoteGroupDetails(entry),
                      onGoToPosition: () => _openNotePosition(entry),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _ensureNotesFuture(List<BookEntity> books) {
    final signature = _buildBookSignature(books);
    if (_notesFuture == null) {
      _refreshNotesFuture(books);
      return;
    }
    if (_notesBookSignature != signature) {
      _refreshNotesFuture(books);
    }
  }

  void _refreshNotesFuture(List<BookEntity> books) {
    _notesBookSignature = _buildBookSignature(books);
    _notesFuture = _loadNoteEntries(books);
  }

  String _buildBookSignature(List<BookEntity> books) {
    return books
        .map((book) => '${book.id}:${book.updatedAt.microsecondsSinceEpoch}')
        .join('|');
  }

  Future<List<_LibraryNoteGroup>> _loadNoteEntries(
    List<BookEntity> books,
  ) async {
    final repository = AppProvidersScope.of(context).annotationRepository;
    final groupsByBook = await Future.wait(
      books.map((book) async {
        final results = await Future.wait([
          repository.listByBookId(book.id),
          repository.listNotesByBookId(book.id),
        ]);
        final annotations = results[0] as List<AnnotationEntity>;
        final notes = results[1] as List<AnnotationNoteEntity>;
        final annotationsById = <String, AnnotationEntity>{
          for (final annotation in annotations)
            if (annotation.kind == AnnotationKind.mark)
              annotation.id: annotation,
        };
        final notesByAnnotationId = <String, List<AnnotationNoteEntity>>{};
        for (final note in notes) {
          if (note.text.trim().isEmpty ||
              !annotationsById.containsKey(note.annotationId)) {
            continue;
          }
          notesByAnnotationId
              .putIfAbsent(note.annotationId, () => <AnnotationNoteEntity>[])
              .add(note);
        }

        return notesByAnnotationId.entries
            .map((entry) {
              final groupNotes = List<AnnotationNoteEntity>.from(entry.value)
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
              final annotation = annotationsById[entry.key]!;
              final anchor = AnnotationAnchorV1.tryParse(annotation.anchorJson);
              final jumpTarget = anchor?.jumpTarget;
              return _LibraryNoteGroup(
                book: book,
                annotation: annotation,
                notes: List<AnnotationNoteEntity>.unmodifiable(groupNotes),
                jumpChapterIndex: jumpTarget?.chapterIndex ?? -1,
                jumpBlockIndex: jumpTarget?.blockIndex ?? -1,
              );
            })
            .toList(growable: false);
      }),
    );

    final groups = groupsByBook.expand((items) => items).toList(growable: false)
      ..sort(
        (a, b) => b.latestNote.createdAt.compareTo(a.latestNote.createdAt),
      );
    return groups;
  }

  Future<void> _pickAndImportBook(BuildContext context) async {
    final store = AppProvidersScope.of(context).libraryStore;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>[
        'epub',
        'txt',
        'pdf',
        'mobi',
        'azw',
        'azw3',
        'fb2',
      ],
      allowMultiple: false,
    );
    if (!mounted || picked == null || picked.files.single.path == null) {
      return;
    }

    await store.importBookFromPath(picked.files.single.path!);
  }

  Future<void> _openBook(String bookId) async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    try {
      final providers = AppProvidersScope.of(context);
      final progressMap = providers.libraryStore.state.progressMap;
      final target = providers.bookProfileEntryService.resolveEntry(
        bookId,
        progressMap,
      );
      if (!mounted) return;
      switch (target) {
        case BookProfileEntryTarget.profile:
          await Navigator.of(
            context,
          ).pushNamed(RouteNames.bookDetail, arguments: bookId);
          break;
        case BookProfileEntryTarget.reader:
          await providers.readerEntryService.openBook(context, bookId);
          break;
      }
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _openNotePosition(_LibraryNoteGroup group) async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    try {
      final providers = AppProvidersScope.of(context);
      final progressMap = providers.libraryStore.state.progressMap;
      final target = providers.bookProfileEntryService.resolveEntry(
        group.book.id,
        progressMap,
      );
      if (!mounted) return;
      switch (target) {
        case BookProfileEntryTarget.profile:
          await Navigator.of(
            context,
          ).pushNamed(RouteNames.bookDetail, arguments: group.book.id);
          break;
        case BookProfileEntryTarget.reader:
          await providers.readerEntryService.openBook(
            context,
            group.book.id,
            navigationTarget: ReaderNavigationTarget(
              source: 'library_notes',
              annotationId: group.annotation.id,
              noteId: group.latestNote.id,
              chapterIndex: group.jumpChapterIndex,
              blockIndex: group.jumpBlockIndex,
              quoteText: group.annotation.quoteText,
              noteText: group.latestNote.text,
            ),
          );
          break;
      }
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _openNoteGroupDetails(_LibraryNoteGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _LibraryNoteGroupDetailPage(
          group: group,
          onGoToPosition: () => _openNotePosition(group),
        ),
      ),
    );
  }
}

enum _LibraryContentTab { books, notes }

class _LibraryNoteGroup {
  const _LibraryNoteGroup({
    required this.book,
    required this.annotation,
    required this.notes,
    required this.jumpChapterIndex,
    required this.jumpBlockIndex,
  });

  final BookEntity book;
  final AnnotationEntity annotation;
  final List<AnnotationNoteEntity> notes;
  final int jumpChapterIndex;
  final int jumpBlockIndex;

  AnnotationNoteEntity get latestNote => notes.last;

  String get chapterLabel => jumpChapterIndex >= 0
      ? 'Chapter ${jumpChapterIndex + 1}'
      : 'Unknown chapter';

  List<AnnotationNoteEntity> get previewNotes {
    return <AnnotationNoteEntity>[latestNote];
  }

  int get hiddenNoteCount {
    final hidden = notes.length - previewNotes.length;
    return hidden > 0 ? hidden : notes.length;
  }

  String get viewAllLabel => 'Show all';
}

class _LibraryContentTabs extends StatelessWidget {
  const _LibraryContentTabs({
    required this.selectedTab,
    required this.onChanged,
  });

  final _LibraryContentTab selectedTab;
  final ValueChanged<_LibraryContentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('library-content-tabs'),
        width: 240,
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE9E4DB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _LibraryContentTabButton(
                label: 'Books',
                selected: selectedTab == _LibraryContentTab.books,
                onTap: () => onChanged(_LibraryContentTab.books),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _LibraryContentTabButton(
                label: 'Notes',
                selected: selectedTab == _LibraryContentTab.notes,
                onTap: () => onChanged(_LibraryContentTab.notes),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryContentTabButton extends StatelessWidget {
  const _LibraryContentTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? CommonDesignTokens.textPrimary
                  : CommonDesignTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryNoteCard extends StatelessWidget {
  const _LibraryNoteCard({
    required this.group,
    required this.onGoToPosition,
    this.onViewAll,
  });

  final _LibraryNoteGroup group;
  final VoidCallback onGoToPosition;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 260;
        return Container(
          key: ValueKey('library-note-card-${group.annotation.id}'),
          decoration: BoxDecoration(
            color: ShelfDesignTokens.statsCardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7DED1)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LibraryBookBadge(book: group.book),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CommonDesignTokens.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group.chapterLabel} • ${_formatLibraryNoteDate(group.latestNote.createdAt)}',
                          style: const TextStyle(
                            color: CommonDesignTokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LibraryQuoteBlock(quoteText: group.annotation.quoteText),
              const SizedBox(height: 14),
              ...List<Widget>.generate(group.previewNotes.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LibraryNotePreviewRow(
                    note: group.previewNotes[index],
                    showConnector: index < group.previewNotes.length - 1,
                    showMarker: false,
                  ),
                );
              }),
              const SizedBox(height: 6),
              const Divider(color: Color(0xFFE7DED1), height: 1),
              const SizedBox(height: 14),
              if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      key: ValueKey(
                        'library-note-view-all-${group.annotation.id}',
                      ),
                      onPressed: onViewAll,
                      style: TextButton.styleFrom(
                        foregroundColor: CommonDesignTokens.textSecondary,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(group.viewAllLabel),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: ValueKey(
                          'library-note-go-to-${group.annotation.id}',
                        ),
                        onPressed: onGoToPosition,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF141D30),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Go to Position'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    TextButton(
                      key: ValueKey(
                        'library-note-view-all-${group.annotation.id}',
                      ),
                      onPressed: onViewAll,
                      style: TextButton.styleFrom(
                        foregroundColor: CommonDesignTokens.textSecondary,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(group.viewAllLabel),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: ValueKey(
                        'library-note-go-to-${group.annotation.id}',
                      ),
                      onPressed: onGoToPosition,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF141D30),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Go to Position'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LibraryBookBadge extends StatelessWidget {
  const _LibraryBookBadge({required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final initials = book.title.trim().isEmpty
        ? 'B'
        : book.title.trim().substring(0, 1).toUpperCase();
    return Container(
      width: 42,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFD8F7EA), Color(0xFFF5FBFF)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: CommonDesignTokens.textPrimary,
        ),
      ),
    );
  }
}

class _LibraryQuoteBlock extends StatelessWidget {
  const _LibraryQuoteBlock({required this.quoteText});

  final String quoteText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3E7),
        border: const Border(
          left: BorderSide(color: Color(0xFFE8BF4E), width: 4),
        ),
      ),
      child: Text(
        '“$quoteText”',
        style: const TextStyle(
          color: Color(0xFF3C4452),
          fontSize: 16,
          height: 1.55,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LibraryNotePreviewRow extends StatelessWidget {
  const _LibraryNotePreviewRow({
    required this.note,
    this.showConnector = true,
    this.showMarker = true,
  });

  final AnnotationNoteEntity note;
  final bool showConnector;
  final bool showMarker;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMarker) ...[
          Column(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF182033),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 1,
                height: 52,
                color: showConnector
                    ? const Color(0xFFE0DBD2)
                    : Colors.transparent,
              ),
            ],
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.text,
                style: const TextStyle(
                  color: Color(0xFF49566A),
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatLibraryNoteTime(note.createdAt),
                style: const TextStyle(
                  color: CommonDesignTokens.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LibraryNoteGroupDetailPage extends StatelessWidget {
  const _LibraryNoteGroupDetailPage({
    required this.group,
    required this.onGoToPosition,
  });

  final _LibraryNoteGroup group;
  final VoidCallback onGoToPosition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommonDesignTokens.pageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 140),
                child: ResponsiveContentWrapper(
                  maxWidth: kWideContentMaxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Material(
                            color: ShelfDesignTokens.statsCardBg,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => Navigator.of(context).maybePop(),
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
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'All Notes',
                              style: TextStyle(
                                color: CommonDesignTokens.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        key: ValueKey(
                          'library-note-detail-card-${group.annotation.id}',
                        ),
                        decoration: BoxDecoration(
                          color: ShelfDesignTokens.statsCardBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE7DED1)),
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _LibraryBookBadge(book: group.book),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.book.title,
                                        style: const TextStyle(
                                          color: CommonDesignTokens.textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${group.chapterLabel} • ${_formatLibraryNoteDate(group.latestNote.createdAt)}',
                                        style: const TextStyle(
                                          color:
                                              CommonDesignTokens.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _LibraryQuoteBlock(
                              quoteText: group.annotation.quoteText,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              '${group.notes.length} notes',
                              style: const TextStyle(
                                color: CommonDesignTokens.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ...List<Widget>.generate(group.notes.length, (
                              index,
                            ) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == group.notes.length - 1
                                      ? 0
                                      : 12,
                                ),
                                child: _LibraryNotePreviewRow(
                                  note: group.notes[index],
                                  showConnector: index < group.notes.length - 1,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: ResponsiveContentWrapper(
                maxWidth: kWideContentMaxWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    key: ValueKey(
                      'library-note-detail-go-to-${group.annotation.id}',
                    ),
                    onPressed: onGoToPosition,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF141D30),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Go to Position'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryNotesEmptyState extends StatelessWidget {
  const _LibraryNotesEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      decoration: BoxDecoration(
        color: ShelfDesignTokens.statsCardBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: CommonDesignTokens.textSecondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }
}

String _formatLibraryNoteTime(DateTime value) {
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
  return '$month/$day';
}

String _formatLibraryNoteDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month/$day';
}
