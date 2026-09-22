// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librasync/models/book.dart';
import 'package:librasync/models/book_copy.dart';
import 'package:librasync/models/branch.dart';
import 'package:librasync/models/loan_record.dart';
import 'package:librasync/screens/catalog/book_catalog_screen.dart';
import 'package:librasync/screens/catalog/book_details_screen.dart';
import 'package:librasync/services/auth_service.dart';
import 'package:librasync/services/book_copy_service.dart';
import 'package:librasync/services/book_service.dart';
import 'package:librasync/services/branch_service.dart';
import 'package:librasync/services/circulation_service.dart';
import 'package:librasync/widgets/catalog/book_form_dialog.dart';
import 'package:librasync/widgets/catalog/delete_book_dialog.dart';

void main() {
  final testBook = Book(
    id: 'book-role-001',
    title: 'Clean Architecture in Practice',
    author: 'Robert C. Martin',
    description: 'Comprehensive software architecture guidelines.',
    category: 'Computer Science',
    publishedYear: 2018,
    isbn: '978-0134494166',
    isAvailable: true,
    totalCopies: 3,
    availableCopies: 3,
  );

  final staffUser = FakeUser(
    uid: 'staff-user-001',
    email: 'staff@librasync.org',
    displayName: 'Head Librarian',
  );

  final adminUser = FakeUser(
    uid: 'admin-user-002',
    email: 'admin@librasync.org',
    displayName: 'System Admin',
  );

  final memberUser1 = FakeUser(
    uid: 'member-user-001',
    email: 'member1@librasync.org',
    displayName: 'Alice Reader',
  );

  final memberUser2 = FakeUser(
    uid: 'member-user-002',
    email: 'member2@librasync.org',
    displayName: 'Bob Scholar',
  );

  group('AuthService Role Identification & Access Validation Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['users/${staffUser.uid}'] = {
        'uid': staffUser.uid,
        'email': staffUser.email,
        'role': 'staff',
      };
      fakeFirestore.store.documents['users/${adminUser.uid}'] = {
        'uid': adminUser.uid,
        'email': adminUser.email,
        'role': 'admin',
      };
      fakeFirestore.store.documents['users/${memberUser1.uid}'] = {
        'uid': memberUser1.uid,
        'email': memberUser1.email,
        'role': 'member',
      };
      fakeFirestore.store.documents['users/mixed-case-staff'] = {
        'uid': 'mixed-case-staff',
        'email': 'mixed@librasync.org',
        'role': '  Staff  ',
      };
      fakeFirestore.store.documents['users/mixed-case-admin'] = {
        'uid': 'mixed-case-admin',
        'email': 'admin_mixed@librasync.org',
        'role': 'ADMIN',
      };
      fakeFirestore.store.documents['users/unknown-role-user'] = {
        'uid': 'unknown-role-user',
        'email': 'custom@librasync.org',
        'role': 'patron',
      };
      fakeFirestore.store.documents['users/empty-role-user'] = {
        'uid': 'empty-role-user',
        'email': 'empty@librasync.org',
        'role': '   ',
      };
      fakeFirestore.store.documents['users/missing-role-user'] = {
        'uid': 'missing-role-user',
        'email': 'missing@librasync.org',
      };
    });

    test(
      'getUserRole returns guest when unauthenticated or uid is null/empty',
      () async {
        final fakeAuth = FakeFirebaseAuth(currentUser: null);
        final authService = AuthService(
          auth: fakeAuth,
          firestore: fakeFirestore,
        );

        expect(await authService.getUserRole(), 'guest');
        expect(await authService.getUserRole(''), 'guest');
        expect(await authService.getUserRole(null), 'guest');
        expect(await authService.isStaffUser(), isFalse);
      },
    );

    test(
      'getUserRole identifies staff user and isStaffUser returns true',
      () async {
        final fakeAuth = FakeFirebaseAuth(currentUser: staffUser);
        final authService = AuthService(
          auth: fakeAuth,
          firestore: fakeFirestore,
        );

        expect(await authService.getUserRole(staffUser.uid), 'staff');
        expect(await authService.isStaffUser(staffUser.uid), isTrue);
        expect(await authService.isStaffUser(), isTrue);
      },
    );

    test(
      'getUserRole identifies admin user and isStaffUser returns true',
      () async {
        final fakeAuth = FakeFirebaseAuth(currentUser: adminUser);
        final authService = AuthService(
          auth: fakeAuth,
          firestore: fakeFirestore,
        );

        expect(await authService.getUserRole(adminUser.uid), 'admin');
        expect(await authService.isStaffUser(adminUser.uid), isTrue);
      },
    );

    test(
      'getUserRole identifies member user and isStaffUser returns false',
      () async {
        final fakeAuth = FakeFirebaseAuth(currentUser: memberUser1);
        final authService = AuthService(
          auth: fakeAuth,
          firestore: fakeFirestore,
        );

        expect(await authService.getUserRole(memberUser1.uid), 'member');
        expect(await authService.isStaffUser(memberUser1.uid), isFalse);
        expect(await authService.isStaffUser(), isFalse);
      },
    );

    test(
      'getUserRole normalizes mixed case and surrounding whitespace in role',
      () async {
        final authService = AuthService(
          auth: FakeFirebaseAuth(),
          firestore: fakeFirestore,
        );

        expect(await authService.getUserRole('mixed-case-staff'), 'staff');
        expect(await authService.isStaffUser('mixed-case-staff'), isTrue);

        expect(await authService.getUserRole('mixed-case-admin'), 'admin');
        expect(await authService.isStaffUser('mixed-case-admin'), isTrue);
      },
    );

    test(
      'getUserRole defaults safely to member for empty or missing role fields',
      () async {
        final authService = AuthService(
          auth: FakeFirebaseAuth(),
          firestore: fakeFirestore,
        );

        expect(await authService.getUserRole('empty-role-user'), 'member');
        expect(await authService.isStaffUser('empty-role-user'), isFalse);

        expect(await authService.getUserRole('missing-role-user'), 'member');
        expect(await authService.isStaffUser('missing-role-user'), isFalse);
      },
    );

    test('getUserRole returns custom role string in lowercase and treats as non-staff', () async {
      final authService = AuthService(
        auth: FakeFirebaseAuth(),
        firestore: fakeFirestore,
      );

      expect(await authService.getUserRole('unknown-role-user'), 'patron');
      expect(await authService.isStaffUser('unknown-role-user'), isFalse);
    });

    test('getUserRole falls back to member if user doc does not exist in Firestore', () async {
      final authService = AuthService(
        auth: FakeFirebaseAuth(),
        firestore: fakeFirestore,
      );

      expect(await authService.getUserRole('non-existent-user-id'), 'member');
      expect(await authService.isStaffUser('non-existent-user-id'), isFalse);
    });

    test('signUpWithEmailAndPassword sets default role to member', () async {
      final fakeAuth = FakeFirebaseAuth();
      final authService = AuthService(auth: fakeAuth, firestore: fakeFirestore);

      final cred = await authService.signUpWithEmailAndPassword(
        email: 'newuser@librasync.org',
        password: 'password123',
        displayName: 'New Member',
      );

      expect(cred.user, isNotNull);
      final uid = cred.user!.uid;
      final docData = fakeFirestore.store.documents['users/$uid'];
      expect(docData, isNotNull);
      expect(docData!['role'], 'member');
      expect(docData['email'], 'newuser@librasync.org');
      expect(docData['displayName'], 'New Member');
    });
  });

  group('BookService Staff Access Enforcement Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['users/${staffUser.uid}'] = {
        'uid': staffUser.uid,
        'email': staffUser.email,
        'role': 'staff',
      };
      fakeFirestore.store.documents['users/${adminUser.uid}'] = {
        'uid': adminUser.uid,
        'email': adminUser.email,
        'role': 'ADMIN',
      };
      fakeFirestore.store.documents['users/${memberUser1.uid}'] = {
        'uid': memberUser1.uid,
        'email': memberUser1.email,
        'role': 'member',
      };
      fakeFirestore.store.documents['users/patron-user'] = {
        'uid': 'patron-user',
        'email': 'patron@librasync.org',
        'role': 'patron',
      };
      // Seed an existing book
      fakeFirestore.store.documents['books/${testBook.id}'] = testBook
          .toFirestore();
    });

    test(
      'isCurrentUserStaff returns true for staff and admin, false for others',
      () async {
        final staffService = BookService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: staffUser),
        );
        expect(await staffService.isCurrentUserStaff(), isTrue);

        final adminService = BookService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: adminUser),
        );
        expect(await adminService.isCurrentUserStaff(), isTrue);

        final memberService = BookService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: memberUser1),
        );
        expect(await memberService.isCurrentUserStaff(), isFalse);

        final patronService = BookService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: FakeUser(uid: 'patron-user')),
        );
        expect(await patronService.isCurrentUserStaff(), isFalse);

        final unauthService = BookService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: null),
        );
        expect(await unauthService.isCurrentUserStaff(), isFalse);
      },
    );

    test('createBook permits staff user but rejects member and unauthenticated user', () async {
      final staffService = BookService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: staffUser),
      );
      final newBook = testBook.copyWith(
        id: 'new-book-1',
        title: 'New Staff Title',
      );
      final created = await staffService.createBook(newBook);
      expect(created.id, isNotEmpty);
      expect(fakeFirestore.store.documents['books/${created.id}'], isNotNull);

      // Member attempt rejected
      final memberService = BookService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: memberUser1),
      );
      expect(
        () => memberService.createBook(newBook),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains(
              'Unauthorized access. Only library staff can manage the book catalog.',
            ),
          ),
        ),
      );

      // Unauthenticated attempt rejected
      final unauthService = BookService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: null),
      );
      expect(
        () => unauthService.createBook(newBook),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Authentication required'),
          ),
        ),
      );
    });

    test('updateBook permits staff user but rejects member and unauthenticated user', () async {
      final staffService = BookService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: staffUser),
      );
      final updatedBook = testBook.copyWith(title: 'Updated Staff Title');
      final saved = await staffService.updateBook(updatedBook);
      expect(saved.title, 'Updated Staff Title');

      // Member attempt rejected
      final memberService = BookService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: memberUser1),
      );
      expect(
        () => memberService.updateBook(updatedBook),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unauthorized access'),
          ),
        ),
      );

      // Unauthenticated attempt rejected
      final unauthService = BookService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: null),
      );
      expect(
        () => unauthService.updateBook(updatedBook),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Authentication required'),
          ),
        ),
      );
    });

    test('deleteBook permits staff user but rejects member and unauthenticated user', () async {
      // Member attempt rejected
      final memberService = BookService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: memberUser1),
      );
      expect(
        () => memberService.deleteBook(testBook.id),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unauthorized access'),
          ),
        ),
      );

      // Unauthenticated attempt rejected
      final unauthService = BookService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: null),
      );
      expect(
        () => unauthService.deleteBook(testBook.id),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Authentication required'),
          ),
        ),
      );

      // Staff deletion succeeds
      final staffService = BookService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: staffUser),
      );
      await staffService.deleteBook(testBook.id);
      expect(
        fakeFirestore.store.documents.containsKey('books/${testBook.id}'),
        isFalse,
      );
    });
  });

  group('CirculationService Role & Ownership Security Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['books/${testBook.id}'] = testBook
          .toFirestore();
    });

    test('Member can borrow available book for themselves', () async {
      final circulationService = CirculationService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: memberUser1),
      );

      await circulationService.requestBorrow(
        book: testBook,
        memberId: memberUser1.uid,
        memberName: memberUser1.displayName,
      );

      // Verify book availableCopies decremented
      final updatedBook = fakeFirestore.store.documents['books/${testBook.id}'];
      expect(updatedBook!['availableCopies'], 2);

      // Verify loan record created for memberUser1
      final loans = fakeFirestore.store.documents.entries
          .where((e) => e.key.startsWith('loans/'))
          .map((e) => e.value)
          .toList();
      expect(loans.length, 1);
      expect(loans.first['memberId'], memberUser1.uid);
      expect(loans.first['status'], 'active');
    });

    test('Member cannot borrow if they already have an active loan for the same book', () async {
      final circulationService = CirculationService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: memberUser1),
      );

      // First borrow
      await circulationService.requestBorrow(
        book: testBook,
        memberId: memberUser1.uid,
      );

      // Second borrow attempt must throw
      expect(
        () => circulationService.requestBorrow(
          book: testBook,
          memberId: memberUser1.uid,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('already have an active loan'),
          ),
        ),
      );
    });

    test('Member can return their own loan', () async {
      final circulationService = CirculationService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: memberUser1),
      );

      // Seed loan for memberUser1
      final loan = LoanRecord(
        id: 'loan-member1-1',
        bookId: testBook.id,
        bookTitle: testBook.title,
        bookAuthor: testBook.author,
        borrowDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 14)),
        memberId: memberUser1.uid,
        status: 'active',
      );
      fakeFirestore.store.documents['loans/${loan.id}'] = loan.toFirestore();

      await circulationService.requestReturn(loanId: loan.id);

      final returnedLoan = fakeFirestore.store.documents['loans/${loan.id}'];
      expect(returnedLoan!['status'], 'returned');
      expect(returnedLoan['returnDate'], isNotNull);
    });

    test('Member is prevented from returning another member loan (ownership check)', () async {
      // Seed loan belonging to memberUser2
      final loan = LoanRecord(
        id: 'loan-member2-1',
        bookId: testBook.id,
        bookTitle: testBook.title,
        bookAuthor: testBook.author,
        borrowDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 14)),
        memberId: memberUser2.uid,
        status: 'active',
      );
      fakeFirestore.store.documents['loans/${loan.id}'] = loan.toFirestore();

      // Signed in as memberUser1 trying to return memberUser2's loan
      final circulationService = CirculationService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: memberUser1),
      );

      expect(
        () => circulationService.requestReturn(loanId: loan.id),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('You are not authorized to return this book.'),
          ),
        ),
      );

      // Verify loan status was NOT modified
      final unmodifiedLoan = fakeFirestore.store.documents['loans/${loan.id}'];
      expect(unmodifiedLoan!['status'], 'active');
    });

    test('Unauthenticated user cannot borrow or return books', () async {
      final unauthCirculation = CirculationService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: null),
      );

      expect(
        () =>
            unauthCirculation.requestBorrow(book: testBook, memberId: 'any-id'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Authentication required'),
          ),
        ),
      );

      expect(
        () => unauthCirculation.requestReturn(loanId: 'any-loan-id'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Authentication required'),
          ),
        ),
      );
    });
  });

  group('UI Role-Based Controls & Visibility Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['users/${staffUser.uid}'] = {
        'uid': staffUser.uid,
        'email': staffUser.email,
        'role': 'staff',
      };
      fakeFirestore.store.documents['users/${memberUser1.uid}'] = {
        'uid': memberUser1.uid,
        'email': memberUser1.email,
        'role': 'member',
      };
      fakeFirestore.store.documents['books/${testBook.id}'] = testBook
          .toFirestore();
    });

    testWidgets(
      'BookCatalogScreen displays Add Book controls when isStaff is true',
      (WidgetTester tester) async {
        final staffService = BookService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: staffUser),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BookCatalogScreen(bookService: staffService, isStaff: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('catalog_add_book_btn')), findsOneWidget);
        expect(find.byKey(const Key('catalog_add_book_fab')), findsOneWidget);
      },
    );

    testWidgets(
      'BookCatalogScreen hides Add Book controls when isStaff is false',
      (WidgetTester tester) async {
        final memberService = BookService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: memberUser1),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BookCatalogScreen(bookService: memberService, isStaff: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('catalog_add_book_btn')), findsNothing);
        expect(find.byKey(const Key('catalog_add_book_fab')), findsNothing);
      },
    );

    testWidgets(
      'BookCatalogScreen auto-detects staff status when isStaff is null',
      (WidgetTester tester) async {
        final staffService = BookService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: staffUser),
        );

        await tester.pumpWidget(
          MaterialApp(home: BookCatalogScreen(bookService: staffService)),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('catalog_add_book_fab')), findsOneWidget);
      },
    );

    testWidgets(
      'BookCatalogScreen auto-detects member status and hides controls when isStaff is null',
      (WidgetTester tester) async {
        final memberService = BookService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: memberUser1),
        );

        await tester.pumpWidget(
          MaterialApp(home: BookCatalogScreen(bookService: memberService)),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('catalog_add_book_fab')), findsNothing);
      },
    );

    testWidgets(
      'BookDetailsScreen displays Edit & Delete actions for staff, hides for member',
      (WidgetTester tester) async {
        // Test staff view
        await tester.pumpWidget(
          MaterialApp(home: BookDetailsScreen(book: testBook, isStaff: true)),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('book_details_edit_btn')), findsOneWidget);
        expect(
          find.byKey(const Key('book_details_delete_btn')),
          findsOneWidget,
        );

        // Test member view
        await tester.pumpWidget(
          MaterialApp(home: BookDetailsScreen(book: testBook, isStaff: false)),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('book_details_edit_btn')), findsNothing);
        expect(find.byKey(const Key('book_details_delete_btn')), findsNothing);
      },
    );

    testWidgets(
      'BookFormDialog handles unauthorized member submission with inline error message',
      (WidgetTester tester) async {
        final memberService = BookService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: memberUser1),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: BookFormDialog(bookService: memberService)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('book_form_title_field')),
          'Unauthorized Book',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_author_field')),
          'Alice Reader',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_description_field')),
          'Sample book details',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_total_copies_field')),
          '2',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_available_copies_field')),
          '2',
        );

        await tester.tap(find.byKey(const Key('book_form_submit_btn')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Unauthorized access. Only library staff can manage the book catalog.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'DeleteBookConfirmationDialog handles unauthorized member deletion with inline error message',
      (WidgetTester tester) async {
        final memberService = BookService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: memberUser1),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DeleteBookConfirmationDialog(
                book: testBook,
                bookService: memberService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('delete_book_confirm_btn')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Unauthorized access. Only library staff can manage the book catalog.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('Public Catalogue & Branch/Copy Access Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    final sampleBranch = Branch(
      id: 'branch-main',
      name: 'Main Central Library',
      address: '100 Library Way',
      phone: '555-0100',
    );
    final sampleCopy = BookCopy(
      id: 'copy-001',
      bookId: testBook.id,
      branchId: 'branch-main',
      status: BookCopy.statusAvailable,
      barcode: 'BC-TEST-01',
      condition: 'New',
    );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['branches/${sampleBranch.id}'] =
          sampleBranch.toFirestore();
      fakeFirestore.store.documents['bookCopies/${sampleCopy.id}'] = sampleCopy
          .toFirestore();
    });

    test('Unauthenticated user can read branch catalogue details', () async {
      final unauthBranchService = BranchService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: null),
      );

      final branches = await unauthBranchService.getBranches();
      expect(branches.length, 1);
      expect(branches.first.id, 'branch-main');
      expect(branches.first.name, 'Main Central Library');

      final singleBranch = await unauthBranchService.getBranchById(
        'branch-main',
      );
      expect(singleBranch, isNotNull);
      expect(singleBranch!.name, 'Main Central Library');
    });

    test('Unauthenticated user can read physical book copies', () async {
      final unauthCopyService = BookCopyService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: null),
      );

      final copies = await unauthCopyService.getAllCopies();
      expect(copies.length, 1);
      expect(copies.first.id, 'copy-001');
      expect(copies.first.barcode, 'BC-TEST-01');

      final bookCopies = await unauthCopyService.getCopiesForBook(testBook.id);
      expect(bookCopies.length, 1);
      expect(bookCopies.first.bookId, testBook.id);

      final branchCopies = await unauthCopyService.getCopiesForBranch(
        'branch-main',
      );
      expect(branchCopies.length, 1);
      expect(branchCopies.first.branchId, 'branch-main');
    });
  });
}

// ── Test Fakes & Mock Infrastructure ──────────────────────────────────────────

class FakeUser extends Fake implements User {
  FakeUser({
    required this.uid,
    this.email = 'test@librasync.org',
    this.displayName = 'Test User',
  });

  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  @override
  Future<void> updateDisplayName(String? name) async {}

  @override
  Future<void> reload() async {}
}

class FakeUserCredential extends Fake implements UserCredential {
  FakeUserCredential(this._user);
  final User _user;

  @override
  User get user => _user;
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  FakeFirebaseAuth({this.currentUser});

  @override
  User? currentUser;

  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = FakeUser(uid: 'signed-in-${email.hashCode}', email: email);
    currentUser = user;
    return FakeUserCredential(user);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = FakeUser(uid: 'registered-${email.hashCode}', email: email);
    currentUser = user;
    return FakeUserCredential(user);
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
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

  @override
  int get size => _docs.length;
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
      if (options?.merge == true) {
        final existing = _store.documents[_path] ?? {};
        _store.documents[_path] = {...existing, ...data};
      } else {
        _store.documents[_path] = Map<String, dynamic>.from(data);
      }
    }
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
  final FakeFirestoreData _store;
  final List<Map<String, dynamic>> _whereFilters;

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
