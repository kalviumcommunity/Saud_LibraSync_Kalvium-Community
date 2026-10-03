import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../repositories/book_repository.dart';
import '../repositories/book_copy_repository.dart';
import 'auth_providers.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(firestore: ref.watch(firestoreProvider));
});

final bookCopyRepositoryProvider = Provider<BookCopyRepository>((ref) {
  return BookCopyRepository(firestore: ref.watch(firestoreProvider));
});

final booksStreamProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(bookRepositoryProvider).streamBooks();
});

final catalogSearchQueryProvider = StateProvider<String>((ref) => '');

final catalogSelectedCategoryProvider = StateProvider<String>((ref) => 'All Genres');

final catalogSelectedBranchProvider = StateProvider<String>((ref) => 'All Branches');

final catalogAvailableOnlyProvider = StateProvider<bool>((ref) => false);

final catalogSortByProvider = StateProvider<String>((ref) => 'Popularity');

final catalogViewModeProvider = StateProvider<bool>((ref) => true); // true = grid, false = list

final filteredBooksProvider = Provider<List<Book>>((ref) {
  final asyncBooks = ref.watch(booksStreamProvider);
  final books = asyncBooks.value ?? [];
  final query = ref.watch(catalogSearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(catalogSelectedCategoryProvider);
  final availableOnly = ref.watch(catalogAvailableOnlyProvider);

  return books.where((b) {
    if (query.isNotEmpty) {
      final matchesTitle = b.title.toLowerCase().contains(query);
      final matchesAuthor = b.author.toLowerCase().contains(query);
      final matchesIsbn = b.isbn?.toLowerCase().contains(query) ?? false;
      final matchesCategory = b.category?.toLowerCase().contains(query) ?? false;
      if (!matchesTitle && !matchesAuthor && !matchesIsbn && !matchesCategory) {
        return false;
      }
    }

    if (category != 'All Genres' && category != 'All Categories') {
      if (b.category?.toLowerCase() != category.toLowerCase()) {
        return false;
      }
    }

    if (availableOnly && (!b.isAvailable || b.availableCopies <= 0)) {
      return false;
    }

    return true;
  }).toList();
});
