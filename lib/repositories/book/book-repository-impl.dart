import '../../dtos/db/book-dto.dart';
import '../../entities/book-entity.dart';
import '../../services/db/daos/books-dao.dart';
import 'book-repository.dart';

class BookRepositoryImpl implements BookRepository {
  BookRepositoryImpl({required BooksDao booksDao}) : _booksDao = booksDao;

  final BooksDao _booksDao;

  @override
  Future<List<BookEntity>> getShelfBooks() async {
    final list = await _booksDao.listBooks();
    return list.map((dto) => dto.toEntity()).toList(growable: false);
  }

  @override
  Future<BookEntity?> getBookById(String bookId) async {
    final dto = await _booksDao.getBookById(bookId);
    return dto?.toEntity();
  }

  @override
  Future<void> upsertBook(BookEntity book) {
    return _booksDao.upsertBook(BookDto.fromEntity(book));
  }

  Future<void> upsertSeedBook({
    required String id,
    required String title,
    required String author,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return _booksDao.upsertBook(
      BookDto(
        id: id,
        title: title,
        author: author,
        sourceType: 'local_epub',
        createdAtMillis: createdAt.millisecondsSinceEpoch,
        updatedAtMillis: updatedAt.millisecondsSinceEpoch,
      ),
    );
  }
}
