import '../../../dtos/db/book-dto.dart';
import '../app-database.dart';

class BooksDao {
  BooksDao({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<List<BookDto>> listBooks() => _database.listBooks();

  Future<BookDto?> getBookById(String id) => _database.getBook(id);

  Future<void> upsertBook(BookDto dto) => _database.upsertBook(dto);
}
