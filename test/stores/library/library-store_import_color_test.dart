import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/repositories/book/book-repository-impl.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/books-dao.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
import 'package:uni/services/library/book-profile-color-service.dart';
import 'package:uni/services/parser/book-import-service.dart';
import 'package:uni/stores/library/library-store.dart';

class _FakeBookImportService extends BookImportService {
  _FakeBookImportService(this._draft);

  final ImportedBookDraft _draft;

  @override
  Future<ImportedBookDraft> importFromPath(String path) async => _draft;
}

void main() {
  const coverDataUrl =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+3xkAAAAASUVORK5CYII=';

  Future<LibraryStore> createStore(ImportedBookDraft draft) async {
    final database = AppDatabase();
    final bookRepository = BookRepositoryImpl(
      booksDao: BooksDao(database: database),
    );
    final progressRepository = ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    );
    return LibraryStore(
      bookRepository: bookRepository,
      bookImportService: _FakeBookImportService(draft),
      booksDirectory: '/tmp/test_books',
      progressRepository: progressRepository,
      bookProfileColorService: BookProfileColorService(
        dominantColorExtractor: (bytes) async => const Color(0xFF336699),
      ),
    );
  }

  test(
    'importBookFromPath stores extracted profileBgColor when cover exists',
    () async {
      final store = await createStore(
        const ImportedBookDraft(
          title: 'Book A',
          author: 'Author A',
          sourceType: 'local_epub',
          sourcePath: '/tmp/book-a.epub',
          format: 'epub',
          coverUrl: coverDataUrl,
        ),
      );

      await store.importBookFromPath('/tmp/book-a.epub');

      final imported = store.state.books.single;
      expect(imported.profileBgColor, isNotNull);
      expect(imported.profileBgColor, startsWith('#'));
    },
  );

  test(
    'importBookFromPath keeps profileBgColor null when cover is missing',
    () async {
      final store = await createStore(
        const ImportedBookDraft(
          title: 'Book B',
          author: 'Author B',
          sourceType: 'local_epub',
          sourcePath: '/tmp/book-b.epub',
          format: 'epub',
          coverUrl: null,
        ),
      );

      await store.importBookFromPath('/tmp/book-b.epub');

      final imported = store.state.books.single;
      expect(imported.profileBgColor, isNull);
    },
  );
}
