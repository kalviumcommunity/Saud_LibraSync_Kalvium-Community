// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librasync/models/book.dart';
import 'package:librasync/models/book_copy.dart';
import 'package:librasync/models/branch.dart';
import 'package:librasync/services/book_copy_service.dart';
import 'package:librasync/services/circulation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PR #6: Physical Book Copy Management Backend Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeUser staffUser;
    late FakeUser memberUser;
    late FakeFirebaseAuth staffAuth;
    late FakeFirebaseAuth memberAuth;

    late Branch branchMain;
    late Branch branchWest;
    late Book testBook;
    late Book otherBook;
    late BookCopy validCopy;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();

      staffUser = FakeUser(
        uid: 'staff-001',
        email: 'librarian@library.org',
        displayName: 'Senior Librarian',
      );
      memberUser = FakeUser(
        uid: 'member-001',
        email: 'patron@example.com',
        displayName: 'Regular Patron',
      );

      staffAuth = FakeFirebaseAuth(currentUser: staffUser);
      memberAuth = FakeFirebaseAuth(currentUser: memberUser);

      // Seed staff and member user profile documents for role authorization checks
      fakeFirestore.store.documents['users/${staffUser.uid}'] = {
        'email': staffUser.email,
        'displayName': staffUser.displayName,
        'role': 'staff',
      };
      fakeFirestore.store.documents['users/${memberUser.uid}'] = {
        'email': memberUser.email,
        'displayName': memberUser.displayName,
        'role': 'member',
      };

      branchMain = const Branch(
        id: 'branch-main',
        name: 'Main Central Library',
        address: '100 Library Way',
      );
      branchWest = const Branch(
        id: 'branch-west',
        name: 'West End Library',
        address: '200 West St',
      );

      testBook = const Book(
        id: 'book-pragmatic',
        title: 'The Pragmatic Programmer',
        author: 'David Thomas, Andrew Hunt',
        description: 'Your Journey to Mastery',
        totalCopies: 4,
        availableCopies: 4,
        isAvailable: true,
      );

      otherBook = const Book(
        id: 'book-clean-coder',
        title: 'The Clean Coder',
        author: 'Robert C. Martin',
        description: 'A Code of Conduct for Professional Programmers',
        totalCopies: 2,
        availableCopies: 2,
        isAvailable: true,
      );

      validCopy = const BookCopy(
        id: 'copy-prag-01',
        bookId: 'book-pragmatic',
        branchId: 'branch-main',
        status: BookCopy.statusAvailable,
        barcode: 'BARCODE-PRAG-01',
        condition: 'new',
      );

      // Seed branches and books in Firestore
      fakeFirestore.store.documents['branches/${branchMain.id}'] = branchMain
          .toFirestore();
      fakeFirestore.store.documents['branches/${branchWest.id}'] = branchWest
          .toFirestore();
      fakeFirestore.store.documents['books/${testBook.id}'] = testBook
          .toFirestore();
      fakeFirestore.store.documents['books/${otherBook.id}'] = otherBook
          .toFirestore();
    });

    // ── 1. AUTHORIZATION TESTS ────────────────────────────────────────────────
    group('1. Staff Role Authorization', () {
      test(
        'Unauthenticated user is rejected when attempting createCopy',
        () async {
          final unauthService = BookCopyService(
            firestore: fakeFirestore,
            auth: FakeFirebaseAuth(currentUser: null),
          );

          expect(
            () => unauthService.createCopy(validCopy),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Authentication required'),
              ),
            ),
          );
        },
      );

      test('Member without staff role is rejected on createCopy', () async {
        final memberService = BookCopyService(
          firestore: fakeFirestore,
          auth: memberAuth,
        );

        expect(
          () => memberService.createCopy(validCopy),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'Unauthorized access. Only library staff can manage physical book copies',
              ),
            ),
          ),
        );
      });

      test('Member without staff role is rejected on updateCopy', () async {
        fakeFirestore.store.documents['bookCopies/${validCopy.id}'] = validCopy
            .toFirestore();

        final memberService = BookCopyService(
          firestore: fakeFirestore,
          auth: memberAuth,
        );

        expect(
          () => memberService.updateCopy(validCopy.copyWith(condition: 'fair')),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Unauthorized access'),
            ),
          ),
        );
      });

      test('Member without staff role is rejected on deleteCopy', () async {
        fakeFirestore.store.documents['bookCopies/${validCopy.id}'] = validCopy
            .toFirestore();

        final memberService = BookCopyService(
          firestore: fakeFirestore,
          auth: memberAuth,
        );

        expect(
          () => memberService.deleteCopy(validCopy.id),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Unauthorized access'),
            ),
          ),
        );
      });

      test('Staff user successfully passes authorization', () async {
        final staffService = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        expect(await staffService.isCurrentUserStaff(), isTrue);
      });
    });

    // ── 2. CREATE / REGISTER COPY ─────────────────────────────────────────────
    group('2. Create / Register Copy', () {
      test(
        'Staff creates valid physical copy and persists correctly in Firestore',
        () async {
          final service = BookCopyService(
            firestore: fakeFirestore,
            auth: staffAuth,
          );

          final created = await service.createCopy(validCopy);

          expect(created.id, validCopy.id);
          expect(created.bookId, testBook.id);
          expect(created.branchId, branchMain.id);
          expect(created.status, BookCopy.statusAvailable);
          expect(created.barcode, 'BARCODE-PRAG-01');
          expect(created.condition, 'new');

          // Verify stored document in Firestore
          final doc =
              fakeFirestore.store.documents['bookCopies/${validCopy.id}'];
          expect(doc, isNotNull);
          expect(doc!['bookId'], testBook.id);
          expect(doc['branchId'], branchMain.id);
          expect(doc['status'], BookCopy.statusAvailable);
          expect(doc['barcode'], 'BARCODE-PRAG-01');
          expect(doc['condition'], 'new');
        },
      );

      test('registerCopy alias functions identically to createCopy', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        final created = await service.registerCopy(validCopy);
        expect(created.id, validCopy.id);
        expect(
          fakeFirestore.store.documents['bookCopies/${validCopy.id}'],
          isNotNull,
        );
      });

      test(
        'createCopy auto-generates document ID when copy ID is empty',
        () async {
          final service = BookCopyService(
            firestore: fakeFirestore,
            auth: staffAuth,
          );

          final copyWithoutId = validCopy.copyWith(id: '');
          final created = await service.createCopy(copyWithoutId);

          expect(created.id, isNotEmpty);
          expect(
            fakeFirestore.store.documents['bookCopies/${created.id}'],
            isNotNull,
          );
        },
      );

      test(
        'createCopy rejects invalid book reference (nonexistent book)',
        () async {
          final service = BookCopyService(
            firestore: fakeFirestore,
            auth: staffAuth,
          );

          final ghostBookCopy = validCopy.copyWith(bookId: 'ghost-book-999');

          expect(
            () => service.createCopy(ghostBookCopy),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains(
                  'Book with ID "ghost-book-999" does not exist in catalog',
                ),
              ),
            ),
          );

          // Document must NOT have been written
          expect(
            fakeFirestore.store.documents['bookCopies/${validCopy.id}'],
            isNull,
          );
        },
      );

      test(
        'createCopy rejects invalid branch reference (nonexistent branch)',
        () async {
          final service = BookCopyService(
            firestore: fakeFirestore,
            auth: staffAuth,
          );

          final ghostBranchCopy = validCopy.copyWith(
            branchId: 'ghost-branch-999',
          );

          expect(
            () => service.createCopy(ghostBranchCopy),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Branch with ID "ghost-branch-999" does not exist'),
              ),
            ),
          );

          expect(
            fakeFirestore.store.documents['bookCopies/${validCopy.id}'],
            isNull,
          );
        },
      );

      test('createCopy rejects duplicate copy document ID', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        // Seed existing copy
        fakeFirestore.store.documents['bookCopies/${validCopy.id}'] = validCopy
            .toFirestore();

        expect(
          () => service.createCopy(validCopy),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Book copy with ID "${validCopy.id}" already exists'),
            ),
          ),
        );
      });

      test('createCopy rejects duplicate barcode across copies', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        fakeFirestore.store.documents['bookCopies/${validCopy.id}'] = validCopy
            .toFirestore();

        final anotherCopyWithSameBarcode = BookCopy(
          id: 'copy-prag-02',
          bookId: testBook.id,
          branchId: branchMain.id,
          status: BookCopy.statusAvailable,
          barcode: validCopy.barcode, // Same barcode
        );

        expect(
          () => service.createCopy(anotherCopyWithSameBarcode),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('already exists'),
            ),
          ),
        );
      });

      test(
        'createCopy rejects registering a new copy with borrowed status',
        () async {
          final service = BookCopyService(
            firestore: fakeFirestore,
            auth: staffAuth,
          );

          final borrowedCopy = validCopy.copyWith(
            status: BookCopy.statusBorrowed,
          );

          expect(
            () => service.createCopy(borrowedCopy),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains(
                  'New physical copies cannot be registered with "borrowed" status',
                ),
              ),
            ),
          );
        },
      );

      test('createCopy validates copy invariants prior to writing', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        expect(
          () => service.createCopy(validCopy.copyWith(bookId: '  ')),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => service.createCopy(validCopy.copyWith(branchId: '')),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => service.createCopy(validCopy.copyWith(status: 'broken')),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ── 3. COPY -> BOOK & BRANCH ASSOCIATION ──────────────────────────────────
    group('3. Copy to Book and Branch Association', () {
      test('Query methods return copies correctly associated with books and branches', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        await service.createCopy(validCopy);

        final copyAtWest = BookCopy(
          id: 'copy-prag-02',
          bookId: testBook.id,
          branchId: branchWest.id,
          status: BookCopy.statusAvailable,
          barcode: 'BC-PRAG-02',
        );
        await service.createCopy(copyAtWest);

        // Query by book
        final bookCopies = await service.getCopiesForBook(testBook.id);
        expect(bookCopies.length, 2);
        expect(
          bookCopies.map((c) => c.id),
          containsAll(['copy-prag-01', 'copy-prag-02']),
        );

        // Query by branch
        final mainCopies = await service.getCopiesForBranch(branchMain.id);
        expect(mainCopies.length, 1);
        expect(mainCopies.first.id, 'copy-prag-01');

        final westCopies = await service.getCopiesForBranch(branchWest.id);
        expect(westCopies.length, 1);
        expect(westCopies.first.id, 'copy-prag-02');
      });
    });

    // ── 4. COPY UPDATE ────────────────────────────────────────────────────────
    group('4. Copy Update', () {
      test('Staff updates copy details successfully', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        await service.createCopy(validCopy);

        final updated = validCopy.copyWith(
          condition: 'good - minor shelf wear',
          barcode: 'BARCODE-PRAG-NEW',
        );
        final result = await service.updateCopy(updated);

        expect(result.condition, 'good - minor shelf wear');
        expect(result.barcode, 'BARCODE-PRAG-NEW');

        final doc =
            fakeFirestore.store.documents['bookCopies/${validCopy.id}']!;
        expect(doc['condition'], 'good - minor shelf wear');
        expect(doc['barcode'], 'BARCODE-PRAG-NEW');
      });

      test('updateCopy rejects updating nonexistent copy', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        expect(
          () => service.updateCopy(validCopy),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('does not exist'),
            ),
          ),
        );
      });

      test('updateCopy rejects updating actively borrowed copy', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        // Copy is borrowed
        fakeFirestore.store.documents['bookCopies/${validCopy.id}'] = validCopy
            .copyWith(status: BookCopy.statusBorrowed)
            .toFirestore();

        expect(
          () => service.updateCopy(validCopy.copyWith(condition: 'fair')),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('while it is actively on loan'),
            ),
          ),
        );
      });

      test(
        'updateCopy rejects updating copy with an active loan record',
        () async {
          final service = BookCopyService(
            firestore: fakeFirestore,
            auth: staffAuth,
          );

          fakeFirestore.store.documents['bookCopies/${validCopy.id}'] =
              validCopy.toFirestore();
          fakeFirestore.store.documents['loans/active-loan-1'] = {
            'bookId': testBook.id,
            'bookCopyId': validCopy.id,
            'memberId': memberUser.uid,
            'status': 'active',
            'borrowDate': Timestamp.now(),
            'dueDate': Timestamp.now(),
          };

          expect(
            () => service.updateCopy(validCopy.copyWith(condition: 'fair')),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('while it is actively on loan'),
              ),
            ),
          );
        },
      );

      test('updateCopy rejects reassigning copy to a different book', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        await service.createCopy(validCopy);

        // Attempting to reassign copy to otherBook
        final reassigned = validCopy.copyWith(bookId: otherBook.id);

        expect(
          () => service.updateCopy(reassigned),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'Reassigning a book copy to a different book is not permitted',
              ),
            ),
          ),
        );
      });

      test('updateCopy rejects invalid branch reference', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        await service.createCopy(validCopy);

        final invalidBranch = validCopy.copyWith(branchId: 'invalid-branch');

        expect(
          () => service.updateCopy(invalidBranch),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Branch with ID "invalid-branch" does not exist'),
            ),
          ),
        );
      });

      test(
        'updateCopyStatus changes shelf copy status and blocks borrowed copy',
        () async {
          final service = BookCopyService(
            firestore: fakeFirestore,
            auth: staffAuth,
          );

          await service.createCopy(validCopy);

          // Update to maintenance
          final maintenanceCopy = await service.updateCopyStatus(
            validCopy.id,
            BookCopy.statusMaintenance,
          );
          expect(maintenanceCopy.status, BookCopy.statusMaintenance);
          expect(maintenanceCopy.isAvailable, isFalse);

          // Simulate borrowed copy
          fakeFirestore.store.documents['bookCopies/${validCopy.id}'] =
              validCopy.copyWith(status: BookCopy.statusBorrowed).toFirestore();

          expect(
            () => service.updateCopyStatus(
              validCopy.id,
              BookCopy.statusAvailable,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('while it is actively on loan'),
              ),
            ),
          );
        },
      );
    });

    // ── 5. COPY DELETION / REMOVAL ────────────────────────────────────────────
    group('5. Copy Deletion / Removal', () {
      test('Staff deletes available copy cleanly from Firestore', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        await service.createCopy(validCopy);
        expect(
          fakeFirestore.store.documents['bookCopies/${validCopy.id}'],
          isNotNull,
        );

        await service.deleteCopy(validCopy.id);

        expect(
          fakeFirestore.store.documents['bookCopies/${validCopy.id}'],
          isNull,
        );
        final fetched = await service.getCopyById(validCopy.id);
        expect(fetched, isNull);
      });

      test('deleteCopy rejects deleting nonexistent copy', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        expect(
          () => service.deleteCopy('nonexistent-copy'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('does not exist'),
            ),
          ),
        );
      });

      test('deleteCopy rejects deleting an actively borrowed copy', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        fakeFirestore.store.documents['bookCopies/${validCopy.id}'] = validCopy
            .copyWith(status: BookCopy.statusBorrowed)
            .toFirestore();

        expect(
          () => service.deleteCopy(validCopy.id),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('because it is currently borrowed'),
            ),
          ),
        );

        // Document was not deleted
        expect(
          fakeFirestore.store.documents['bookCopies/${validCopy.id}'],
          isNotNull,
        );
      });

      test('deleteCopy rejects deleting copy with active loan record in circulation', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        fakeFirestore.store.documents['bookCopies/${validCopy.id}'] = validCopy
            .toFirestore();
        fakeFirestore.store.documents['loans/active-loan-copy'] = {
          'bookId': testBook.id,
          'bookCopyId': validCopy.id,
          'memberId': memberUser.uid,
          'status': 'active',
          'borrowDate': Timestamp.now(),
          'dueDate': Timestamp.now(),
        };

        expect(
          () => service.deleteCopy(validCopy.id),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('because it is currently on an active loan'),
            ),
          ),
        );

        // Document was not deleted
        expect(
          fakeFirestore.store.documents['bookCopies/${validCopy.id}'],
          isNotNull,
        );
      });

      test('deleteCopy validates non-empty copy ID', () async {
        final service = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        expect(() => service.deleteCopy('  '), throwsA(isA<ArgumentError>()));
      });
    });

    // ── 6. AVAILABILITY & CIRCULATION INTEGRATION ─────────────────────────────
    group('6. Availability and Circulation Integration', () {
      test('Available copy is borrowed, marked borrowed, and restored to available upon return', () async {
        final copyService = BookCopyService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );
        final circulationService = CirculationService(
          firestore: fakeFirestore,
          auth: memberAuth,
        );

        // 1. Staff creates copy
        await copyService.createCopy(validCopy);
        expect(await copyService.getAvailableCopyCountForBook(testBook.id), 1);

        // 2. Member borrows copy
        await circulationService.requestBorrow(
          book: testBook,
          memberId: memberUser.uid,
          branchId: branchMain.id,
          bookCopyId: validCopy.id,
        );

        // Verify copy status is borrowed
        final borrowedCopy = await copyService.getCopyById(validCopy.id);
        expect(borrowedCopy!.status, BookCopy.statusBorrowed);
        expect(borrowedCopy.isAvailable, isFalse);
        expect(await copyService.getAvailableCopyCountForBook(testBook.id), 0);

        // 3. Member returns copy
        final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
          (e) => e.key.startsWith('loans/'),
        );
        final loanId = loanEntry.key.replaceFirst('loans/', '');

        await circulationService.requestReturn(loanId: loanId);

        // Verify copy status is restored to available
        final returnedCopy = await copyService.getCopyById(validCopy.id);
        expect(returnedCopy!.status, BookCopy.statusAvailable);
        expect(returnedCopy.isAvailable, isTrue);
        expect(await copyService.getAvailableCopyCountForBook(testBook.id), 1);
      });

      test(
        'Cross-branch return updates copy branch location cleanly',
        () async {
          final copyService = BookCopyService(
            firestore: fakeFirestore,
            auth: staffAuth,
          );
          final circulationService = CirculationService(
            firestore: fakeFirestore,
            auth: memberAuth,
          );

          await copyService.createCopy(validCopy); // at branchMain

          // Borrow at Main
          await circulationService.requestBorrow(
            book: testBook,
            memberId: memberUser.uid,
            branchId: branchMain.id,
            bookCopyId: validCopy.id,
          );

          final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
            (e) => e.key.startsWith('loans/'),
          );
          final loanId = loanEntry.key.replaceFirst('loans/', '');

          // Return at West
          await circulationService.requestReturn(
            loanId: loanId,
            returnBranchId: branchWest.id,
          );

          // Copy is now located at West
          final copyAtWest = await copyService.getCopyById(validCopy.id);
          expect(copyAtWest!.branchId, branchWest.id);
          expect(copyAtWest.status, BookCopy.statusAvailable);

          final westCopies = await copyService.getCopiesForBranch(
            branchWest.id,
          );
          expect(westCopies.map((c) => c.id), contains(validCopy.id));

          final mainCopies = await copyService.getCopiesForBranch(
            branchMain.id,
          );
          expect(mainCopies.map((c) => c.id), isNot(contains(validCopy.id)));
        },
      );
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

  @override
  Future<void> set(T data, [SetOptions? options]) async {
    if (data is Map<String, dynamic>) {
      final existing = _store.documents[_path];
      if (options?.merge == true && existing != null) {
        final merged = Map<String, dynamic>.from(existing);
        data.forEach((k, v) => merged[k] = v);
        _store.documents[_path] = merged;
      } else {
        _store.documents[_path] = Map<String, dynamic>.from(data);
      }
    }
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    final existing = _store.documents[_path];
    if (existing == null) {
      throw Exception('Document does not exist');
    }
    final merged = Map<String, dynamic>.from(existing);
    data.forEach((k, v) => merged[k.toString()] = v);
    _store.documents[_path] = merged;
  }

  @override
  Future<void> delete() async {
    _store.documents.remove(_path);
  }

  @override
  Stream<DocumentSnapshot<T>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    final data = _store.documents[_path];
    return Stream.value(FakeDocumentSnapshot<T>(id, data as T?));
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

  @override
  Transaction delete(DocumentReference<Object?> documentSnapshot) {
    _hasWritten = true;
    final ref = documentSnapshot as FakeDocumentReference;
    _store.documents.remove(ref._path);
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
