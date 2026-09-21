import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/book.dart';
import '../models/loan_record.dart';

/// Service responsible for managing member circulation and book loan operations.
///
/// Encapsulates loan queries and provides clean UI-ready service interfaces.
class CirculationService {
  CirculationService({
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

  CollectionReference<Map<String, dynamic>> get _loansCollection =>
      _firestore.collection('loans');

  CollectionReference<Map<String, dynamic>> get _booksCollection =>
      _firestore.collection('books');

  /// Streams active loans for a specific member, or all active loans if [memberId] is null.
  Stream<List<LoanRecord>> streamActiveLoans({String? memberId}) {
    try {
      Query<Map<String, dynamic>> query =
          _loansCollection.where('status', isEqualTo: 'active');

      if (memberId != null && memberId.trim().isNotEmpty) {
        query = query.where('memberId', isEqualTo: memberId);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return LoanRecord.fromFirestore(doc.data(), doc.id);
        }).toList();
      });
    } catch (e) {
      return Stream.error(e);
    }
  }

  /// Fetches a one-time snapshot of active loans.
  Future<List<LoanRecord>> getActiveLoans({String? memberId}) async {
    Query<Map<String, dynamic>> query =
        _loansCollection.where('status', isEqualTo: 'active');

    if (memberId != null && memberId.trim().isNotEmpty) {
      query = query.where('memberId', isEqualTo: memberId);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return LoanRecord.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Initiates a borrow operation for the given [book] by [memberId].
  Future<void> requestBorrow({
    required Book book,
    required String memberId,
    String? memberName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Authentication required. Please sign in to borrow books.');
    }

    final activeUserId =
        memberId.trim().isNotEmpty ? memberId.trim() : currentUser.uid;

    // Check for duplicate active loan
    final existingActiveLoans = await _loansCollection
        .where('memberId', isEqualTo: activeUserId)
        .where('bookId', isEqualTo: book.id)
        .where('status', isEqualTo: 'active')
        .get();

    if (existingActiveLoans.docs.isNotEmpty) {
      throw Exception('You already have an active loan for "${book.title}".');
    }

    // Run transaction to check availability and create loan atomically
    await _firestore.runTransaction((transaction) async {
      final bookRef = _booksCollection.doc(book.id);
      final bookSnapshot = await transaction.get(bookRef);

      if (!bookSnapshot.exists || bookSnapshot.data() == null) {
        throw Exception('The requested book "${book.title}" was not found.');
      }

      final bookData = bookSnapshot.data()!;
      final currentBook = Book.fromFirestore(bookData, bookSnapshot.id);

      if (!currentBook.isAvailable || currentBook.availableCopies <= 0) {
        throw Exception('No available copies of "${book.title}" to borrow.');
      }

      final newAvailableCopies = currentBook.availableCopies - 1;
      final newIsAvailable = newAvailableCopies > 0;

      transaction.update(bookRef, {
        'availableCopies': newAvailableCopies,
        'isAvailable': newIsAvailable,
      });

      final newLoanRef = _loansCollection.doc();
      final now = DateTime.now();
      final dueDate = now.add(const Duration(days: 14));

      final loanRecord = LoanRecord(
        id: newLoanRef.id,
        bookId: currentBook.id,
        bookTitle: currentBook.title,
        bookAuthor: currentBook.author,
        bookImageUrl: currentBook.imageUrl,
        borrowDate: now,
        dueDate: dueDate,
        memberId: activeUserId,
        memberName: memberName ?? currentUser.displayName ?? currentUser.email,
        status: 'active',
      );

      transaction.set(newLoanRef, loanRecord.toFirestore());
    });
  }

  /// Initiates a return operation for the given [loanId].
  Future<void> requestReturn({
    required String loanId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Authentication required. Please sign in to return books.');
    }

    await _firestore.runTransaction((transaction) async {
      final loanRef = _loansCollection.doc(loanId);
      final loanSnapshot = await transaction.get(loanRef);

      if (!loanSnapshot.exists || loanSnapshot.data() == null) {
        throw Exception('Loan record does not exist.');
      }

      final loanData = loanSnapshot.data()!;
      final loanRecord = LoanRecord.fromFirestore(loanData, loanSnapshot.id);

      if (loanRecord.memberId != null && loanRecord.memberId != currentUser.uid) {
        throw Exception('You are not authorized to return this book.');
      }

      if (loanRecord.status == 'returned' || loanRecord.returnDate != null) {
        throw Exception('This book has already been returned.');
      }

      if (loanRecord.status != 'active') {
        throw Exception('This loan record is not active.');
      }

      // Read book document BEFORE performing any writes (Firestore requirement: reads before writes)
      final bookRef = _booksCollection.doc(loanRecord.bookId);
      final bookSnapshot = await transaction.get(bookRef);

      // All reads complete. Perform atomic updates.
      final now = DateTime.now();
      transaction.update(loanRef, {
        'status': 'returned',
        'returnDate': Timestamp.fromDate(now),
      });

      if (bookSnapshot.exists && bookSnapshot.data() != null) {
        final bookData = bookSnapshot.data()!;
        final currentAvailable = (bookData['availableCopies'] as num?)?.toInt() ?? 0;
        final newAvailable = currentAvailable + 1;

        transaction.update(bookRef, {
          'availableCopies': newAvailable,
          'isAvailable': true,
        });
      }
    });
  }

}

