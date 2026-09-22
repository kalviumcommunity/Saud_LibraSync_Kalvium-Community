import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/book_copy.dart';

/// Service responsible for managing and querying physical book copy data.
///
/// Encapsulates Firestore `bookCopies` collection queries and real-time streaming interfaces.
class BookCopyService {
  BookCopyService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _customFirestore = firestore,
      _customAuth = auth;

  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  FirebaseAuth get auth => _customAuth ?? FirebaseAuth.instance;

  /// Firestore collection reference for physical book copies.
  CollectionReference<Map<String, dynamic>> get _bookCopiesCollection =>
      _firestore.collection('bookCopies');

  /// Streams all physical book copies in real time.
  Stream<List<BookCopy>> streamCopies() {
    try {
      return _bookCopiesCollection.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return BookCopy.fromFirestore(doc.data(), doc.id);
        }).toList();
      });
    } catch (e) {
      return Stream.error(e);
    }
  }

  /// Streams physical copies associated with a specific [bookId].
  Stream<List<BookCopy>> streamCopiesForBook(String bookId) {
    final trimmedId = bookId.trim();
    if (trimmedId.isEmpty) {
      return Stream.value([]);
    }
    try {
      return _bookCopiesCollection
          .where('bookId', isEqualTo: trimmedId)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return BookCopy.fromFirestore(doc.data(), doc.id);
            }).toList();
          });
    } catch (e) {
      return Stream.error(e);
    }
  }

  /// Streams physical copies currently located at a specific [branchId].
  Stream<List<BookCopy>> streamCopiesForBranch(String branchId) {
    final trimmedId = branchId.trim();
    if (trimmedId.isEmpty) {
      return Stream.value([]);
    }
    try {
      return _bookCopiesCollection
          .where('branchId', isEqualTo: trimmedId)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return BookCopy.fromFirestore(doc.data(), doc.id);
            }).toList();
          });
    } catch (e) {
      return Stream.error(e);
    }
  }

  /// Fetches a one-time list of all physical book copies.
  Future<List<BookCopy>> getAllCopies() async {
    final snapshot = await _bookCopiesCollection.get();
    return snapshot.docs.map((doc) {
      return BookCopy.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Fetches all physical copies for a specific [bookId].
  Future<List<BookCopy>> getCopiesForBook(String bookId) async {
    final trimmedId = bookId.trim();
    if (trimmedId.isEmpty) return [];

    final snapshot = await _bookCopiesCollection
        .where('bookId', isEqualTo: trimmedId)
        .get();
    return snapshot.docs.map((doc) {
      return BookCopy.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Fetches all physical copies located at a specific [branchId].
  Future<List<BookCopy>> getCopiesForBranch(String branchId) async {
    final trimmedId = branchId.trim();
    if (trimmedId.isEmpty) return [];

    final snapshot = await _bookCopiesCollection
        .where('branchId', isEqualTo: trimmedId)
        .get();
    return snapshot.docs.map((doc) {
      return BookCopy.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Fetches a single physical copy by its document [id].
  ///
  /// Returns `null` if the document does not exist or [id] is empty.
  Future<BookCopy?> getCopyById(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return null;

    final doc = await _bookCopiesCollection.doc(trimmedId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return BookCopy.fromFirestore(doc.data()!, doc.id);
  }

  /// Streams a single physical copy by document [id] for real-time detail updates.
  Stream<BookCopy?> streamCopyById(String id) {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      return Stream.value(null);
    }
    try {
      return _bookCopiesCollection.doc(trimmedId).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) {
          return null;
        }
        return BookCopy.fromFirestore(doc.data()!, doc.id);
      });
    } catch (e) {
      return Stream.error(e);
    }
  }
}
