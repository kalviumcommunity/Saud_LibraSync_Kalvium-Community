// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librasync/models/book.dart';
import 'package:librasync/models/book_copy.dart';
import 'package:librasync/services/book_copy_service.dart';
import 'package:librasync/services/circulation_service.dart';

void main() {
  final sampleCopy1 = BookCopy(
    id: 'copy-101',
    bookId: 'book-001',
    branchId: 'branch-central',
    status: BookCopy.statusAvailable,
    barcode: 'BC-001-01',
    condition: 'good',
  );

  final sampleCopy2 = BookCopy(
    id: 'copy-102',
    bookId: 'book-001',
    branchId: 'branch-north',
    status: BookCopy.statusBorrowed,
    barcode: 'BC-001-02',
    condition: 'fair',
  );

  final sampleCopy3 = BookCopy(
    id: 'copy-201',
    bookId: 'book-002',
    branchId: 'branch-central',
    status: BookCopy.statusAvailable,
    barcode: 'BC-002-01',
    condition: 'new',
  );

  group('BookCopy Model Unit Tests', () {
    test('Valid book copy passes validation without error', () {
      expect(() => sampleCopy1.validate(), returnsNormally);
    });

    test('Throws ArgumentError when bookId is empty or whitespace', () {
      final invalid = sampleCopy1.copyWith(bookId: '   ');
      expect(
        () => invalid.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Book ID cannot be empty'),
          ),
        ),
      );
    });

    test('Throws ArgumentError when branchId is empty or whitespace', () {
      final invalid = sampleCopy1.copyWith(branchId: '   ');
      expect(
        () => invalid.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Branch ID cannot be empty'),
          ),
        ),
      );
    });

    test('Throws ArgumentError when status is empty or whitespace', () {
      final invalid = sampleCopy1.copyWith(status: '   ');
      expect(
        () => invalid.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Status cannot be empty'),
          ),
        ),
      );
    });

    test('Throws ArgumentError when status is invalid', () {
      final invalidStatus = sampleCopy1.copyWith(status: 'damaged');
      expect(
        () => invalidStatus.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Invalid copy status'),
          ),
        ),
      );
    });

    test('Correctly serializes to and from Firestore map', () {
      final map = sampleCopy1.toFirestore();
      expect(map['bookId'], 'book-001');
      expect(map['branchId'], 'branch-central');
      expect(map['status'], 'available');
      expect(map['barcode'], 'BC-001-01');
      expect(map['condition'], 'good');

      final deserialized = BookCopy.fromFirestore(map, 'copy-101');
      expect(deserialized.id, 'copy-101');
      expect(deserialized.bookId, 'book-001');
      expect(deserialized.branchId, 'branch-central');
      expect(deserialized.status, 'available');
      expect(deserialized.barcode, 'BC-001-01');
      expect(deserialized.condition, 'good');
      expect(deserialized.isAvailable, isTrue);
    });

    test('Handles missing optional fields during deserialization', () {
      final minimalMap = <String, dynamic>{
        'bookId': 'book-003',
        'branchId': 'branch-west',
      };
      final deserialized = BookCopy.fromFirestore(minimalMap, 'copy-min');

      expect(deserialized.id, 'copy-min');
      expect(deserialized.bookId, 'book-003');
      expect(deserialized.branchId, 'branch-west');
      expect(deserialized.status, BookCopy.statusAvailable);
      expect(deserialized.barcode, isNull);
      expect(deserialized.condition, isNull);
      expect(deserialized.isAvailable, isTrue);
    });

    test('Evaluates isAvailable correctly for various statuses', () {
      expect(sampleCopy1.copyWith(status: 'available').isAvailable, isTrue);
      expect(sampleCopy1.copyWith(status: 'Available').isAvailable, isTrue);
      expect(sampleCopy1.copyWith(status: 'borrowed').isAvailable, isFalse);
      expect(sampleCopy1.copyWith(status: 'maintenance').isAvailable, isFalse);
      expect(sampleCopy1.copyWith(status: 'lost').isAvailable, isFalse);
    });

    test('copyWith updates properties properly', () {
      final updated = sampleCopy1.copyWith(
        status: BookCopy.statusMaintenance,
        condition: 'damaged cover',
      );
      expect(updated.id, sampleCopy1.id);
      expect(updated.bookId, sampleCopy1.bookId);
      expect(updated.branchId, sampleCopy1.branchId);
      expect(updated.status, BookCopy.statusMaintenance);
      expect(updated.condition, 'damaged cover');
      expect(updated.barcode, sampleCopy1.barcode);
    });

    test('Equality and hashCode operate correctly', () {
      final duplicate = BookCopy(
        id: 'copy-101',
        bookId: 'book-001',
        branchId: 'branch-central',
        status: BookCopy.statusAvailable,
        barcode: 'BC-001-01',
        condition: 'good',
      );
      expect(sampleCopy1, equals(duplicate));
      expect(sampleCopy1.hashCode, equals(duplicate.hashCode));
      expect(sampleCopy1.toString(), contains('copy-101'));
    });
  });

  group('BookCopyService Operations Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late BookCopyService copyService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      copyService = BookCopyService(firestore: fakeFirestore);
    });

    test('getAllCopies returns empty list when collection is empty', () async {
      final copies = await copyService.getAllCopies();
      expect(copies, isEmpty);
    });

    test('getAllCopies returns all seeded copies', () async {
      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore();
      fakeFirestore.store.documents['bookCopies/${sampleCopy2.id}'] =
          sampleCopy2.toFirestore();

      final copies = await copyService.getAllCopies();
      expect(copies.length, 2);
      expect(copies.map((c) => c.id), containsAll(['copy-101', 'copy-102']));
    });

    test('getCopiesForBook filters by bookId', () async {
      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore();
      fakeFirestore.store.documents['bookCopies/${sampleCopy2.id}'] =
          sampleCopy2.toFirestore();
      fakeFirestore.store.documents['bookCopies/${sampleCopy3.id}'] =
          sampleCopy3.toFirestore();

      final book1Copies = await copyService.getCopiesForBook('book-001');
      expect(book1Copies.length, 2);
      expect(
        book1Copies.map((c) => c.id),
        containsAll(['copy-101', 'copy-102']),
      );

      final book2Copies = await copyService.getCopiesForBook('book-002');
      expect(book2Copies.length, 1);
      expect(book2Copies.first.id, 'copy-201');

      final emptyCopies = await copyService.getCopiesForBook('book-unknown');
      expect(emptyCopies, isEmpty);

      final blankIdCopies = await copyService.getCopiesForBook('   ');
      expect(blankIdCopies, isEmpty);
    });

    test('getCopiesForBranch filters by branchId', () async {
      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore();
      fakeFirestore.store.documents['bookCopies/${sampleCopy2.id}'] =
          sampleCopy2.toFirestore();
      fakeFirestore.store.documents['bookCopies/${sampleCopy3.id}'] =
          sampleCopy3.toFirestore();

      final centralCopies = await copyService.getCopiesForBranch(
        'branch-central',
      );
      expect(centralCopies.length, 2);
      expect(
        centralCopies.map((c) => c.id),
        containsAll(['copy-101', 'copy-201']),
      );

      final northCopies = await copyService.getCopiesForBranch('branch-north');
      expect(northCopies.length, 1);
      expect(northCopies.first.id, 'copy-102');

      final blankBranchCopies = await copyService.getCopiesForBranch('  ');
      expect(blankBranchCopies, isEmpty);
    });

    test('getCopyById returns correct copy or null if missing', () async {
      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore();

      final copy = await copyService.getCopyById(sampleCopy1.id);
      expect(copy, isNotNull);
      expect(copy!.id, sampleCopy1.id);
      expect(copy.barcode, 'BC-001-01');

      final missing = await copyService.getCopyById('non-existent');
      expect(missing, isNull);

      final empty = await copyService.getCopyById('   ');
      expect(empty, isNull);
    });

    test('streamCopies emits real-time copy list', () async {
      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore();

      final stream = copyService.streamCopies();
      final emitted = await stream.first;

      expect(emitted.length, 1);
      expect(emitted.first.id, sampleCopy1.id);
    });

    test('streamCopiesForBook emits filtered real-time copy list', () async {
      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore();
      fakeFirestore.store.documents['bookCopies/${sampleCopy3.id}'] =
          sampleCopy3.toFirestore();

      final stream = copyService.streamCopiesForBook('book-001');
      final emitted = await stream.first;

      expect(emitted.length, 1);
      expect(emitted.first.id, sampleCopy1.id);

      final blankStream = copyService.streamCopiesForBook('  ');
      final blankEmitted = await blankStream.first;
      expect(blankEmitted, isEmpty);
    });

    test('streamCopiesForBranch emits filtered real-time copy list', () async {
      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore();
      fakeFirestore.store.documents['bookCopies/${sampleCopy2.id}'] =
          sampleCopy2.toFirestore();

      final stream = copyService.streamCopiesForBranch('branch-north');
      final emitted = await stream.first;

      expect(emitted.length, 1);
      expect(emitted.first.id, sampleCopy2.id);

      final blankStream = copyService.streamCopiesForBranch('  ');
      final blankEmitted = await blankStream.first;
      expect(blankEmitted, isEmpty);
    });

    test('streamCopyById emits copy or null', () async {
      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore();

      final stream = copyService.streamCopyById(sampleCopy1.id);
      final emitted = await stream.first;
      expect(emitted, isNotNull);
      expect(emitted!.id, sampleCopy1.id);

      final missingStream = copyService.streamCopyById('missing-id');
      final missingEmitted = await missingStream.first;
      expect(missingEmitted, isNull);

      final blankStream = copyService.streamCopyById('  ');
      final blankEmitted = await blankStream.first;
      expect(blankEmitted, isNull);
    });

    test('getAvailableCopiesForBook filters out unavailable copies', () async {
      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore(); // book-001, branch-central, available
      fakeFirestore.store.documents['bookCopies/${sampleCopy2.id}'] =
          sampleCopy2.toFirestore(); // book-001, branch-north, borrowed
      fakeFirestore.store.documents['bookCopies/${sampleCopy3.id}'] =
          sampleCopy3.toFirestore(); // book-002, branch-central, available

      final availableBook1 = await copyService.getAvailableCopiesForBook(
        'book-001',
      );
      expect(availableBook1.length, 1);
      expect(availableBook1.first.id, 'copy-101');
      expect(availableBook1.first.isAvailable, isTrue);

      final blankBook = await copyService.getAvailableCopiesForBook('  ');
      expect(blankBook, isEmpty);
    });

    test(
      'getAvailableCopiesForBook with branchId filters by both book and branch',
      () async {
        final centralCopy2 = sampleCopy1.copyWith(
          id: 'copy-103',
          branchId: 'branch-central',
          status: BookCopy.statusAvailable,
        );
        final northCopyAvail = sampleCopy1.copyWith(
          id: 'copy-104',
          branchId: 'branch-north',
          status: BookCopy.statusAvailable,
        );

        fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
            sampleCopy1.toFirestore();
        fakeFirestore.store.documents['bookCopies/${centralCopy2.id}'] =
            centralCopy2.toFirestore();
        fakeFirestore.store.documents['bookCopies/${northCopyAvail.id}'] =
            northCopyAvail.toFirestore();

        final centralCopies = await copyService.getAvailableCopiesForBook(
          'book-001',
          branchId: 'branch-central',
        );
        expect(centralCopies.length, 2);
        expect(
          centralCopies.map((c) => c.id),
          containsAll(['copy-101', 'copy-103']),
        );

        final northCopies = await copyService.getAvailableCopiesForBook(
          'book-001',
          branchId: 'branch-north',
        );
        expect(northCopies.length, 1);
        expect(northCopies.first.id, 'copy-104');
      },
    );

    test(
      'streamAvailableCopiesForBook streams only available copies for a book',
      () async {
        fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
            sampleCopy1.toFirestore(); // available
        fakeFirestore.store.documents['bookCopies/${sampleCopy2.id}'] =
            sampleCopy2.toFirestore(); // borrowed

        final stream = copyService.streamAvailableCopiesForBook('book-001');
        final emitted = await stream.first;

        expect(emitted.length, 1);
        expect(emitted.first.id, 'copy-101');
        expect(emitted.first.isAvailable, isTrue);

        final blankStream = copyService.streamAvailableCopiesForBook('  ');
        expect(await blankStream.first, isEmpty);
      },
    );

    test('streamAvailableCopiesForBook with branchId streams available copies at branch', () async {
      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore(); // central, available

      final stream = copyService.streamAvailableCopiesForBook(
        'book-001',
        branchId: 'branch-central',
      );
      final emitted = await stream.first;

      expect(emitted.length, 1);
      expect(emitted.first.id, 'copy-101');

      final emptyBranchStream = copyService.streamAvailableCopiesForBook(
        'book-001',
        branchId: 'branch-west',
      );
      expect(await emptyBranchStream.first, isEmpty);
    });

    test(
      'getAvailableCopiesForBranch returns all available copies at branch',
      () async {
        fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
            sampleCopy1.toFirestore(); // book-001, central, available
        fakeFirestore.store.documents['bookCopies/${sampleCopy2.id}'] =
            sampleCopy2.toFirestore(); // book-001, north, borrowed
        fakeFirestore.store.documents['bookCopies/${sampleCopy3.id}'] =
            sampleCopy3.toFirestore(); // book-002, central, available

        final centralAvailable = await copyService.getAvailableCopiesForBranch(
          'branch-central',
        );
        expect(centralAvailable.length, 2);
        expect(
          centralAvailable.map((c) => c.id),
          containsAll(['copy-101', 'copy-201']),
        );

        final northAvailable = await copyService.getAvailableCopiesForBranch(
          'branch-north',
        );
        expect(northAvailable, isEmpty);

        expect(await copyService.getAvailableCopiesForBranch('  '), isEmpty);
      },
    );

    test('streamAvailableCopiesForBranch streams real-time available copies at branch', () async {
      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore();

      final stream = copyService.streamAvailableCopiesForBranch(
        'branch-central',
      );
      final emitted = await stream.first;

      expect(emitted.length, 1);
      expect(emitted.first.id, 'copy-101');

      final blankStream = copyService.streamAvailableCopiesForBranch(' ');
      expect(await blankStream.first, isEmpty);
    });

    test(
      'getCopiesForBookAndBranch returns all copies regardless of status',
      () async {
        final copyBorrowed = sampleCopy1.copyWith(
          id: 'copy-105',
          status: BookCopy.statusBorrowed,
        );
        fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
            sampleCopy1.toFirestore(); // central, available
        fakeFirestore.store.documents['bookCopies/${copyBorrowed.id}'] =
            copyBorrowed.toFirestore(); // central, borrowed

        final copies = await copyService.getCopiesForBookAndBranch(
          'book-001',
          'branch-central',
        );
        expect(copies.length, 2);
        expect(copies.map((c) => c.id), containsAll(['copy-101', 'copy-105']));

        expect(
          await copyService.getCopiesForBookAndBranch('', 'branch-central'),
          isEmpty,
        );
        expect(
          await copyService.getCopiesForBookAndBranch('book-001', ''),
          isEmpty,
        );
      },
    );

    test(
      'streamCopiesForBookAndBranch streams copies for book and branch',
      () async {
        fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
            sampleCopy1.toFirestore();

        final stream = copyService.streamCopiesForBookAndBranch(
          'book-001',
          'branch-central',
        );
        final emitted = await stream.first;

        expect(emitted.length, 1);
        expect(emitted.first.id, 'copy-101');

        final emptyStream = copyService.streamCopiesForBookAndBranch(' ', ' ');
        expect(await emptyStream.first, isEmpty);
      },
    );

    test('getAvailableCopyCountForBook returns correct count', () async {
      final centralCopy2 = sampleCopy1.copyWith(
        id: 'copy-106',
        branchId: 'branch-central',
        status: BookCopy.statusAvailable,
      );
      final northCopy2 = sampleCopy1.copyWith(
        id: 'copy-107',
        branchId: 'branch-north',
        status: BookCopy.statusAvailable,
      );
      final borrowedCopy = sampleCopy1.copyWith(
        id: 'copy-108',
        status: BookCopy.statusBorrowed,
      );

      fakeFirestore.store.documents['bookCopies/${sampleCopy1.id}'] =
          sampleCopy1.toFirestore();
      fakeFirestore.store.documents['bookCopies/${centralCopy2.id}'] =
          centralCopy2.toFirestore();
      fakeFirestore.store.documents['bookCopies/${northCopy2.id}'] = northCopy2
          .toFirestore();
      fakeFirestore.store.documents['bookCopies/${borrowedCopy.id}'] =
          borrowedCopy.toFirestore();

      final totalAvail = await copyService.getAvailableCopyCountForBook(
        'book-001',
      );
      expect(totalAvail, 3);

      final centralAvail = await copyService.getAvailableCopyCountForBook(
        'book-001',
        branchId: 'branch-central',
      );
      expect(centralAvail, 2);

      final northAvail = await copyService.getAvailableCopyCountForBook(
        'book-001',
        branchId: 'branch-north',
      );
      expect(northAvail, 1);
    });

    test('Handles Firestore errors gracefully in stream methods', () async {
      final errorFirestore = ErrorFirebaseFirestore();
      final errorService = BookCopyService(firestore: errorFirestore);

      expect(errorService.streamCopies(), emitsError(isA<FirebaseException>()));
      expect(
        errorService.streamCopiesForBook('book-001'),
        emitsError(isA<FirebaseException>()),
      );
      expect(
        errorService.streamCopiesForBranch('branch-central'),
        emitsError(isA<FirebaseException>()),
      );
      expect(
        errorService.streamCopyById('copy-101'),
        emitsError(isA<FirebaseException>()),
      );
      expect(
        errorService.streamAvailableCopiesForBook('book-001'),
        emitsError(isA<FirebaseException>()),
      );
      expect(
        errorService.streamAvailableCopiesForBranch('branch-central'),
        emitsError(isA<FirebaseException>()),
      );
      expect(
        errorService.streamCopiesForBookAndBranch('book-001', 'branch-central'),
        emitsError(isA<FirebaseException>()),
      );
    });

    test('Handles Firestore errors gracefully in future methods', () async {
      final errorFirestore = ErrorFirebaseFirestore();
      final errorService = BookCopyService(firestore: errorFirestore);

      expect(
        () => errorService.getAllCopies(),
        throwsA(isA<FirebaseException>()),
      );
      expect(
        () => errorService.getCopiesForBook('book-001'),
        throwsA(isA<FirebaseException>()),
      );
      expect(
        () => errorService.getCopiesForBranch('branch-central'),
        throwsA(isA<FirebaseException>()),
      );
      expect(
        () => errorService.getCopyById('copy-101'),
        throwsA(isA<FirebaseException>()),
      );
      expect(
        () => errorService.getAvailableCopiesForBook('book-001'),
        throwsA(isA<FirebaseException>()),
      );
      expect(
        () => errorService.getAvailableCopiesForBranch('branch-central'),
        throwsA(isA<FirebaseException>()),
      );
      expect(
        () => errorService.getCopiesForBookAndBranch(
          'book-001',
          'branch-central',
        ),
        throwsA(isA<FirebaseException>()),
      );
    });

    test(
      'Circulation borrow and return operations remain intact and unaffected',
      () async {
        final memberUser = FakeUser(
          uid: 'user-001',
          email: 'member@test.com',
          displayName: 'Test Member',
        );
        final memberAuth = FakeFirebaseAuth(currentUser: memberUser);
        final circulationService = CirculationService(
          firestore: fakeFirestore,
          auth: memberAuth,
        );

        final testBook = Book(
          id: 'book-circ-001',
          title: 'Refactoring',
          author: 'Martin Fowler',
          description: 'Improving the Design of Existing Code',
          totalCopies: 3,
          availableCopies: 3,
          isAvailable: true,
        );

        fakeFirestore.store.documents['books/${testBook.id}'] = testBook
            .toFirestore();

        // Member borrows book
        await circulationService.requestBorrow(
          book: testBook,
          memberId: memberUser.uid,
        );

        final bookAfterBorrow =
            fakeFirestore.store.documents['books/${testBook.id}'];
        expect(bookAfterBorrow!['availableCopies'], 2);
        expect(bookAfterBorrow['isAvailable'], isTrue);

        final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
          (e) => e.key.startsWith('loans/'),
        );
        final loanId = loanEntry.key.replaceFirst('loans/', '');

        // Member returns book
        await circulationService.requestReturn(loanId: loanId);

        final bookAfterReturn =
            fakeFirestore.store.documents['books/${testBook.id}'];
        expect(bookAfterReturn!['availableCopies'], 3);
        expect(bookAfterReturn['isAvailable'], isTrue);
      },
    );
  });
}

// ── Fake Test Doubles ────────────────────────────────────────────────────────

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

  @override
  Stream<QuerySnapshot<T>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
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
    return Stream.value(FakeQuerySnapshot<T>(docs));
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

  @override
  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    final docs = <QueryDocumentSnapshot<T>>[];
    _store.documents.forEach((path, data) {
      if (path.startsWith('$_collectionPath/')) {
        final docId = path.substring('$_collectionPath/'.length);
        docs.add(FakeQueryDocumentSnapshot<T>(docId, data as T));
      }
    });
    return FakeQuerySnapshot<T>(docs);
  }

  @override
  Stream<QuerySnapshot<T>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    final docs = <QueryDocumentSnapshot<T>>[];
    _store.documents.forEach((path, data) {
      if (path.startsWith('$_collectionPath/')) {
        final docId = path.substring('$_collectionPath/'.length);
        docs.add(FakeQueryDocumentSnapshot<T>(docId, data as T));
      }
    });
    return Stream.value(FakeQuerySnapshot<T>(docs));
  }
}

class FakeFirestoreData {
  final Map<String, Map<String, dynamic>> documents = {};
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

class ErrorFirebaseFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'Firestore service unavailable.',
    );
  }
}
