import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/book.dart';

/// Service class responsible for managing Book catalog data and staff book operations.
///
/// Encapsulates all Firestore queries, validation, and role authorization logic,
/// keeping the presentation layer decoupled from backend details.
class BookService {
  BookService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customFirestore = firestore,
        _customAuth = auth;

  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  FirebaseAuth get _auth =>
      _customAuth ?? FirebaseAuth.instance;

  /// Firestore collection reference for books.
  CollectionReference<Map<String, dynamic>> get _booksCollection =>
      _firestore.collection('books');

  /// Firestore collection reference for users.
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // ── Role Authorization Helpers ─────────────────────────────────────────────

  /// Determines whether the currently signed-in user possesses staff privileges.
  Future<bool> isCurrentUserStaff() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return false;
    }

    try {
      final doc = await _usersCollection.doc(currentUser.uid).get();
      if (doc.exists && doc.data() != null) {
        final role = doc.data()!['role'] as String?;
        if (role == 'staff' || role == 'admin') {
          return true;
        }
      }
    } catch (_) {
      // In case of network / permission errors, fall through
    }

    return false;
  }

  /// Verifies that the requesting user is authenticated and authorized as staff.
  Future<void> _verifyStaffAuthorization() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Authentication required. Please sign in as staff.');
    }

    final isStaff = await isCurrentUserStaff();
    if (!isStaff) {
      throw Exception(
        'Unauthorized access. Only library staff can manage the book catalog.',
      );
    }
  }

  // ── Catalog Query Methods ──────────────────────────────────────────────────

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
    if (id.trim().isEmpty) return null;
    final doc = await _booksCollection.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return Book.fromFirestore(doc.data()!, doc.id);
  }

  /// Streams a single book by document [id] for real-time detail updates.
  Stream<Book?> streamBookById(String id) {
    if (id.trim().isEmpty) {
      return Stream.value(null);
    }
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

  // ── Staff Management Methods ───────────────────────────────────────────────

  /// Creates a new book entry in the library catalog after validating fields and staff authorization.
  ///
  /// Returns the newly created [Book] with its assigned document ID.
  Future<Book> createBook(
    Book book, {
    bool enforceStaffRole = true,
  }) async {
    // 1. Validate book fields and invariants
    book.validate();

    // 2. Enforce authorization
    if (enforceStaffRole) {
      await _verifyStaffAuthorization();
    }

    // 3. Prepare document reference
    final docRef = book.id.trim().isNotEmpty
        ? _booksCollection.doc(book.id.trim())
        : _booksCollection.doc();

    final bookToSave = book.copyWith(
      id: docRef.id,
      isAvailable: book.availableCopies > 0,
    );

    // 4. Persist to Firestore
    await docRef.set(bookToSave.toFirestore());

    return bookToSave;
  }

  /// Updates an existing book in the catalog after verifying field invariants and staff authorization.
  ///
  /// Returns the updated [Book].
  Future<Book> updateBook(
    Book book, {
    bool enforceStaffRole = true,
  }) async {
    if (book.id.trim().isEmpty) {
      throw ArgumentError('Book ID is required for update.');
    }

    // 1. Validate book fields and invariants
    book.validate();

    // 2. Enforce authorization
    if (enforceStaffRole) {
      await _verifyStaffAuthorization();
    }

    // 3. Verify book existence
    final docRef = _booksCollection.doc(book.id.trim());
    final existingDoc = await docRef.get();
    if (!existingDoc.exists) {
      throw Exception('Book with ID "${book.id}" does not exist in catalog.');
    }

    final bookToSave = book.copyWith(
      isAvailable: book.availableCopies > 0,
    );

    // 4. Update in Firestore
    await docRef.set(bookToSave.toFirestore(), SetOptions(merge: true));

    return bookToSave;
  }

  /// Deletes a book from the catalog by its [id] after verifying staff authorization.
  Future<void> deleteBook(
    String id, {
    bool enforceStaffRole = true,
  }) async {
    final bookId = id.trim();
    if (bookId.isEmpty) {
      throw ArgumentError('Book ID cannot be empty for deletion.');
    }

    // 1. Enforce authorization
    if (enforceStaffRole) {
      await _verifyStaffAuthorization();
    }

    // 2. Verify book existence
    final docRef = _booksCollection.doc(bookId);
    final existingDoc = await docRef.get();
    if (!existingDoc.exists) {
      throw Exception('Book with ID "$bookId" does not exist in catalog.');
    }

    // 3. Delete from Firestore
    await docRef.delete();
  }
}
