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
  Future<List<_LibraryNoteEntry>>? _notesFuture;
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
        Future<List<_LibraryNoteEntry>>.value(const <_LibraryNoteEntry>[]);
    return FutureBuilder<List<_LibraryNoteEntry>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final entries = snapshot.data ?? const <_LibraryNoteEntry>[];
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

        return Column(
          children: [
            for (int i = 0; i < entries.length; i++) ...[
              _LibraryNoteCard(
                entry: entries[i],
                onTap: () => _openBook(entries[i].book.id),
              ),
              if (i < entries.length - 1) const SizedBox(height: 12),
            ],
          ],
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

  Future<List<_LibraryNoteEntry>> _loadNoteEntries(
    List<BookEntity> books,
  ) async {
    final repository = AppProvidersScope.of(context).annotationRepository;
    final entriesByBook = await Future.wait(
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
        return notes
            .where(
              (note) =>
                  note.text.trim().isNotEmpty &&
                  annotationsById.containsKey(note.annotationId),
            )
            .map(
              (note) => _LibraryNoteEntry(
                book: book,
                annotation: annotationsById[note.annotationId]!,
                note: note,
              ),
            )
            .toList(growable: false);
      }),
    );

    final entries =
        entriesByBook.expand((items) => items).toList(growable: false)
          ..sort((a, b) => b.note.createdAt.compareTo(a.note.createdAt));
    return entries;
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
}

enum _LibraryContentTab { books, notes }

class _LibraryNoteEntry {
  const _LibraryNoteEntry({
    required this.book,
    required this.annotation,
    required this.note,
  });

  final BookEntity book;
  final AnnotationEntity annotation;
  final AnnotationNoteEntity note;
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
  const _LibraryNoteCard({required this.entry, required this.onTap});

  final _LibraryNoteEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('library-note-card-${entry.note.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
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
                children: [
                  Expanded(
                    child: Text(
                      entry.book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CommonDesignTokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatLibraryNoteTime(entry.note.createdAt),
                    style: const TextStyle(
                      color: CommonDesignTokens.headerLabelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (entry.book.author.isNotEmpty &&
                  entry.book.author != 'Unknown') ...[
                const SizedBox(height: 2),
                Text(
                  entry.book.author,
                  style: const TextStyle(
                    color: CommonDesignTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                entry.note.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF49566A),
                  fontSize: 16,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '"${entry.annotation.quoteText}"',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CommonDesignTokens.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
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
