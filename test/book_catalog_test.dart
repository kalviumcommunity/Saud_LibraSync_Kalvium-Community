import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librasync/models/book.dart';
import 'package:librasync/screens/catalog/book_catalog_screen.dart';
import 'package:librasync/screens/catalog/book_details_screen.dart';
import 'package:librasync/screens/home_screen.dart';
import 'package:librasync/widgets/book_card.dart';

void main() {
  final sampleBook1 = Book(
    id: 'book-1',
    title: 'Clean Architecture',
    author: 'Robert C. Martin',
    description: 'A Craftsman\'s Guide to Software Structure and Design.',
    category: 'Software Engineering',
    publishedYear: 2017,
    isbn: '978-0134494166',
    isAvailable: true,
    totalCopies: 3,
    availableCopies: 2,
  );

  final sampleBook2 = Book(
    id: 'book-2',
    title: 'Design Patterns',
    author: 'Erich Gamma, Richard Helm, Ralph Johnson, John Vlissides',
    description: 'Elements of Reusable Object-Oriented Software.',
    category: 'Computer Science',
    publishedYear: 1994,
    isbn: '978-0201633610',
    isAvailable: false,
    totalCopies: 2,
    availableCopies: 0,
  );

  final sampleBook3 = Book(
    id: 'book-3',
    title: 'Flutter in Action',
    author: 'Eric Windmill',
    description: 'Teaches you to build beautiful modern mobile applications.',
    category: 'Mobile Development',
    publishedYear: 2020,
    isbn: '978-1617296147',
    isAvailable: true,
    totalCopies: 5,
    availableCopies: 5,
  );

  group('Book Model Unit Tests', () {
    test('Correctly serializes to and from Firestore map', () {
      final map = sampleBook1.toFirestore();
      expect(map['title'], 'Clean Architecture');
      expect(map['author'], 'Robert C. Martin');
      expect(
        map['description'],
        'A Craftsman\'s Guide to Software Structure and Design.',
      );
      expect(map['category'], 'Software Engineering');
      expect(map['publishedYear'], 2017);
      expect(map['isbn'], '978-0134494166');
      expect(map['isAvailable'], true);
      expect(map['totalCopies'], 3);
      expect(map['availableCopies'], 2);

      final fromMap = Book.fromFirestore(map, 'book-1');
      expect(fromMap, equals(sampleBook1));
    });

    test('Handles null optional fields in fromFirestore gracefully', () {
      final minimalMap = <String, dynamic>{
        'title': 'Minimal Book',
        'author': 'Author Name',
        'description': 'Short description',
      };
      final book = Book.fromFirestore(minimalMap, 'min-1');
      expect(book.id, 'min-1');
      expect(book.title, 'Minimal Book');
      expect(book.author, 'Author Name');
      expect(book.description, 'Short description');
      expect(book.imageUrl, isNull);
      expect(book.isbn, isNull);
      expect(book.category, isNull);
      expect(book.publishedYear, isNull);
      expect(book.isAvailable, isTrue);
      expect(book.totalCopies, 1);
      expect(book.availableCopies, 1);
    });

    test('copyWith updates properties properly', () {
      final updated = sampleBook1.copyWith(
        title: 'Clean Architecture 2nd Edition',
        availableCopies: 1,
      );
      expect(updated.title, 'Clean Architecture 2nd Edition');
      expect(updated.availableCopies, 1);
      expect(updated.author, sampleBook1.author);
      expect(updated.id, sampleBook1.id);
    });
  });

  group('BookCard Widget Tests', () {
    testWidgets('Renders book title, author, description, and status chip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BookCard(book: sampleBook1)),
        ),
      );

      expect(find.text('Clean Architecture'), findsWidgets);
      expect(find.text('Robert C. Martin'), findsOneWidget);
      expect(
        find.text('A Craftsman\'s Guide to Software Structure and Design.'),
        findsOneWidget,
      );
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Software Engineering'), findsOneWidget);
    });

    testWidgets('Renders Checked Out badge when book unavailable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BookCard(book: sampleBook2)),
        ),
      );

      expect(find.text('Design Patterns'), findsWidgets);
      expect(find.text('Checked Out'), findsOneWidget);
    });

    testWidgets('Tapping BookCard triggers onTap callback', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(book: sampleBook1, onTap: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.byType(BookCard));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('BookDetailsScreen Widget Tests', () {
    testWidgets('Renders all book details, metadata, and synopsis', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BookDetailsScreen(book: sampleBook1)),
      );

      expect(find.text('Clean Architecture'), findsWidgets);
      expect(find.text('Robert C. Martin'), findsOneWidget);
      expect(find.text('Available (2 of 3 copies)'), findsOneWidget);
      expect(find.text('Genre'), findsOneWidget);
      expect(find.text('Software Engineering'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('2017'), findsOneWidget);
      expect(find.text('ISBN'), findsOneWidget);
      expect(find.text('978-0134494166'), findsOneWidget);
      expect(find.text('Total Copies'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(
        find.text('A Craftsman\'s Guide to Software Structure and Design.'),
        findsOneWidget,
      );
    });

    testWidgets('Renders unavailable status badge on details screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BookDetailsScreen(book: sampleBook2)),
      );

      expect(
        find.text('Currently Unavailable (0 of 2 copies)'),
        findsOneWidget,
      );
    });
  });

  group('BookCatalogScreen Widget Tests', () {
    testWidgets('Shows loading state while stream is waiting', (
      WidgetTester tester,
    ) async {
      final controller = StreamController<List<Book>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(home: BookCatalogScreen(booksStream: controller.stream)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading catalog...'), findsOneWidget);
    });

    testWidgets('Shows error state with retry button when stream errors', (
      WidgetTester tester,
    ) async {
      final controller = StreamController<List<Book>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(home: BookCatalogScreen(booksStream: controller.stream)),
      );

      controller.addError(Exception('Network timeout'));
      await tester.pump();

      expect(find.text('Failed to load book catalog'), findsOneWidget);
      expect(find.byKey(const Key('catalog_retry_btn')), findsOneWidget);
    });

    testWidgets('Shows empty state when no books exist in catalog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookCatalogScreen(booksStream: Stream.value(<Book>[])),
        ),
      );
      await tester.pump();

      expect(find.text('No Books Available'), findsOneWidget);
      expect(
        find.text(
          'The library catalog is currently empty.\nNew titles will appear here once added.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Renders populated list of books', (WidgetTester tester) async {
      final books = [sampleBook1, sampleBook2, sampleBook3];

      await tester.pumpWidget(
        MaterialApp(home: BookCatalogScreen(booksStream: Stream.value(books))),
      );
      await tester.pump();

      expect(find.text('All Books (3)'), findsOneWidget);
      expect(find.text('Clean Architecture'), findsWidgets);
      expect(find.text('Design Patterns'), findsWidgets);
      expect(find.text('Flutter in Action'), findsWidgets);
    });

    testWidgets('Filters books by title search query', (
      WidgetTester tester,
    ) async {
      final books = [sampleBook1, sampleBook2, sampleBook3];

      await tester.pumpWidget(
        MaterialApp(home: BookCatalogScreen(booksStream: Stream.value(books))),
      );
      await tester.pump();

      // Enter search query for "flutter"
      await tester.enterText(
        find.byKey(const Key('catalog_search_field')),
        'flutter',
      );
      await tester.pump();

      expect(find.text('Found 1 matching books'), findsOneWidget);
      expect(find.text('Flutter in Action'), findsWidgets);
      expect(find.text('Clean Architecture'), findsNothing);
      expect(find.text('Design Patterns'), findsNothing);
    });

    testWidgets('Filters books by author search query', (
      WidgetTester tester,
    ) async {
      final books = [sampleBook1, sampleBook2, sampleBook3];

      await tester.pumpWidget(
        MaterialApp(home: BookCatalogScreen(booksStream: Stream.value(books))),
      );
      await tester.pump();

      // Search by author name "Robert"
      await tester.enterText(
        find.byKey(const Key('catalog_search_field')),
        'Robert',
      );
      await tester.pump();

      expect(find.text('Found 1 matching books'), findsOneWidget);
      expect(find.text('Clean Architecture'), findsWidgets);
      expect(find.text('Flutter in Action'), findsNothing);
    });

    testWidgets('Shows empty search state and clears search on button tap', (
      WidgetTester tester,
    ) async {
      final books = [sampleBook1, sampleBook2];

      await tester.pumpWidget(
        MaterialApp(home: BookCatalogScreen(booksStream: Stream.value(books))),
      );
      await tester.pump();

      // Search for non-existing query
      await tester.enterText(
        find.byKey(const Key('catalog_search_field')),
        'NonExistentBookXYZ',
      );
      await tester.pump();

      expect(find.text('No matching books found'), findsOneWidget);
      expect(find.byKey(const Key('catalog_empty_clear_btn')), findsOneWidget);

      // Tap clear search button
      await tester.tap(find.byKey(const Key('catalog_empty_clear_btn')));
      await tester.pump();

      expect(find.text('All Books (2)'), findsOneWidget);
      expect(find.text('Clean Architecture'), findsWidgets);
      expect(find.text('Design Patterns'), findsWidgets);
    });

    testWidgets('Tapping book card navigates to BookDetailsScreen', (
      WidgetTester tester,
    ) async {
      final books = [sampleBook1];

      await tester.pumpWidget(
        MaterialApp(home: BookCatalogScreen(booksStream: Stream.value(books))),
      );
      await tester.pump();

      // Tap the book card
      await tester.tap(find.byKey(Key('book_card_${sampleBook1.id}')));
      await tester.pumpAndSettle();

      // Verify BookDetailsScreen is opened
      expect(find.byType(BookDetailsScreen), findsOneWidget);
      expect(find.text('Book Information'), findsOneWidget);
      expect(find.text('Synopsis & Description'), findsOneWidget);
      expect(find.text('Robert C. Martin'), findsOneWidget);
    });
  });

  group('HomeScreen to Book Catalog Navigation Tests', () {
    testWidgets('Tapping Books card on HomeScreen opens BookCatalogScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      // Tap Books Quick Access card
      await tester.tap(find.text('Books'));
      await tester.pumpAndSettle();

      // Verify BookCatalogScreen is opened
      expect(find.byType(BookCatalogScreen), findsOneWidget);
      expect(find.text('Book Catalog'), findsOneWidget);
    });
  });
}
