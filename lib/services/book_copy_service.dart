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

  /// Firestore collection reference for books.
  CollectionReference<Map<String, dynamic>> get _booksCollection =>
      _firestore.collection('books');

  /// Firestore collection reference for library branches.
  CollectionReference<Map<String, dynamic>> get _branchesCollection =>
      _firestore.collection('branches');

  /// Firestore collection reference for circulation loans.
  CollectionReference<Map<String, dynamic>> get _loansCollection =>
      _firestore.collection('loans');

  /// Firestore collection reference for users.
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // ── Role Authorization Helpers ─────────────────────────────────────────────

  /// Determines whether the currently signed-in user possesses staff privileges.
  Future<bool> isCurrentUserStaff() async {
    try {
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      final doc = await _usersCollection.doc(currentUser.uid).get();
      if (doc.exists && doc.data() != null) {
        final role = (doc.data()!['role'] as String?)?.trim().toLowerCase();
        if (role == 'staff' || role == 'admin') {
          return true;
        }
      }
    } catch (_) {
      // In case of network / uninitialized / permission errors, fall through
    }

    return false;
  }

  /// Verifies that the requesting user is authenticated and authorized as staff.
  Future<void> _verifyStaffAuthorization() async {
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      throw Exception('Authentication required. Please sign in as staff.');
    }

    final isStaff = await isCurrentUserStaff();
    if (!isStaff) {
      throw Exception(
        'Unauthorized access. Only library staff can manage physical book copies.',
      );
    }
  }

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

  /// Fetches physical copies with 'available' status for a [bookId], optionally filtered by [branchId].
  Future<List<BookCopy>> getAvailableCopiesForBook(
    String bookId, {
    String? branchId,
  }) async {
    final trimmedBookId = bookId.trim();
    if (trimmedBookId.isEmpty) return [];

    Query<Map<String, dynamic>> query = _bookCopiesCollection
        .where('bookId', isEqualTo: trimmedBookId)
        .where('status', isEqualTo: BookCopy.statusAvailable);

    if (branchId != null && branchId.trim().isNotEmpty) {
      query = query.where('branchId', isEqualTo: branchId.trim());
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return BookCopy.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Streams real-time physical copies with 'available' status for a [bookId], optionally filtered by [branchId].
  Stream<List<BookCopy>> streamAvailableCopiesForBook(
    String bookId, {
    String? branchId,
  }) {
    final trimmedBookId = bookId.trim();
    if (trimmedBookId.isEmpty) {
      return Stream.value([]);
    }
    try {
      Query<Map<String, dynamic>> query = _bookCopiesCollection
          .where('bookId', isEqualTo: trimmedBookId)
          .where('status', isEqualTo: BookCopy.statusAvailable);

      if (branchId != null && branchId.trim().isNotEmpty) {
        query = query.where('branchId', isEqualTo: branchId.trim());
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return BookCopy.fromFirestore(doc.data(), doc.id);
        }).toList();
      });
    } catch (e) {
      return Stream.error(e);
    }
  }

  /// Fetches all available physical copies located at a specific [branchId].
  Future<List<BookCopy>> getAvailableCopiesForBranch(String branchId) async {
    final trimmedId = branchId.trim();
    if (trimmedId.isEmpty) return [];

    final snapshot = await _bookCopiesCollection
        .where('branchId', isEqualTo: trimmedId)
        .where('status', isEqualTo: BookCopy.statusAvailable)
        .get();
    return snapshot.docs.map((doc) {
      return BookCopy.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Streams all available physical copies located at a specific [branchId].
  Stream<List<BookCopy>> streamAvailableCopiesForBranch(String branchId) {
    final trimmedId = branchId.trim();
    if (trimmedId.isEmpty) {
      return Stream.value([]);
    }
    try {
      return _bookCopiesCollection
          .where('branchId', isEqualTo: trimmedId)
          .where('status', isEqualTo: BookCopy.statusAvailable)
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

  /// Fetches all physical copies for a [bookId] at a specific [branchId].
  Future<List<BookCopy>> getCopiesForBookAndBranch(
    String bookId,
    String branchId,
  ) async {
    final trimmedBookId = bookId.trim();
    final trimmedBranchId = branchId.trim();
    if (trimmedBookId.isEmpty || trimmedBranchId.isEmpty) return [];

    final snapshot = await _bookCopiesCollection
        .where('bookId', isEqualTo: trimmedBookId)
        .where('branchId', isEqualTo: trimmedBranchId)
        .get();
    return snapshot.docs.map((doc) {
      return BookCopy.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Streams physical copies for a [bookId] at a specific [branchId].
  Stream<List<BookCopy>> streamCopiesForBookAndBranch(
    String bookId,
    String branchId,
  ) {
    final trimmedBookId = bookId.trim();
    final trimmedBranchId = branchId.trim();
    if (trimmedBookId.isEmpty || trimmedBranchId.isEmpty) {
      return Stream.value([]);
    }
    try {
      return _bookCopiesCollection
          .where('bookId', isEqualTo: trimmedBookId)
          .where('branchId', isEqualTo: trimmedBranchId)
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

  /// Returns the count of available copies for a [bookId], optionally filtered by [branchId].
  Future<int> getAvailableCopyCountForBook(
    String bookId, {
    String? branchId,
  }) async {
    final copies = await getAvailableCopiesForBook(bookId, branchId: branchId);
    return copies.length;
  }

  // ── Staff Physical Copy Management Methods ─────────────────────────────────

  /// Creates / registers a new physical book copy in the system after validating
  /// authorization and references (book and branch existence, copy uniqueness).
  ///
  /// Returns the newly created [BookCopy] with its assigned document ID.
  Future<BookCopy> createCopy(
    BookCopy copy, {
    bool enforceStaffRole = true,
  }) async {
    // 1. Enforce authorization
    if (enforceStaffRole) {
      await _verifyStaffAuthorization();
    }

    // 2. Validate copy data invariants
    copy.validate();

    if (copy.status.trim().toLowerCase() == BookCopy.statusBorrowed) {
      throw ArgumentError(
        'New physical copies cannot be registered with "borrowed" status.',
      );
    }

    // 3. Prepare document reference
    final docRef = copy.id.trim().isNotEmpty
        ? _bookCopiesCollection.doc(copy.id.trim())
        : _bookCopiesCollection.doc();

    if (copy.id.trim().isNotEmpty) {
      final existingDoc = await docRef.get();
      if (existingDoc.exists) {
        throw Exception(
          'Book copy with ID "${copy.id.trim()}" already exists.',
        );
      }
    }

    // 4. Barcode uniqueness check if provided
    if (copy.barcode != null && copy.barcode!.trim().isNotEmpty) {
      final barcodeQuery = await _bookCopiesCollection
          .where('barcode', isEqualTo: copy.barcode!.trim())
          .get();
      for (final doc in barcodeQuery.docs) {
        if (doc.id != docRef.id) {
          throw Exception(
            'A book copy with barcode "${copy.barcode!.trim()}" already exists.',
          );
        }
      }
    }

    final copyToSave = copy.copyWith(id: docRef.id);

    // 5. Atomic transaction to ensure referenced book and branch exist and ID is unique
    await _firestore.runTransaction((transaction) async {
      final copySnapshot = await transaction.get(docRef);
      if (copySnapshot.exists && copySnapshot.data() != null) {
        throw Exception('Book copy with ID "${docRef.id}" already exists.');
      }

      final bookRef = _booksCollection.doc(copy.bookId.trim());
      final bookSnapshot = await transaction.get(bookRef);
      if (!bookSnapshot.exists || bookSnapshot.data() == null) {
        throw Exception(
          'Book with ID "${copy.bookId.trim()}" does not exist in catalog.',
        );
      }

      final branchRef = _branchesCollection.doc(copy.branchId.trim());
      final branchSnapshot = await transaction.get(branchRef);
      if (!branchSnapshot.exists || branchSnapshot.data() == null) {
        throw Exception(
          'Branch with ID "${copy.branchId.trim()}" does not exist.',
        );
      }

      transaction.set(docRef, copyToSave.toFirestore());
    });

    return copyToSave;
  }

  /// Alias for [createCopy] to support PRD registration naming.
  Future<BookCopy> registerCopy(
    BookCopy copy, {
    bool enforceStaffRole = true,
  }) => createCopy(copy, enforceStaffRole: enforceStaffRole);

  /// Updates an existing physical book copy after validating authorization,
  /// active loan state, and referenced book and branch existence.
  ///
  /// Returns the updated [BookCopy].
  Future<BookCopy> updateCopy(
    BookCopy copy, {
    bool enforceStaffRole = true,
  }) async {
    final copyId = copy.id.trim();
    if (copyId.isEmpty) {
      throw ArgumentError('Book copy ID is required for update.');
    }

    // 1. Enforce authorization
    if (enforceStaffRole) {
      await _verifyStaffAuthorization();
    }

    // 2. Validate copy data invariants
    copy.validate();

    // 3. Prevent updating while actively on loan in loans collection
    final activeLoans = await _loansCollection
        .where('bookCopyId', isEqualTo: copyId)
        .where('status', isEqualTo: 'active')
        .get();
    if (activeLoans.docs.isNotEmpty) {
      throw Exception(
        'Cannot update book copy "$copyId" while it is actively on loan.',
      );
    }

    // 4. Barcode uniqueness check if provided
    if (copy.barcode != null && copy.barcode!.trim().isNotEmpty) {
      final barcodeQuery = await _bookCopiesCollection
          .where('barcode', isEqualTo: copy.barcode!.trim())
          .get();
      for (final doc in barcodeQuery.docs) {
        if (doc.id != copyId) {
          throw Exception(
            'A book copy with barcode "${copy.barcode!.trim()}" already exists.',
          );
        }
      }
    }

    final docRef = _bookCopiesCollection.doc(copyId);

    // 5. Atomic transaction to verify existing copy, book, and branch
    await _firestore.runTransaction((transaction) async {
      final copySnapshot = await transaction.get(docRef);
      if (!copySnapshot.exists || copySnapshot.data() == null) {
        throw Exception('Book copy with ID "$copyId" does not exist.');
      }

      final existingCopy = BookCopy.fromFirestore(
        copySnapshot.data()!,
        copySnapshot.id,
      );

      if (existingCopy.status == BookCopy.statusBorrowed) {
        throw Exception(
          'Cannot update book copy "$copyId" while it is actively on loan.',
        );
      }

      if (copy.bookId.trim() != existingCopy.bookId.trim()) {
        throw Exception(
          'Reassigning a book copy to a different book is not permitted.',
        );
      }

      final bookRef = _booksCollection.doc(copy.bookId.trim());
      final bookSnapshot = await transaction.get(bookRef);
      if (!bookSnapshot.exists || bookSnapshot.data() == null) {
        throw Exception(
          'Book with ID "${copy.bookId.trim()}" does not exist in catalog.',
        );
      }

      final branchRef = _branchesCollection.doc(copy.branchId.trim());
      final branchSnapshot = await transaction.get(branchRef);
      if (!branchSnapshot.exists || branchSnapshot.data() == null) {
        throw Exception(
          'Branch with ID "${copy.branchId.trim()}" does not exist.',
        );
      }

      transaction.set(docRef, copy.toFirestore(), SetOptions(merge: true));
    });

    return copy;
  }

  /// Updates the status of an existing physical book copy (e.g. marking for maintenance or lost).
  ///
  /// Prevents manual status change if the copy is currently borrowed.
  Future<BookCopy> updateCopyStatus(
    String copyId,
    String newStatus, {
    bool enforceStaffRole = true,
  }) async {
    final trimmedId = copyId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('Book copy ID cannot be empty.');
    }

    final trimmedStatus = newStatus.trim().toLowerCase();
    if (!BookCopy.isValidStatus(trimmedStatus)) {
      throw ArgumentError(
        'Invalid copy status: "$newStatus". Allowed statuses are: ${BookCopy.validStatuses.join(", ")}.',
      );
    }

    if (enforceStaffRole) {
      await _verifyStaffAuthorization();
    }

    final copy = await getCopyById(trimmedId);
    if (copy == null) {
      throw Exception('Book copy with ID "$trimmedId" does not exist.');
    }

    if (copy.status == BookCopy.statusBorrowed &&
        trimmedStatus != BookCopy.statusBorrowed) {
      throw Exception(
        'Cannot update book copy "$trimmedId" while it is actively on loan.',
      );
    }

    final updatedCopy = copy.copyWith(status: trimmedStatus);
    return updateCopy(updatedCopy, enforceStaffRole: false);
  }

  /// Deletes a physical book copy by [id] after verifying staff authorization,
  /// existence, and ensuring it is not currently borrowed or on an active loan.
  Future<void> deleteCopy(String id, {bool enforceStaffRole = true}) async {
    final copyId = id.trim();
    if (copyId.isEmpty) {
      throw ArgumentError('Book copy ID cannot be empty for deletion.');
    }

    // 1. Enforce authorization
    if (enforceStaffRole) {
      await _verifyStaffAuthorization();
    }

    // 2. Prevent deleting while actively on loan in loans collection
    final activeLoans = await _loansCollection
        .where('bookCopyId', isEqualTo: copyId)
        .where('status', isEqualTo: 'active')
        .get();
    if (activeLoans.docs.isNotEmpty) {
      throw Exception(
        'Cannot delete book copy "$copyId" because it is currently on an active loan.',
      );
    }

    final docRef = _bookCopiesCollection.doc(copyId);

    // 3. Atomic transaction to verify existence, status, and delete
    await _firestore.runTransaction((transaction) async {
      final copySnapshot = await transaction.get(docRef);
      if (!copySnapshot.exists || copySnapshot.data() == null) {
        throw Exception('Book copy with ID "$copyId" does not exist.');
      }

      final existingCopy = BookCopy.fromFirestore(
        copySnapshot.data()!,
        copySnapshot.id,
      );
      if (existingCopy.status == BookCopy.statusBorrowed) {
        throw Exception(
          'Cannot delete book copy "$copyId" because it is currently borrowed.',
        );
      }

      transaction.delete(docRef);
    });
  }
}
