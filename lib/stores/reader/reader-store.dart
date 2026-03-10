import 'dart:async';

import 'package:flutter/material.dart';

import '../../entities/reader-preferences-entity.dart';
import '../../entities/reading-progress-entity.dart';
import '../../repositories/book/book-repository.dart';
import '../../repositories/progress/progress-repository.dart';
import '../../repositories/reader-preferences/reader-preferences-repository.dart';
import '../../services/reader/reader-performance-tracker.dart';
import '../../shared/constants/reader-constants.dart';
import 'reader-state.dart';

class ReaderStore extends ChangeNotifier {
  ReaderStore({
    required BookRepository bookRepository,
    required ProgressRepository progressRepository,
    required ReaderPreferencesRepository readerPreferencesRepository,
  }) : _bookRepository = bookRepository,
       _progressRepository = progressRepository,
       _readerPreferencesRepository = readerPreferencesRepository;

  final BookRepository _bookRepository;
  final ProgressRepository _progressRepository;
  final ReaderPreferencesRepository _readerPreferencesRepository;

  ReaderState _state = const ReaderState();
  Timer? _saveTimer;

  ReaderState get state => _state;

  Future<void> openBook(String bookId) async {
    final watch = ReaderPerf.start('store.open_book', bookId: bookId);
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final queryWatch = ReaderPerf.start(
      'store.open_book.query',
      bookId: bookId,
    );
    final (book, progress, rawPrefs) = await (
      _bookRepository.getBookById(bookId),
      _progressRepository.getProgress(bookId),
      _readerPreferencesRepository.getByBookId(bookId),
    ).wait;
    ReaderPerf.end('store.open_book.query', queryWatch, bookId: bookId);
    final preferences =
        rawPrefs ?? ReaderPreferencesEntity.defaultsForBook(bookId);

    if (book == null || book.epubFilePath == null) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      ReaderPerf.mark('store.open_book.missing_book', bookId: bookId);
      ReaderPerf.end('store.open_book', watch, bookId: bookId);
      return;
    }

    _state = _state.copyWith(
      book: book,
      locatorJson: progress?.locatorJson,
      bookPercent: progress?.percent ?? 0,
      preferences: preferences,
      isLoading: false,
      isReaderReady: false,
    );
    notifyListeners();
    ReaderPerf.end('store.open_book', watch, bookId: bookId);
  }

  void onReaderReady() {
    _state = _state.copyWith(isReaderReady: true);
    notifyListeners();
  }

  void updateLocator(String locatorJson, {double? percent}) {
    final prevPercent = _state.bookPercent;
    final nextPercent = percent ?? prevPercent;
    _state = _state.copyWith(
      locatorJson: locatorJson,
      bookPercent: nextPercent,
    );
    ReaderPerf.mark(
      'store.update_locator',
      bookId: _state.book?.id,
      extras: <String, Object?>{
        'prev_percent': prevPercent,
        'next_percent': nextPercent,
        'incoming_percent': percent,
        'locator_len': locatorJson.length,
      },
    );
    notifyListeners();
    _scheduleProgressSave();
  }

  Future<void> updatePreferences(
    ReaderPreferencesEntity Function(ReaderPreferencesEntity current) updater,
  ) async {
    final current =
        _state.preferences ??
        ReaderPreferencesEntity.defaultsForBook(_state.book?.id ?? '');
    final next = updater(current);
    _state = _state.copyWith(preferences: next);
    notifyListeners();
    if (next.bookId.isNotEmpty) {
      await _readerPreferencesRepository.savePreferences(next);
    }
  }

  String? get savedLocatorJson => _state.locatorJson;

  void _scheduleProgressSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: ReaderConstants.progressSaveThrottleMs),
      () {
        unawaited(saveProgress());
      },
    );
  }

  Future<void> saveProgress() async {
    final book = _state.book;
    final locatorJson = _state.locatorJson;
    if (book == null || locatorJson == null || locatorJson.isEmpty) {
      ReaderPerf.mark(
        'store.save_progress.skip',
        bookId: book?.id,
        extras: <String, Object?>{
          'has_book': book != null,
          'has_locator': locatorJson != null && locatorJson.isNotEmpty,
        },
      );
      return;
    }

    final progress = ReadingProgressEntity(
      bookId: book.id,
      locatorJson: locatorJson,
      percent: _state.bookPercent,
      updatedAt: DateTime.now(),
    );
    ReaderPerf.mark(
      'store.save_progress',
      bookId: book.id,
      extras: <String, Object?>{
        'percent': progress.percent,
        'locator_len': locatorJson.length,
      },
    );
    await _progressRepository.saveProgress(progress);
  }

  Future<void> flushProgress() async {
    _saveTimer?.cancel();
    await saveProgress();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
