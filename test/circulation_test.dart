// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librasync/models/book.dart';
import 'package:librasync/models/loan_record.dart';
import 'package:librasync/screens/catalog/book_details_screen.dart';
import 'package:librasync/screens/circulation/member_circulation_screen.dart';
import 'package:librasync/screens/home_screen.dart';
import 'package:librasync/services/circulation_service.dart';
import 'package:librasync/widgets/circulation/borrow_confirmation_sheet.dart';
import 'package:librasync/widgets/circulation/borrowed_book_card.dart';
import 'package:librasync/widgets/circulation/return_confirmation_dialog.dart';

void main() {
  final availableBook = Book(
    id: 'book-avail-1',
    title: 'Clean Code',
    author: 'Robert C. Martin',
    description: 'A handbook of agile software craftsmanship.',
    category: 'Software Engineering',
    publishedYear: 2008,
    isbn: '978-0132350884',
    isAvailable: true,
    totalCopies: 4,
    availableCopies: 3,
  );

  final unavailableBook = Book(
    id: 'book-unavail-1',
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

  final sampleLoan1 = LoanRecord(
    id: 'loan-1',
    bookId: 'book-avail-1',
    bookTitle: 'Clean Code',
    bookAuthor: 'Robert C. Martin',
    borrowDate: DateTime.now().subtract(const Duration(days: 4)),
    dueDate: DateTime.now().add(const Duration(days: 10)),
    status: 'active',
  );

  final sampleOverdueLoan = LoanRecord(
    id: 'loan-2',
    bookId: 'book-unavail-1',
    bookTitle: 'Designing Data-Intensive Applications',
    bookAuthor: 'Martin Kleppmann',
    borrowDate: DateTime.now().subtract(const Duration(days: 20)),
    dueDate: DateTime.now().subtract(const Duration(days: 6)),
    status: 'active',
  );

  group('LoanRecord Model Unit Tests', () {
    test('Correctly serializes to and from Firestore map', () {
      final map = sampleLoan1.toFirestore();
      expect(map['bookId'], 'book-avail-1');
      expect(map['bookTitle'], 'Clean Code');
      expect(map['bookAuthor'], 'Robert C. Martin');
      expect(map['status'], 'active');

      final deserialized = LoanRecord.fromFirestore(map, 'loan-1');
      expect(deserialized.id, 'loan-1');
      expect(deserialized.bookTitle, 'Clean Code');
      expect(deserialized.bookAuthor, 'Robert C. Martin');
      expect(deserialized.isOverdue, isFalse);
    });

    test('Correctly computes isOverdue and daysUntilDue', () {
      expect(sampleLoan1.isOverdue, isFalse);
      expect(sampleOverdueLoan.isOverdue, isTrue);
      expect(sampleOverdueLoan.daysUntilDue, lessThan(0));
    });

    test('copyWith updates properties properly', () {
      final returnDate = DateTime.now();
      final returned = sampleLoan1.copyWith(
        status: 'returned',
        returnDate: returnDate,
      );
      expect(returned.status, 'returned');
      expect(returned.returnDate, returnDate);
      expect(returned.bookTitle, sampleLoan1.bookTitle);
    });
  });

  group('BookDetailsScreen Borrow Action Tests', () {
    testWidgets('Shows enabled Borrow Book button when copies are available', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BookDetailsScreen(book: availableBook)),
      );

      final borrowButton = find.byKey(const Key('book_details_borrow_btn'));
      expect(borrowButton, findsOneWidget);
      expect(find.text('Borrow Book'), findsOneWidget);

      final buttonWidget = tester.widget<FilledButton>(borrowButton);
      expect(buttonWidget.onPressed, isNotNull);
    });

    testWidgets('Shows disabled state when book is unavailable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BookDetailsScreen(book: unavailableBook)),
      );

      final disabledButton = find.byKey(
        const Key('book_details_borrow_btn_disabled'),
      );
      expect(disabledButton, findsOneWidget);
      expect(find.text('Currently Unavailable'), findsOneWidget);

      final buttonWidget = tester.widget<FilledButton>(disabledButton);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('Tapping Borrow Book button opens BorrowConfirmationSheet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BookDetailsScreen(book: availableBook)),
      );

      await tester.tap(find.byKey(const Key('book_details_borrow_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(BorrowConfirmationSheet), findsOneWidget);
      expect(find.text('Confirm Borrowing'), findsOneWidget);
      expect(find.text('Clean Code'), findsWidgets);
      expect(find.text('by Robert C. Martin'), findsOneWidget);
      expect(find.byKey(const Key('borrow_confirm_btn')), findsOneWidget);
      expect(find.byKey(const Key('borrow_cancel_btn')), findsOneWidget);
    });

    testWidgets(
      'Completing borrow in BorrowConfirmationSheet pops screen with true',
      (WidgetTester tester) async {
        bool? poppedResult;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  poppedResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (context) => BookDetailsScreen(
                        book: availableBook,
                        onConfirmBorrow: () async {},
                      ),
                    ),
                  );
                },
                child: const Text('Open Details'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Details'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('book_details_borrow_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('borrow_confirm_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('borrow_success_done_btn')));
        await tester.pumpAndSettle();

        expect(poppedResult, isTrue);
      },
    );
  });

  group('BorrowConfirmationSheet Widget Tests', () {
    testWidgets('Renders all terms, due date, and cancel action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BorrowConfirmationSheet(book: availableBook)),
        ),
      );

      expect(find.text('Confirm Borrowing'), findsOneWidget);
      expect(find.text('Expected Due Date'), findsOneWidget);
      expect(find.text('Loan Policy'), findsOneWidget);
      expect(find.byKey(const Key('borrow_confirm_btn')), findsOneWidget);
      expect(find.byKey(const Key('borrow_cancel_btn')), findsOneWidget);
    });

    testWidgets('Handles loading and success state on confirm borrow', (
      WidgetTester tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BorrowConfirmationSheet(
              book: availableBook,
              onConfirmBorrow: () => completer.future,
            ),
          ),
        ),
      );

      // Tap confirm borrow
      await tester.tap(find.byKey(const Key('borrow_confirm_btn')));
      await tester.pump();

      // Verify loading spinner is displayed
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete operation
      completer.complete();
      await tester.pumpAndSettle();

      // Verify success banner is shown
      expect(find.text('Book Borrowed Successfully!'), findsOneWidget);
      expect(find.byKey(const Key('borrow_success_done_btn')), findsOneWidget);
    });

    testWidgets('Handles error state gracefully without fake success', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BorrowConfirmationSheet(
              book: availableBook,
              onConfirmBorrow: () async {
                throw Exception('Borrowing limit exceeded.');
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('borrow_confirm_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Borrowing limit exceeded.'), findsOneWidget);
      expect(find.byKey(const Key('borrow_confirm_btn')), findsOneWidget);
    });

    testWidgets('Cancel button dismisses BorrowConfirmationSheet with false', (
      WidgetTester tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await BorrowConfirmationSheet.show(
                  context,
                  book: availableBook,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('borrow_cancel_btn')));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets(
      'BorrowConfirmationSheet disables buttons while borrow request is in progress',
      (WidgetTester tester) async {
        final completer = Completer<void>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BorrowConfirmationSheet(
                book: availableBook,
                onConfirmBorrow: () => completer.future,
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('borrow_confirm_btn')));
        await tester.pump();

        // Both buttons should be disabled during loading
        final confirmBtn = tester.widget<FilledButton>(
          find.byKey(const Key('borrow_confirm_btn')),
        );
        final cancelBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('borrow_cancel_btn')),
        );
        expect(confirmBtn.onPressed, isNull);
        expect(cancelBtn.onPressed, isNull);

        completer.complete();
        await tester.pumpAndSettle();
      },
    );
  });

  group('BorrowedBookCard Widget Tests', () {
    testWidgets('Renders active loan details and return action', (
      WidgetTester tester,
    ) async {
      bool returnTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BorrowedBookCard(
              loan: sampleLoan1,
              onReturn: () => returnTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Clean Code'), findsWidgets);
      expect(find.text('by Robert C. Martin'), findsOneWidget);
      expect(find.byKey(Key('return_btn_${sampleLoan1.id}')), findsOneWidget);

      await tester.tap(find.byKey(Key('return_btn_${sampleLoan1.id}')));
      await tester.pump();
      expect(returnTapped, isTrue);
    });

    testWidgets('Renders overdue status badge for past due loans', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BorrowedBookCard(loan: sampleOverdueLoan, onReturn: () {}),
          ),
        ),
      );

      expect(find.text('Designing Data-Intensive Applications'), findsWidgets);
      expect(find.textContaining('Overdue'), findsOneWidget);
    });

    testWidgets('Renders warning status badge when book is due in <= 3 days', (
      WidgetTester tester,
    ) async {
      final dueSoonLoan = LoanRecord(
        id: 'loan-due-soon',
        bookId: 'book-avail-1',
        bookTitle: 'Clean Code',
        bookAuthor: 'Robert C. Martin',
        borrowDate: DateTime.now().subtract(const Duration(days: 12)),
        dueDate: DateTime.now().add(const Duration(days: 2, hours: 4)),
        status: 'active',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BorrowedBookCard(loan: dueSoonLoan, onReturn: () {}),
          ),
        ),
      );

      expect(find.textContaining('Due in'), findsOneWidget);
    });

    testWidgets(
      'Renders placeholder cover gracefully when bookImageUrl is null or empty',
      (WidgetTester tester) async {
        final noImageLoan = LoanRecord(
          id: 'loan-no-img',
          bookId: 'book-avail-1',
          bookTitle: 'Clean Architecture',
          bookAuthor: 'Robert C. Martin',
          bookImageUrl: '',
          borrowDate: DateTime.now().subtract(const Duration(days: 2)),
          dueDate: DateTime.now().add(const Duration(days: 12)),
          status: 'active',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BorrowedBookCard(loan: noImageLoan, onReturn: () {}),
            ),
          ),
        );

        expect(find.text('Clean Architecture'), findsWidgets);
        expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
      },
    );
  });

  group('ReturnConfirmationDialog Widget Tests', () {
    testWidgets('Renders return dialog content, cancel, and confirm buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReturnConfirmationDialog(loan: sampleLoan1)),
        ),
      );

      expect(find.text('Return Book'), findsOneWidget);
      expect(find.text('Clean Code'), findsWidgets);
      expect(find.byKey(const Key('return_confirm_btn')), findsOneWidget);
      expect(find.byKey(const Key('return_cancel_btn')), findsOneWidget);
    });

    testWidgets('Handles loading and success state on return confirm', (
      WidgetTester tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnConfirmationDialog(
              loan: sampleLoan1,
              onConfirmReturn: () => completer.future,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('return_confirm_btn')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('Book Marked as Returned'), findsOneWidget);
      expect(find.byKey(const Key('return_success_done_btn')), findsOneWidget);
    });

    testWidgets('Cancel button dismisses ReturnConfirmationDialog with false', (
      WidgetTester tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ReturnConfirmationDialog.show(
                  context,
                  loan: sampleLoan1,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('return_cancel_btn')));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets(
      'ReturnConfirmationDialog handles backend error and shows error banner',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReturnConfirmationDialog(
                loan: sampleLoan1,
                onConfirmReturn: () async {
                  throw Exception('Loan record does not exist.');
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('return_confirm_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Loan record does not exist.'), findsOneWidget);
        expect(find.byKey(const Key('return_confirm_btn')), findsOneWidget);
      },
    );

    testWidgets('ReturnConfirmationDialog disables buttons while loading', (
      WidgetTester tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnConfirmationDialog(
              loan: sampleLoan1,
              onConfirmReturn: () => completer.future,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('return_confirm_btn')));
      await tester.pump();

      final confirmBtn = tester.widget<FilledButton>(
        find.byKey(const Key('return_confirm_btn')),
      );
      final cancelBtn = tester.widget<TextButton>(
        find.byKey(const Key('return_cancel_btn')),
      );
      expect(confirmBtn.onPressed, isNull);
      expect(cancelBtn.onPressed, isNull);

      completer.complete();
      await tester.pumpAndSettle();
    });
  });

  group('MemberCirculationScreen Widget Tests', () {
    testWidgets('Shows loading state while loan stream is waiting', (
      WidgetTester tester,
    ) async {
      final controller = StreamController<List<LoanRecord>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MemberCirculationScreen(loansStream: controller.stream),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading your borrowed books...'), findsOneWidget);
    });

    testWidgets('Shows empty state when no books are borrowed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MemberCirculationScreen(
            loansStream: Stream.value(<LoanRecord>[]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Books Borrowed'), findsOneWidget);
      expect(
        find.byKey(const Key('circulation_browse_catalog_btn')),
        findsOneWidget,
      );
    });

    testWidgets(
      'Tapping Browse Book Catalog in empty state navigates to BookCatalogScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MemberCirculationScreen(
              loansStream: Stream.value(<LoanRecord>[]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('circulation_browse_catalog_btn')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Book Catalog'), findsOneWidget);
      },
    );

    testWidgets('Shows error state with retry button on stream failure', (
      WidgetTester tester,
    ) async {
      final controller = StreamController<List<LoanRecord>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MemberCirculationScreen(loansStream: controller.stream),
        ),
      );

      controller.addError(Exception('Failed to load loans'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load borrowed books'), findsOneWidget);
      expect(find.byKey(const Key('circulation_retry_btn')), findsOneWidget);
    });

    testWidgets('Tapping Retry button in error state triggers stream reload', (
      WidgetTester tester,
    ) async {
      final controller = StreamController<List<LoanRecord>>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MemberCirculationScreen(loansStream: controller.stream),
        ),
      );

      controller.addError(Exception('Network error'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load borrowed books'), findsOneWidget);
      expect(find.byKey(const Key('circulation_retry_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('circulation_retry_btn')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Renders active borrowed books list with overdue banner', (
      WidgetTester tester,
    ) async {
      final loans = [sampleLoan1, sampleOverdueLoan];

      await tester.pumpWidget(
        MaterialApp(
          home: MemberCirculationScreen(loansStream: Stream.value(loans)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('You have 1 overdue book(s) requiring attention.'),
        findsOneWidget,
      );
      expect(find.text('Clean Code'), findsWidgets);
      expect(find.text('Designing Data-Intensive Applications'), findsWidgets);
      expect(find.byKey(Key('loan_card_${sampleLoan1.id}')), findsOneWidget);
      expect(
        find.byKey(Key('loan_card_${sampleOverdueLoan.id}')),
        findsOneWidget,
      );
    });

    testWidgets(
      'Renders standard active loan banner when no loans are overdue',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MemberCirculationScreen(
              loansStream: Stream.value([sampleLoan1]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('You currently have 1 active borrowed book(s).'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Tapping Return on a loan card opens ReturnConfirmationDialog',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MemberCirculationScreen(
              loansStream: Stream.value([sampleLoan1]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final returnBtn = find.byKey(Key('return_btn_${sampleLoan1.id}'));
        expect(returnBtn, findsOneWidget);

        await tester.tap(returnBtn);
        await tester.pumpAndSettle();

        expect(find.byType(ReturnConfirmationDialog), findsOneWidget);
        expect(find.text('Return Book'), findsOneWidget);
      },
    );
  });

  group('HomeScreen to Member Circulation Navigation Tests', () {
    testWidgets(
      'Tapping Borrowing card on HomeScreen opens MemberCirculationScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

        // Tap Borrowing Quick Access card
        await tester.tap(find.text('Borrowing'));
        await tester.pumpAndSettle();

        // Verify MemberCirculationScreen is opened
        expect(find.byType(MemberCirculationScreen), findsOneWidget);
        expect(find.text('My Borrowed Books'), findsOneWidget);
      },
    );
  });

  group('CirculationService Transaction & Security Unit Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeUser fakeUser;
    late FakeFirebaseAuth fakeAuth;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeUser = FakeUser(
        uid: 'user-123',
        email: 'user@example.com',
        displayName: 'Test User',
      );
      fakeAuth = FakeFirebaseAuth(currentUser: fakeUser);
    });

    test('requestBorrow throws error when user is unauthenticated', () async {
      final service = CirculationService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: null),
      );

      expect(
        () => service.requestBorrow(book: availableBook, memberId: 'user-123'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Authentication required'),
          ),
        ),
      );
    });

    test('requestBorrow throws error when book does not exist', () async {
      final service = CirculationService(
        firestore: fakeFirestore,
        auth: fakeAuth,
      );

      expect(
        () => service.requestBorrow(book: availableBook, memberId: 'user-123'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('was not found'),
          ),
        ),
      );
    });

    test('requestBorrow throws error when book availableCopies is 0', () async {
      fakeFirestore.store.documents['books/${unavailableBook.id}'] =
          unavailableBook.toFirestore();

      final service = CirculationService(
        firestore: fakeFirestore,
        auth: fakeAuth,
      );

      expect(
        () =>
            service.requestBorrow(book: unavailableBook, memberId: 'user-123'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No available copies'),
          ),
        ),
      );
    });

    test('requestBorrow throws error when user already has an active loan for same book', () async {
      fakeFirestore.store.documents['books/${availableBook.id}'] = availableBook
          .toFirestore();
      fakeFirestore.store.documents['loans/existing-loan'] = {
        'bookId': availableBook.id,
        'memberId': 'user-123',
        'status': 'active',
      };

      final service = CirculationService(
        firestore: fakeFirestore,
        auth: fakeAuth,
      );

      expect(
        () => service.requestBorrow(book: availableBook, memberId: 'user-123'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('already have an active loan'),
          ),
        ),
      );
    });

    test('requestBorrow succeeds: decrements copies, sets isAvailable, creates loan', () async {
      fakeFirestore.store.documents['books/${availableBook.id}'] = availableBook
          .toFirestore(); // availableCopies: 3

      final service = CirculationService(
        firestore: fakeFirestore,
        auth: fakeAuth,
      );

      await service.requestBorrow(book: availableBook, memberId: 'user-123');

      final updatedBookMap =
          fakeFirestore.store.documents['books/${availableBook.id}']!;
      expect(updatedBookMap['availableCopies'], 2);
      expect(updatedBookMap['isAvailable'], true);

      final loanDocs = fakeFirestore.store.documents.entries
          .where((e) => e.key.startsWith('loans/'))
          .toList();
      expect(loanDocs.length, 1);
      final loanData = loanDocs.first.value;
      expect(loanData['bookId'], availableBook.id);
      expect(loanData['memberId'], 'user-123');
      expect(loanData['status'], 'active');
    });

    test(
      'requestBorrow sets isAvailable false when last copy borrowed',
      () async {
        final singleCopyBook = availableBook.copyWith(availableCopies: 1);
        fakeFirestore.store.documents['books/${singleCopyBook.id}'] =
            singleCopyBook.toFirestore();

        final service = CirculationService(
          firestore: fakeFirestore,
          auth: fakeAuth,
        );

        await service.requestBorrow(book: singleCopyBook, memberId: 'user-123');

        final updatedBookMap =
            fakeFirestore.store.documents['books/${singleCopyBook.id}']!;
        expect(updatedBookMap['availableCopies'], 0);
        expect(updatedBookMap['isAvailable'], false);
      },
    );

    test('requestReturn throws error when user is unauthenticated', () async {
      final service = CirculationService(
        firestore: fakeFirestore,
        auth: FakeFirebaseAuth(currentUser: null),
      );

      expect(
        () => service.requestReturn(loanId: 'loan-1'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Authentication required'),
          ),
        ),
      );
    });

    test('requestReturn throws error when loan does not exist', () async {
      final service = CirculationService(
        firestore: fakeFirestore,
        auth: fakeAuth,
      );

      expect(
        () => service.requestReturn(loanId: 'non-existent-loan'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('does not exist'),
          ),
        ),
      );
    });

    test(
      'requestReturn throws error when loan belongs to another user',
      () async {
        fakeFirestore.store.documents['loans/other-loan'] = {
          'bookId': availableBook.id,
          'memberId': 'different-user-999',
          'status': 'active',
        };

        final service = CirculationService(
          firestore: fakeFirestore,
          auth: fakeAuth,
        );

        expect(
          () => service.requestReturn(loanId: 'other-loan'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authorized'),
            ),
          ),
        );
      },
    );

    test('requestReturn throws error when loan is already returned', () async {
      fakeFirestore.store.documents['loans/returned-loan'] = {
        'bookId': availableBook.id,
        'memberId': 'user-123',
        'status': 'returned',
        'returnDate': Timestamp.now(),
      };

      final service = CirculationService(
        firestore: fakeFirestore,
        auth: fakeAuth,
      );

      expect(
        () => service.requestReturn(loanId: 'returned-loan'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('already been returned'),
          ),
        ),
      );
    });

    test('requestReturn succeeds: updates loan status and increments availableCopies', () async {
      fakeFirestore.store.documents['books/${availableBook.id}'] = availableBook
          .toFirestore(); // availableCopies: 3
      fakeFirestore.store.documents['loans/valid-loan'] = {
        'bookId': availableBook.id,
        'bookTitle': availableBook.title,
        'bookAuthor': availableBook.author,
        'borrowDate': Timestamp.now(),
        'dueDate': Timestamp.now(),
        'memberId': 'user-123',
        'status': 'active',
      };

      final service = CirculationService(
        firestore: fakeFirestore,
        auth: fakeAuth,
      );

      await service.requestReturn(loanId: 'valid-loan');

      final updatedLoanMap = fakeFirestore.store.documents['loans/valid-loan']!;
      expect(updatedLoanMap['status'], 'returned');
      expect(updatedLoanMap['returnDate'], isNotNull);

      final updatedBookMap =
          fakeFirestore.store.documents['books/${availableBook.id}']!;
      expect(updatedBookMap['availableCopies'], 4);
      expect(updatedBookMap['isAvailable'], true);
    });

    test(
      'requestReturn succeeds cleanly when book document is missing in catalog',
      () async {
        fakeFirestore.store.documents['loans/orphan-loan'] = {
          'bookId': 'deleted-book-999',
          'bookTitle': 'Deleted Book',
          'bookAuthor': 'Unknown Author',
          'borrowDate': Timestamp.now(),
          'dueDate': Timestamp.now(),
          'memberId': 'user-123',
          'status': 'active',
        };

        final service = CirculationService(
          firestore: fakeFirestore,
          auth: fakeAuth,
        );

        await service.requestReturn(loanId: 'orphan-loan');

        final updatedLoanMap =
            fakeFirestore.store.documents['loans/orphan-loan']!;
        expect(updatedLoanMap['status'], 'returned');
        expect(updatedLoanMap['returnDate'], isNotNull);
      },
    );

    test(
      'requestReturn fails on second call and does not double-increment copies',
      () async {
        fakeFirestore.store.documents['books/${availableBook.id}'] =
            availableBook.toFirestore(); // availableCopies: 3
        fakeFirestore.store.documents['loans/double-return-loan'] = {
          'bookId': availableBook.id,
          'bookTitle': availableBook.title,
          'bookAuthor': availableBook.author,
          'borrowDate': Timestamp.now(),
          'dueDate': Timestamp.now(),
          'memberId': 'user-123',
          'status': 'active',
        };

        final service = CirculationService(
          firestore: fakeFirestore,
          auth: fakeAuth,
        );

        // First return succeeds
        await service.requestReturn(loanId: 'double-return-loan');
        expect(
          fakeFirestore
              .store
              .documents['books/${availableBook.id}']!['availableCopies'],
          4,
        );

        // Second return throws error
        expect(
          () => service.requestReturn(loanId: 'double-return-loan'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('already been returned'),
            ),
          ),
        );

        // Copies remain 4, NOT 5
        expect(
          fakeFirestore
              .store
              .documents['books/${availableBook.id}']!['availableCopies'],
          4,
        );
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
  FakeFirebaseAuth({this._currentUser});

  final User? _currentUser;

  @override
  User? get currentUser => _currentUser;
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

  @override
  Stream<QuerySnapshot<T>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    return Stream.value(FakeQuerySnapshot<T>([]));
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
