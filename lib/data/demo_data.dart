import '../models/book.dart';
import '../models/book_copy.dart';
import '../models/branch.dart';

/// Static demo dataset for branches, books, and book copies.
///
/// Used in place of Firestore writes/streams for branches, catalog books,
/// and physical inventory copies.
abstract final class DemoData {
  // ── 4 Branches ─────────────────────────────────────────────────────────────
  static const List<Branch> branches = [
    Branch(
      id: 'branch_central',
      name: 'Central Branch',
      address: '100 Library Way, City Center',
      phone: '(555) 010-1000',
    ),
    Branch(
      id: 'branch_northside',
      name: 'Northside Branch',
      address: '450 North Blvd, Uptown District',
      phone: '(555) 010-2000',
    ),
    Branch(
      id: 'branch_downtown',
      name: 'Downtown Branch',
      address: '220 Market St, Downtown',
      phone: '(555) 010-3000',
    ),
    Branch(
      id: 'branch_eastside',
      name: 'Eastside Branch',
      address: '780 East River Rd, Waterfront',
      phone: '(555) 010-4000',
    ),
  ];

  // ── 7 Books ────────────────────────────────────────────────────────────────
  static const List<Book> books = [
    Book(
      id: 'book_project_hail_mary',
      title: 'Project Hail Mary',
      author: 'Andy Weir',
      description:
          'A lone astronaut must save Earth from an extinction-level catastrophe in this thrilling space adventure.',
      category: 'Sci-Fi',
      isbn: '978-0593135204',
      publishedYear: 2021,
      totalCopies: 3,
      availableCopies: 3,
      isAvailable: true,
    ),
    Book(
      id: 'book_atomic_habits',
      title: 'Atomic Habits',
      author: 'James Clear',
      description:
          'An easy and proven way to build good habits and break bad ones with actionable strategies.',
      category: 'Self-Help',
      isbn: '978-0735211292',
      publishedYear: 2018,
      totalCopies: 3,
      availableCopies: 3,
      isAvailable: true,
    ),
    Book(
      id: 'book_great_gatsby',
      title: 'The Great Gatsby',
      author: 'F. Scott Fitzgerald',
      description:
          'A portrait of the Jazz Age exploring obsession, wealth, and the elusive American Dream.',
      category: 'Classic',
      isbn: '978-0743273565',
      publishedYear: 1925,
      totalCopies: 2,
      availableCopies: 2,
      isAvailable: true,
    ),
    Book(
      id: 'book_the_hobbit',
      title: 'The Hobbit',
      author: 'J.R.R. Tolkien',
      description:
          'Bilbo Baggins journeys with dwarves and the wizard Gandalf to reclaim a mountain kingdom from Smaug.',
      category: 'Fantasy',
      isbn: '978-0547928227',
      publishedYear: 1937,
      totalCopies: 3,
      availableCopies: 3,
      isAvailable: true,
    ),
    Book(
      id: 'book_dune',
      title: 'Dune',
      author: 'Frank Herbert',
      description:
          'Set on the desert planet Arrakis, a sweeping epic of adventure, politics, religion, and mysticism.',
      category: 'Sci-Fi',
      isbn: '978-0441172719',
      publishedYear: 1965,
      totalCopies: 3,
      availableCopies: 3,
      isAvailable: true,
    ),
    Book(
      id: 'book_midnight_library',
      title: 'The Midnight Library',
      author: 'Matt Haig',
      description:
          'Between life and death lies a library containing infinite books of different choices and possibilities.',
      category: 'Fiction',
      isbn: '978-0525559474',
      publishedYear: 2020,
      totalCopies: 2,
      availableCopies: 2,
      isAvailable: true,
    ),
    Book(
      id: 'book_klara_and_the_sun',
      title: 'Klara and the Sun',
      author: 'Kazuo Ishiguro',
      description:
          'The story of Klara, an Artificial Friend with extraordinary observational qualities exploring what it means to love.',
      category: 'Sci-Fi',
      isbn: '978-0593318171',
      publishedYear: 2021,
      totalCopies: 2,
      availableCopies: 2,
      isAvailable: true,
    ),
  ];

  // ── 18 Physical Book Copies across 4 Branches ──────────────────────────────
  static const List<BookCopy> bookCopies = [
    // Project Hail Mary (3 copies)
    BookCopy(
      id: 'copy_phm_1',
      bookId: 'book_project_hail_mary',
      branchId: 'branch_central',
      barcode: 'PHM-1001',
      condition: 'Excellent',
      status: BookCopy.statusAvailable,
    ),
    BookCopy(
      id: 'copy_phm_2',
      bookId: 'book_project_hail_mary',
      branchId: 'branch_northside',
      barcode: 'PHM-1002',
      condition: 'Good',
      status: BookCopy.statusAvailable,
    ),
    BookCopy(
      id: 'copy_phm_3',
      bookId: 'book_project_hail_mary',
      branchId: 'branch_eastside',
      barcode: 'PHM-1003',
      condition: 'New',
      status: BookCopy.statusAvailable,
    ),

    // Atomic Habits (3 copies)
    BookCopy(
      id: 'copy_ah_1',
      bookId: 'book_atomic_habits',
      branchId: 'branch_central',
      barcode: 'AH-2001',
      condition: 'Good',
      status: BookCopy.statusAvailable,
    ),
    BookCopy(
      id: 'copy_ah_2',
      bookId: 'book_atomic_habits',
      branchId: 'branch_downtown',
      barcode: 'AH-2002',
      condition: 'Excellent',
      status: BookCopy.statusAvailable,
    ),
    BookCopy(
      id: 'copy_ah_3',
      bookId: 'book_atomic_habits',
      branchId: 'branch_northside',
      barcode: 'AH-2003',
      condition: 'New',
      status: BookCopy.statusAvailable,
    ),

    // The Great Gatsby (2 copies)
    BookCopy(
      id: 'copy_gg_1',
      bookId: 'book_great_gatsby',
      branchId: 'branch_central',
      barcode: 'GG-3001',
      condition: 'Fair',
      status: BookCopy.statusAvailable,
    ),
    BookCopy(
      id: 'copy_gg_2',
      bookId: 'book_great_gatsby',
      branchId: 'branch_eastside',
      barcode: 'GG-3002',
      condition: 'Good',
      status: BookCopy.statusAvailable,
    ),

    // The Hobbit (3 copies)
    BookCopy(
      id: 'copy_th_1',
      bookId: 'book_the_hobbit',
      branchId: 'branch_central',
      barcode: 'TH-4001',
      condition: 'Excellent',
      status: BookCopy.statusAvailable,
    ),
    BookCopy(
      id: 'copy_th_2',
      bookId: 'book_the_hobbit',
      branchId: 'branch_northside',
      barcode: 'TH-4002',
      condition: 'Good',
      status: BookCopy.statusAvailable,
    ),
    BookCopy(
      id: 'copy_th_3',
      bookId: 'book_the_hobbit',
      branchId: 'branch_downtown',
      barcode: 'TH-4003',
      condition: 'New',
      status: BookCopy.statusAvailable,
    ),

    // Dune (3 copies)
    BookCopy(
      id: 'copy_du_1',
      bookId: 'book_dune',
      branchId: 'branch_central',
      barcode: 'DU-5001',
      condition: 'New',
      status: BookCopy.statusAvailable,
    ),
    BookCopy(
      id: 'copy_du_2',
      bookId: 'book_dune',
      branchId: 'branch_northside',
      barcode: 'DU-5002',
      condition: 'Good',
      status: BookCopy.statusAvailable,
    ),
    BookCopy(
      id: 'copy_du_3',
      bookId: 'book_dune',
      branchId: 'branch_downtown',
      barcode: 'DU-5003',
      condition: 'Excellent',
      status: BookCopy.statusAvailable,
    ),

    // The Midnight Library (2 copies)
    BookCopy(
      id: 'copy_ml_1',
      bookId: 'book_midnight_library',
      branchId: 'branch_downtown',
      barcode: 'ML-6001',
      condition: 'Good',
      status: BookCopy.statusAvailable,
    ),
    BookCopy(
      id: 'copy_ml_2',
      bookId: 'book_midnight_library',
      branchId: 'branch_eastside',
      barcode: 'ML-6002',
      condition: 'New',
      status: BookCopy.statusAvailable,
    ),

    // Klara and the Sun (2 copies)
    BookCopy(
      id: 'copy_ks_1',
      bookId: 'book_klara_and_the_sun',
      branchId: 'branch_eastside',
      barcode: 'KS-7001',
      condition: 'New',
      status: BookCopy.statusAvailable,
    ),
    BookCopy(
      id: 'copy_ks_2',
      bookId: 'book_klara_and_the_sun',
      branchId: 'branch_northside',
      barcode: 'KS-7002',
      condition: 'Good',
      status: BookCopy.statusAvailable,
    ),
  ];
}

/// Top-level convenience accessors.
const demoBranches = DemoData.branches;
const demoBooks = DemoData.books;
const demoBookCopies = DemoData.bookCopies;
