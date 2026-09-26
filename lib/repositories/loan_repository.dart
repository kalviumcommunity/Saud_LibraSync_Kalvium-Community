import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/book.dart';
import '../models/book_copy.dart';
import '../models/loan_record.dart';
import '../services/circulation_service.dart';

class LoanRepository {
  LoanRepository({
    CirculationService? circulationService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _circulationService =
            circulationService ?? CirculationService(firestore: firestore, auth: auth),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final CirculationService _circulationService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _loansCol =>
      _firestore.collection('loans');

  CollectionReference<Map<String, dynamic>> get _booksCol =>
      _firestore.collection('books');

  CollectionReference<Map<String, dynamic>> get _copiesCol =>
      _firestore.collection('bookCopies');

  Stream<List<LoanRecord>> streamActiveLoans({String? memberId}) {
    return _circulationService.streamActiveLoans(memberId: memberId);
  }

  Stream<List<LoanRecord>> streamMemberLoans(String memberId) {
    if (memberId.isEmpty) return Stream.value([]);
    return _loansCol
        .where('memberId', isEqualTo: memberId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LoanRecord.fromFirestore(d.data(), d.id))
            .toList());
  }

  Stream<List<LoanRecord>> streamAllActiveLoans({String? branchId}) {
    Query<Map<String, dynamic>> q = _loansCol.where('status', isEqualTo: 'active');
    if (branchId != null && branchId.isNotEmpty && branchId != 'all') {
      q = q.where('borrowedBranchId', isEqualTo: branchId);
    }
    return q.snapshots().map((snap) =>
        snap.docs.map((d) => LoanRecord.fromFirestore(d.data(), d.id)).toList());
  }

  Future<void> borrowBook({
    required Book book,
    required String memberId,
    String? memberName,
    String? branchId,
    String? bookCopyId,
    int loanDays = 14,
  }) async {
    // If standard 14 days, delegate to circulationService or custom transaction
    if (loanDays == 14) {
      await _circulationService.requestBorrow(
        book: book,
        memberId: memberId,
        memberName: memberName,
        branchId: branchId,
        bookCopyId: bookCopyId,
      );
    } else {
      // Custom due date borrow transaction
      await _firestore.runTransaction((transaction) async {
        final bookRef = _booksCol.doc(book.id);
        final bookSnap = await transaction.get(bookRef);
        if (!bookSnap.exists) throw Exception('Book not found');

        DocumentSnapshot<Map<String, dynamic>>? copySnap;
        DocumentReference<Map<String, dynamic>>? copyRef;
        if (bookCopyId != null && bookCopyId.isNotEmpty) {
          copyRef = _copiesCol.doc(bookCopyId);
          copySnap = await transaction.get(copyRef);
        }

        final bookData = bookSnap.data()!;
        final available = (bookData['availableCopies'] as num?)?.toInt() ?? 0;
        if (available <= 0) throw Exception('No copies available');

        transaction.update(bookRef, {
          'availableCopies': available - 1,
          'isAvailable': available - 1 > 0,
        });

        if (copyRef != null && copySnap != null && copySnap.exists) {
          transaction.update(copyRef, {'status': BookCopy.statusBorrowed});
        }

        final newLoanRef = _loansCol.doc();
        final now = DateTime.now();
        final dueDate = now.add(Duration(days: loanDays));

        final loan = LoanRecord(
          id: newLoanRef.id,
          bookId: book.id,
          bookTitle: book.title,
          bookAuthor: book.author,
          bookImageUrl: book.imageUrl,
          borrowDate: now,
          dueDate: dueDate,
          memberId: memberId,
          memberName: memberName,
          status: 'active',
          borrowedBranchId: branchId,
          bookCopyId: bookCopyId,
        );

        transaction.set(newLoanRef, loan.toFirestore());
      });
    }
  }

  Future<void> returnBook({
    required String loanId,
    String? returnBranchId,
    bool waiveFine = false,
    double? fineAmount,
  }) async {
    // Execute atomic return transaction
    await _firestore.runTransaction((transaction) async {
      final loanRef = _loansCol.doc(loanId);
      final loanSnap = await transaction.get(loanRef);
      if (!loanSnap.exists || loanSnap.data() == null) {
        throw Exception('Loan record does not exist');
      }

      final loan = LoanRecord.fromFirestore(loanSnap.data()!, loanSnap.id);
      if (loan.status == 'returned') return;

      final now = DateTime.now();
      final effectiveBranch = returnBranchId ?? loan.borrowedBranchId;

      final Map<String, dynamic> updates = {
        'status': 'returned',
        'returnDate': Timestamp.fromDate(now),
        'fineAmount': waiveFine ? 0.0 : (fineAmount ?? loan.fineAmount ?? 0.0),
      };
      if (effectiveBranch != null && effectiveBranch.isNotEmpty) {
        updates['returnBranchId'] = effectiveBranch;
      }
      transaction.update(loanRef, updates);

      // Book copies & book counts
      final bookRef = _booksCol.doc(loan.bookId);
      final bookSnap = await transaction.get(bookRef);
      if (bookSnap.exists && bookSnap.data() != null) {
        final bData = bookSnap.data()!;
        final total = (bData['totalCopies'] as num?)?.toInt() ?? 1;
        final current = (bData['availableCopies'] as num?)?.toInt() ?? 0;
        final updated = (current + 1).clamp(0, total);
        transaction.update(bookRef, {
          'availableCopies': updated,
          'isAvailable': updated > 0,
        });
      }

      if (loan.bookCopyId != null && loan.bookCopyId!.isNotEmpty) {
        final copyRef = _copiesCol.doc(loan.bookCopyId);
        final copySnap = await transaction.get(copyRef);
        if (copySnap.exists) {
          final Map<String, dynamic> copyUpdates = {
            'status': BookCopy.statusAvailable,
          };
          if (effectiveBranch != null && effectiveBranch.isNotEmpty) {
            copyUpdates['branchId'] = effectiveBranch;
          }
          transaction.update(copyRef, copyUpdates);
        }
      }
    });
  }

  Future<void> renewLoan(String loanId, {int additionalDays = 14}) async {
    final doc = await _loansCol.doc(loanId).get();
    if (!doc.exists || doc.data() == null) throw Exception('Loan not found');
    final loan = LoanRecord.fromFirestore(doc.data()!, doc.id);
    final newDueDate = loan.dueDate.add(Duration(days: additionalDays));
    await _loansCol.doc(loanId).update({
      'dueDate': Timestamp.fromDate(newDueDate),
    });
  }

  Future<void> updateReadingProgress(
    String loanId, {
    required int progressPercent,
    String? currentChapter,
  }) async {
    final Map<String, dynamic> updates = {
      'progressPercent': progressPercent.clamp(0, 100),
    };
    if (currentChapter != null) {
      updates['currentChapter'] = currentChapter;
    }
    await _loansCol.doc(loanId).update(updates);
  }
}
