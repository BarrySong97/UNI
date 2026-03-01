import '../../entities/book-entity.dart';

abstract class BookRepository {
  Future<List<BookEntity>> getShelfBooks();

  Future<BookEntity?> getBookById(String bookId);

  Future<void> upsertBook(BookEntity book);

  Future<void> deleteBookById(String bookId);
}
