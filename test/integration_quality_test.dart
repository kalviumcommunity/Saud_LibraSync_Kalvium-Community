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
import 'package:librasync/services/book_copy_service.dart';
import 'package:librasync/services/book_service.dart';
import 'package:librasync/services/circulation_service.dart';
import 'package:librasync/widgets/catalog/book_form_dialog.dart';
import 'package:librasync/widgets/catalog/delete_book_dialog.dart';
import 'package:librasync/widgets/circulation/borrow_confirmation_sheet.dart';
import 'package:librasync/widgets/circulation/return_confirmation_dialog.dart';
import 'package:librasync/widgets/dashboard_card.dart';

void main() {
  // ── Test Fixtures ─────────────────────────────────────────────────────────

  final sampleBook1 = Book(
    id: 'book-001',
    title: 'Clean Architecture: A Craftsman\'s Guide',
    author: 'Robert C. Martin',
    description: 'A Craftsman\'s Guide to Software Structure and Design.',
    category: 'Software Engineering',
    publishedYear: 2017,
    isbn: '978-0134494166',
    isAvailable: true,
    totalCopies: 5,
    availableCopies: 3,
  );

  final sampleBookUnavailable = Book(
    id: 'book-002',
    title: 'Designing Data-Intensive Applications',
    author: 'Martin Kleppmann',
    description: 'The big ideas behind reliable, scalable systems.',
    category: 'System Design',
    publishedYear: 2017,
    isbn: '978-1449373320',
    isAvailable: false,
    totalCopies: 2,
    availableCopies: 0,
  );

  final sampleBranchCentral = Branch(
    id: 'branch-central',
    name: 'Central City Library',
    address: '100 Downtown Plaza, Cityville',
    phone: '555-0101',
  );

  final sampleBranchNorth = Branch(
    id: 'branch-north',
    name: 'Northside Community Library',
    address: '250 North Hill Road, Cityville',
    phone: '555-0102',
  );

  final staffUser = FakeUser(
    uid: 'staff-user-99',
    email: 'librarian@librasync.org',
    displayName: 'Head Librarian',
  );

  final memberUser = FakeUser(
    uid: 'member-user-42',
    email: 'member@librasync.org',
    displayName: 'Jane Reader',
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOW 1 & 2: Book Catalog & Multi-Field Search Integration Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('Flow 1 & 2: Book Catalog & Search Integration Tests', () {
    testWidgets(
      'Renders books from BookService stream and updates dynamically',
      (WidgetTester tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        fakeFirestore.store.documents['books/${sampleBook1.id}'] = sampleBook1
            .toFirestore();
        final bookService = BookService(firestore: fakeFirestore);

        await tester.pumpWidget(
          MaterialApp(home: BookCatalogScreen(bookService: bookService)),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Clean Architecture: A Craftsman\'s Guide'),
          findsWidgets,
        );
        expect(find.text('Robert C. Martin'), findsOneWidget);
        expect(find.text('All Books (1)'), findsOneWidget);
      },
    );

    testWidgets('Performs case-insensitive search by title and author', (
      WidgetTester tester,
    ) async {
      final books = [sampleBook1, sampleBookUnavailable];

      await tester.pumpWidget(
        MaterialApp(home: BookCatalogScreen(booksStream: Stream.value(books))),
      );
      await tester.pumpAndSettle();

      // Search by lowercase substring of title
      await tester.enterText(
        find.byKey(const Key('catalog_search_field')),
        'clean arch',
      );
      await tester.pump();

      expect(find.text('Found 1 matching books'), findsOneWidget);
      expect(
        find.text('Clean Architecture: A Craftsman\'s Guide'),
        findsWidgets,
      );
      expect(find.text('Designing Data-Intensive Applications'), findsNothing);

      // Search by author
      await tester.enterText(
        find.byKey(const Key('catalog_search_field')),
        'kleppmann',
      );
      await tester.pump();

      expect(find.text('Found 1 matching books'), findsOneWidget);
      expect(find.text('Designing Data-Intensive Applications'), findsWidgets);
      expect(
        find.text('Clean Architecture: A Craftsman\'s Guide'),
        findsNothing,
      );
    });

    testWidgets(
      'Clearing search using suffix clear button resets catalog list',
      (WidgetTester tester) async {
        final books = [sampleBook1, sampleBookUnavailable];

        await tester.pumpWidget(
          MaterialApp(
            home: BookCatalogScreen(booksStream: Stream.value(books)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('catalog_search_field')),
          'NonExistentQuery',
        );
        await tester.pump();

        expect(find.text('No matching books found'), findsOneWidget);

        // Tap suffix clear icon button in search bar
        expect(
          find.byKey(const Key('catalog_clear_search_btn')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('catalog_clear_search_btn')));
        await tester.pump();

        expect(find.text('All Books (2)'), findsOneWidget);
        expect(
          find.text('Clean Architecture: A Craftsman\'s Guide'),
          findsWidgets,
        );
      },
    );

    testWidgets('Empty catalog shows Add Book button for staff user', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookCatalogScreen(
            booksStream: Stream.value(<Book>[]),
            isStaff: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Books Available'), findsOneWidget);
      expect(
        find.byKey(const Key('catalog_empty_add_book_btn')),
        findsOneWidget,
      );
    });

    testWidgets(
      'Stream error retry button re-initializes book catalog stream',
      (WidgetTester tester) async {
        final controller = StreamController<List<Book>>.broadcast();

        await tester.pumpWidget(
          MaterialApp(home: BookCatalogScreen(booksStream: controller.stream)),
        );

        controller.addError('Network connection timeout');
        await tester.pumpAndSettle();

        expect(find.text('Failed to load book catalog'), findsOneWidget);
        expect(find.byKey(const Key('catalog_retry_btn')), findsOneWidget);

        await tester.tap(find.byKey(const Key('catalog_retry_btn')));
        await tester.pump();

        await controller.close();
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOW 3: Book Details Navigation & Metadata Handling Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('Flow 3: Book Details Navigation & Metadata Integrity Tests', () {
    testWidgets(
      'Navigating from Catalog to Book Details and popping returns cleanly',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BookCatalogScreen(booksStream: Stream.value([sampleBook1])),
          ),
        );
        await tester.pumpAndSettle();

        // Tap book card
        await tester.tap(find.byKey(Key('book_card_${sampleBook1.id}')));
        await tester.pumpAndSettle();

        expect(find.byType(BookDetailsScreen), findsOneWidget);
        expect(find.text('Available (3 of 5 copies)'), findsOneWidget);
        expect(find.text('Software Engineering'), findsOneWidget);
        expect(find.text('978-0134494166'), findsOneWidget);

        // Tap back button
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(BookCatalogScreen), findsOneWidget);
      },
    );

    testWidgets(
      'BookDetailsScreen renders minimal book with null optional fields gracefully',
      (WidgetTester tester) async {
        final minimalBook = Book(
          id: 'book-min',
          title: 'Minimal Metadata Title',
          author: 'Unknown Author',
          description: 'No detailed synopsis provided.',
          isAvailable: true,
          totalCopies: 1,
          availableCopies: 1,
        );

        await tester.pumpWidget(
          MaterialApp(home: BookDetailsScreen(book: minimalBook)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Minimal Metadata Title'), findsWidgets);
        expect(find.text('Unknown Author'), findsOneWidget);
        expect(find.text('Available (1 of 1 copies)'), findsOneWidget);
        expect(find.text('No detailed synopsis provided.'), findsOneWidget);
      },
    );

    testWidgets(
      'BookDetailsScreen dynamically checks staff status via BookService',
      (WidgetTester tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        final staffAuth = FakeFirebaseAuth(currentUser: staffUser);
        fakeFirestore.store.documents['users/${staffUser.uid}'] = {
          'uid': staffUser.uid,
          'email': staffUser.email,
          'role': 'staff',
        };
        final bookService = BookService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BookDetailsScreen(
              book: sampleBook1,
              bookService: bookService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Staff actions should be visible
        expect(find.byKey(const Key('book_details_edit_btn')), findsOneWidget);
        expect(
          find.byKey(const Key('book_details_delete_btn')),
          findsOneWidget,
        );
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOW 4 & 6: Circulation Screen & Book Return Lifecycle Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group(
    'Flow 4 & 6: Member Circulation & Return Lifecycle Integration Tests',
    () {
      testWidgets(
        'MemberCirculationScreen renders active and overdue loan indicators',
        (WidgetTester tester) async {
          final activeLoan = LoanRecord(
            id: 'loan-active-1',
            bookId: 'book-001',
            bookTitle: 'Clean Architecture: A Craftsman\'s Guide',
            bookAuthor: 'Robert C. Martin',
            borrowDate: DateTime.now().subtract(const Duration(days: 3)),
            dueDate: DateTime.now().add(const Duration(days: 11)),
            status: 'active',
          );

          final overdueLoan = LoanRecord(
            id: 'loan-overdue-1',
            bookId: 'book-002',
            bookTitle: 'Designing Data-Intensive Applications',
            bookAuthor: 'Martin Kleppmann',
            borrowDate: DateTime.now().subtract(const Duration(days: 20)),
            dueDate: DateTime.now().subtract(const Duration(days: 6)),
            status: 'active',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: MemberCirculationScreen(
                loansStream: Stream.value([activeLoan, overdueLoan]),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.textContaining('1 overdue book(s) requiring attention'),
            findsOneWidget,
          );
          expect(
            find.text('Clean Architecture: A Craftsman\'s Guide'),
            findsWidgets,
          );
          expect(
            find.text('Designing Data-Intensive Applications'),
            findsWidgets,
          );
          expect(find.textContaining('Overdue by 6 day(s)'), findsOneWidget);
        },
      );

      testWidgets(
        'Tapping Browse Books in empty circulation navigates to BookCatalogScreen',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: MemberCirculationScreen(
                loansStream: Stream.value(<LoanRecord>[]),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('No Books Borrowed'), findsOneWidget);
          final browseBtn = find.byKey(
            const Key('circulation_browse_catalog_btn'),
          );
          expect(browseBtn, findsOneWidget);

          await tester.tap(browseBtn);
          await tester.pumpAndSettle();

          expect(find.byType(BookCatalogScreen), findsOneWidget);
        },
      );

      testWidgets(
        'Full Return Book flow updates loan in Firestore and increments copies',
        (WidgetTester tester) async {
          final fakeFirestore = FakeFirebaseFirestore();
          final memberAuth = FakeFirebaseAuth(currentUser: memberUser);

          // Seed Book in Firestore with availableCopies = 2
          fakeFirestore.store.documents['books/${sampleBook1.id}'] = sampleBook1
              .copyWith(availableCopies: 2)
              .toFirestore();

          // Seed active loan in Firestore
          final activeLoan = LoanRecord(
            id: 'loan-return-test-1',
            bookId: sampleBook1.id,
            bookTitle: sampleBook1.title,
            bookAuthor: sampleBook1.author,
            memberId: memberUser.uid,
            borrowDate: DateTime.now().subtract(const Duration(days: 2)),
            dueDate: DateTime.now().add(const Duration(days: 12)),
            status: 'active',
          );
          fakeFirestore.store.documents['loans/${activeLoan.id}'] = activeLoan
              .toFirestore();

          final circulationService = CirculationService(
            firestore: fakeFirestore,
            auth: memberAuth,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: MemberCirculationScreen(
                circulationService: circulationService,
                memberId: memberUser.uid,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(sampleBook1.title), findsWidgets);

          // Tap Return Book button on the card
          final returnBtn = find.byKey(Key('return_btn_${activeLoan.id}'));
          expect(returnBtn, findsOneWidget);
          await tester.tap(returnBtn);
          await tester.pumpAndSettle();

          // Verify Return Confirmation Dialog is displayed
          expect(find.byType(ReturnConfirmationDialog), findsOneWidget);
          expect(find.text('Return Book'), findsOneWidget);

          // Confirm return
          await tester.tap(find.byKey(const Key('return_confirm_btn')));
          await tester.pumpAndSettle();

          // Tap Done on the success view
          expect(find.text('Book Marked as Returned'), findsOneWidget);
          expect(
            find.byKey(const Key('return_success_done_btn')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('return_success_done_btn')));
          await tester.pumpAndSettle();

          // Verify loan in Firestore is marked 'returned'
          final updatedLoanDoc =
              fakeFirestore.store.documents['loans/${activeLoan.id}'];
          expect(updatedLoanDoc, isNotNull);
          expect(updatedLoanDoc!['status'], 'returned');
          expect(updatedLoanDoc['returnDate'], isNotNull);

          // Verify book availableCopies incremented from 2 to 3
          final updatedBookDoc =
              fakeFirestore.store.documents['books/${sampleBook1.id}'];
          expect(updatedBookDoc, isNotNull);
          expect(updatedBookDoc!['availableCopies'], 3);
        },
      );

      testWidgets('ReturnConfirmationDialog handles service error gracefully', (
        WidgetTester tester,
      ) async {
        final testLoan = LoanRecord(
          id: 'loan-err-1',
          bookId: 'book-err',
          bookTitle: 'Error Book',
          bookAuthor: 'Error Author',
          borrowDate: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 14)),
          status: 'active',
        );

        // Use a custom service or failing callback
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReturnConfirmationDialog(
                loan: testLoan,
                onConfirmReturn: () async {
                  throw Exception('Backend return failure simulated');
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('return_confirm_btn')));
        await tester.pumpAndSettle();

        // Error message should be visible in the dialog
        expect(
          find.textContaining('Backend return failure simulated'),
          findsOneWidget,
        );
      });
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOW 5: End-to-End Borrow Action Integration Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('Flow 5: End-to-End Borrow Action Integration Tests', () {
    testWidgets(
      'Full Borrow flow creates loan document and decrements availableCopies',
      (WidgetTester tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        final memberAuth = FakeFirebaseAuth(currentUser: memberUser);

        // Seed Book in Firestore with availableCopies = 3
        fakeFirestore.store.documents['books/${sampleBook1.id}'] = sampleBook1
            .toFirestore();

        final circulationService = CirculationService(
          firestore: fakeFirestore,
          auth: memberAuth,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BookDetailsScreen(
              book: sampleBook1,
              circulationService: circulationService,
              onConfirmBorrow: () async {
                await circulationService.requestBorrow(
                  book: sampleBook1,
                  memberId: memberUser.uid,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Borrow Book
        await tester.tap(find.byKey(const Key('book_details_borrow_btn')));
        await tester.pumpAndSettle();

        // Verify Borrow Confirmation Sheet appears
        expect(find.byType(BorrowConfirmationSheet), findsOneWidget);
        expect(find.text('Confirm Borrowing'), findsOneWidget);
        expect(
          find.text('Clean Architecture: A Craftsman\'s Guide'),
          findsWidgets,
        );

        // Tap Confirm Borrow button
        await tester.tap(find.byKey(const Key('borrow_confirm_btn')));
        await tester.pumpAndSettle();

        // Tap Done on success screen
        expect(find.text('Book Borrowed Successfully!'), findsOneWidget);
        expect(
          find.byKey(const Key('borrow_success_done_btn')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('borrow_success_done_btn')));
        await tester.pumpAndSettle();

        // Verify new loan was created in Firestore
        final loans = fakeFirestore.store.documents.entries
            .where((e) => e.key.startsWith('loans/'))
            .toList();
        expect(loans, isNotEmpty);
        final loanData = loans.first.value;
        expect(loanData['bookId'], sampleBook1.id);
        expect(loanData['memberId'], memberUser.uid);
        expect(loanData['status'], 'active');

        // Verify book availableCopies was decremented from 3 to 2
        final updatedBookDoc =
            fakeFirestore.store.documents['books/${sampleBook1.id}'];
        expect(updatedBookDoc!['availableCopies'], 2);
      },
    );

    testWidgets('Borrowing fails gracefully when copies are depleted', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BookDetailsScreen(book: sampleBookUnavailable)),
      );
      await tester.pumpAndSettle();

      // Borrow button should be disabled
      final disabledBorrowBtn = find.byKey(
        const Key('book_details_borrow_btn_disabled'),
      );
      expect(disabledBorrowBtn, findsOneWidget);

      final buttonWidget = tester.widget<FilledButton>(disabledBorrowBtn);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets(
      'BorrowConfirmationSheet displays error message if borrow fails',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BorrowConfirmationSheet(
                book: sampleBook1,
                onConfirmBorrow: () async {
                  throw Exception(
                    'Maximum borrowing limit exceeded (5 loans).',
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('borrow_confirm_btn')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Maximum borrowing limit exceeded'),
          findsOneWidget,
        );
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOW 7 & 8: Staff Add Book End-to-End Integration Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('Flow 7 & 8: Staff Add Book End-to-End Integration Tests', () {
    testWidgets(
      'Staff user can open Add Book dialog, submit, and write to Firestore',
      (WidgetTester tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        final staffAuth = FakeFirebaseAuth(currentUser: staffUser);
        fakeFirestore.store.documents['users/${staffUser.uid}'] = {
          'uid': staffUser.uid,
          'email': staffUser.email,
          'role': 'staff',
        };
        final bookService = BookService(
          firestore: fakeFirestore,
          auth: staffAuth,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BookCatalogScreen(bookService: bookService, isStaff: true),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Add Book FAB
        expect(find.byKey(const Key('catalog_add_book_fab')), findsOneWidget);
        await tester.tap(find.byKey(const Key('catalog_add_book_fab')));
        await tester.pumpAndSettle();

        expect(find.byType(BookFormDialog), findsOneWidget);
        expect(find.text('Add New Book'), findsOneWidget);

        // Enter book information
        await tester.enterText(
          find.byKey(const Key('book_form_title_field')),
          'The Pragmatic Programmer',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_author_field')),
          'David Thomas, Andrew Hunt',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_description_field')),
          'Your journey to mastery in software development.',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_category_field')),
          'Programming',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_published_year_field')),
          '2019',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_isbn_field')),
          '978-0135957059',
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

        // Verify book was written to Firestore
        final createdBooks = fakeFirestore.store.documents.entries
            .where((e) => e.key.startsWith('books/'))
            .toList();
        expect(createdBooks, isNotEmpty);
        final created = createdBooks.first.value;
        expect(created['title'], 'The Pragmatic Programmer');
        expect(created['author'], 'David Thomas, Andrew Hunt');
        expect(created['totalCopies'], 4);
        expect(created['availableCopies'], 4);

        // SnackBar verification
        expect(
          find.textContaining('added to catalog successfully'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'BookFormDialog blocks submit when available copies exceed total copies',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: BookFormDialog())),
        );

        await tester.enterText(
          find.byKey(const Key('book_form_title_field')),
          'Valid Title',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_author_field')),
          'Valid Author',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_description_field')),
          'Valid Description with plenty of detail.',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_total_copies_field')),
          '2',
        );
        await tester.enterText(
          find.byKey(const Key('book_form_available_copies_field')),
          '5',
        );

        await tester.tap(find.byKey(const Key('book_form_submit_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Cannot exceed total'), findsOneWidget);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOW 9 & 10: Staff Edit & Delete Book End-to-End Integration Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group(
    'Flow 9 & 10: Staff Edit & Delete Book End-to-End Integration Tests',
    () {
      testWidgets(
        'Staff user can edit book details and BookDetailsScreen updates immediately',
        (WidgetTester tester) async {
          final fakeFirestore = FakeFirebaseFirestore();
          final staffAuth = FakeFirebaseAuth(currentUser: staffUser);
          fakeFirestore.store.documents['users/${staffUser.uid}'] = {
            'uid': staffUser.uid,
            'email': staffUser.email,
            'role': 'staff',
          };
          fakeFirestore.store.documents['books/${sampleBook1.id}'] = sampleBook1
              .toFirestore();

          final bookService = BookService(
            firestore: fakeFirestore,
            auth: staffAuth,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: BookDetailsScreen(
                book: sampleBook1,
                bookService: bookService,
                isStaff: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tap Edit button
          expect(
            find.byKey(const Key('book_details_edit_btn')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('book_details_edit_btn')));
          await tester.pumpAndSettle();

          expect(find.text('Edit Book Details'), findsOneWidget);

          // Modify title and copies
          await tester.enterText(
            find.byKey(const Key('book_form_title_field')),
            'Clean Architecture (Updated Edition)',
          );
          await tester.enterText(
            find.byKey(const Key('book_form_total_copies_field')),
            '10',
          );
          await tester.enterText(
            find.byKey(const Key('book_form_available_copies_field')),
            '8',
          );

          // Save changes
          await tester.tap(find.byKey(const Key('book_form_submit_btn')));
          await tester.pumpAndSettle();

          // Verify BookDetailsScreen displays updated information
          expect(
            find.text('Clean Architecture (Updated Edition)'),
            findsWidgets,
          );
          expect(find.text('Available (8 of 10 copies)'), findsOneWidget);

          // Verify Firestore was updated
          final updatedDoc =
              fakeFirestore.store.documents['books/${sampleBook1.id}'];
          expect(updatedDoc!['title'], 'Clean Architecture (Updated Edition)');
          expect(updatedDoc['totalCopies'], 10);
          expect(updatedDoc['availableCopies'], 8);
        },
      );

      testWidgets(
        'Staff user can delete book and pop back with confirmation SnackBar',
        (WidgetTester tester) async {
          final fakeFirestore = FakeFirebaseFirestore();
          final staffAuth = FakeFirebaseAuth(currentUser: staffUser);
          fakeFirestore.store.documents['users/${staffUser.uid}'] = {
            'uid': staffUser.uid,
            'email': staffUser.email,
            'role': 'staff',
          };
          fakeFirestore.store.documents['books/${sampleBook1.id}'] = sampleBook1
              .toFirestore();

          final bookService = BookService(
            firestore: fakeFirestore,
            auth: staffAuth,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: BookCatalogScreen(bookService: bookService, isStaff: true),
            ),
          );
          await tester.pumpAndSettle();

          // Navigate to details
          await tester.tap(find.byKey(Key('book_card_${sampleBook1.id}')));
          await tester.pumpAndSettle();

          expect(find.byType(BookDetailsScreen), findsOneWidget);

          // Tap Delete button
          await tester.tap(find.byKey(const Key('book_details_delete_btn')));
          await tester.pumpAndSettle();

          expect(find.byType(DeleteBookConfirmationDialog), findsOneWidget);

          // Confirm deletion
          await tester.tap(find.byKey(const Key('delete_book_confirm_btn')));
          await tester.pumpAndSettle();

          // Returned to catalog
          expect(find.byType(BookCatalogScreen), findsOneWidget);
          expect(find.textContaining('deleted from catalog'), findsOneWidget);

          // Verify book removed from Firestore
          expect(
            fakeFirestore.store.documents.containsKey(
              'books/${sampleBook1.id}',
            ),
            isFalse,
          );
        },
      );
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOW 11: Branches Screen & Navigation Integration Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group(
    'Flow 11: Branches Screen & Dashboard Navigation Integration Tests',
    () {
      testWidgets(
        'HomeScreen navigation to BranchesScreen displays branches from BranchService',
        (WidgetTester tester) async {
          await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
          await tester.pumpAndSettle();

          final branchCardFinder = find.widgetWithText(
            DashboardCard,
            'Branches',
          );
          expect(branchCardFinder, findsOneWidget);

          await tester.tap(branchCardFinder);
          await tester.pumpAndSettle();

          expect(find.byType(BranchesScreen), findsOneWidget);
          expect(find.text('Library Branches'), findsOneWidget);
        },
      );

      testWidgets(
        'BranchesScreen displays multiple branches with active count and addresses',
        (WidgetTester tester) async {
          final branches = [sampleBranchCentral, sampleBranchNorth];

          await tester.pumpWidget(
            MaterialApp(
              home: BranchesScreen(branchesStream: Stream.value(branches)),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('2 branches currently active in the LibraSync network.'),
            findsOneWidget,
          );
          expect(find.text('Central City Library'), findsOneWidget);
          expect(find.text('100 Downtown Plaza, Cityville'), findsOneWidget);
          expect(find.text('555-0101'), findsOneWidget);
          expect(find.text('Northside Community Library'), findsOneWidget);
          expect(find.text('250 North Hill Road, Cityville'), findsOneWidget);
          expect(find.text('555-0102'), findsOneWidget);
        },
      );

      testWidgets('BranchesScreen error view triggers retry on tap', (
        WidgetTester tester,
      ) async {
        final controller = StreamController<List<Branch>>.broadcast();

        await tester.pumpWidget(
          MaterialApp(home: BranchesScreen(branchesStream: controller.stream)),
        );

        controller.addError('Network connection lost');
        await tester.pumpAndSettle();

        expect(find.text('Failed to load library branches'), findsOneWidget);
        expect(find.byKey(const Key('branches_retry_btn')), findsOneWidget);

        await tester.tap(find.byKey(const Key('branches_retry_btn')));
        await tester.pump();

        await controller.close();
      });
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOW 12: Book Copy Availability & Branch Inventory Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('Flow 12: Book Copy Availability & Branch Inventory Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late BookCopyService copyService;

    final copyCentral1 = BookCopy(
      id: 'copy-c1',
      bookId: 'book-001',
      branchId: 'branch-central',
      status: BookCopy.statusAvailable,
      barcode: 'BC-001-C1',
      condition: 'new',
    );

    final copyCentral2 = BookCopy(
      id: 'copy-c2',
      bookId: 'book-001',
      branchId: 'branch-central',
      status: BookCopy.statusBorrowed,
      barcode: 'BC-001-C2',
      condition: 'good',
    );

    final copyNorth1 = BookCopy(
      id: 'copy-n1',
      bookId: 'book-001',
      branchId: 'branch-north',
      status: BookCopy.statusAvailable,
      barcode: 'BC-001-N1',
      condition: 'fair',
    );

    final copyNorth2 = BookCopy(
      id: 'copy-n2',
      bookId: 'book-001',
      branchId: 'branch-north',
      status: BookCopy.statusMaintenance,
      barcode: 'BC-001-N2',
      condition: 'damaged',
    );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['bookCopies/${copyCentral1.id}'] =
          copyCentral1.toFirestore();
      fakeFirestore.store.documents['bookCopies/${copyCentral2.id}'] =
          copyCentral2.toFirestore();
      fakeFirestore.store.documents['bookCopies/${copyNorth1.id}'] = copyNorth1
          .toFirestore();
      fakeFirestore.store.documents['bookCopies/${copyNorth2.id}'] = copyNorth2
          .toFirestore();
      copyService = BookCopyService(firestore: fakeFirestore);
    });

    test('Queries all copies for a book across all branches', () async {
      final copies = await copyService.getCopiesForBook('book-001');
      expect(copies.length, 4);
    });

    test('Filters available copies by specific branch', () async {
      final centralAvail = await copyService.getAvailableCopiesForBook(
        'book-001',
        branchId: 'branch-central',
      );
      expect(centralAvail.length, 1);
      expect(centralAvail.first.id, 'copy-c1');

      final northAvail = await copyService.getAvailableCopiesForBook(
        'book-001',
        branchId: 'branch-north',
      );
      expect(northAvail.length, 1);
      expect(northAvail.first.id, 'copy-n1');
    });

    test('Counts total available copies for a book accurately', () async {
      final count = await copyService.getAvailableCopyCountForBook('book-001');
      expect(count, 2); // copyCentral1 and copyNorth1
    });

    test('Streams available copies for a branch in real time', () async {
      final stream = copyService.streamAvailableCopiesForBranch(
        'branch-central',
      );
      final initial = await stream.first;
      expect(initial.length, 1);
      expect(initial.first.id, 'copy-c1');
    });

    test('Copies transition across statuses (available -> borrowed -> maintenance -> lost)', () {
      final copy = BookCopy(
        id: 'copy-status-test',
        bookId: 'book-001',
        branchId: 'branch-central',
        status: BookCopy.statusAvailable,
      );
      expect(copy.isAvailable, isTrue);

      final borrowed = copy.copyWith(status: BookCopy.statusBorrowed);
      expect(borrowed.isAvailable, isFalse);
      expect(borrowed.status, 'borrowed');

      final maintenance = copy.copyWith(status: BookCopy.statusMaintenance);
      expect(maintenance.isAvailable, isFalse);
      expect(maintenance.status, 'maintenance');

      final lost = copy.copyWith(status: BookCopy.statusLost);
      expect(lost.isAvailable, isFalse);
      expect(lost.status, 'lost');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOW 13: AuthGate Authentication Routing & State Transitions
  // ═══════════════════════════════════════════════════════════════════════════

  group('Flow 13: AuthGate Routing & Authentication State Transitions', () {
    testWidgets(
      'AuthGate shows loading spinner while auth status is unresolved',
      (WidgetTester tester) async {
        final controller = StreamController<User?>();

        final fakeAuth = FakeFirebaseAuthWithStream(controller.stream);
        final authService = AuthService(auth: fakeAuth);

        await tester.pumpWidget(
          MaterialApp(home: AuthGate(authService: authService)),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await controller.close();
      },
    );

    testWidgets('AuthGate routes to HomeScreen when user is authenticated', (
      WidgetTester tester,
    ) async {
      final fakeAuth = FakeFirebaseAuthWithUser(memberUser);
      final authService = AuthService(auth: fakeAuth);

      await tester.pumpWidget(
        MaterialApp(home: AuthGate(authService: authService)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Welcome to LibraSync'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('AuthGate routes to LoginScreen when user is unauthenticated', (
      WidgetTester tester,
    ) async {
      final fakeAuth = FakeFirebaseAuthWithUser(null);
      final authService = AuthService(auth: fakeAuth);

      await tester.pumpWidget(
        MaterialApp(home: AuthGate(authService: authService)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// Test Doubles & Fakes
// ═════════════════════════════════════════════════════════════════════════════

class FakeUser extends Fake implements User {
  FakeUser({required this.uid, required this.email, this.displayName});

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
  User? currentUser;

  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);
}

class FakeFirebaseAuthWithStream extends Fake implements FirebaseAuth {
  FakeFirebaseAuthWithStream(this._stream);

  final Stream<User?> _stream;

  @override
  Stream<User?> authStateChanges() => _stream;

  @override
  User? get currentUser => null;
}

class FakeFirebaseAuthWithUser extends Fake implements FirebaseAuth {
  FakeFirebaseAuthWithUser(this._user);

  final User? _user;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() => Stream.value(_user);
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
      if (options?.merge == true) {
        final existing = _store.documents[_path] ?? {};
        _store.documents[_path] = {...existing, ...data};
      } else {
        _store.documents[_path] = Map<String, dynamic>.from(data);
      }
    }
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    final existing = Map<String, dynamic>.from(_store.documents[_path] ?? {});
    data.forEach((key, value) {
      existing[key.toString()] = value;
    });
    _store.documents[_path] = existing;
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
