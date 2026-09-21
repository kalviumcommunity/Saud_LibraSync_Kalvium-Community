// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librasync/models/book.dart';
import 'package:librasync/services/auth_service.dart';
import 'package:librasync/services/book_service.dart';
import 'package:librasync/services/circulation_service.dart';

void main() {
  final validStaffBook = Book(
    id: 'book-staff-1',
    title: 'Clean Architecture',
    author: 'Robert C. Martin',
    description: 'A Craftsman\'s Guide to Software Structure and Design.',
    category: 'Software Engineering',
    publishedYear: 2017,
    isbn: '978-0134494166',
    isAvailable: true,
    totalCopies: 5,
    availableCopies: 5,
  );

  final staffUser = FakeUser(
    uid: 'staff-user-001',
    email: 'librarian@librasync.org',
    displayName: 'Head Librarian',
  );

  final memberUser = FakeUser(
    uid: 'member-user-002',
    email: 'member@gmail.com',
    displayName: 'Regular Member',
  );

  group('Book Model Field & Invariant Validation Tests', () {
    test('Valid book passes validation without error', () {
      expect(() => validStaffBook.validate(), returnsNormally);
    });

    test('Throws ArgumentError when title is empty or whitespace', () {
      final invalidBook = validStaffBook.copyWith(title: '   ');
      expect(
        () => invalidBook.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('title cannot be empty'),
          ),
        ),
      );
    });

    test('Throws ArgumentError when author is empty or whitespace', () {
      final invalidBook = validStaffBook.copyWith(author: '');
      expect(
        () => invalidBook.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('author cannot be empty'),
          ),
        ),
      );
    });

    test('Throws ArgumentError when description is empty or whitespace', () {
      final invalidBook = validStaffBook.copyWith(description: '  \n ');
      expect(
        () => invalidBook.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('description cannot be empty'),
          ),
        ),
      );
    });

    test('Throws ArgumentError when totalCopies is less than 1', () {
      final zeroTotal = validStaffBook.copyWith(totalCopies: 0, availableCopies: 0);
      expect(
        () => zeroTotal.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Total copies must be at least 1'),
          ),
        ),
      );

      final negativeTotal = validStaffBook.copyWith(totalCopies: -3);
      expect(
        () => negativeTotal.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Total copies must be at least 1'),
          ),
        ),
      );
    });

    test('Throws ArgumentError when availableCopies is negative', () {
      final negativeAvail = validStaffBook.copyWith(availableCopies: -1);
      expect(
        () => negativeAvail.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Available copies cannot be negative'),
          ),
        ),
      );
    });

    test('Throws ArgumentError when availableCopies exceeds totalCopies', () {
      final invalidCopies = validStaffBook.copyWith(
        totalCopies: 3,
        availableCopies: 5,
      );
      expect(
        () => invalidCopies.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('cannot exceed total copies'),
          ),
        ),
      );
    });

    test('Throws ArgumentError when publishedYear is unrealistic', () {
      final invalidYear = validStaffBook.copyWith(publishedYear: 3050);
      expect(
        () => invalidYear.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Invalid publication year'),
          ),
        ),
      );
    });

    test('Static validateBookData verifies standalone input parameters', () {
      expect(
        () => Book.validateBookData(
          title: 'Refactoring',
          author: 'Martin Fowler',
          description: 'Improving the Design of Existing Code',
          totalCopies: 4,
          availableCopies: 2,
        ),
        returnsNormally,
      );

      expect(
        () => Book.validateBookData(
          title: '',
          author: 'Author',
          description: 'Desc',
          totalCopies: 2,
          availableCopies: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('toFirestore trims strings and auto-computes isAvailable', () {
      final book = Book(
        id: 'book-zero-copies',
        title: '  Algorithms ',
        author: ' Sedgewick ',
        description: ' Comprehensive guide ',
        totalCopies: 2,
        availableCopies: 0,
        isAvailable: true, // Should be normalized to false
      );

      final map = book.toFirestore();
      expect(map['title'], 'Algorithms');
      expect(map['author'], 'Sedgewick');
      expect(map['description'], 'Comprehensive guide');
      expect(map['isAvailable'], isFalse);
    });
  });

  group('Staff Authorization & Access Control Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      // Setup users in Firestore
      fakeFirestore.store.documents['users/${staffUser.uid}'] = {
        'uid': staffUser.uid,
        'email': staffUser.email,
        'displayName': staffUser.displayName,
        'role': 'staff',
      };
      fakeFirestore.store.documents['users/${memberUser.uid}'] = {
        'uid': memberUser.uid,
        'email': memberUser.email,
        'displayName': memberUser.displayName,
        'role': 'member',
      };
    });

    test('Unauthenticated user is rejected when attempting createBook', () async {
      final fakeAuth = FakeFirebaseAuth(currentUser: null);
      final service = BookService(firestore: fakeFirestore, auth: fakeAuth);

      expect(
        () => service.createBook(validStaffBook),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Authentication required'),
          ),
        ),
      );
    });

    test('Unauthenticated user is rejected when attempting updateBook', () async {
      final fakeAuth = FakeFirebaseAuth(currentUser: null);
      final service = BookService(firestore: fakeFirestore, auth: fakeAuth);

      expect(
        () => service.updateBook(validStaffBook),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Authentication required'),
          ),
        ),
      );
    });

    test('Unauthenticated user is rejected when attempting deleteBook', () async {
      final fakeAuth = FakeFirebaseAuth(currentUser: null);
      final service = BookService(firestore: fakeFirestore, auth: fakeAuth);

      expect(
        () => service.deleteBook(validStaffBook.id),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Authentication required'),
          ),
        ),
      );
    });

    test('Member without staff role is rejected on createBook', () async {
      final fakeAuth = FakeFirebaseAuth(currentUser: memberUser);
      final service = BookService(firestore: fakeFirestore, auth: fakeAuth);

      expect(
        () => service.createBook(validStaffBook),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unauthorized access. Only library staff can manage the book catalog'),
          ),
        ),
      );
    });

    test('Member without staff role is rejected on updateBook', () async {
      final fakeAuth = FakeFirebaseAuth(currentUser: memberUser);
      final service = BookService(firestore: fakeFirestore, auth: fakeAuth);

      // Seed book in firestore
      fakeFirestore.store.documents['books/${validStaffBook.id}'] =
          validStaffBook.toFirestore();

      expect(
        () => service.updateBook(validStaffBook),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unauthorized access'),
          ),
        ),
      );
    });

    test('Member without staff role is rejected on deleteBook', () async {
      final fakeAuth = FakeFirebaseAuth(currentUser: memberUser);
      final service = BookService(firestore: fakeFirestore, auth: fakeAuth);

      fakeFirestore.store.documents['books/${validStaffBook.id}'] =
          validStaffBook.toFirestore();

      expect(
        () => service.deleteBook(validStaffBook.id),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unauthorized access'),
          ),
        ),
      );
    });

    test('AuthService correctly identifies staff vs member roles', () async {
      final authService = AuthService(firestore: fakeFirestore);
      expect(await authService.isStaffUser(staffUser.uid), isTrue);
      expect(await authService.isStaffUser(memberUser.uid), isFalse);
      expect(await authService.getUserRole(staffUser.uid), 'staff');
      expect(await authService.getUserRole(memberUser.uid), 'member');
      expect(await authService.getUserRole('non-existent-uid'), 'member');
    });
  });

  group('Staff Book Backend CRUD Operations', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseAuth staffAuth;
    late BookService bookService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      staffAuth = FakeFirebaseAuth(currentUser: staffUser);
      fakeFirestore.store.documents['users/${staffUser.uid}'] = {
        'uid': staffUser.uid,
        'email': staffUser.email,
        'role': 'staff',
      };
      bookService = BookService(firestore: fakeFirestore, auth: staffAuth);
    });

    test('Staff successfully creates a book with auto-generated ID', () async {
      final newBook = Book(
        id: '', // Should be auto-assigned
        title: 'Domain-Driven Design',
        author: 'Eric Evans',
        description: 'Tackling Complexity in the Heart of Software.',
        category: 'Software Engineering',
        publishedYear: 2003,
        totalCopies: 4,
        availableCopies: 4,
      );

      final created = await bookService.createBook(newBook);

      expect(created.id, isNotEmpty);
      expect(created.title, 'Domain-Driven Design');
      expect(created.isAvailable, isTrue);

      final doc = fakeFirestore.store.documents['books/${created.id}'];
      expect(doc, isNotNull);
      expect(doc!['title'], 'Domain-Driven Design');
      expect(doc['author'], 'Eric Evans');
      expect(doc['totalCopies'], 4);
      expect(doc['availableCopies'], 4);
      expect(doc['isAvailable'], isTrue);
    });

    test('Staff successfully creates a book with specified ID', () async {
      final created = await bookService.createBook(validStaffBook);

      expect(created.id, validStaffBook.id);
      expect(fakeFirestore.store.documents['books/${validStaffBook.id}'], isNotNull);
    });

    test('Invalid copy counts on createBook fail validation before writing', () async {
      final invalidBook = validStaffBook.copyWith(
        totalCopies: 2,
        availableCopies: 5,
      );

      expect(
        () => bookService.createBook(invalidBook),
        throwsA(isA<ArgumentError>()),
      );

      expect(fakeFirestore.store.documents['books/${invalidBook.id}'], isNull);
    });

    test('Staff successfully updates an existing book in catalog', () async {
      // Seed existing book
      fakeFirestore.store.documents['books/${validStaffBook.id}'] =
          validStaffBook.toFirestore();

      final updatedBook = validStaffBook.copyWith(
        title: 'Clean Architecture (2nd Edition)',
        totalCopies: 10,
        availableCopies: 8,
      );

      final result = await bookService.updateBook(updatedBook);

      expect(result.title, 'Clean Architecture (2nd Edition)');
      expect(result.totalCopies, 10);
      expect(result.availableCopies, 8);

      final doc = fakeFirestore.store.documents['books/${validStaffBook.id}'];
      expect(doc!['title'], 'Clean Architecture (2nd Edition)');
      expect(doc['totalCopies'], 10);
      expect(doc['availableCopies'], 8);
    });

    test('Updating non-existent book throws Exception', () async {
      expect(
        () => bookService.updateBook(validStaffBook),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('does not exist in catalog'),
          ),
        ),
      );
    });

    test('Updating book with empty ID throws ArgumentError', () async {
      final noIdBook = validStaffBook.copyWith(id: '');
      expect(
        () => bookService.updateBook(noIdBook),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Staff successfully deletes a book from catalog', () async {
      fakeFirestore.store.documents['books/${validStaffBook.id}'] =
          validStaffBook.toFirestore();

      await bookService.deleteBook(validStaffBook.id);

      expect(fakeFirestore.store.documents['books/${validStaffBook.id}'], isNull);
    });

    test('Deleting non-existent book throws Exception', () async {
      expect(
        () => bookService.deleteBook('non-existent-book-id'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('does not exist in catalog'),
          ),
        ),
      );
    });
  });

  group('Catalog Queries & Circulation Regression Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseAuth memberAuth;
    late BookService bookService;
    late CirculationService circulationService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      memberAuth = FakeFirebaseAuth(currentUser: memberUser);
      bookService = BookService(firestore: fakeFirestore, auth: memberAuth);
      circulationService = CirculationService(firestore: fakeFirestore, auth: memberAuth);

      // Seed catalog with books
      fakeFirestore.store.documents['books/${validStaffBook.id}'] =
          validStaffBook.toFirestore();
    });

    test('getBooks and getBookById return expected catalog items', () async {
      final books = await bookService.getBooks();
      expect(books.length, 1);
      expect(books.first.title, validStaffBook.title);

      final singleBook = await bookService.getBookById(validStaffBook.id);
      expect(singleBook, isNotNull);
      expect(singleBook!.id, validStaffBook.id);

      final nonExistent = await bookService.getBookById('non-existent');
      expect(nonExistent, isNull);
    });

    test('Circulation borrow and return operations remain 100% intact', () async {
      // 1. Member borrows book
      await circulationService.requestBorrow(
        book: validStaffBook,
        memberId: memberUser.uid,
        memberName: memberUser.displayName,
      );

      // Verify book available copies decremented from 5 to 4
      final bookAfterBorrow =
          fakeFirestore.store.documents['books/${validStaffBook.id}'];
      expect(bookAfterBorrow!['availableCopies'], 4);
      expect(bookAfterBorrow['isAvailable'], isTrue);

      // Find created loan record
      final loanEntry = fakeFirestore.store.documents.entries.firstWhere(
        (e) => e.key.startsWith('loans/'),
      );
      final loanId = loanEntry.key.replaceFirst('loans/', '');
      expect(loanEntry.value['bookId'], validStaffBook.id);
      expect(loanEntry.value['memberId'], memberUser.uid);
      expect(loanEntry.value['status'], 'active');

      // 2. Member returns book
      await circulationService.requestReturn(loanId: loanId);

      // Verify loan is marked returned
      final loanAfterReturn = fakeFirestore.store.documents['loans/$loanId'];
      expect(loanAfterReturn!['status'], 'returned');
      expect(loanAfterReturn['returnDate'], isNotNull);

      // Verify copies restored back to 5
      final bookAfterReturn =
          fakeFirestore.store.documents['books/${validStaffBook.id}'];
      expect(bookAfterReturn!['availableCopies'], 5);
      expect(bookAfterReturn['isAvailable'], isTrue);
    });
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
  Stream<DocumentSnapshot<T>> snapshots({bool includeMetadataChanges = false}) {
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
    return FakeQuery<T>(_collectionPath, _store).where(field, isEqualTo: isEqualTo);
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

class FakeTransaction extends Fake implements Transaction {
  FakeTransaction(this._store);

  final FakeFirestoreData _store;
  bool _hasWritten = false;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
      DocumentReference<T> documentSnapshot) async {
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
      DocumentReference<Object?> documentSnapshot, Map<Object, Object?> data) {
    _hasWritten = true;
    final ref = documentSnapshot as FakeDocumentReference;
    final existing =
        Map<String, dynamic>.from(_store.documents[ref._path] ?? {});
    data.forEach((k, v) => existing[k.toString()] = v);
    _store.documents[ref._path] = existing;
    return this;
  }

  @override
  Transaction set<T extends Object?>(
      DocumentReference<T> documentSnapshot, T data,
      [SetOptions? options]) {
    _hasWritten = true;
    final ref = documentSnapshot as FakeDocumentReference<T>;
    if (data is Map<String, dynamic>) {
      _store.documents[ref._path] = Map<String, dynamic>.from(data);
    }
    return this;
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
  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    final transaction = FakeTransaction(store);
    return await transactionHandler(transaction);
  }
}
