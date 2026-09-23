// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librasync/models/book.dart';
import 'package:librasync/models/book_copy.dart';
import 'package:librasync/models/branch.dart';
import 'package:librasync/models/loan_record.dart';
import 'package:librasync/services/circulation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-Branch Return Validation Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeUser memberA;
    late FakeUser memberB;
    late FakeFirebaseAuth authMemberA;
    late FakeFirebaseAuth authMemberB;

    late Branch branchDowntown;
    late Branch branchUptown;
    late Book testBook;
    late BookCopy copyDowntown;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();

      memberA = FakeUser(
        uid: 'member-001',
        email: 'alice@library.org',
        displayName: 'Alice Patron',
      );
      memberB = FakeUser(
        uid: 'member-002',
        email: 'bob@library.org',
        displayName: 'Bob Patron',
      );

      authMemberA = FakeFirebaseAuth(currentUser: memberA);
      authMemberB = FakeFirebaseAuth(currentUser: memberB);

      branchDowntown = const Branch(
        id: 'branch-downtown',
        name: 'Downtown Central Branch',
        address: '100 Main St',
        phone: '555-0101',
      );

      branchUptown = const Branch(
        id: 'branch-uptown',
        name: 'Uptown North Branch',
        address: '400 North Ave',
        phone: '555-0102',
      );

      testBook = const Book(
        id: 'book-clean-code',
        title: 'Clean Code',
        author: 'Robert C. Martin',
        description: 'A Handbook of Agile Software Craftsmanship',
        totalCopies: 5,
        availableCopies: 5,
        isAvailable: true,
      );

      copyDowntown = const BookCopy(
        id: 'copy-dt-01',
        bookId: 'book-clean-code',
        branchId: 'branch-downtown',
        status: BookCopy.statusAvailable,
        barcode: 'BARCODE-DT-01',
      );

      // Seed Firestore with branches, book, and physical copy
      fakeFirestore.store.documents['branches/${branchDowntown.id}'] =
          branchDowntown.toFirestore();
      fakeFirestore.store.documents['branches/${branchUptown.id}'] =
          branchUptown.toFirestore();
      fakeFirestore.store.documents['books/${testBook.id}'] = testBook
          .toFirestore();
      fakeFirestore.store.documents['bookCopies/${copyDowntown.id}'] =
          copyDowntown.toFirestore();
    });

    // ── 1. Borrowing from Branch A and Returning to Branch B ───────────────────
    test(
      '1. Borrow from branch A and return to branch B (cross-branch return)',
      () async {
        final circulation = CirculationService(
          firestore: fakeFirestore,
          auth: authMemberA,
        );

        // Member borrows copy from Downtown branch
        await circulation.requestBorrow(
          book: testBook,
          memberId: memberA.uid,
          branchId: branchDowntown.id,
          bookCopyId: copyDowntown.id,
        );

        // Verify book available copies decremented
        final bookDocAfterBorrow =
            fakeFirestore.store.documents['books/${testBook.id}']!;
        expect(bookDocAfterBorrow['availableCopies'], 4);

        // Verify copy status is now borrowed at Downtown
        final copyDocAfterBorrow =
            fakeFirestore.store.documents['bookCopies/${copyDowntown.id}']!;
        expect(copyDocAfterBorrow['status'], BookCopy.statusBorrowed);
        expect(copyDocAfterBorrow['branchId'], branchDowntown.id);

        // Locate generated loan record
        final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
          (e) => e.key.startsWith('loans/'),
        );
        final loanId = loanEntry.key.replaceFirst('loans/', '');
        final loanBeforeReturn = LoanRecord.fromFirestore(
          loanEntry.value,
          loanId,
        );

        expect(loanBeforeReturn.status, 'active');
        expect(loanBeforeReturn.borrowedBranchId, branchDowntown.id);
        expect(loanBeforeReturn.bookCopyId, copyDowntown.id);
        expect(loanBeforeReturn.returnBranchId, isNull);
        expect(loanBeforeReturn.returnDate, isNull);

        // Member returns the book at Uptown branch (cross-branch return)
        await circulation.requestReturn(
          loanId: loanId,
          returnBranchId: branchUptown.id,
        );

        // Verify loan record: original borrowed branch preserved, return branch recorded
        final loanDocAfterReturn =
            fakeFirestore.store.documents['loans/$loanId']!;
        final loanAfterReturn = LoanRecord.fromFirestore(
          loanDocAfterReturn,
          loanId,
        );

        expect(loanAfterReturn.status, 'returned');
        expect(loanAfterReturn.returnDate, isNotNull);
        expect(
          loanAfterReturn.borrowedBranchId,
          branchDowntown.id,
          reason: 'Original borrowing branch must be preserved',
        );
        expect(
          loanAfterReturn.returnBranchId,
          branchUptown.id,
          reason: 'Actual return branch must be accurately recorded',
        );
        expect(loanAfterReturn.bookCopyId, copyDowntown.id);

        // Verify physical book copy: relocated to Uptown branch and marked available
        final copyDocAfterReturn =
            fakeFirestore.store.documents['bookCopies/${copyDowntown.id}']!;
        expect(
          copyDocAfterReturn['status'],
          BookCopy.statusAvailable,
          reason: 'Physical copy must become available on return',
        );
        expect(
          copyDocAfterReturn['branchId'],
          branchUptown.id,
          reason:
              'Physical copy branch location must be updated to return branch',
        );

        // Verify catalogue availability restored
        final bookDocAfterReturn =
            fakeFirestore.store.documents['books/${testBook.id}']!;
        expect(bookDocAfterReturn['availableCopies'], 5);
        expect(bookDocAfterReturn['isAvailable'], isTrue);
      },
    );

    // ── 2. Returning to the Same Branch ────────────────────────────────────────
    test('2. Return to the same branch (Branch A to Branch A)', () async {
      final circulation = CirculationService(
        firestore: fakeFirestore,
        auth: authMemberA,
      );

      await circulation.requestBorrow(
        book: testBook,
        memberId: memberA.uid,
        branchId: branchDowntown.id,
        bookCopyId: copyDowntown.id,
      );

      final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
        (e) => e.key.startsWith('loans/'),
      );
      final loanId = loanEntry.key.replaceFirst('loans/', '');

      // Return explicitly to Downtown branch
      await circulation.requestReturn(
        loanId: loanId,
        returnBranchId: branchDowntown.id,
      );

      final loanDoc = fakeFirestore.store.documents['loans/$loanId']!;
      final loan = LoanRecord.fromFirestore(loanDoc, loanId);
      expect(loan.status, 'returned');
      expect(loan.borrowedBranchId, branchDowntown.id);
      expect(loan.returnBranchId, branchDowntown.id);

      final copyDoc =
          fakeFirestore.store.documents['bookCopies/${copyDowntown.id}']!;
      expect(copyDoc['status'], BookCopy.statusAvailable);
      expect(copyDoc['branchId'], branchDowntown.id);
    });

    // ── 3. Invalid or Missing Return Branch Information ───────────────────────
    group('3. Invalid or missing return branch information', () {
      test('validateReturnBranch throws ArgumentError on empty or whitespace strings', () {
        expect(
          () => CirculationService.validateReturnBranch(''),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('cannot be empty'),
            ),
          ),
        );
        expect(
          () => CirculationService.validateReturnBranch('   '),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('cannot be empty'),
            ),
          ),
        );
      });

      test(
        'validateReturnBranch throws ArgumentError when required but null',
        () {
          expect(
            () => CirculationService.validateReturnBranch(null, required: true),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains('is required'),
              ),
            ),
          );
          expect(
            () => CirculationService.validateReturnBranch('', required: true),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test('requestReturn throws ArgumentError when returnBranchId is blank string', () async {
        final circulation = CirculationService(
          firestore: fakeFirestore,
          auth: authMemberA,
        );

        expect(
          () => circulation.requestReturn(
            loanId: 'any-loan',
            returnBranchId: '   ',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Return branch ID cannot be empty'),
            ),
          ),
        );
      });

      test('requestReturn throws Exception when return branch does not exist in Firestore', () async {
        final circulation = CirculationService(
          firestore: fakeFirestore,
          auth: authMemberA,
        );

        await circulation.requestBorrow(
          book: testBook,
          memberId: memberA.uid,
          branchId: branchDowntown.id,
          bookCopyId: copyDowntown.id,
        );

        final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
          (e) => e.key.startsWith('loans/'),
        );
        final loanId = loanEntry.key.replaceFirst('loans/', '');

        expect(
          () => circulation.requestReturn(
            loanId: loanId,
            returnBranchId: 'non-existent-branch-999',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'Return branch "non-existent-branch-999" does not exist',
              ),
            ),
          ),
        );

        // Verify loan status was NOT modified
        final loanDoc = fakeFirestore.store.documents['loans/$loanId']!;
        expect(loanDoc['status'], 'active');
        expect(loanDoc['returnDate'], isNull);

        // Verify copy status remains borrowed at Downtown
        final copyDoc =
            fakeFirestore.store.documents['bookCopies/${copyDowntown.id}']!;
        expect(copyDoc['status'], BookCopy.statusBorrowed);
        expect(copyDoc['branchId'], branchDowntown.id);
      });
    });

    // ── 4. Duplicate Return Prevention ────────────────────────────────────────
    test('4. Duplicate return prevention: second return call throws and does not double-increment', () async {
      final circulation = CirculationService(
        firestore: fakeFirestore,
        auth: authMemberA,
      );

      await circulation.requestBorrow(
        book: testBook,
        memberId: memberA.uid,
        branchId: branchDowntown.id,
        bookCopyId: copyDowntown.id,
      );

      final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
        (e) => e.key.startsWith('loans/'),
      );
      final loanId = loanEntry.key.replaceFirst('loans/', '');

      // First return succeeds
      await circulation.requestReturn(
        loanId: loanId,
        returnBranchId: branchUptown.id,
      );

      final bookDocAfterFirstReturn =
          fakeFirestore.store.documents['books/${testBook.id}']!;
      expect(bookDocAfterFirstReturn['availableCopies'], 5);

      // Second return attempt with same loanId throws
      expect(
        () => circulation.requestReturn(
          loanId: loanId,
          returnBranchId: branchDowntown.id,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('This book has already been returned'),
          ),
        ),
      );

      // Ensure availableCopies is NOT incremented past original 5
      final bookDocAfterSecondAttempt =
          fakeFirestore.store.documents['books/${testBook.id}']!;
      expect(bookDocAfterSecondAttempt['availableCopies'], 5);

      // Ensure copy remains at Uptown branch where first return put it
      final copyDoc =
          fakeFirestore.store.documents['bookCopies/${copyDowntown.id}']!;
      expect(copyDoc['branchId'], branchUptown.id);
      expect(copyDoc['status'], BookCopy.statusAvailable);
    });

    // ── 5. Unauthorized Return Attempts ───────────────────────────────────────
    test('5. Unauthorized return attempt: another user cannot return borrower loan', () async {
      // Alice borrows the book
      final aliceCirculation = CirculationService(
        firestore: fakeFirestore,
        auth: authMemberA,
      );
      await aliceCirculation.requestBorrow(
        book: testBook,
        memberId: memberA.uid,
        branchId: branchDowntown.id,
        bookCopyId: copyDowntown.id,
      );

      final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
        (e) => e.key.startsWith('loans/'),
      );
      final loanId = loanEntry.key.replaceFirst('loans/', '');

      // Bob tries to return Alice's loan
      final bobCirculation = CirculationService(
        firestore: fakeFirestore,
        auth: authMemberB,
      );

      expect(
        () => bobCirculation.requestReturn(
          loanId: loanId,
          returnBranchId: branchUptown.id,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('You are not authorized to return this book'),
          ),
        ),
      );

      // Verify loan remains active and untouched
      final loanDoc = fakeFirestore.store.documents['loans/$loanId']!;
      expect(loanDoc['status'], 'active');
      expect(loanDoc['returnDate'], isNull);

      // Verify physical copy remains borrowed at Downtown
      final copyDoc =
          fakeFirestore.store.documents['bookCopies/${copyDowntown.id}']!;
      expect(copyDoc['status'], BookCopy.statusBorrowed);
      expect(copyDoc['branchId'], branchDowntown.id);
    });

    // ── 6. Correct Loan Status Updates ────────────────────────────────────────
    test('6. Correct loan status updates: status transitions and inactive loan rejection', () async {
      final circulation = CirculationService(
        firestore: fakeFirestore,
        auth: authMemberA,
      );

      // Create an inactive loan record (e.g. status: 'lost')
      final inactiveLoan = LoanRecord(
        id: 'loan-inactive-01',
        bookId: testBook.id,
        bookTitle: testBook.title,
        bookAuthor: testBook.author,
        borrowDate: DateTime.now().subtract(const Duration(days: 30)),
        dueDate: DateTime.now().subtract(const Duration(days: 16)),
        memberId: memberA.uid,
        status: 'lost',
        borrowedBranchId: branchDowntown.id,
      );
      fakeFirestore.store.documents['loans/${inactiveLoan.id}'] = inactiveLoan
          .toFirestore();

      expect(
        () => circulation.requestReturn(
          loanId: inactiveLoan.id,
          returnBranchId: branchDowntown.id,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('This loan record is not active'),
          ),
        ),
      );
    });

    // ── 7. Correct Copy Availability Updates ──────────────────────────────────
    test('7. Correct copy availability updates: full lifecycle from available -> borrowed -> available', () async {
      final circulation = CirculationService(
        firestore: fakeFirestore,
        auth: authMemberA,
      );

      // Pre-borrow check
      expect(copyDowntown.isAvailable, isTrue);

      // Borrow
      await circulation.requestBorrow(
        book: testBook,
        memberId: memberA.uid,
        branchId: branchDowntown.id,
        bookCopyId: copyDowntown.id,
      );

      final copyAfterBorrow = BookCopy.fromFirestore(
        fakeFirestore.store.documents['bookCopies/${copyDowntown.id}']!,
        copyDowntown.id,
      );
      expect(copyAfterBorrow.status, BookCopy.statusBorrowed);
      expect(copyAfterBorrow.isAvailable, isFalse);

      final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
        (e) => e.key.startsWith('loans/'),
      );
      final loanId = loanEntry.key.replaceFirst('loans/', '');

      // Return
      await circulation.requestReturn(
        loanId: loanId,
        returnBranchId: branchUptown.id,
      );

      final copyAfterReturn = BookCopy.fromFirestore(
        fakeFirestore.store.documents['bookCopies/${copyDowntown.id}']!,
        copyDowntown.id,
      );
      expect(copyAfterReturn.status, BookCopy.statusAvailable);
      expect(copyAfterReturn.isAvailable, isTrue);
      expect(copyAfterReturn.branchId, branchUptown.id);
    });

    // ── 8. Existing Borrowing & Returning Behavior Remains Unchanged ───────────
    test('8. Existing borrowing and returning behavior without branch IDs remains intact', () async {
      final circulation = CirculationService(
        firestore: fakeFirestore,
        auth: authMemberA,
      );

      // Borrow without branchId or bookCopyId (legacy / simple mode)
      await circulation.requestBorrow(book: testBook, memberId: memberA.uid);

      final bookDocAfterBorrow =
          fakeFirestore.store.documents['books/${testBook.id}']!;
      expect(bookDocAfterBorrow['availableCopies'], 4);

      final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
        (e) => e.key.startsWith('loans/'),
      );
      final loanId = loanEntry.key.replaceFirst('loans/', '');
      final loan = LoanRecord.fromFirestore(loanEntry.value, loanId);
      expect(loan.borrowedBranchId, isNull);
      expect(loan.bookCopyId, isNull);
      expect(loan.returnBranchId, isNull);

      // Return without returnBranchId
      await circulation.requestReturn(loanId: loanId);

      final loanDocAfterReturn =
          fakeFirestore.store.documents['loans/$loanId']!;
      expect(loanDocAfterReturn['status'], 'returned');
      expect(loanDocAfterReturn['returnDate'], isNotNull);

      final bookDocAfterReturn =
          fakeFirestore.store.documents['books/${testBook.id}']!;
      expect(bookDocAfterReturn['availableCopies'], 5);
    });

    // ── 9. Transaction Failure Handling ───────────────────────────────────────
    group('9. Transaction failure handling', () {
      test(
        'Borrow fails when specified physical copy does not exist',
        () async {
          final circulation = CirculationService(
            firestore: fakeFirestore,
            auth: authMemberA,
          );

          expect(
            () => circulation.requestBorrow(
              book: testBook,
              memberId: memberA.uid,
              branchId: branchDowntown.id,
              bookCopyId: 'ghost-copy-999',
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Physical book copy "ghost-copy-999" does not exist'),
              ),
            ),
          );

          // Verify book copy count was NOT decremented
          final bookDoc =
              fakeFirestore.store.documents['books/${testBook.id}']!;
          expect(bookDoc['availableCopies'], 5);
        },
      );

      test(
        'Borrow fails when physical copy belongs to another branch',
        () async {
          final circulation = CirculationService(
            firestore: fakeFirestore,
            auth: authMemberA,
          );

          // copyDowntown is at branch-downtown; request with branch-uptown
          expect(
            () => circulation.requestBorrow(
              book: testBook,
              memberId: memberA.uid,
              branchId: branchUptown.id,
              bookCopyId: copyDowntown.id,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains(
                  'is located at branch "branch-downtown", not "branch-uptown"',
                ),
              ),
            ),
          );
        },
      );

      test('Borrow fails when physical copy status is not available', () async {
        // Mark copy as maintenance
        fakeFirestore.store.documents['bookCopies/${copyDowntown.id}'] =
            copyDowntown
                .copyWith(status: BookCopy.statusMaintenance)
                .toFirestore();

        final circulation = CirculationService(
          firestore: fakeFirestore,
          auth: authMemberA,
        );

        expect(
          () => circulation.requestBorrow(
            book: testBook,
            memberId: memberA.uid,
            branchId: branchDowntown.id,
            bookCopyId: copyDowntown.id,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'is not available for borrowing (status: "maintenance")',
              ),
            ),
          ),
        );
      });

      test('Borrow fails when borrowing branch does not exist', () async {
        final circulation = CirculationService(
          firestore: fakeFirestore,
          auth: authMemberA,
        );

        expect(
          () => circulation.requestBorrow(
            book: testBook,
            memberId: memberA.uid,
            branchId: 'invalid-branch-id',
            bookCopyId: copyDowntown.id,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Borrowing branch "invalid-branch-id" does not exist'),
            ),
          ),
        );
      });

      test('Return fails when loan document does not exist', () async {
        final circulation = CirculationService(
          firestore: fakeFirestore,
          auth: authMemberA,
        );

        expect(
          () => circulation.requestReturn(
            loanId: 'non-existent-loan-id',
            returnBranchId: branchDowntown.id,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Loan record does not exist'),
            ),
          ),
        );
      });
    });
  });
}

// ── Test Doubles & Fakes ──────────────────────────────────────────────────────

class FakeUser extends Fake implements User {
  FakeUser({required this.uid, this.email, this.displayName});

  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  FakeFirebaseAuth({this.currentUser});

  @override
  final User? currentUser;
}

class FakeFirestoreData {
  final Map<String, Map<String, dynamic>> documents = {};
}

class FakeDocumentSnapshot<T extends Object?> extends Fake
    implements DocumentSnapshot<T> {
  FakeDocumentSnapshot(this._id, this._data);

  final String _id;
  final T? _data;

  @override
  String get id => _id;

  @override
  bool get exists => _data != null;

  @override
  T? data() => _data;
}

class FakeQueryDocumentSnapshot<T extends Object?> extends Fake
    implements QueryDocumentSnapshot<T> {
  FakeQueryDocumentSnapshot(this._id, this._data);

  final String _id;
  final T _data;

  @override
  String get id => _id;

  @override
  bool get exists => true;

  @override
  T data() => _data;
}

class FakeQuerySnapshot<T extends Object?> extends Fake
    implements QuerySnapshot<T> {
  FakeQuerySnapshot(this._docs);

  final List<QueryDocumentSnapshot<T>> _docs;

  @override
  List<QueryDocumentSnapshot<T>> get docs => _docs;
}

class FakeDocumentReference<T extends Object?> extends Fake
    implements DocumentReference<T> {
  FakeDocumentReference(this._path, this._store);

  final String _path;
  final FakeFirestoreData _store;

  @override
  String get id => _path.split('/').last;

  @override
  Future<DocumentSnapshot<T>> get([GetOptions? options]) async {
    final data = _store.documents[_path];
    return FakeDocumentSnapshot<T>(id, data as T?);
  }
}

class FakeQuery<T extends Object?> extends Fake implements Query<T> {
  FakeQuery(this._collectionPath, this._store, [this._whereFilters = const []]);

  final String _collectionPath;
  final List<Map<String, dynamic>> _whereFilters;
  final FakeFirestoreData _store;

  @override
  Query<T> where(
    Object field, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? isNotEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    final newFilters = List<Map<String, dynamic>>.from(_whereFilters)
      ..add({'field': field, 'isEqualTo': isEqualTo});
    return FakeQuery<T>(_collectionPath, _store, newFilters);
  }

  @override
  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    final docs = <QueryDocumentSnapshot<T>>[];
    _store.documents.forEach((path, data) {
      if (path.startsWith('$_collectionPath/')) {
        final docId = path.substring('$_collectionPath/'.length);
        bool matches = true;
        for (final filter in _whereFilters) {
          final field = filter['field'] as String;
          final target = filter['isEqualTo'];
          if (data[field] != target) {
            matches = false;
            break;
          }
        }
        if (matches) {
          docs.add(FakeQueryDocumentSnapshot<T>(docId, data as T));
        }
      }
    });
    return FakeQuerySnapshot<T>(docs);
  }
}

class FakeCollectionReference<T extends Object?> extends Fake
    implements CollectionReference<T> {
  FakeCollectionReference(this._collectionPath, this._store);

  final String _collectionPath;
  final FakeFirestoreData _store;

  @override
  DocumentReference<T> doc([String? path]) {
    final docId = path ?? 'generated_id_${_store.documents.length + 1}';
    return FakeDocumentReference<T>('$_collectionPath/$docId', _store);
  }

  @override
  Query<T> where(
    Object field, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? isNotEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return FakeQuery<T>(
      _collectionPath,
      _store,
    ).where(field, isEqualTo: isEqualTo);
  }
}

class FakeTransaction extends Fake implements Transaction {
  FakeTransaction(this._store);

  final FakeFirestoreData _store;
  bool _hasWritten = false;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentSnapshot,
  ) async {
    if (_hasWritten) {
      throw StateError(
        'FirestoreException: Reads must occur before any writes in a transaction.',
      );
    }
    final ref = documentSnapshot as FakeDocumentReference<T>;
    final data = _store.documents[ref._path];
    return FakeDocumentSnapshot<T>(ref.id, data as T?);
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentSnapshot,
    Map<Object, Object?> data,
  ) {
    _hasWritten = true;
    final ref = documentSnapshot as FakeDocumentReference;
    final existing = Map<String, dynamic>.from(
      _store.documents[ref._path] ?? {},
    );
    data.forEach((k, v) => existing[k.toString()] = v);
    _store.documents[ref._path] = existing;
    return this;
  }

  @override
  Transaction set<T extends Object?>(
    DocumentReference<T> documentSnapshot,
    T data, [
    SetOptions? options,
  ]) {
    _hasWritten = true;
    final ref = documentSnapshot as FakeDocumentReference<T>;
    if (data is Map<String, dynamic>) {
      _store.documents[ref._path] = Map<String, dynamic>.from(data);
    }
    return this;
  }
}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  final FakeFirestoreData store = FakeFirestoreData();

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference<Map<String, dynamic>>(collectionPath, store);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = FakeTransaction(store);
    return await transactionHandler(transaction);
  }
}
