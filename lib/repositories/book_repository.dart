import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/demo_data.dart';
import '../models/book.dart';
import '../services/book_service.dart';

class BookRepository {
  BookRepository({
    BookService? bookService,
    FirebaseFirestore? firestore,
    this.useStaticData = true,
  })  : _bookService = bookService ?? BookService(firestore: firestore),
        _customFirestore = firestore;

  final BookService _bookService;
  final FirebaseFirestore? _customFirestore;
  final bool useStaticData;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _booksCol =>
      _firestore.collection('books');

  Stream<List<Book>> streamBooks() {
    if (useStaticData) {
      return Stream.value(demoBooks);
    }
    return _bookService.streamBooks();
  }

  Stream<Book?> streamBookById(String bookId) {
    if (useStaticData) {
      if (bookId.isEmpty) return Stream.value(null);
      try {
        final book = demoBooks.firstWhere((b) => b.id == bookId);
        return Stream.value(book);
      } catch (_) {
        return Stream.value(null);
      }
    }
    if (bookId.isEmpty) return Stream.value(null);
    return _booksCol.doc(bookId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Book.fromFirestore(doc.data()!, doc.id);
    });
  }

  Future<List<Book>> getBooks() {
    if (useStaticData) {
      return Future.value(demoBooks);
    }
    return _bookService.getBooks();
  }

  Future<Book?> getBookById(String bookId) {
    if (useStaticData) {
      if (bookId.isEmpty) return Future.value(null);
      try {
        final book = demoBooks.firstWhere((b) => b.id == bookId);
        return Future.value(book);
      } catch (_) {
        return Future.value(null);
      }
    }
    return _bookService.getBookById(bookId);
  }

  Future<Book> createBook(Book book, {bool enforceStaffRole = true}) =>
      _bookService.createBook(book, enforceStaffRole: enforceStaffRole);

  Future<Book> upsertBook(Book book, {bool enforceStaffRole = false}) =>
      _bookService.upsertBook(book, enforceStaffRole: enforceStaffRole);

  Future<Book> updateBook(Book book, {bool enforceStaffRole = true}) =>
      _bookService.updateBook(book, enforceStaffRole: enforceStaffRole);

  Future<void> deleteBook(String bookId, {bool enforceStaffRole = true}) =>
      _bookService.deleteBook(bookId, enforceStaffRole: enforceStaffRole);
}
