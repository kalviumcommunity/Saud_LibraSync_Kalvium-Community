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
import 'package:librasync/screens/auth/auth_gate.dart';
import 'package:librasync/screens/auth/login_screen.dart';
import 'package:librasync/screens/branches/branches_screen.dart';
import 'package:librasync/screens/catalog/book_catalog_screen.dart';
import 'package:librasync/screens/catalog/book_details_screen.dart';
import 'package:librasync/screens/circulation/member_circulation_screen.dart';
import 'package:librasync/screens/home_screen.dart';
import 'package:librasync/services/auth_service.dart';
import 'package:librasync/services/book_service.dart';
import 'package:librasync/services/branch_service.dart';
import 'package:librasync/services/circulation_service.dart';
import 'package:librasync/widgets/catalog/book_form_dialog.dart';
import 'package:librasync/widgets/catalog/delete_book_dialog.dart';
import 'package:librasync/widgets/circulation/borrow_confirmation_sheet.dart';
import 'package:librasync/widgets/circulation/return_confirmation_dialog.dart';

void main() {
  // ── Sample Test Fixtures ───────────────────────────────────────────────────

  final testBranchCentral = Branch(
    id: 'branch-central',
    name: 'Central Library Hub',
    address: '100 Main Street, Metro City',
    phone: '555-0100',
  );

  final testBranchNorth = Branch(
    id: 'branch-north',
    name: 'North Community Library',
    address: '200 North Avenue, Metro City',
    phone: '555-0200',
  );

  final testBook1 = Book(
    id: 'book-e2e-001',
    title: 'Domain-Driven Design in Practice',
    author: 'Eric Evans',
    description: 'Tackling Complexity in the Heart of Software.',
    category: 'Software Architecture',
    publishedYear: 2003,
    isbn: '978-0321125217',
    isAvailable: true,
    totalCopies: 3,
    availableCopies: 2,
  );

  final testBookUnavailable = Book(
    id: 'book-e2e-002',
    title: 'Database Internals',
    author: 'Alex Petrov',
    description: 'A deep dive into how distributed data systems work.',
    category: 'Databases',
    publishedYear: 2019,
    isbn: '978-1492040347',
    isAvailable: false,
    totalCopies: 1,
    availableCopies: 0,
  );

  final memberUser = FakeUser(
    uid: 'member-e2e-101',
    email: 'alice.member@librasync.org',
    displayName: 'Alice Member',
  );

  final staffUser = FakeUser(
    uid: 'staff-e2e-202',
    email: 'bob.staff@librasync.org',
    displayName: 'Bob Librarian',
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 1: Complete End-to-End Member Journey
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E Suite 1: Complete Member Lifecycle Integration Flow', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['users/${memberUser.uid}'] = {
        'uid': memberUser.uid,
        'email': memberUser.email,
        'displayName': memberUser.displayName,
        'role': 'member',
      };
      fakeFirestore.store.documents['books/${testBook1.id}'] = testBook1
          .toFirestore();
      fakeFirestore.store.documents['branches/${testBranchCentral.id}'] =
          testBranchCentral.toFirestore();
      fakeFirestore.store.documents['branches/${testBranchNorth.id}'] =
          testBranchNorth.toFirestore();

      // Seed physical book copies
      final copy1 = BookCopy(
        id: 'copy-e2e-1',
        bookId: testBook1.id,
        branchId: testBranchCentral.id,
        status: BookCopy.statusAvailable,
        barcode: 'BC-DDD-001',
        condition: 'Good',
      );
      final copy2 = BookCopy(
        id: 'copy-e2e-2',
        bookId: testBook1.id,
        branchId: testBranchCentral.id,
        status: BookCopy.statusAvailable,
        barcode: 'BC-DDD-002',
        condition: 'Good',
      );
      fakeFirestore.store.documents['bookCopies/${copy1.id}'] = copy1
          .toFirestore();
      fakeFirestore.store.documents['bookCopies/${copy2.id}'] = copy2
          .toFirestore();
    });

    testWidgets(
      'Full Member Flow: AuthGate -> Member HomeScreen -> Catalog -> Borrow -> Circulation -> Return -> Sign Out',
      (WidgetTester tester) async {
        final fakeAuth = FakeFirebaseAuth(currentUser: memberUser);
        final authService = AuthService(
          auth: fakeAuth,
          firestore: fakeFirestore,
        );
        final bookService = BookService(
          firestore: fakeFirestore,
          auth: fakeAuth,
        );
        final circulationService = CirculationService(
          firestore: fakeFirestore,
          auth: fakeAuth,
        );
        final branchService = BranchService(
          firestore: fakeFirestore,
          auth: fakeAuth,
        );

        // Step 1: Render AuthGate with authenticated member
        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              authService: authService,
              bookService: bookService,
              circulationService: circulationService,
              branchService: branchService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Member HomeScreen is rendered
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byKey(const Key('home_role_badge_member')), findsOneWidget);
        expect(find.text('Member'), findsOneWidget);
        expect(find.text('Welcome to LibraSync'), findsOneWidget);

        // Step 2: Navigate to Books Catalog
        await tester.tap(find.text('Books'));
        await tester.pumpAndSettle();

        expect(find.byType(BookCatalogScreen), findsOneWidget);
        expect(find.text('Domain-Driven Design in Practice'), findsWidgets);
        // Verify staff controls are hidden from member
        expect(find.byKey(const Key('catalog_add_book_fab')), findsNothing);
        expect(find.byKey(const Key('catalog_add_book_btn')), findsNothing);

        // Step 3: Open BookDetailsScreen
        await tester.tap(find.text('Domain-Driven Design in Practice').first);
        await tester.pumpAndSettle();

        expect(find.byType(BookDetailsScreen), findsOneWidget);
        expect(
          find.textContaining('Available (2 of 3 copies)'),
          findsOneWidget,
        );
        // Verify Edit and Delete controls are hidden from member
        expect(find.byKey(const Key('book_details_edit_btn')), findsNothing);
        expect(find.byKey(const Key('book_details_delete_btn')), findsNothing);
        // Verify Borrow button is present and enabled
        expect(
          find.byKey(const Key('book_details_borrow_btn')),
          findsOneWidget,
        );

        // Step 4: Tap Borrow Book -> Opens BorrowConfirmationSheet
        await tester.tap(find.byKey(const Key('book_details_borrow_btn')));
        await tester.pumpAndSettle();

        expect(find.byType(BorrowConfirmationSheet), findsOneWidget);
        expect(find.text('Confirm Borrowing'), findsOneWidget);

        // Confirm loan submission
        await tester.tap(find.byKey(const Key('borrow_confirm_btn')));
        await tester.pumpAndSettle();

        // Tap Done button in success state
        expect(
          find.byKey(const Key('borrow_success_done_btn')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('borrow_success_done_btn')));
        await tester.pumpAndSettle();

        // Verify backend state after borrow
        final updatedBookDoc =
            fakeFirestore.store.documents['books/${testBook1.id}'];
        expect(updatedBookDoc!['availableCopies'], 1);

        // Verify loan document was created
        final loans = fakeFirestore.store.documents.entries
            .where((e) => e.key.startsWith('loans/'))
            .toList();
        expect(loans.length, 1);
        final loanData = loans.first.value;
        expect(loanData['memberId'], memberUser.uid);
        expect(loanData['bookId'], testBook1.id);
        expect(loanData['status'], 'active');

        // Automatic pop from BookDetailsScreen after successful borrow brings us back to CatalogScreen
        expect(find.byType(BookCatalogScreen), findsOneWidget);
        // Pop back to HomeScreen
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);

        // Step 5: Navigate to Member Circulation Screen
        await tester.tap(find.text('Borrowing'));
        await tester.pumpAndSettle();

        expect(find.byType(MemberCirculationScreen), findsOneWidget);
        expect(find.text('My Borrowed Books'), findsOneWidget);
        expect(find.text('Domain-Driven Design in Practice'), findsWidgets);

        // Step 6: Return the borrowed book
        expect(find.text('Return'), findsOneWidget);
        await tester.tap(find.text('Return'));
        await tester.pumpAndSettle();

        expect(find.byType(ReturnConfirmationDialog), findsOneWidget);
        expect(find.text('Return Book'), findsOneWidget);
        await tester.tap(find.byKey(const Key('return_confirm_btn')));
        await tester.pumpAndSettle();

        // Verify success view in dialog
        expect(find.text('Book Marked as Returned'), findsOneWidget);
        expect(
          find.byKey(const Key('return_success_done_btn')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('return_success_done_btn')));
        await tester.pumpAndSettle();

        // Verify backend state after return
        final returnedBookDoc =
            fakeFirestore.store.documents['books/${testBook1.id}'];
        expect(returnedBookDoc!['availableCopies'], 2);

        final returnedLoanDoc = fakeFirestore.store.documents[loans.first.key];
        expect(returnedLoanDoc!['status'], 'returned');

        // Pop back to HomeScreen
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);

        // Step 7: Member Sign Out flow
        expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
        await tester.tap(find.byIcon(Icons.logout_rounded));
        await tester.pumpAndSettle();

        expect(
          find.text('Are you sure you want to log out of LibraSync?'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('logout_confirm_btn')));
        await tester.pumpAndSettle();

        // Verify signed-out state transitions back to LoginScreen
        expect(fakeAuth.currentUser, isNull);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 2: Complete End-to-End Staff Management Journey
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E Suite 2: Complete Staff Management Lifecycle Flow', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['users/${staffUser.uid}'] = {
        'uid': staffUser.uid,
        'email': staffUser.email,
        'displayName': staffUser.displayName,
        'role': 'staff',
      };
      fakeFirestore.store.documents['books/${testBook1.id}'] = testBook1
          .toFirestore();
    });

    testWidgets(
      'Full Staff Flow: Staff HomeScreen -> Catalog -> Add Book -> Edit Book -> Delete Book',
      (WidgetTester tester) async {
        final fakeAuth = FakeFirebaseAuth(currentUser: staffUser);
        final authService = AuthService(
          auth: fakeAuth,
          firestore: fakeFirestore,
        );
        final bookService = BookService(
          firestore: fakeFirestore,
          auth: fakeAuth,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              authService: authService,
              bookService: bookService,
              isStaff: true,
              userRole: 'staff',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Staff badge
        expect(find.byKey(const Key('home_role_badge_staff')), findsOneWidget);
        expect(find.text('Staff'), findsOneWidget);

        // Step 1: Navigate to Catalog
        await tester.tap(find.text('Books'));
        await tester.pumpAndSettle();

        expect(find.byType(BookCatalogScreen), findsOneWidget);
        // Verify staff controls are visible
        expect(find.byKey(const Key('catalog_add_book_fab')), findsOneWidget);

        // Step 2: Tap Add Book FAB -> Opens BookFormDialog
        await tester.tap(find.byKey(const Key('catalog_add_book_fab')));
        await tester.pumpAndSettle();

        expect(find.byType(BookFormDialog), findsOneWidget);
        expect(find.text('Add New Book'), findsOneWidget);

        // Fill form fields
        await tester.enterText(
          find.byKey(const Key('book_form_title_field')),
          'Refactoring 2nd Edition',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_author_field')),
          'Martin Fowler',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_description_field')),
          'Improving the design of existing code.',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_category_field')),
          'Software Engineering',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_published_year_field')),
          '2018',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_isbn_field')),
          '978-0134757599',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_total_copies_field')),
          '4',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_available_copies_field')),
          '4',
        );

        // Submit form
        await tester.tap(find.byKey(const Key('book_form_submit_btn')));
        await tester.pumpAndSettle();

        // Verify dialog closed and snackbar confirmed addition
        expect(find.byType(BookFormDialog), findsNothing);
        expect(
          find.text('"Refactoring 2nd Edition" added to catalog successfully.'),
          findsOneWidget,
        );

        // Verify book appears in catalog
        expect(find.text('Refactoring 2nd Edition'), findsWidgets);

        // Step 3: Open details for testBook1
        await tester.tap(find.byKey(Key('book_card_${testBook1.id}')).first);
        await tester.pumpAndSettle();

        expect(find.byType(BookDetailsScreen), findsOneWidget);
        // Verify Edit and Delete controls are present for staff
        expect(find.byKey(const Key('book_details_edit_btn')), findsOneWidget);
        expect(
          find.byKey(const Key('book_details_delete_btn')),
          findsOneWidget,
        );

        // Step 4: Tap Edit Button -> Opens BookFormDialog in Edit mode
        await tester.tap(find.byKey(const Key('book_details_edit_btn')));
        await tester.pumpAndSettle();

        expect(find.byType(BookFormDialog), findsOneWidget);
        expect(find.text('Edit Book Details'), findsOneWidget);

        // Modify title
        await tester.enterText(
          find.byKey(const Key('book_form_title_field')),
          'Domain-Driven Design: Enterprise Edition',
        );
        await tester.tap(find.byKey(const Key('book_form_submit_btn')));
        await tester.pumpAndSettle();

        // Verify updated title on BookDetailsScreen
        expect(
          find.text('Domain-Driven Design: Enterprise Edition'),
          findsWidgets,
        );

        // Step 5: Tap Delete Button -> Opens DeleteBookConfirmationDialog
        await tester.tap(find.byKey(const Key('book_details_delete_btn')));
        await tester.pumpAndSettle();

        expect(find.byType(DeleteBookConfirmationDialog), findsOneWidget);
        expect(find.text('Delete Book'), findsWidgets);

        // Confirm deletion
        await tester.tap(find.byKey(const Key('delete_book_confirm_btn')));
        await tester.pumpAndSettle();

        // Verify popped back to catalog and book is deleted from Firestore
        expect(find.byType(BookCatalogScreen), findsOneWidget);
        expect(fakeFirestore.store.documents['books/${testBook1.id}'], isNull);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 3: Cross-Branch Circulation & Integrity Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E Suite 3: Cross-Branch Return & Multi-Branch Integrity Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['branches/${testBranchCentral.id}'] =
          testBranchCentral.toFirestore();
      fakeFirestore.store.documents['branches/${testBranchNorth.id}'] =
          testBranchNorth.toFirestore();
      fakeFirestore.store.documents['books/${testBook1.id}'] = testBook1
          .toFirestore();
    });

    test('Cross-branch return updates copy location to returning branch and marks loan returned', () async {
      final copy = BookCopy(
        id: 'copy-cross-01',
        bookId: testBook1.id,
        branchId: testBranchCentral.id,
        status: BookCopy.statusBorrowed,
        barcode: 'BC-CROSS-01',
      );
      fakeFirestore.store.documents['bookCopies/${copy.id}'] = copy
          .toFirestore();

      final loan = LoanRecord(
        id: 'loan-cross-01',
        bookId: testBook1.id,
        bookTitle: testBook1.title,
        bookAuthor: testBook1.author,
        bookCopyId: copy.id,
        borrowedBranchId: testBranchCentral.id,
        borrowDate: DateTime.now().subtract(const Duration(days: 3)),
        dueDate: DateTime.now().add(const Duration(days: 11)),
        memberId: memberUser.uid,
        status: 'active',
      );
      fakeFirestore.store.documents['loans/${loan.id}'] = loan.toFirestore();

      final circulationService = CirculationService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: memberUser),
      );

      // Return at North Community Library (Cross-branch)
      await circulationService.requestReturn(
        loanId: loan.id,
        returnBranchId: testBranchNorth.id,
      );

      // Verify copy now resides at North Community branch
      final updatedCopyDoc =
          fakeFirestore.store.documents['bookCopies/${copy.id}'];
      expect(updatedCopyDoc!['branchId'], testBranchNorth.id);
      expect(updatedCopyDoc['status'], BookCopy.statusAvailable);

      // Verify loan record has returned status and returnBranchId
      final updatedLoanDoc = fakeFirestore.store.documents['loans/${loan.id}'];
      expect(updatedLoanDoc!['status'], 'returned');
      expect(updatedLoanDoc['returnBranchId'], testBranchNorth.id);

      // Verify book availability incremented
      final updatedBookDoc =
          fakeFirestore.store.documents['books/${testBook1.id}'];
      expect(updatedBookDoc!['availableCopies'], 3);
    });

    test('Return to a non-existent branch ID is rejected with error', () async {
      final copy = BookCopy(
        id: 'copy-cross-02',
        bookId: testBook1.id,
        branchId: testBranchCentral.id,
        status: BookCopy.statusBorrowed,
        barcode: 'BC-CROSS-02',
      );
      fakeFirestore.store.documents['bookCopies/${copy.id}'] = copy
          .toFirestore();

      final loan = LoanRecord(
        id: 'loan-cross-02',
        bookId: testBook1.id,
        bookTitle: testBook1.title,
        bookAuthor: testBook1.author,
        bookCopyId: copy.id,
        borrowedBranchId: testBranchCentral.id,
        borrowDate: DateTime.now().subtract(const Duration(days: 1)),
        dueDate: DateTime.now().add(const Duration(days: 13)),
        memberId: memberUser.uid,
        status: 'active',
      );
      fakeFirestore.store.documents['loans/${loan.id}'] = loan.toFirestore();

      final circulationService = CirculationService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: memberUser),
      );

      expect(
        () => circulationService.requestReturn(
          loanId: loan.id,
          returnBranchId: 'branch-non-existent',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('does not exist'),
          ),
        ),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 4: Branches Screen UI & Rendering Integration Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E Suite 4: Branches Dashboard Navigation & Screen Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['branches/${testBranchCentral.id}'] =
          testBranchCentral.toFirestore();
      fakeFirestore.store.documents['branches/${testBranchNorth.id}'] =
          testBranchNorth.toFirestore();
    });

    testWidgets(
      'HomeScreen navigates to BranchesScreen and renders all branch cards',
      (WidgetTester tester) async {
        final fakeAuth = FakeFirebaseAuth(currentUser: memberUser);
        final branchService = BranchService(
          firestore: fakeFirestore,
          auth: fakeAuth,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(branchService: branchService, isStaff: false),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Branches dashboard card
        await tester.tap(find.text('Branches'));
        await tester.pumpAndSettle();

        expect(find.byType(BranchesScreen), findsOneWidget);
        expect(find.text('Library Branches'), findsOneWidget);
        expect(find.text('Central Library Hub'), findsOneWidget);
        expect(find.text('North Community Library'), findsOneWidget);

        // Verify branch cards are displayed
        expect(
          find.byKey(Key('branch_card_${testBranchCentral.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('branch_card_${testBranchNorth.id}')),
          findsOneWidget,
        );
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 5: Regression & Edge Cases Validation
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E Suite 5: Security & Edge Case Regression Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['users/${memberUser.uid}'] = {
        'uid': memberUser.uid,
        'email': memberUser.email,
        'role': 'member',
      };
      fakeFirestore.store.documents['books/${testBookUnavailable.id}'] =
          testBookUnavailable.toFirestore();
    });

    testWidgets(
      'Book with 0 available copies disables borrow button and shows unavailable badge',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BookDetailsScreen(book: testBookUnavailable, isStaff: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Currently Unavailable (0 of 1 copies)'),
          findsOneWidget,
        );

        final borrowButtonFinder = find.byKey(
          const Key('book_details_borrow_btn_disabled'),
        );
        expect(borrowButtonFinder, findsOneWidget);

        // Verify the FilledButton is disabled (onPressed is null)
        final buttonWidget = tester.widget<FilledButton>(borrowButtonFinder);
        expect(buttonWidget.onPressed, isNull);
      },
    );

    test(
      'CirculationService blocks borrowing unavailable books on backend',
      () async {
        final circulationService = CirculationService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: memberUser),
        );

        expect(
          () => circulationService.requestBorrow(
            book: testBookUnavailable,
            memberId: memberUser.uid,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('No available copies'),
            ),
          ),
        );
      },
    );

    test(
      'CirculationService prevents member from returning someone else\'s loan',
      () async {
        final otherMemberLoan = LoanRecord(
          id: 'loan-other-member',
          bookId: testBookUnavailable.id,
          bookTitle: testBookUnavailable.title,
          bookAuthor: testBookUnavailable.author,
          borrowDate: DateTime.now().subtract(const Duration(days: 2)),
          dueDate: DateTime.now().add(const Duration(days: 12)),
          memberId: 'other-member-uid',
          status: 'active',
        );
        fakeFirestore.store.documents['loans/${otherMemberLoan.id}'] =
            otherMemberLoan.toFirestore();

        final circulationService = CirculationService(
          firestore: fakeFirestore,
          auth: FakeFirebaseAuth(currentUser: memberUser),
        );

        expect(
          () => circulationService.requestReturn(loanId: otherMemberLoan.id),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('You are not authorized to return this book.'),
            ),
          ),
        );
      },
    );
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
  FakeFirebaseAuth({User? currentUser}) {
    _currentUser = currentUser;
    _controller = StreamController<User?>.broadcast();
  }

  late final StreamController<User?> _controller;
  User? _currentUser;

  @override
  User? get currentUser => _currentUser;

  set currentUser(User? val) {
    _currentUser = val;
    _controller.add(val);
  }

  @override
  Stream<User?> authStateChanges() async* {
    yield _currentUser;
    yield* _controller.stream;
  }

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
