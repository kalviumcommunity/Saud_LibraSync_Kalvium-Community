import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:librasync/firebase_options.dart';

/// Seed script for populating Cloud Firestore with initial branches, books, and book copies.
///
/// Usage:
///   flutter run tool/seed_firestore.dart -d [device]
///   or invoke `seedFirestoreData()` in debug mode.
///
/// NOTE: Confirm target project in firebase_options.dart before running against production.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  stdout.writeln('========================================');
  stdout.writeln('  LibraSync Firestore Seeder Script');
  stdout.writeln('========================================');
  stdout.writeln('Connecting to Firebase...');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  await seedFirestoreData(firestore);

  stdout.writeln('\n========================================');
  stdout.writeln('  BOOTSTRAP INSTRUCTIONS FOR STAFF ROLE');
  stdout.writeln('========================================');
  stdout.writeln('1. Open Firebase Console -> Authentication -> Users.');
  stdout.writeln('2. Sign up a new user via the app (defaults to role: "member").');
  stdout.writeln('3. Open Cloud Firestore -> users collection -> find the user document by UID.');
  stdout.writeln('4. Update the "role" field from "member" to "staff" (or "admin").');
  stdout.writeln('5. Restart or re-authenticate in the app to access staff features.');
  stdout.writeln('========================================\n');

  exit(0);
}

/// Populates branches, books, and book copies in Firestore.
Future<void> seedFirestoreData(FirebaseFirestore firestore) async {
  final branchesColl = firestore.collection('branches');
  final booksColl = firestore.collection('books');
  final copiesColl = firestore.collection('bookCopies');

  stdout.writeln('Seeding 3 Branches...');
  final branches = [
    {
      'id': 'branch_central',
      'name': 'Central Branch',
      'address': '100 Library Way, City Center',
    },
    {
      'id': 'branch_northside',
      'name': 'Northside Branch',
      'address': '450 North Blvd, Uptown District',
    },
    {
      'id': 'branch_downtown',
      'name': 'Downtown Branch',
      'address': '220 Market St, Downtown',
    },
  ];

  for (final b in branches) {
    await branchesColl.doc(b['id']).set({
      'name': b['name'],
      'address': b['address'],
    });
    stdout.writeln('  ✓ Added branch: ${b['name']} (${b['id']})');
  }

  stdout.writeln('\nSeeding Books and Book Copies...');
  final books = [
    {
      'id': 'book_project_hail_mary',
      'title': 'Project Hail Mary',
      'author': 'Andy Weir',
      'genre': 'Sci-Fi',
      'description': 'A lone astronaut must save the earth from disaster.',
      'publicationYear': 2021,
      'pages': 496,
      'rating': 4.8,
      'totalCopies': 3,
      'availableCopies': 3,
      'copies': [
        {'copyId': 'copy_phm_1', 'branchId': 'branch_central', 'barcode': 'PHM-1001'},
        {'copyId': 'copy_phm_2', 'branchId': 'branch_northside', 'barcode': 'PHM-1002'},
        {'copyId': 'copy_phm_3', 'branchId': 'branch_downtown', 'barcode': 'PHM-1003'},
      ],
    },
    {
      'id': 'book_atomic_habits',
      'title': 'Atomic Habits',
      'author': 'James Clear',
      'genre': 'Self-Help',
      'description': 'An easy and proven way to build good habits and break bad ones.',
      'publicationYear': 2018,
      'pages': 320,
      'rating': 4.9,
      'totalCopies': 3,
      'availableCopies': 3,
      'copies': [
        {'copyId': 'copy_ah_1', 'branchId': 'branch_central', 'barcode': 'AH-2001'},
        {'copyId': 'copy_ah_2', 'branchId': 'branch_central', 'barcode': 'AH-2002'},
        {'copyId': 'copy_ah_3', 'branchId': 'branch_northside', 'barcode': 'AH-2003'},
      ],
    },
    {
      'id': 'book_great_gatsby',
      'title': 'The Great Gatsby',
      'author': 'F. Scott Fitzgerald',
      'genre': 'Fiction',
      'description': 'A portrait of the Jazz Age and the tragic story of Jay Gatsby.',
      'publicationYear': 1925,
      'pages': 180,
      'rating': 4.4,
      'totalCopies': 2,
      'availableCopies': 2,
      'copies': [
        {'copyId': 'copy_gg_1', 'branchId': 'branch_central', 'barcode': 'GG-3001'},
        {'copyId': 'copy_gg_2', 'branchId': 'branch_downtown', 'barcode': 'GG-3002'},
      ],
    },
    {
      'id': 'book_the_hobbit',
      'title': 'The Hobbit',
      'author': 'J.R.R. Tolkien',
      'genre': 'Fantasy',
      'description': 'Bilbo Baggins journeys with dwarves and wizard Gandalf to reclaim a mountain kingdom.',
      'publicationYear': 1937,
      'pages': 310,
      'rating': 4.7,
      'totalCopies': 3,
      'availableCopies': 3,
      'copies': [
        {'copyId': 'copy_th_1', 'branchId': 'branch_central', 'barcode': 'TH-4001'},
        {'copyId': 'copy_th_2', 'branchId': 'branch_northside', 'barcode': 'TH-4002'},
        {'copyId': 'copy_th_3', 'branchId': 'branch_downtown', 'barcode': 'TH-4003'},
      ],
    },
    {
      'id': 'book_dune',
      'title': 'Dune',
      'author': 'Frank Herbert',
      'genre': 'Sci-Fi',
      'description': 'Set on the desert planet Arrakis, a sweeping epic of adventure, politics, and mysticism.',
      'publicationYear': 1965,
      'pages': 688,
      'rating': 4.6,
      'totalCopies': 3,
      'availableCopies': 3,
      'copies': [
        {'copyId': 'copy_du_1', 'branchId': 'branch_central', 'barcode': 'DU-5001'},
        {'copyId': 'copy_du_2', 'branchId': 'branch_northside', 'barcode': 'DU-5002'},
        {'copyId': 'copy_du_3', 'branchId': 'branch_downtown', 'barcode': 'DU-5003'},
      ],
    },
    {
      'id': 'book_midnight_library',
      'title': 'The Midnight Library',
      'author': 'Matt Haig',
      'genre': 'Fiction',
      'description': 'Between life and death there is a library containing infinite books of different choices.',
      'publicationYear': 2020,
      'pages': 304,
      'rating': 4.5,
      'totalCopies': 2,
      'availableCopies': 2,
      'copies': [
        {'copyId': 'copy_ml_1', 'branchId': 'branch_central', 'barcode': 'ML-6001'},
        {'copyId': 'copy_ml_2', 'branchId': 'branch_northside', 'barcode': 'ML-6002'},
      ],
    },
    {
      'id': 'book_klara_and_the_sun',
      'title': 'Klara and the Sun',
      'author': 'Kazuo Ishiguro',
      'genre': 'Sci-Fi',
      'description': 'The story of Klara, an Artificial Friend with outstanding observational qualities.',
      'publicationYear': 2021,
      'pages': 320,
      'rating': 4.3,
      'totalCopies': 2,
      'availableCopies': 2,
      'copies': [
        {'copyId': 'copy_ks_1', 'branchId': 'branch_downtown', 'barcode': 'KS-7001'},
        {'copyId': 'copy_ks_2', 'branchId': 'branch_northside', 'barcode': 'KS-7002'},
      ],
    },
    {
      'id': 'book_braiding_sweetgrass',
      'title': 'Braiding Sweetgrass',
      'author': 'Robin Wall Kimmerer',
      'genre': 'Nature',
      'description': 'Indigenous wisdom, scientific knowledge, and the teachings of plants.',
      'publicationYear': 2013,
      'pages': 390,
      'rating': 4.9,
      'totalCopies': 2,
      'availableCopies': 2,
      'copies': [
        {'copyId': 'copy_bs_1', 'branchId': 'branch_central', 'barcode': 'BS-8001'},
        {'copyId': 'copy_bs_2', 'branchId': 'branch_downtown', 'barcode': 'BS-8002'},
      ],
    },
  ];

  for (final book in books) {
    final bookId = book['id'] as String;
    final totalCopies = book['totalCopies'] as int;
    final availableCopies = book['availableCopies'] as int;

    await booksColl.doc(bookId).set({
      'title': book['title'],
      'author': book['author'],
      'genre': book['genre'],
      'description': book['description'],
      'publicationYear': book['publicationYear'],
      'pages': book['pages'],
      'rating': book['rating'],
      'totalCopies': totalCopies,
      'availableCopies': availableCopies,
      'isAvailable': availableCopies > 0,
    });
    stdout.writeln('  ✓ Added book: ${book['title']} ($bookId)');

    final copies = book['copies'] as List<Map<String, String>>;
    for (final c in copies) {
      await copiesColl.doc(c['copyId']).set({
        'bookId': bookId,
        'branchId': c['branchId'],
        'status': 'available',
        'barcode': c['barcode'],
      });
      stdout.writeln('    - Copy: ${c['barcode']} at ${c['branchId']}');
    }
  }

  stdout.writeln('\nDatabase seeding completed successfully!');
}
