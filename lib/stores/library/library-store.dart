import 'package:flutter/foundation.dart';
import 'dart:convert';

import '../../entities/book-entity.dart';
import '../../entities/chapter-entity.dart';
import '../../repositories/book/book-repository.dart';
import '../../repositories/chapter/chapter-repository.dart';
import '../../services/library/book-profile-color-service.dart';
import '../../services/parser/book-import-service.dart';
import 'library-state.dart';

class LibraryStore extends ChangeNotifier {
  LibraryStore({
    required BookRepository bookRepository,
    required ChapterRepository chapterRepository,
    required BookImportService bookImportService,
    BookProfileColorService? bookProfileColorService,
  }) : _bookRepository = bookRepository,
       _chapterRepository = chapterRepository,
       _bookImportService = bookImportService,
       _bookProfileColorService =
           bookProfileColorService ?? const BookProfileColorService();

  final BookRepository _bookRepository;
  final ChapterRepository _chapterRepository;
  final BookImportService _bookImportService;
  final BookProfileColorService _bookProfileColorService;
  LibraryState _state = LibraryState.initial();

  LibraryState get state => _state;

  Future<void> loadShelf() async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final books = await _bookRepository.getShelfBooks();
      _state = _state.copyWith(
        books: books,
        filteredBooks: _filterByCategory(books, _state.activeCategory),
        isLoading: false,
        errorMessage: null,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> importBookFromPath(String filePath) async {
    _state = _state.copyWith(
      isImporting: true,
      lastImportMessage: null,
      errorMessage: null,
    );
    notifyListeners();

    try {
      final imported = await _bookImportService.importFromPath(filePath);
      final now = DateTime.now();
      final bookId = 'book_${now.microsecondsSinceEpoch}';
      final coverBytes = _decodeCoverDataUrl(imported.coverUrl);
      final profileBgColor = await _bookProfileColorService
          .resolveProfileBgColorHex(coverBytes);
      final book = BookEntity(
        id: bookId,
        title: imported.title,
        author: imported.author,
        coverUrl: imported.coverUrl,
        profileBgColor: profileBgColor,
        sourceType: imported.sourceType,
        sourcePath: imported.sourcePath,
        createdAt: now,
        updatedAt: now,
      );
      await _bookRepository.upsertBook(book);

      for (var i = 0; i < imported.chapters.length; i++) {
        final chapter = imported.chapters[i];
        await _chapterRepository.upsertChapter(
          ChapterEntity(
            id: '${bookId}_chapter_$i',
            bookId: bookId,
            idx: i,
            title: chapter.title,
            content: chapter.content,
            wordCount: chapter.content.length,
          ),
        );
      }

      final books = await _bookRepository.getShelfBooks();
      _state = _state.copyWith(
        books: books,
        filteredBooks: _filterByCategory(books, _state.activeCategory),
        isImporting: false,
        lastImportMessage: 'Imported ${imported.title} (${imported.format})',
        errorMessage: null,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        isImporting: false,
        errorMessage: 'Import failed: $error',
        lastImportMessage: null,
      );
      notifyListeners();
    }
  }

  Future<void> deleteBookById(String bookId) async {
    try {
      await _bookRepository.deleteBookById(bookId);
      final books = await _bookRepository.getShelfBooks();
      _state = _state.copyWith(
        books: books,
        filteredBooks: _filterByCategory(books, _state.activeCategory),
        errorMessage: null,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(errorMessage: 'Delete failed: $error');
      notifyListeners();
      rethrow;
    }
  }

  void setCategory(String category) {
    if (_state.activeCategory == category) {
      return;
    }
    _state = _state.copyWith(
      activeCategory: category,
      filteredBooks: _filterByCategory(_state.books, category),
    );
    notifyListeners();
  }

  List<BookEntity> _filterByCategory(List<BookEntity> books, String category) {
    if (category == 'ALL') {
      return books;
    }
    return books
        .where((book) => _mapCategory(book) == category)
        .toList(growable: false);
  }

  String _mapCategory(BookEntity book) {
    final bucket = book.id.hashCode.abs() % 4;
    switch (bucket) {
      case 0:
        return 'FICTION';
      case 1:
        return 'NON-FICTION';
      case 2:
        return 'DESIGN';
      default:
        return 'HISTORY';
    }
  }

  Uint8List? _decodeCoverDataUrl(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:image/')) {
      return null;
    }
    const marker = ';base64,';
    final markerIndex = dataUrl.indexOf(marker);
    if (markerIndex <= 0 || markerIndex + marker.length >= dataUrl.length) {
      return null;
    }
    final payload = dataUrl.substring(markerIndex + marker.length);
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
}
