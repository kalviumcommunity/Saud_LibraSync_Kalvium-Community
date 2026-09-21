import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librasync/models/book.dart';
import 'package:librasync/models/loan_record.dart';
import 'package:librasync/screens/catalog/book_details_screen.dart';
import 'package:librasync/screens/circulation/member_circulation_screen.dart';
import 'package:librasync/screens/home_screen.dart';
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
    testWidgets('Shows enabled Borrow Book button when copies are available',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookDetailsScreen(book: availableBook),
        ),
      );

      final borrowButton = find.byKey(const Key('book_details_borrow_btn'));
      expect(borrowButton, findsOneWidget);
      expect(find.text('Borrow Book'), findsOneWidget);

      final buttonWidget = tester.widget<FilledButton>(borrowButton);
      expect(buttonWidget.onPressed, isNotNull);
    });

    testWidgets('Shows disabled state when book is unavailable',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookDetailsScreen(book: unavailableBook),
        ),
      );

      final disabledButton =
          find.byKey(const Key('book_details_borrow_btn_disabled'));
      expect(disabledButton, findsOneWidget);
      expect(find.text('Currently Unavailable'), findsOneWidget);

      final buttonWidget = tester.widget<FilledButton>(disabledButton);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('Tapping Borrow Book button opens BorrowConfirmationSheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookDetailsScreen(book: availableBook),
        ),
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
  });

  group('BorrowConfirmationSheet Widget Tests', () {
    testWidgets('Renders all terms, due date, and cancel action',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BorrowConfirmationSheet(book: availableBook),
          ),
        ),
      );

      expect(find.text('Confirm Borrowing'), findsOneWidget);
      expect(find.text('Expected Due Date'), findsOneWidget);
      expect(find.text('Loan Policy'), findsOneWidget);
      expect(find.byKey(const Key('borrow_confirm_btn')), findsOneWidget);
      expect(find.byKey(const Key('borrow_cancel_btn')), findsOneWidget);
    });

    testWidgets('Handles loading and success state on confirm borrow',
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

    testWidgets('Handles error state gracefully without fake success',
        (WidgetTester tester) async {
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
  });

  group('BorrowedBookCard Widget Tests', () {
    testWidgets('Renders active loan details and return action',
        (WidgetTester tester) async {
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

    testWidgets('Renders overdue status badge for past due loans',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BorrowedBookCard(
              loan: sampleOverdueLoan,
              onReturn: () {},
            ),
          ),
        ),
      );

      expect(
        find.text('Designing Data-Intensive Applications'),
        findsWidgets,
      );
      expect(find.textContaining('Overdue'), findsOneWidget);
    });
  });

  group('ReturnConfirmationDialog Widget Tests', () {
    testWidgets('Renders return dialog content, cancel, and confirm buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnConfirmationDialog(loan: sampleLoan1),
          ),
        ),
      );

      expect(find.text('Return Book'), findsOneWidget);
      expect(find.text('Clean Code'), findsWidgets);
      expect(find.byKey(const Key('return_confirm_btn')), findsOneWidget);
      expect(find.byKey(const Key('return_cancel_btn')), findsOneWidget);
    });

    testWidgets('Handles loading and success state on return confirm',
        (WidgetTester tester) async {
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
  });

  group('MemberCirculationScreen Widget Tests', () {
    testWidgets('Shows loading state while loan stream is waiting',
        (WidgetTester tester) async {
      final controller = StreamController<List<LoanRecord>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MemberCirculationScreen(
            loansStream: controller.stream,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading your borrowed books...'), findsOneWidget);
    });

    testWidgets('Shows empty state when no books are borrowed',
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
      expect(
        find.byKey(const Key('circulation_browse_catalog_btn')),
        findsOneWidget,
      );
    });

    testWidgets('Shows error state with retry button on stream failure',
        (WidgetTester tester) async {
      final controller = StreamController<List<LoanRecord>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MemberCirculationScreen(
            loansStream: controller.stream,
          ),
        ),
      );

      controller.addError(Exception('Failed to load loans'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load borrowed books'), findsOneWidget);
      expect(find.byKey(const Key('circulation_retry_btn')), findsOneWidget);
    });

    testWidgets('Renders active borrowed books list',
        (WidgetTester tester) async {
      final loans = [sampleLoan1, sampleOverdueLoan];

      await tester.pumpWidget(
        MaterialApp(
          home: MemberCirculationScreen(
            loansStream: Stream.value(loans),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('You have 1 overdue book(s) requiring attention.'),
        findsOneWidget,
      );
      expect(find.text('Clean Code'), findsWidgets);
      expect(
        find.text('Designing Data-Intensive Applications'),
        findsWidgets,
      );
      expect(find.byKey(Key('loan_card_${sampleLoan1.id}')), findsOneWidget);
      expect(
        find.byKey(Key('loan_card_${sampleOverdueLoan.id}')),
        findsOneWidget,
      );
    });
  });

  group('HomeScreen to Member Circulation Navigation Tests', () {
    testWidgets(
        'Tapping Borrowing card on HomeScreen opens MemberCirculationScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      // Tap Borrowing Quick Access card
      await tester.tap(find.text('Borrowing'));
      await tester.pumpAndSettle();

      // Verify MemberCirculationScreen is opened
      expect(find.byType(MemberCirculationScreen), findsOneWidget);
      expect(find.text('My Borrowed Books'), findsOneWidget);
    });
  });
}
