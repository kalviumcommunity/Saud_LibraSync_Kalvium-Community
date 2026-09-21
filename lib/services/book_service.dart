import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/book.dart';

/// Service class responsible for managing Book catalog data.
///
/// Encapsulates all Firestore queries and data conversions, keeping
/// the presentation layer decoupled from backend details.
class BookService {
  BookService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Firestore collection reference for books.
  CollectionReference<Map<String, dynamic>> get _booksCollection =>
      _firestore.collection('books');

  /// Streams all books in real time from the Firestore `books` collection.
  Stream<List<Book>> streamBooks() {
    try {
      return _booksCollection.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return Book.fromFirestore(doc.data(), doc.id);
        }).toList();
      });
    } catch (e) {
      return Stream.error(e);
    }
  }

  /// Fetches a one-time list of all books from Firestore.
  Future<List<Book>> getBooks() async {
    final snapshot = await _booksCollection.get();
    return snapshot.docs.map((doc) {
      return Book.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Fetches a single book by its document [id].
  Future<Book?> getBookById(String id) async {
    final doc = await _booksCollection.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return Book.fromFirestore(doc.data()!, doc.id);
  }

  /// Streams a single book by document [id] for real-time detail updates.
  Stream<Book?> streamBookById(String id) {
    try {
      return _booksCollection.doc(id).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) {
          return null;
        }
        return Book.fromFirestore(doc.data()!, doc.id);
      });
    } catch (e) {
      return Stream.error(e);
    }
  }
}
