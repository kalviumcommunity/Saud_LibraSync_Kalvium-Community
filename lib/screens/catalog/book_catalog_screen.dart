import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../services/book_service.dart';
import '../../services/circulation_service.dart';
import '../../widgets/book_card.dart';
import '../../widgets/catalog/book_form_dialog.dart';
import 'book_details_screen.dart';

/// Screen displaying the library's Book Catalog with real-time Firestore updates,
/// responsive grid/list layout, search by title and author, staff book addition, and comprehensive state handling.
class BookCatalogScreen extends StatefulWidget {
  const BookCatalogScreen({
    super.key,
    this.bookService,
    this.circulationService,
    this.booksStream,
    this.isStaff,
  });

  /// Optional custom book service instance.
  final BookService? bookService;

  /// Optional custom circulation service instance.
  final CirculationService? circulationService;

  /// Optional custom stream of books (useful for testing or customized queries).
  final Stream<List<Book>>? booksStream;

  /// Optional staff status override (useful for testing or direct permission pass-through).
  final bool? isStaff;

  @override
  State<BookCatalogScreen> createState() => _BookCatalogScreenState();
}

class _BookCatalogScreenState extends State<BookCatalogScreen> {
  late Stream<List<Book>> _stream;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Key _streamKey = UniqueKey();
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    _initStream();
    _checkStaffStatus();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant BookCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStaff != oldWidget.isStaff ||
        widget.bookService != oldWidget.bookService) {
      _checkStaffStatus();
    }
    if (widget.booksStream != oldWidget.booksStream ||
        widget.bookService != oldWidget.bookService) {
      _initStream();
    }
  }

  Future<void> _checkStaffStatus() async {
    if (widget.isStaff != null) {
      if (mounted) setState(() => _isStaff = widget.isStaff!);
      return;
    }
    final service = widget.bookService ?? BookService();
    final staff = await service.isCurrentUserStaff();
    if (mounted) {
      setState(() => _isStaff = staff);
    }
  }

  void _initStream() {
    if (widget.booksStream != null) {
      _stream = widget.booksStream!;
    } else {
      final service = widget.bookService ?? BookService();
      _stream = service.streamBooks();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  void _retryStream() {
    setState(() {
      _streamKey = UniqueKey();
      _initStream();
    });
  }

  Future<void> _openAddBookDialog() async {
    final createdBook = await BookFormDialog.show(
      context,
      bookService: widget.bookService,
    );

    if (createdBook != null && mounted) {
      _retryStream();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${createdBook.title}" added to catalog successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Book> _filterBooks(List<Book> books) {
    if (_searchQuery.isEmpty) return books;
    final lowerQuery = _searchQuery.toLowerCase();
    return books.where((book) {
      final matchesTitle = book.title.toLowerCase().contains(lowerQuery);
      final matchesAuthor = book.author.toLowerCase().contains(lowerQuery);
      return matchesTitle || matchesAuthor;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Catalog'),
        actions: [
          if (_isStaff)
            IconButton(
              key: const Key('catalog_add_book_btn'),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Book',
              onPressed: _openAddBookDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _retryStream,
          ),
        ],
      ),
      floatingActionButton: _isStaff
          ? FloatingActionButton.extended(
              key: const Key('catalog_add_book_fab'),
              onPressed: _openAddBookDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Book'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search Bar Section ─────────────────────────────────────
            _buildSearchHeader(colorScheme, theme),

            // ── Main Content Stream ────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<Book>>(
                key: _streamKey,
                stream: _stream,
                builder: (context, snapshot) {
                  // ── Loading State ────────────────────────────────────
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _CatalogLoadingView();
                  }

                  // ── Error State ──────────────────────────────────────
                  if (snapshot.hasError) {
                    return _CatalogErrorView(
                      error: snapshot.error.toString(),
                      onRetry: _retryStream,
                    );
                  }

                  final allBooks = snapshot.data ?? [];

                  // ── Empty Catalog State (no books in Firestore) ───────
                  if (allBooks.isEmpty) {
                    return _CatalogEmptyView(
                      isStaff: _isStaff,
                      onAddBook: _openAddBookDialog,
                    );
                  }

                  // Filter books based on search query
                  final filteredBooks = _filterBooks(allBooks);

                  // ── Empty Search Results State ───────────────────────
                  if (filteredBooks.isEmpty && _searchQuery.isNotEmpty) {
                    return _NoSearchResultsView(
                      query: _searchQuery,
                      onClear: _clearSearch,
                    );
                  }

                  // ── Populated Catalog View ───────────────────────────
                  return _CatalogGridView(
                    books: filteredBooks,
                    totalCount: allBooks.length,
                    isFiltered: _searchQuery.isNotEmpty,
                    onBookTap: (book) async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => BookDetailsScreen(
                            book: book,
                            bookService: widget.bookService,
                            circulationService: widget.circulationService,
                            isStaff: _isStaff,
                          ),
                        ),
                      );

                      if ((result == true || _isStaff) && mounted) {
                        _retryStream();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: TextField(
            key: const Key('catalog_search_field'),
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by title or author...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      key: const Key('catalog_clear_search_btn'),
                      icon: const Icon(Icons.clear_rounded),
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Responsive Populated Grid View ──────────────────────────────────────────

class _CatalogGridView extends StatelessWidget {
  const _CatalogGridView({
    required this.books,
    required this.totalCount,
    required this.isFiltered,
    required this.onBookTap,
  });

  final List<Book> books;
  final int totalCount;
  final bool isFiltered;
  final void Function(Book book) onBookTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive column count based on available width
            final width = constraints.maxWidth;
            final int crossAxisCount;
            if (width >= 1000) {
              crossAxisCount = 3;
            } else if (width >= 620) {
              crossAxisCount = 2;
            } else {
              crossAxisCount = 1;
            }

            return CustomScrollView(
              slivers: [
                // Header summary text
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isFiltered
                              ? 'Found ${books.length} matching books'
                              : 'All Books ($totalCount)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Responsive Book Grid / List
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 168,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final book = books[index];
                      return BookCard(
                        key: Key('book_card_${book.id}'),
                        book: book,
                        onTap: () => onBookTap(book),
                      );
                    }, childCount: books.length),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── State Views ─────────────────────────────────────────────────────────────

/// View displayed when loading book catalog data.
class _CatalogLoadingView extends StatelessWidget {
  const _CatalogLoadingView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading catalog...',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// View displayed when an error occurs while fetching books.
class _CatalogErrorView extends StatelessWidget {
  const _CatalogErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load book catalog',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your network connection and try again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('catalog_retry_btn'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// View displayed when no books exist in the entire library.
class _CatalogEmptyView extends StatelessWidget {
  const _CatalogEmptyView({this.isStaff = false, this.onAddBook});

  final bool isStaff;
  final VoidCallback? onAddBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withAlpha(140),
            ),
            const SizedBox(height: 16),
            Text(
              'No Books Available',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The library catalog is currently empty.\nNew titles will appear here once added.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (isStaff && onAddBook != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('catalog_empty_add_book_btn'),
                onPressed: onAddBook,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add First Book'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// View displayed when search query yields 0 results.
class _NoSearchResultsView extends StatelessWidget {
  const _NoSearchResultsView({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: colorScheme.onSurfaceVariant.withAlpha(140),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching books found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No results for "$query". Try searching for a different title or author.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('catalog_empty_clear_btn'),
              onPressed: onClear,
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Clear Search'),
            ),
          ],
        ),
      ),
    );
  }
}
