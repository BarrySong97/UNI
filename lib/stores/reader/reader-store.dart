import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../entities/reader-preferences-entity.dart';
import '../../entities/reading-progress-entity.dart';
import '../../repositories/book/book-repository.dart';
import '../../repositories/progress/progress-repository.dart';
import '../../repositories/reader-preferences/reader-preferences-repository.dart';
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
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final book = await _bookRepository.getBookById(bookId);
    final progress = await _progressRepository.getProgress(bookId);
    final preferences =
        await _readerPreferencesRepository.getByBookId(bookId) ??
        ReaderPreferencesEntity.defaultsForBook(bookId);

    if (book == null || book.epubFilePath == null) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
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
  }

  void onReaderReady() {
    _state = _state.copyWith(isReaderReady: true);
    notifyListeners();
  }

  void updateLocator(String locatorJson, {double? percent}) {
    _state = _state.copyWith(
      locatorJson: locatorJson,
      bookPercent: percent ?? _state.bookPercent,
    );
    notifyListeners();
    _scheduleProgressSave();
  }

  Future<void> loadPreferences(String bookId) async {
    final preferences =
        await _readerPreferencesRepository.getByBookId(bookId) ??
        ReaderPreferencesEntity.defaultsForBook(bookId);
    _state = _state.copyWith(preferences: preferences);
    notifyListeners();
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

  Map<String, dynamic>? get savedLocatorMap {
    final json = _state.locatorJson;
    if (json == null || json.isEmpty) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _scheduleProgressSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: ReaderConstants.progressSaveThrottleMs),
      () {
        unawaited(saveProgress());
      },
    );
  }

  Future<void> saveProgress({bool emitStateChanges = true}) async {
    final book = _state.book;
    final locatorJson = _state.locatorJson;
    if (book == null || locatorJson == null || locatorJson.isEmpty) {
      return;
    }

    if (emitStateChanges) {
      _state = _state.copyWith(isSaving: true);
      notifyListeners();
    }

    final progress = ReadingProgressEntity(
      bookId: book.id,
      locatorJson: locatorJson,
      percent: _state.bookPercent,
      updatedAt: DateTime.now(),
    );
    await _progressRepository.saveProgress(progress);

    if (emitStateChanges) {
      _state = _state.copyWith(isSaving: false);
      notifyListeners();
    }
  }

  Future<void> flushProgress({bool emitStateChanges = true}) async {
    _saveTimer?.cancel();
    await saveProgress(emitStateChanges: emitStateChanges);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
