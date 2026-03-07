import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../entities/book-entity.dart';
import '../../repositories/book/book-repository.dart';
import '../../repositories/progress/progress-repository.dart';
import '../../services/library/book-profile-color-service.dart';
import '../../services/parser/book-import-service.dart';
import 'library-state.dart';

class LibraryStore extends ChangeNotifier {
  LibraryStore({
    required BookRepository bookRepository,
    required BookImportService bookImportService,
    required String booksDirectory,
    required ProgressRepository progressRepository,
    BookProfileColorService? bookProfileColorService,
  }) : _bookRepository = bookRepository,
       _bookImportService = bookImportService,
       _booksDirectory = booksDirectory,
       _progressRepository = progressRepository,
       _bookProfileColorService =
           bookProfileColorService ?? const BookProfileColorService();

  final BookRepository _bookRepository;
  final BookImportService _bookImportService;
  final String _booksDirectory;
  final ProgressRepository _progressRepository;
  final BookProfileColorService _bookProfileColorService;
  LibraryState _state = LibraryState.initial();

  LibraryState get state => _state;

  Future<void> loadShelf() async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final books = await _bookRepository.getShelfBooks();
      await _migrateAbsolutePathsIfNeeded(books);
      final progressData = await _loadProgressData(books);
      _state = _state.copyWith(
        books: books,
        filteredBooks: _filterByCategory(books, _state.activeCategory),
        progressMap: progressData.percentMap,
        progressUpdatedMap: progressData.updatedMap,
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

  Future<_ProgressData> _loadProgressData(List<BookEntity> books) async {
    final percentMap = <String, double>{};
    final updatedMap = <String, DateTime>{};
    for (final book in books) {
      final progress = await _progressRepository.getProgress(book.id);
      if (progress != null) {
        percentMap[book.id] = progress.percent;
        updatedMap[book.id] = progress.updatedAt;
      }
    }
    return _ProgressData(percentMap: percentMap, updatedMap: updatedMap);
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

      final epubFilePath = await _copyEpubToLocal(filePath, bookId);

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
        epubFilePath: epubFilePath,
        createdAt: now,
        updatedAt: now,
      );
      await _bookRepository.upsertBook(book);

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

  Future<String> _copyEpubToLocal(String sourcePath, String bookId) async {
    final dir = Directory(_booksDirectory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final ext = p.extension(sourcePath);
    final destPath = p.join(_booksDirectory, '$bookId$ext');
    await File(sourcePath).copy(destPath);
    // Return relative path so it survives iOS container UUID changes.
    return 'books/$bookId$ext';
  }

  String _resolveEpubPath(String storedPath) {
    if (p.isAbsolute(storedPath)) {
      return storedPath;
    }
    final docsDir = p.dirname(_booksDirectory);
    return p.join(docsDir, storedPath);
  }

  Future<void> _migrateAbsolutePathsIfNeeded(List<BookEntity> books) async {
    for (final book in books) {
      final path = book.epubFilePath;
      if (path == null || !p.isAbsolute(path)) continue;

      final booksSegment = '${p.separator}books${p.separator}';
      final idx = path.lastIndexOf(booksSegment);
      if (idx < 0) continue;

      final relativePath = path.substring(idx + 1);
      final updated = BookEntity(
        id: book.id,
        title: book.title,
        author: book.author,
        coverUrl: book.coverUrl,
        profileBgColor: book.profileBgColor,
        estimatedTotalPages: book.estimatedTotalPages,
        sourceType: book.sourceType,
        sourcePath: book.sourcePath,
        epubFilePath: relativePath,
        createdAt: book.createdAt,
        updatedAt: book.updatedAt,
      );
      await _bookRepository.upsertBook(updated);
    }
  }

  Future<void> deleteBookById(String bookId) async {
    try {
      final book = await _bookRepository.getBookById(bookId);
      await _bookRepository.deleteBookById(bookId);

      if (book?.epubFilePath != null) {
        final resolvedPath = _resolveEpubPath(book!.epubFilePath!);
        final file = File(resolvedPath);
        if (await file.exists()) {
          await file.delete();
        }
      }

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
    if (category == 'All') {
      return books;
    }
    final progressMap = _state.progressMap;
    return books.where((book) {
      final progress = progressMap[book.id] ?? 0;
      if (category == 'Finished') {
        return progress >= 1.0;
      }
      // "Reading" — has some progress but not finished
      return progress > 0 && progress < 1.0;
    }).toList(growable: false);
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

class _ProgressData {
  const _ProgressData({required this.percentMap, required this.updatedMap});

  final Map<String, double> percentMap;
  final Map<String, DateTime> updatedMap;
}
