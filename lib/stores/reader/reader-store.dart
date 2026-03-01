import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../entities/reading-progress-entity.dart';
import '../../repositories/book/book-repository.dart';
import '../../repositories/chapter/chapter-repository.dart';
import '../../repositories/progress/progress-repository.dart';
import '../../services/reader/reading-position-service.dart';
import '../../shared/constants/reader-constants.dart';
import 'reader-state.dart';

class ReaderStore extends ChangeNotifier {
  ReaderStore({
    required BookRepository bookRepository,
    required ChapterRepository chapterRepository,
    required ProgressRepository progressRepository,
    ReadingPositionService? readingPositionService,
  }) : _bookRepository = bookRepository,
       _chapterRepository = chapterRepository,
       _progressRepository = progressRepository,
       _readingPositionService =
           readingPositionService ?? ReadingPositionService();

  final BookRepository _bookRepository;
  final ChapterRepository _chapterRepository;
  final ProgressRepository _progressRepository;
  final ReadingPositionService _readingPositionService;

  ReaderState _state = const ReaderState();
  Timer? _saveTimer;

  ReaderState get state => _state;

  Future<void> openBook(String bookId) async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final book = await _bookRepository.getBookById(bookId);
    final chapters = await _chapterRepository.getChapters(bookId);
    final progress = await _progressRepository.getProgress(bookId);

    if (book == null || chapters.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    final targetChapter = progress == null
        ? chapters.first
        : chapters.firstWhere(
            (item) => item.id == progress.chapterId,
            orElse: () => chapters.first,
          );

    final maxOffset = targetChapter.content.length;
    final charOffset = _readingPositionService.clampOffset(
      offset: progress?.charOffset ?? 0,
      totalLength: maxOffset,
    );
    final percent = _readingPositionService.toPercent(
      offset: charOffset,
      totalLength: maxOffset,
    );

    _state = _state.copyWith(
      book: book,
      chapters: chapters,
      chapter: targetChapter,
      charOffset: charOffset,
      percent: percent,
      isLoading: false,
    );
    notifyListeners();
  }

  Future<void> switchChapter(String chapterId) async {
    final chapter = _state.chapters.firstWhere(
      (item) => item.id == chapterId,
      orElse: () => _state.chapter!,
    );
    _state = _state.copyWith(chapter: chapter, charOffset: 0, percent: 0);
    notifyListeners();
    await flushProgress();
  }

  void updateOffset(int offset) {
    final chapter = _state.chapter;
    if (chapter == null) {
      return;
    }

    final clamped = _readingPositionService.clampOffset(
      offset: offset,
      totalLength: chapter.content.length,
    );
    final percent = _readingPositionService.toPercent(
      offset: clamped,
      totalLength: chapter.content.length,
    );

    _state = _state.copyWith(charOffset: clamped, percent: percent);
    notifyListeners();
    _scheduleProgressSave();
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
    final chapter = _state.chapter;
    if (book == null || chapter == null) {
      return;
    }

    if (emitStateChanges) {
      _state = _state.copyWith(isSaving: true);
      notifyListeners();
    }

    final progress = ReadingProgressEntity(
      bookId: book.id,
      chapterId: chapter.id,
      charOffset: _state.charOffset,
      percent: _state.percent,
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
