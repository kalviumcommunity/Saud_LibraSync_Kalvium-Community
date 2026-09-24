import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/book.dart';
import '../models/book_copy.dart';
import '../models/loan_record.dart';

/// Service responsible for managing member circulation and book loan operations.
///
/// Encapsulates loan queries and provides clean UI-ready service interfaces.
class CirculationService {
  CirculationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _customFirestore = firestore,
      _customAuth = auth;

  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _loansCollection =>
      _firestore.collection('loans');

  CollectionReference<Map<String, dynamic>> get _booksCollection =>
      _firestore.collection('books');

  CollectionReference<Map<String, dynamic>> get _branchesCollection =>
      _firestore.collection('branches');

  CollectionReference<Map<String, dynamic>> get _bookCopiesCollection =>
      _firestore.collection('bookCopies');

  /// Validates return branch parameter.
  ///
  /// Throws [ArgumentError] if [required] is true and [returnBranchId] is null/empty,
  /// or if [returnBranchId] is provided but empty or whitespace.
  static void validateReturnBranch(
    String? returnBranchId, {
    bool required = false,
  }) {
    if (required && (returnBranchId == null || returnBranchId.trim().isEmpty)) {
      throw ArgumentError('Return branch ID is required.');
    }
    if (returnBranchId != null && returnBranchId.trim().isEmpty) {
      throw ArgumentError('Return branch ID cannot be empty.');
    }
  }

  /// Streams active loans for a specific member, or all active loans if [memberId] is null.
  Stream<List<LoanRecord>> streamActiveLoans({String? memberId}) {
    try {
      Query<Map<String, dynamic>> query = _loansCollection.where(
        'status',
        isEqualTo: 'active',
      );

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
    Query<Map<String, dynamic>> query = _loansCollection.where(
      'status',
      isEqualTo: 'active',
    );

    if (memberId != null && memberId.trim().isNotEmpty) {
      query = query.where('memberId', isEqualTo: memberId);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return LoanRecord.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Initiates a borrow operation for the given [book] by [memberId].
  ///
  /// Optionally associates the loan with a specific physical branch via [branchId]
  /// and/or an individual physical copy via [bookCopyId].
  Future<void> requestBorrow({
    required Book book,
    required String memberId,
    String? memberName,
    String? branchId,
    String? bookCopyId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception(
        'Authentication required. Please sign in to borrow books.',
      );
    }

    final activeUserId = memberId.trim().isNotEmpty
        ? memberId.trim()
        : currentUser.uid;

    if (branchId != null && branchId.trim().isEmpty) {
      throw ArgumentError('Branch ID cannot be empty.');
    }
    if (bookCopyId != null && bookCopyId.trim().isEmpty) {
      throw ArgumentError('Book copy ID cannot be empty.');
    }

    final trimmedBranchId = branchId?.trim();
    final trimmedCopyId = bookCopyId?.trim();

    // Check for duplicate active loan
    final existingActiveLoans = await _loansCollection
        .where('memberId', isEqualTo: activeUserId)
        .where('bookId', isEqualTo: book.id)
        .where('status', isEqualTo: 'active')
        .get();

    if (existingActiveLoans.docs.isNotEmpty) {
      throw Exception('You already have an active loan for "${book.title}".');
    }

    if (trimmedCopyId != null) {
      final existingCopyLoans = await _loansCollection
          .where('bookCopyId', isEqualTo: trimmedCopyId)
          .where('status', isEqualTo: 'active')
          .get();

      if (existingCopyLoans.docs.isNotEmpty) {
        throw Exception(
          'Physical book copy "$trimmedCopyId" is already currently on loan.',
        );
      }
    }

    // Run transaction to check availability and create loan atomically
    await _firestore.runTransaction((transaction) async {
      // ── READS (all reads must occur before any writes) ──
      final bookRef = _booksCollection.doc(book.id);
      final bookSnapshot = await transaction.get(bookRef);

      DocumentSnapshot<Map<String, dynamic>>? branchSnapshot;
      if (trimmedBranchId != null) {
        final branchRef = _branchesCollection.doc(trimmedBranchId);
        branchSnapshot = await transaction.get(branchRef);
      }

      DocumentSnapshot<Map<String, dynamic>>? copySnapshot;
      if (trimmedCopyId != null) {
        final copyRef = _bookCopiesCollection.doc(trimmedCopyId);
        copySnapshot = await transaction.get(copyRef);
      }

      // Validations
      if (!bookSnapshot.exists || bookSnapshot.data() == null) {
        throw Exception('The requested book "${book.title}" was not found.');
      }

      if (trimmedBranchId != null) {
        if (branchSnapshot == null ||
            !branchSnapshot.exists ||
            branchSnapshot.data() == null) {
          throw Exception(
            'Borrowing branch "$trimmedBranchId" does not exist.',
          );
        }
      }

      if (trimmedCopyId != null) {
        if (copySnapshot == null ||
            !copySnapshot.exists ||
            copySnapshot.data() == null) {
          throw Exception(
            'Physical book copy "$trimmedCopyId" does not exist.',
          );
        }
        final copyData = copySnapshot.data()!;
        final copy = BookCopy.fromFirestore(copyData, copySnapshot.id);

        if (copy.bookId != book.id) {
          throw Exception(
            'Book copy "$trimmedCopyId" does not match book "${book.id}".',
          );
        }

        if (trimmedBranchId != null && copy.branchId != trimmedBranchId) {
          throw Exception(
            'Book copy "$trimmedCopyId" is located at branch "${copy.branchId}", not "$trimmedBranchId".',
          );
        }

        if (!copy.isAvailable) {
          throw Exception(
            'Physical book copy "$trimmedCopyId" is not available for borrowing (status: "${copy.status}").',
          );
        }
      }

      final bookData = bookSnapshot.data()!;
      final currentBook = Book.fromFirestore(bookData, bookSnapshot.id);

      if (!currentBook.isAvailable || currentBook.availableCopies <= 0) {
        throw Exception('No available copies of "${book.title}" to borrow.');
      }

      // ── WRITES ──
      final newAvailableCopies = currentBook.availableCopies - 1;
      final newIsAvailable = newAvailableCopies > 0;

      transaction.update(bookRef, {
        'availableCopies': newAvailableCopies,
        'isAvailable': newIsAvailable,
      });

      if (trimmedCopyId != null) {
        final copyRef = _bookCopiesCollection.doc(trimmedCopyId);
        transaction.update(copyRef, {'status': BookCopy.statusBorrowed});
      }

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
        borrowedBranchId: trimmedBranchId,
        bookCopyId: trimmedCopyId,
      );

      transaction.set(newLoanRef, loanRecord.toFirestore());
    });
  }

  /// Initiates a return operation for the given [loanId].
  ///
  /// Optionally accepts [returnBranchId] to support returning to a specific
  /// library branch (including cross-branch returns).
  ///
  /// If [returnBranchId] is provided, validates that the branch exists and
  /// records it as the return branch on the loan record. If the loan is associated
  /// with a physical [BookCopy], the copy's location ([branchId]) is updated to
  /// [returnBranchId], and its status is restored to 'available'.
  Future<void> requestReturn({
    required String loanId,
    String? returnBranchId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception(
        'Authentication required. Please sign in to return books.',
      );
    }

    validateReturnBranch(returnBranchId);
    final trimmedReturnBranchId = returnBranchId?.trim();

    await _firestore.runTransaction((transaction) async {
      // ── READS (all reads must occur before any writes) ──
      final loanRef = _loansCollection.doc(loanId);
      final loanSnapshot = await transaction.get(loanRef);

      if (!loanSnapshot.exists || loanSnapshot.data() == null) {
        throw Exception('Loan record does not exist.');
      }

      final loanData = loanSnapshot.data()!;
      final loanRecord = LoanRecord.fromFirestore(loanData, loanSnapshot.id);

      if (loanRecord.memberId != null &&
          loanRecord.memberId != currentUser.uid) {
        throw Exception('You are not authorized to return this book.');
      }

      if (loanRecord.status == 'returned' || loanRecord.returnDate != null) {
        throw Exception('This book has already been returned.');
      }

      if (loanRecord.status != 'active') {
        throw Exception('This loan record is not active.');
      }

      DocumentSnapshot<Map<String, dynamic>>? returnBranchSnapshot;
      if (trimmedReturnBranchId != null) {
        final returnBranchRef = _branchesCollection.doc(trimmedReturnBranchId);
        returnBranchSnapshot = await transaction.get(returnBranchRef);
        if (!returnBranchSnapshot.exists ||
            returnBranchSnapshot.data() == null) {
          throw Exception(
            'Return branch "$trimmedReturnBranchId" does not exist.',
          );
        }
      }

      // Read book document BEFORE performing any writes
      final bookRef = _booksCollection.doc(loanRecord.bookId);
      final bookSnapshot = await transaction.get(bookRef);

      // Read book copy document if assigned, BEFORE performing any writes
      DocumentSnapshot<Map<String, dynamic>>? copySnapshot;
      DocumentReference<Map<String, dynamic>>? copyRef;
      if (loanRecord.bookCopyId != null &&
          loanRecord.bookCopyId!.trim().isNotEmpty) {
        copyRef = _bookCopiesCollection.doc(loanRecord.bookCopyId!.trim());
        copySnapshot = await transaction.get(copyRef);
      }

      // Validations on physical copy if associated with this loan
      BookCopy? copy;
      if (loanRecord.bookCopyId != null &&
          loanRecord.bookCopyId!.trim().isNotEmpty) {
        if (copySnapshot == null ||
            !copySnapshot.exists ||
            copySnapshot.data() == null) {
          throw Exception(
            'Physical book copy "${loanRecord.bookCopyId}" does not exist.',
          );
        }

        final copyData = copySnapshot.data()!;
        copy = BookCopy.fromFirestore(copyData, copySnapshot.id);

        if (copy.isAvailable) {
          throw Exception(
            'Physical book copy "${copy.id}" is already marked as available.',
          );
        }

        if (copy.bookId != loanRecord.bookId) {
          throw Exception(
            'Book copy "${copy.id}" does not match loan book "${loanRecord.bookId}".',
          );
        }
      }

      // ── WRITES ──
      final now = DateTime.now();
      final effectiveReturnBranch =
          trimmedReturnBranchId ?? loanRecord.borrowedBranchId;

      final Map<String, dynamic> loanUpdates = {
        'status': 'returned',
        'returnDate': Timestamp.fromDate(now),
      };
      if (effectiveReturnBranch != null && effectiveReturnBranch.isNotEmpty) {
        loanUpdates['returnBranchId'] = effectiveReturnBranch;
      }
      transaction.update(loanRef, loanUpdates);

      if (bookSnapshot.exists && bookSnapshot.data() != null) {
        final bookData = bookSnapshot.data()!;
        final totalCopies = (bookData['totalCopies'] as num?)?.toInt() ?? 1;
        final currentAvailable =
            (bookData['availableCopies'] as num?)?.toInt() ?? 0;
        final newAvailable = (currentAvailable + 1).clamp(0, totalCopies);

        transaction.update(bookRef, {
          'availableCopies': newAvailable,
          'isAvailable': newAvailable > 0,
        });
      }

      if (copyRef != null && copy != null) {
        final Map<String, dynamic> copyUpdates = {
          'status': BookCopy.statusAvailable,
        };
        if (effectiveReturnBranch != null && effectiveReturnBranch.isNotEmpty) {
          copyUpdates['branchId'] = effectiveReturnBranch;
        }
        transaction.update(copyRef, copyUpdates);
      }
    });
  }
}
