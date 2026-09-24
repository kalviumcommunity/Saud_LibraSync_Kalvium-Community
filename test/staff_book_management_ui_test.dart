// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librasync/models/book.dart';
import 'package:librasync/screens/catalog/book_catalog_screen.dart';
import 'package:librasync/screens/catalog/book_details_screen.dart';
import 'package:librasync/services/book_service.dart';
import 'package:librasync/widgets/catalog/book_form_dialog.dart';
import 'package:librasync/widgets/catalog/delete_book_dialog.dart';

void main() {
  final sampleBook = Book(
    id: 'book-staff-test-1',
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

  group('BookFormDialog Widget Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseAuth staffAuth;
    late BookService bookService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      final staffUser = FakeUser(
        uid: 'staff-user-1',
        email: 'librarian@librasync.org',
      );
      staffAuth = FakeFirebaseAuth(currentUser: staffUser);
      fakeFirestore.store.documents['users/${staffUser.uid}'] = {
        'uid': staffUser.uid,
        'email': staffUser.email,
        'role': 'staff',
      };
      bookService = BookService(firestore: fakeFirestore, auth: staffAuth);
    });

    testWidgets('Renders all fields in Add New Book mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BookFormDialog(bookService: bookService)),
        ),
      );

      expect(find.text('Add New Book'), findsOneWidget);
      expect(find.byKey(const Key('book_form_title_field')), findsOneWidget);
      expect(find.byKey(const Key('book_form_author_field')), findsOneWidget);
      expect(
        find.byKey(const Key('book_form_description_field')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('book_form_category_field')), findsOneWidget);
      expect(
        find.byKey(const Key('book_form_published_year_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('book_form_total_copies_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('book_form_available_copies_field')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('book_form_submit_btn')), findsOneWidget);
      expect(find.byKey(const Key('book_form_cancel_btn')), findsOneWidget);
      expect(find.text('Add Book'), findsOneWidget);
    });

    testWidgets('Validates required fields on submit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BookFormDialog(bookService: bookService)),
        ),
      );

      // Clear default numeric inputs to trigger empty errors
      await tester.enterText(
        find.byKey(const Key('book_form_total_copies_field')),
        '',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_available_copies_field')),
        '',
      );

      // Tap submit
      await tester.tap(find.byKey(const Key('book_form_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter the book title.'), findsOneWidget);
      expect(find.text('Please enter the author name.'), findsOneWidget);
      expect(
        find.text('Please enter a description for the book.'),
        findsOneWidget,
      );
    });

    testWidgets('Validates available copies cannot exceed total copies', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BookFormDialog(bookService: bookService)),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('book_form_title_field')),
        'Test Book',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_author_field')),
        'Test Author',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_description_field')),
        'Test Description',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_total_copies_field')),
        '3',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_available_copies_field')),
        '5',
      );

      await tester.tap(find.byKey(const Key('book_form_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Cannot exceed total'), findsOneWidget);
    });

    testWidgets('Successfully creates a new book and returns Book instance', (
      WidgetTester tester,
    ) async {
      Book? createdResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                createdResult = await BookFormDialog.show(
                  context,
                  bookService: bookService,
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter book data
      await tester.enterText(
        find.byKey(const Key('book_form_title_field')),
        'Pragmatic Programmer',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_author_field')),
        'Andy Hunt, Dave Thomas',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_description_field')),
        'From Journeyman to Master',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_category_field')),
        'Software Engineering',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_published_year_field')),
        '1999',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_total_copies_field')),
        '4',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_available_copies_field')),
        '4',
      );

      // Submit
      await tester.tap(find.byKey(const Key('book_form_submit_btn')));
      await tester.pumpAndSettle();

      expect(createdResult, isNotNull);
      expect(createdResult!.title, 'Pragmatic Programmer');
      expect(createdResult!.author, 'Andy Hunt, Dave Thomas');
      expect(createdResult!.totalCopies, 4);

      // Check Firestore doc created
      final docs = fakeFirestore.store.documents.entries
          .where((e) => e.key.startsWith('books/'))
          .toList();
      expect(docs.length, 1);
      expect(docs.first.value['title'], 'Pragmatic Programmer');
    });

    testWidgets(
      'Renders pre-filled fields in Edit Book mode and updates book',
      (WidgetTester tester) async {
        // Seed book in firestore
        fakeFirestore.store.documents['books/${sampleBook.id}'] = sampleBook
            .toFirestore();

        Book? updatedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  updatedResult = await BookFormDialog.show(
                    context,
                    book: sampleBook,
                    bookService: bookService,
                  );
                },
                child: const Text('Open Edit Dialog'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Edit Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Book Details'), findsOneWidget);
        expect(find.text('Clean Architecture'), findsOneWidget);
        expect(find.text('Robert C. Martin'), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);

        // Modify title and copies
        await tester.enterText(
          find.byKey(const Key('book_form_title_field')),
          'Clean Architecture (Updated)',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_total_copies_field')),
          '10',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_available_copies_field')),
          '8',
        );

        await tester.tap(find.byKey(const Key('book_form_submit_btn')));
        await tester.pumpAndSettle();

        expect(updatedResult, isNotNull);
        expect(updatedResult!.title, 'Clean Architecture (Updated)');
        expect(updatedResult!.totalCopies, 10);
        expect(updatedResult!.availableCopies, 8);

        final doc = fakeFirestore.store.documents['books/${sampleBook.id}'];
        expect(doc!['title'], 'Clean Architecture (Updated)');
        expect(doc['totalCopies'], 10);
      },
    );

    testWidgets('Handles backend error gracefully in dialog', (
      WidgetTester tester,
    ) async {
      final unauthenticatedAuth = FakeFirebaseAuth(currentUser: null);
      final unauthService = BookService(
        firestore: fakeFirestore,
        auth: unauthenticatedAuth,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookFormDialog(book: sampleBook, bookService: unauthService),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('book_form_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Authentication required'), findsOneWidget);
    });

    testWidgets('Prevents duplicate submissions while save is in flight', (
      WidgetTester tester,
    ) async {
      int createCalls = 0;
      final completer = Completer<Book>();
      final mockService = DelayBookService(
        onCreate: (book) {
          createCalls++;
          return completer.future;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BookFormDialog(bookService: mockService)),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('book_form_title_field')),
        'Async Title',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_author_field')),
        'Async Author',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_description_field')),
        'Async Desc',
      );

      // First tap
      await tester.tap(find.byKey(const Key('book_form_submit_btn')));
      await tester.pump();

      expect(createCalls, 1);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('book_form_submit_btn')),
      );
      expect(button.onPressed, isNull);

      // Attempt second tap while saving
      await tester.tap(find.byKey(const Key('book_form_submit_btn')));
      await tester.pump();
      expect(createCalls, 1);

      completer.complete(sampleBook);
      await tester.pumpAndSettle();
    });

    testWidgets('Validates invalid publication year and total copies', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BookFormDialog(bookService: bookService)),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('book_form_published_year_field')),
        '3000',
      );
      await tester.enterText(
        find.byKey(const Key('book_form_total_copies_field')),
        '0',
      );

      await tester.tap(find.byKey(const Key('book_form_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid year'), findsOneWidget);
      expect(find.text('Must be >= 1'), findsOneWidget);
    });
  });

  group('DeleteBookConfirmationDialog Widget Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseAuth staffAuth;
    late BookService bookService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      final staffUser = FakeUser(
        uid: 'staff-user-1',
        email: 'librarian@librasync.org',
      );
      staffAuth = FakeFirebaseAuth(currentUser: staffUser);
      fakeFirestore.store.documents['users/${staffUser.uid}'] = {
        'uid': staffUser.uid,
        'email': staffUser.email,
        'role': 'staff',
      };
      bookService = BookService(firestore: fakeFirestore, auth: staffAuth);

      fakeFirestore.store.documents['books/${sampleBook.id}'] = sampleBook
          .toFirestore();
    });

    testWidgets('Renders warning content and buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteBookConfirmationDialog(
              book: sampleBook,
              bookService: bookService,
            ),
          ),
        ),
      );

      expect(find.text('Delete Book'), findsWidgets);
      expect(
        find.textContaining(
          'Are you sure you want to delete "${sampleBook.title}"',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('delete_book_confirm_btn')), findsOneWidget);
      expect(find.byKey(const Key('delete_book_cancel_btn')), findsOneWidget);
    });

    testWidgets('Successfully deletes book and returns true', (
      WidgetTester tester,
    ) async {
      bool? deletedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                deletedResult = await DeleteBookConfirmationDialog.show(
                  context,
                  book: sampleBook,
                  bookService: bookService,
                );
              },
              child: const Text('Open Delete Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Delete Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_book_confirm_btn')));
      await tester.pumpAndSettle();

      expect(deletedResult, isTrue);
      expect(fakeFirestore.store.documents['books/${sampleBook.id}'], isNull);
    });

    testWidgets('Canceling delete dialog pops with false and preserves book', (
      WidgetTester tester,
    ) async {
      bool? deletedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                deletedResult = await DeleteBookConfirmationDialog.show(
                  context,
                  book: sampleBook,
                  bookService: bookService,
                );
              },
              child: const Text('Open Delete Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Delete Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_book_cancel_btn')));
      await tester.pumpAndSettle();

      expect(deletedResult, isFalse);
      expect(
        fakeFirestore.store.documents['books/${sampleBook.id}'],
        isNotNull,
      );
    });

    testWidgets('Handles backend error gracefully in delete dialog', (
      WidgetTester tester,
    ) async {
      final unauthenticatedAuth = FakeFirebaseAuth(currentUser: null);
      final unauthService = BookService(
        firestore: fakeFirestore,
        auth: unauthenticatedAuth,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteBookConfirmationDialog(
              book: sampleBook,
              bookService: unauthService,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('delete_book_confirm_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Authentication required'), findsOneWidget);
    });

    testWidgets('Prevents duplicate deletions while delete is in flight', (
      WidgetTester tester,
    ) async {
      int deleteCalls = 0;
      final completer = Completer<void>();
      final mockService = DelayBookService(
        onDelete: (id) {
          deleteCalls++;
          return completer.future;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteBookConfirmationDialog(
              book: sampleBook,
              bookService: mockService,
            ),
          ),
        ),
      );

      // First tap
      await tester.tap(find.byKey(const Key('delete_book_confirm_btn')));
      await tester.pump();

      expect(deleteCalls, 1);
      final confirmBtn = tester.widget<FilledButton>(
        find.byKey(const Key('delete_book_confirm_btn')),
      );
      expect(confirmBtn.onPressed, isNull);

      // Attempt second tap while in flight
      await tester.tap(find.byKey(const Key('delete_book_confirm_btn')));
      await tester.pump();
      expect(deleteCalls, 1);

      completer.complete();
      await tester.pumpAndSettle();
    });
  });

  group('Staff Catalog & Details Screen Integration Tests', () {
    testWidgets('Shows Add Book FAB and action button when isStaff is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookCatalogScreen(
            booksStream: Stream.value([sampleBook]),
            isStaff: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('catalog_add_book_fab')), findsOneWidget);
      expect(find.byKey(const Key('catalog_add_book_btn')), findsOneWidget);
      expect(find.text('Add Book'), findsWidgets);
    });

    testWidgets('Hides Add Book FAB when isStaff is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookCatalogScreen(
            booksStream: Stream.value([sampleBook]),
            isStaff: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('catalog_add_book_fab')), findsNothing);
      expect(find.byKey(const Key('catalog_add_book_btn')), findsNothing);
    });

    testWidgets(
      'Shows Edit and Delete action buttons on BookDetailsScreen when isStaff is true',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(home: BookDetailsScreen(book: sampleBook, isStaff: true)),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('book_details_edit_btn')), findsOneWidget);
        expect(
          find.byKey(const Key('book_details_delete_btn')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Hides Edit and Delete buttons on BookDetailsScreen when isStaff is false',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BookDetailsScreen(book: sampleBook, isStaff: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('book_details_edit_btn')), findsNothing);
        expect(find.byKey(const Key('book_details_delete_btn')), findsNothing);
      },
    );

    testWidgets(
      'Shows Add First Book button on empty catalog when isStaff is true',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BookCatalogScreen(
              booksStream: Stream.value([]),
              isStaff: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('catalog_empty_add_book_btn')),
          findsOneWidget,
        );
        expect(find.text('Add First Book'), findsOneWidget);
      },
    );

    testWidgets(
      'Hides Add First Book button on empty catalog when isStaff is false',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BookCatalogScreen(
              booksStream: Stream.value([]),
              isStaff: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('catalog_empty_add_book_btn')),
          findsNothing,
        );
        expect(find.text('Add First Book'), findsNothing);
      },
    );
  });
}

class DelayBookService extends Fake implements BookService {
  DelayBookService({this.onCreate, this.onDelete});
  final Future<Book> Function(Book)? onCreate;
  final Future<void> Function(String)? onDelete;

  @override
  Future<Book> createBook(Book book, {bool enforceStaffRole = true}) async {
    return onCreate != null ? await onCreate!(book) : book;
  }

  @override
  Future<void> deleteBook(String id, {bool enforceStaffRole = true}) async {
    if (onDelete != null) await onDelete!(id);
  }

  @override
  Future<bool> isCurrentUserStaff() async => true;
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
    throw UnimplementedError();
  }
}
