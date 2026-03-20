import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/repositories/book/book-repository-impl.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/books-dao.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
import 'package:uni/services/library/book-profile-color-service.dart';
import 'package:uni/services/parser/book-import-service.dart';
import 'package:uni/services/reader/epub_preparse_service.dart';
import 'package:uni/stores/library/library-store.dart';

class _FakeBookImportService extends BookImportService {
  _FakeBookImportService(this._draft);

  final ImportedBookDraft _draft;

  @override
  Future<ImportedBookDraft> importFromPath(String path) async => _draft;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const coverDataUrl =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+3xkAAAAASUVORK5CYII=';

  Future<(LibraryStore, String)> createStore(ImportedBookDraft draft) async {
    final tempDir = await Directory.systemTemp.createTemp('library-import-');
    final sourcePath = draft.sourcePath;
    final archive = Archive()
      ..addFile(ArchiveFile.string('mimetype', 'application/epub+zip'));
    final bytes = ZipEncoder().encode(archive);
    File(sourcePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    addTearDown(() async {
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.delete();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final database = AppDatabase();
    final bookRepository = BookRepositoryImpl(
      booksDao: BooksDao(database: database),
    );
    final progressRepository = ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    );
    final store = LibraryStore(
      bookRepository: bookRepository,
      bookImportService: _FakeBookImportService(draft),
      booksDirectory: tempDir.path,
      progressRepository: progressRepository,
      database: database,
      bookProfileColorService: BookProfileColorService(
        dominantColorExtractor: (bytes) async => const Color(0xFF336699),
      ),
      epubPreparseService: EpubPreparseService(),
    );
    return (store, sourcePath);
  }

  test(
    'importBookFromPath stores extracted profileBgColor when cover exists',
    () async {
      final (store, sourcePath) = await createStore(
        const ImportedBookDraft(
          title: 'Book A',
          author: 'Author A',
          sourceType: 'local_epub',
          sourcePath: '/tmp/book-a.epub',
          format: 'epub',
          coverUrl: coverDataUrl,
        ),
      );

      await store.importBookFromPath(sourcePath);

      final imported = store.state.books.single;
      expect(imported.profileBgColor, isNotNull);
      expect(imported.profileBgColor, startsWith('#'));
    },
  );

  test(
    'importBookFromPath keeps profileBgColor null when cover is missing',
    () async {
      final (store, sourcePath) = await createStore(
        const ImportedBookDraft(
          title: 'Book B',
          author: 'Author B',
          sourceType: 'local_epub',
          sourcePath: '/tmp/book-b.epub',
          format: 'epub',
          coverUrl: null,
        ),
      );

      await store.importBookFromPath(sourcePath);

      final imported = store.state.books.single;
      expect(imported.profileBgColor, isNull);
    },
  );
}
