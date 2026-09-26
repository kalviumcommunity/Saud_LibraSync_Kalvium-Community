import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book.dart';
import '../services/book_service.dart';

class BookRepository {
  BookRepository({BookService? bookService, FirebaseFirestore? firestore})
      : _bookService = bookService ?? BookService(firestore: firestore),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final BookService _bookService;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _booksCol =>
      _firestore.collection('books');

  Stream<List<Book>> streamBooks() => _bookService.streamBooks();

  Stream<Book?> streamBookById(String bookId) {
    if (bookId.isEmpty) return Stream.value(null);
    return _booksCol.doc(bookId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Book.fromFirestore(doc.data()!, doc.id);
    });
  }

  Future<List<Book>> getBooks() => _bookService.getBooks();

  Future<Book?> getBookById(String bookId) => _bookService.getBookById(bookId);

  Future<Book> createBook(Book book) => _bookService.createBook(book);

  Future<Book> updateBook(Book book) => _bookService.updateBook(book);

  Future<void> deleteBook(String bookId) => _bookService.deleteBook(bookId);
}
