import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo_data.dart';
import '../../models/book.dart';
import '../../providers/book_providers.dart';
import '../../theme/app_colors.dart';
import 'book_details_screen.dart';

/// Member Book Catalog screen matching Mockup 10.
class MemberBookCatalogView extends ConsumerStatefulWidget {
  const MemberBookCatalogView({
    super.key,
    this.booksStream,
  });

  final Stream<List<Book>>? booksStream;

  @override
  ConsumerState<MemberBookCatalogView> createState() => _MemberBookCatalogViewState();
}

class _MemberBookCatalogViewState extends ConsumerState<MemberBookCatalogView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = true;
  String _selectedGenre = 'All Genres';
  bool _availableOnly = false;
  String _selectedBranch = 'Central';
  String _sortBy = 'Popularity';

  final List<String> _genres = [
    'All Genres',
    'Sci-Fi',
    'Self-Help',
    'Fiction',
    'Fantasy',
    'Classic',
    'Nature',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncBooks = ref.watch(booksStreamProvider);
    final books = asyncBooks.value ?? [];
    final query = _searchController.text.trim().toLowerCase();

    final filtered = books.where((b) {
      if (query.isNotEmpty) {
        final matches = b.title.toLowerCase().contains(query) ||
            b.author.toLowerCase().contains(query) ||
            (b.isbn?.toLowerCase().contains(query) ?? false);
        if (!matches) return false;
      }
      if (_selectedGenre != 'All Genres') {
        if (b.category?.toLowerCase() != _selectedGenre.toLowerCase()) {
          return false;
        }
      }
      if (_availableOnly && (!b.isAvailable || b.availableCopies <= 0)) {
        return false;
      }
      return true;
    }).toList();

    // Standard demo books if none loaded yet
    final displayBooks = filtered.isNotEmpty
        ? filtered
        : (query.isEmpty && _selectedGenre == 'All Genres' && !_availableOnly
            ? demoBooks
            : <Book>[]);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.pillPurpleBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_library_rounded, color: AppColors.primaryPurple, size: 20),
        ),
        title: const Text(
          'LibraSync',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.pillPurpleBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Live Shelf',
              style: TextStyle(
                color: AppColors.primaryPurple,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Book Catalog',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Search Bar + Filter Icon
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search title, author, ISBN...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.tune_rounded, color: AppColors.primaryPurple),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Genre dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGenre,
                          dropdownColor: AppColors.primaryPurpleDark,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          items: _genres.map((g) {
                            return DropdownMenuItem(value: g, child: Text(g));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedGenre = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Available Filter Chip
                    GestureDetector(
                      onTap: () => setState(() => _availableOnly = !_availableOnly),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _availableOnly ? AppColors.statusGreenBg : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _availableOnly ? AppColors.statusGreen : AppColors.cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: _availableOnly ? AppColors.statusGreen : AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              'Available',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _availableOnly ? AppColors.statusGreen : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Branch Dropdown Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedBranch,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Browse Count, Popularity, Grid/List view toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Browse ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.pillPurpleBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${displayBooks.length} Results',
                          style: const TextStyle(color: AppColors.primaryPurple, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Text(_sortBy, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(width: 4),
                            const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Grid / List toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.grid_view_rounded,
                                size: 18,
                                color: _isGridView ? AppColors.primaryPurple : AppColors.textMuted,
                              ),
                              onPressed: () => setState(() => _isGridView = true),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.view_list_rounded,
                                size: 18,
                                color: !_isGridView ? AppColors.primaryPurple : AppColors.textMuted,
                              ),
                              onPressed: () => setState(() => _isGridView = false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Book Cards Grid / List
              if (_isGridView)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: displayBooks.length,
                  itemBuilder: (context, index) {
                    final book = displayBooks[index];
                    return _buildGridBookCard(book);
                  },
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayBooks.length,
                  itemBuilder: (context, index) {
                    final book = displayBooks[index];
                    return _buildListBookCard(book);
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridBookCard(Book book) {
    final isAvail = book.isAvailable && book.availableCopies > 0;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookDetailsScreen(book: book, isStaff: false),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image Box with Bookmark and Genre
            Stack(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0FC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_stories_rounded, color: AppColors.primaryPurple, size: 48),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bookmark_outline_rounded, size: 16, color: AppColors.textSecondary),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      book.category ?? 'Sci-Fi',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Rating & Pages
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: AppColors.primaryOrange),
                    SizedBox(width: 2),
                    Text(
                      '4.9',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const Text(
                  '496p',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Title
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),

            // Author
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Spacer(),

            // Availability status
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 6,
                  color: isAvail ? AppColors.statusGreen : AppColors.statusOrange,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isAvail ? 'Avail. • Shelf 02' : 'Due Nov 22 • Downtown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isAvail ? AppColors.statusGreen : AppColors.statusOrange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListBookCard(Book book) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookDetailsScreen(book: book, isStaff: false),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_rounded, color: AppColors.primaryPurple, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(book.author, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '${book.category ?? 'General'} • ${book.availableCopies} available',
                    style: const TextStyle(color: AppColors.primaryPurple, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
