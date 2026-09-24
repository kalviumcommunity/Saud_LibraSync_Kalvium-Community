// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librasync/models/book.dart';
import 'package:librasync/models/book_copy.dart';
import 'package:librasync/models/branch.dart';
import 'package:librasync/services/circulation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PR #5: Loan / Book-Copy Transaction Consistency Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeUser member1;
    late FakeUser member2;
    late FakeFirebaseAuth authMember1;
    late FakeFirebaseAuth authMember2;

    late Branch branchMain;
    late Branch branchWest;
    late Book testBook;
    late Book singleCopyBook;
    late BookCopy copy1;
    late BookCopy copy2;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();

      member1 = FakeUser(
        uid: 'member-001',
        email: 'alice@library.org',
        displayName: 'Alice Patron',
      );
      member2 = FakeUser(
        uid: 'member-002',
        email: 'bob@library.org',
        displayName: 'Bob Patron',
      );

      authMember1 = FakeFirebaseAuth(currentUser: member1);
      authMember2 = FakeFirebaseAuth(currentUser: member2);

      branchMain = const Branch(
        id: 'branch-main',
        name: 'Main Central Branch',
        address: '100 Library Way',
      );
      branchWest = const Branch(
        id: 'branch-west',
        name: 'West End Branch',
        address: '200 West St',
      );

      testBook = const Book(
        id: 'book-clean-arch',
        title: 'Clean Architecture',
        author: 'Robert C. Martin',
        description: 'A Craftsman Guide to Software Structure',
        totalCopies: 3,
        availableCopies: 3,
        isAvailable: true,
      );

      singleCopyBook = const Book(
        id: 'book-refactoring',
        title: 'Refactoring',
        author: 'Martin Fowler',
        description: 'Improving the Design of Existing Code',
        totalCopies: 1,
        availableCopies: 1,
        isAvailable: true,
      );

      copy1 = const BookCopy(
        id: 'copy-ca-01',
        bookId: 'book-clean-arch',
        branchId: 'branch-main',
        status: BookCopy.statusAvailable,
        barcode: 'BC-CA-01',
      );

      copy2 = const BookCopy(
        id: 'copy-ca-02',
        bookId: 'book-clean-arch',
        branchId: 'branch-main',
        status: BookCopy.statusAvailable,
        barcode: 'BC-CA-02',
      );

      // Seed baseline database
      fakeFirestore.store.documents['branches/${branchMain.id}'] = branchMain
          .toFirestore();
      fakeFirestore.store.documents['branches/${branchWest.id}'] = branchWest
          .toFirestore();
      fakeFirestore.store.documents['books/${testBook.id}'] = testBook
          .toFirestore();
      fakeFirestore.store.documents['books/${singleCopyBook.id}'] =
          singleCopyBook.toFirestore();
      fakeFirestore.store.documents['bookCopies/${copy1.id}'] = copy1
          .toFirestore();
      fakeFirestore.store.documents['bookCopies/${copy2.id}'] = copy2
          .toFirestore();
    });

    // ── 1. BORROW TRANSACTION CONSISTENCY ─────────────────────────────────────
    group('1. Borrow Transaction Consistency', () {
      test(
        'Successful borrow atomically updates copy, book, and loan record',
        () async {
          final service = CirculationService(
            firestore: fakeFirestore,
            auth: authMember1,
          );

          await service.requestBorrow(
            book: testBook,
            memberId: member1.uid,
            branchId: branchMain.id,
            bookCopyId: copy1.id,
          );

          // 1. Verify physical copy is marked borrowed
          final copyDoc =
              fakeFirestore.store.documents['bookCopies/${copy1.id}']!;
          expect(copyDoc['status'], BookCopy.statusBorrowed);

          // 2. Verify book availability is decremented
          final bookDoc =
              fakeFirestore.store.documents['books/${testBook.id}']!;
          expect(bookDoc['availableCopies'], 2);
          expect(bookDoc['isAvailable'], isTrue);

          // 3. Verify loan record is created with active status
          final loanDocs = fakeFirestore.store.documents.entries
              .where((e) => e.key.startsWith('loans/'))
              .toList();
          expect(loanDocs.length, 1);
          final loan = loanDocs.first.value;
          expect(loan['bookId'], testBook.id);
          expect(loan['bookCopyId'], copy1.id);
          expect(loan['borrowedBranchId'], branchMain.id);
          expect(loan['memberId'], member1.uid);
          expect(loan['status'], 'active');
          expect(loan['borrowDate'], isNotNull);
          expect(loan['dueDate'], isNotNull);
          expect(loan['returnDate'], isNull);
        },
      );

      test(
        'Failed borrow due to validation leaves zero partial state',
        () async {
          final service = CirculationService(
            firestore: fakeFirestore,
            auth: authMember1,
          );

          // Request with non-existent copy ID
          expect(
            () => service.requestBorrow(
              book: testBook,
              memberId: member1.uid,
              branchId: branchMain.id,
              bookCopyId: 'non-existent-copy-id',
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains(
                  'Physical book copy "non-existent-copy-id" does not exist',
                ),
              ),
            ),
          );

          // Verify book availability was NOT modified
          final bookDoc =
              fakeFirestore.store.documents['books/${testBook.id}']!;
          expect(bookDoc['availableCopies'], 3);
          expect(bookDoc['isAvailable'], isTrue);

          // Verify copy1 is untouched
          final copyDoc =
              fakeFirestore.store.documents['bookCopies/${copy1.id}']!;
          expect(copyDoc['status'], BookCopy.statusAvailable);

          // Verify no loan record created
          final loanDocs = fakeFirestore.store.documents.entries
              .where((e) => e.key.startsWith('loans/'))
              .toList();
          expect(loanDocs, isEmpty);
        },
      );
    });

    // ── 2. PREVENT DOUBLE BORROWING ──────────────────────────────────────────
    group('2. Prevent Double Borrowing', () {
      test('Cannot borrow a copy that is already marked borrowed', () async {
        // Mark copy1 as borrowed
        fakeFirestore.store.documents['bookCopies/${copy1.id}'] = copy1
            .copyWith(status: BookCopy.statusBorrowed)
            .toFirestore();

        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        expect(
          () => service.requestBorrow(
            book: testBook,
            memberId: member1.uid,
            branchId: branchMain.id,
            bookCopyId: copy1.id,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('is not available for borrowing (status: "borrowed")'),
            ),
          ),
        );

        // Book availability unchanged
        final bookDoc = fakeFirestore.store.documents['books/${testBook.id}']!;
        expect(bookDoc['availableCopies'], 3);
      });

      test('Cannot borrow a copy that already has an active loan record', () async {
        // Simulate a pre-existing active loan record for copy1
        fakeFirestore.store.documents['loans/active-loan-copy1'] = {
          'bookId': testBook.id,
          'bookCopyId': copy1.id,
          'memberId': member2.uid,
          'status': 'active',
          'borrowDate': Timestamp.now(),
          'dueDate': Timestamp.now(),
        };

        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        expect(
          () => service.requestBorrow(
            book: testBook,
            memberId: member1.uid,
            branchId: branchMain.id,
            bookCopyId: copy1.id,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'Physical book copy "${copy1.id}" is already currently on loan',
              ),
            ),
          ),
        );

        // Book availability unchanged
        final bookDoc = fakeFirestore.store.documents['books/${testBook.id}']!;
        expect(bookDoc['availableCopies'], 3);
      });

      test(
        'Two members attempting to borrow the same copy: second fails cleanly',
        () async {
          final service1 = CirculationService(
            firestore: fakeFirestore,
            auth: authMember1,
          );
          final service2 = CirculationService(
            firestore: fakeFirestore,
            auth: authMember2,
          );

          // Member 1 borrows copy1
          await service1.requestBorrow(
            book: testBook,
            memberId: member1.uid,
            branchId: branchMain.id,
            bookCopyId: copy1.id,
          );

          // Member 2 attempts to borrow the same copy1
          expect(
            () => service2.requestBorrow(
              book: testBook,
              memberId: member2.uid,
              branchId: branchMain.id,
              bookCopyId: copy1.id,
            ),
            throwsA(isA<Exception>()),
          );

          // Verify only 1 loan was created in total
          final loanDocs = fakeFirestore.store.documents.entries
              .where((e) => e.key.startsWith('loans/'))
              .toList();
          expect(loanDocs.length, 1);
          expect(loanDocs.first.value['memberId'], member1.uid);

          // Book available copies decremented only once (from 3 to 2)
          final bookDoc =
              fakeFirestore.store.documents['books/${testBook.id}']!;
          expect(bookDoc['availableCopies'], 2);
        },
      );
    });

    // ── 3. RETURN CONSISTENCY ────────────────────────────────────────────────
    group('3. Return Consistency', () {
      test('Successful return atomically closes loan, marks copy available, and increments book availability', () async {
        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        // Borrow first
        await service.requestBorrow(
          book: testBook,
          memberId: member1.uid,
          branchId: branchMain.id,
          bookCopyId: copy1.id,
        );

        final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
          (e) => e.key.startsWith('loans/'),
        );
        final loanId = loanEntry.key.replaceFirst('loans/', '');

        // Now return
        await service.requestReturn(loanId: loanId);

        // 1. Verify loan is closed
        final updatedLoan = fakeFirestore.store.documents['loans/$loanId']!;
        expect(updatedLoan['status'], 'returned');
        expect(updatedLoan['returnDate'], isNotNull);

        // 2. Verify copy is restored to available
        final updatedCopy =
            fakeFirestore.store.documents['bookCopies/${copy1.id}']!;
        expect(updatedCopy['status'], BookCopy.statusAvailable);

        // 3. Verify book availability restored to 3
        final updatedBook =
            fakeFirestore.store.documents['books/${testBook.id}']!;
        expect(updatedBook['availableCopies'], 3);
        expect(updatedBook['isAvailable'], isTrue);
      });

      test('Failed return does not mutate any document state', () async {
        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        // Attempting to return with nonexistent return branch ID
        fakeFirestore.store.documents['loans/test-loan'] = {
          'bookId': testBook.id,
          'bookCopyId': copy1.id,
          'memberId': member1.uid,
          'status': 'active',
          'borrowDate': Timestamp.now(),
          'dueDate': Timestamp.now(),
        };
        fakeFirestore.store.documents['bookCopies/${copy1.id}'] = copy1
            .copyWith(status: BookCopy.statusBorrowed)
            .toFirestore();

        expect(
          () => service.requestReturn(
            loanId: 'test-loan',
            returnBranchId: 'non-existent-branch',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Return branch "non-existent-branch" does not exist'),
            ),
          ),
        );

        // Verify loan status is still active
        final loanDoc = fakeFirestore.store.documents['loans/test-loan']!;
        expect(loanDoc['status'], 'active');
        expect(loanDoc['returnDate'], isNull);

        // Verify copy status is still borrowed
        final copyDoc =
            fakeFirestore.store.documents['bookCopies/${copy1.id}']!;
        expect(copyDoc['status'], BookCopy.statusBorrowed);

        // Verify book availability unmodified
        final bookDoc = fakeFirestore.store.documents['books/${testBook.id}']!;
        expect(bookDoc['availableCopies'], 3);
      });
    });

    // ── 4. DUPLICATE RETURN PROTECTION ───────────────────────────────────────
    group('4. Duplicate Return Protection', () {
      test('Already-returned loan cannot be returned again and does not double-increment copies', () async {
        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        // Borrow and return once
        await service.requestBorrow(
          book: testBook,
          memberId: member1.uid,
          branchId: branchMain.id,
          bookCopyId: copy1.id,
        );

        final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
          (e) => e.key.startsWith('loans/'),
        );
        final loanId = loanEntry.key.replaceFirst('loans/', '');

        await service.requestReturn(loanId: loanId);

        expect(
          fakeFirestore
              .store
              .documents['books/${testBook.id}']!['availableCopies'],
          3,
        );

        // Second return attempt
        expect(
          () => service.requestReturn(loanId: loanId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('already been returned'),
            ),
          ),
        );

        // Copies remain 3, never 4
        expect(
          fakeFirestore
              .store
              .documents['books/${testBook.id}']!['availableCopies'],
          3,
        );
      });

      test('Loan with returnDate already set is rejected even if status was active', () async {
        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        fakeFirestore.store.documents['loans/inconsistent-loan'] = {
          'bookId': testBook.id,
          'memberId': member1.uid,
          'status': 'active',
          'returnDate': Timestamp.now(),
          'borrowDate': Timestamp.now(),
          'dueDate': Timestamp.now(),
        };

        expect(
          () => service.requestReturn(loanId: 'inconsistent-loan'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('already been returned'),
            ),
          ),
        );
      });
    });

    // ── 5. INVALID COPY / LOAN STATES ────────────────────────────────────────
    group('5. Invalid Copy / Loan States', () {
      test(
        'Borrowing an unavailable copy (maintenance or lost) is rejected',
        () async {
          final service = CirculationService(
            firestore: fakeFirestore,
            auth: authMember1,
          );

          // Mark copy1 as lost
          fakeFirestore.store.documents['bookCopies/${copy1.id}'] = copy1
              .copyWith(status: BookCopy.statusLost)
              .toFirestore();

          expect(
            () => service.requestBorrow(
              book: testBook,
              memberId: member1.uid,
              branchId: branchMain.id,
              bookCopyId: copy1.id,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('is not available for borrowing (status: "lost")'),
              ),
            ),
          );
        },
      );

      test('Borrowing a nonexistent copy is rejected', () async {
        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        expect(
          () => service.requestBorrow(
            book: testBook,
            memberId: member1.uid,
            branchId: branchMain.id,
            bookCopyId: 'phantom-copy-99',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Physical book copy "phantom-copy-99" does not exist'),
            ),
          ),
        );
      });

      test('Returning a nonexistent loan is rejected', () async {
        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        expect(
          () => service.requestReturn(loanId: 'phantom-loan-99'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Loan record does not exist'),
            ),
          ),
        );
      });

      test(
        'Returning a loan whose copy is already available is rejected',
        () async {
          final service = CirculationService(
            firestore: fakeFirestore,
            auth: authMember1,
          );

          // Loan says copy1 is borrowed, but copy1 in Firestore is already available
          fakeFirestore.store.documents['loans/desync-loan'] = {
            'bookId': testBook.id,
            'bookCopyId': copy1.id,
            'memberId': member1.uid,
            'status': 'active',
            'borrowDate': Timestamp.now(),
            'dueDate': Timestamp.now(),
          };
          // copy1 status is available in DB

          expect(
            () => service.requestReturn(loanId: 'desync-loan'),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('is already marked as available'),
              ),
            ),
          );
        },
      );

      test(
        'Returning a loan whose physical copy does not exist is rejected',
        () async {
          final service = CirculationService(
            firestore: fakeFirestore,
            auth: authMember1,
          );

          fakeFirestore.store.documents['loans/missing-copy-loan'] = {
            'bookId': testBook.id,
            'bookCopyId': 'deleted-copy-id',
            'memberId': member1.uid,
            'status': 'active',
            'borrowDate': Timestamp.now(),
            'dueDate': Timestamp.now(),
          };

          expect(
            () => service.requestReturn(loanId: 'missing-copy-loan'),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Physical book copy "deleted-copy-id" does not exist'),
              ),
            ),
          );
        },
      );

      test('Inconsistent book/copy reference on borrow is rejected', () async {
        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        // copy1 belongs to testBook ('book-clean-arch'), but request passes singleCopyBook ('book-refactoring')
        expect(
          () => service.requestBorrow(
            book: singleCopyBook,
            memberId: member1.uid,
            branchId: branchMain.id,
            bookCopyId: copy1.id,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('does not match book'),
            ),
          ),
        );
      });

      test('Inconsistent book/copy reference on return is rejected', () async {
        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        // Loan references singleCopyBook, but copy1 belongs to testBook
        fakeFirestore.store.documents['loans/mismatched-loan'] = {
          'bookId': singleCopyBook.id,
          'bookCopyId': copy1.id,
          'memberId': member1.uid,
          'status': 'active',
          'borrowDate': Timestamp.now(),
          'dueDate': Timestamp.now(),
        };
        fakeFirestore.store.documents['bookCopies/${copy1.id}'] = copy1
            .copyWith(status: BookCopy.statusBorrowed)
            .toFirestore();

        expect(
          () => service.requestReturn(loanId: 'mismatched-loan'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('does not match loan book'),
            ),
          ),
        );
      });
    });

    // ── 6. BOOK-LEVEL AVAILABILITY ───────────────────────────────────────────
    group('6. Book-Level Availability Consistency', () {
      test('Borrowing last available copy sets isAvailable false and availableCopies to 0', () async {
        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        // singleCopyBook has availableCopies: 1, totalCopies: 1
        await service.requestBorrow(
          book: singleCopyBook,
          memberId: member1.uid,
        );

        final bookDoc =
            fakeFirestore.store.documents['books/${singleCopyBook.id}']!;
        expect(bookDoc['availableCopies'], 0);
        expect(bookDoc['isAvailable'], isFalse);

        // Another borrow attempt must fail
        expect(
          () => service.requestBorrow(
            book: singleCopyBook,
            memberId: member2.uid,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('No available copies'),
            ),
          ),
        );
      });

      test('Return operation clamps availableCopies to never exceed totalCopies', () async {
        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        // Seed book where availableCopies is already equal to totalCopies (3/3)
        fakeFirestore.store.documents['books/${testBook.id}'] = testBook
            .copyWith(availableCopies: 3, totalCopies: 3)
            .toFirestore();

        fakeFirestore.store.documents['loans/legacy-return-loan'] = {
          'bookId': testBook.id,
          'memberId': member1.uid,
          'status': 'active',
          'borrowDate': Timestamp.now(),
          'dueDate': Timestamp.now(),
        };

        await service.requestReturn(loanId: 'legacy-return-loan');

        final bookDoc = fakeFirestore.store.documents['books/${testBook.id}']!;
        // Clamped at 3, not incremented to 4
        expect(bookDoc['availableCopies'], 3);
        expect(bookDoc['isAvailable'], isTrue);
      });

      test(
        'Sequential borrows and returns maintain exact copy counts',
        () async {
          final service1 = CirculationService(
            firestore: fakeFirestore,
            auth: authMember1,
          );
          final service2 = CirculationService(
            firestore: fakeFirestore,
            auth: authMember2,
          );

          // Initial: 3 available
          expect(
            fakeFirestore
                .store
                .documents['books/${testBook.id}']!['availableCopies'],
            3,
          );

          // Member 1 borrows copy1
          await service1.requestBorrow(
            book: testBook,
            memberId: member1.uid,
            branchId: branchMain.id,
            bookCopyId: copy1.id,
          );
          expect(
            fakeFirestore
                .store
                .documents['books/${testBook.id}']!['availableCopies'],
            2,
          );

          // Member 2 borrows copy2
          await service2.requestBorrow(
            book: testBook,
            memberId: member2.uid,
            branchId: branchMain.id,
            bookCopyId: copy2.id,
          );
          expect(
            fakeFirestore
                .store
                .documents['books/${testBook.id}']!['availableCopies'],
            1,
          );

          final member1Loan = fakeFirestore.store.documents.entries.firstWhere(
            (e) =>
                e.key.startsWith('loans/') &&
                e.value['memberId'] == member1.uid &&
                e.value['status'] == 'active',
          );
          final member1LoanId = member1Loan.key.replaceFirst('loans/', '');

          // Member 1 returns copy1
          await service1.requestReturn(loanId: member1LoanId);
          expect(
            fakeFirestore
                .store
                .documents['books/${testBook.id}']!['availableCopies'],
            2,
          );
          expect(
            fakeFirestore.store.documents['bookCopies/${copy1.id}']!['status'],
            BookCopy.statusAvailable,
          );
          expect(
            fakeFirestore.store.documents['bookCopies/${copy2.id}']!['status'],
            BookCopy.statusBorrowed,
          );

          final member2Loan = fakeFirestore.store.documents.entries.firstWhere(
            (e) =>
                e.key.startsWith('loans/') &&
                e.value['memberId'] == member2.uid &&
                e.value['status'] == 'active',
          );
          final member2LoanId = member2Loan.key.replaceFirst('loans/', '');

          // Member 2 returns copy2
          await service2.requestReturn(loanId: member2LoanId);
          expect(
            fakeFirestore
                .store
                .documents['books/${testBook.id}']!['availableCopies'],
            3,
          );
          expect(
            fakeFirestore.store.documents['bookCopies/${copy2.id}']!['status'],
            BookCopy.statusAvailable,
          );
        },
      );
    });

    // ── 7. CROSS-BRANCH RETURNS COMPATIBILITY ─────────────────────────────────
    group('7. Cross-Branch Return Compatibility', () {
      test('Cross-branch return updates copy location, preserves borrowedBranchId, and marks available', () async {
        final service = CirculationService(
          firestore: fakeFirestore,
          auth: authMember1,
        );

        // Borrow from Main branch
        await service.requestBorrow(
          book: testBook,
          memberId: member1.uid,
          branchId: branchMain.id,
          bookCopyId: copy1.id,
        );

        final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
          (e) => e.key.startsWith('loans/'),
        );
        final loanId = loanEntry.key.replaceFirst('loans/', '');

        // Return to West branch
        await service.requestReturn(
          loanId: loanId,
          returnBranchId: branchWest.id,
        );

        // Verify loan record
        final loanDoc = fakeFirestore.store.documents['loans/$loanId']!;
        expect(loanDoc['status'], 'returned');
        expect(loanDoc['borrowedBranchId'], branchMain.id);
        expect(loanDoc['returnBranchId'], branchWest.id);

        // Verify copy location updated to West branch and status available
        final copyDoc =
            fakeFirestore.store.documents['bookCopies/${copy1.id}']!;
        expect(copyDoc['status'], BookCopy.statusAvailable);
        expect(copyDoc['branchId'], branchWest.id);

        // Verify book availability restored
        final bookDoc = fakeFirestore.store.documents['books/${testBook.id}']!;
        expect(bookDoc['availableCopies'], 3);
        expect(bookDoc['isAvailable'], isTrue);
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
