import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book.dart';
import '../../providers/book_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/catalog/book_form_dialog.dart';
import '../../widgets/catalog/delete_book_dialog.dart';
import 'book_details_screen.dart';

/// Staff Book Management view matching Mockup 1.
class StaffBookManagementView extends ConsumerStatefulWidget {
  const StaffBookManagementView({super.key});

  @override
  ConsumerState<StaffBookManagementView> createState() => _StaffBookManagementViewState();
}

class _StaffBookManagementViewState extends ConsumerState<StaffBookManagementView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All Categories';
  String _selectedBranch = 'Central Branch';
  String _selectedStatus = 'Status Available';

  final List<String> _categories = [
    'All Categories',
    'Fiction',
    'Self-Help',
    'Fantasy',
    'Sci-Fi',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddBookDialog() async {
    final newBook = await BookFormDialog.show(context);
    if (newBook != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${newBook.title}" added to inventory successfully.'),
          backgroundColor: AppColors.statusGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openEditBookDialog(Book book) async {
    final updated = await BookFormDialog.show(context, book: book);
    if (updated != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${updated.title}" updated successfully.'),
          backgroundColor: AppColors.statusGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openDeleteBookDialog(Book book) async {
    final deleted = await DeleteBookConfirmationDialog.show(context, book: book);
    if (deleted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${book.title}" deleted from catalog.'),
          backgroundColor: AppColors.statusRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncBooks = ref.watch(booksStreamProvider);
    final books = asyncBooks.value ?? [];
    final query = _searchController.text.trim().toLowerCase();

    final filteredBooks = books.where((b) {
      if (query.isNotEmpty) {
        final matches = b.title.toLowerCase().contains(query) ||
            b.author.toLowerCase().contains(query) ||
            (b.isbn?.toLowerCase().contains(query) ?? false);
        if (!matches) return false;
      }
      if (_selectedCategory != 'All Categories') {
        if (b.category?.toLowerCase() != _selectedCategory.toLowerCase()) {
          return false;
        }
      }
      if (_selectedStatus == 'Status Available' && !b.isAvailable) {
        return false;
      }
      return true;
    }).toList();

    final effectiveBooks = filteredBooks;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {},
        ),
        title: Row(
          children: [
            const Text(
              'Book Management',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.pillPurpleBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: AppColors.primaryPurple),
                  SizedBox(width: 4),
                  Text(
                    'Staff Portal',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Inventory Hub Bar with "+ Add Book" CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INVENTORY HUB',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '14,820 Titles • Downtown Central',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    key: const Key('staff_add_book_btn'),
                    onPressed: _openAddBookDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Book', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by title, author, or ISBN...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Category dropdown chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          dropdownColor: AppColors.primaryPurpleDark,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          items: _categories.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Branch Chip
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
                    const SizedBox(width: 8),

                    // Status Chip
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedStatus = _selectedStatus == 'All Status'
                              ? 'Status Available'
                              : 'All Status';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedStatus == 'Status Available'
                              ? AppColors.pillPurpleBg
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedStatus == 'Status Available'
                                ? AppColors.primaryPurple
                                : AppColors.cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _selectedStatus,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _selectedStatus == 'Status Available'
                                    ? AppColors.primaryPurple
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Book Cards List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: effectiveBooks.length,
                itemBuilder: (context, index) {
                  final book = effectiveBooks[index];
                  final isLowStock = book.availableCopies <= 1;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Book Thumbnail
                            Container(
                              width: 60,
                              height: 84,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0EDFB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: const Icon(Icons.menu_book_rounded, color: AppColors.primaryPurple, size: 30),
                            ),
                            const SizedBox(width: 14),

                            // Book Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    book.author,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ISBN: ${book.isbn ?? '978-0743273565'}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                  const SizedBox(height: 6),
                                  // Category & Year Tags
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.pillPurpleBg,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${book.category ?? 'Fiction'} • ${book.publishedYear ?? 1925}',
                                          style: const TextStyle(
                                            color: AppColors.primaryPurple,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F1FA),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Stack 1A',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // 3-dot overflow menu
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              onSelected: (val) {
                                if (val == 'details') {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => BookDetailsScreen(book: book, isStaff: true),
                                    ),
                                  );
                                } else if (val == 'edit') {
                                  _openEditBookDialog(book);
                                } else if (val == 'delete') {
                                  _openDeleteBookDialog(book);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'details',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility_outlined, size: 18, color: AppColors.primaryPurple),
                                      SizedBox(width: 10),
                                      Text('View Details', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryPurple),
                                      SizedBox(width: 10),
                                      Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: AppColors.statusRed),
                                      SizedBox(width: 10),
                                      Text('Delete Book', style: TextStyle(color: AppColors.statusRed, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Availability and Holds pills
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLowStock ? AppColors.statusOrangeBg : AppColors.statusGreenBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: isLowStock ? AppColors.statusOrange : AppColors.statusGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isLowStock
                                        ? 'Low Stock (${book.availableCopies} copy)'
                                        : 'Available (${book.availableCopies} copies)',
                                    style: TextStyle(
                                      color: isLowStock ? AppColors.statusOrange : AppColors.statusGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isLowStock)
                              const Text(
                                '2 Active Holds',
                                style: TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
