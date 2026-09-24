import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../services/book_service.dart';
import '../../services/circulation_service.dart';
import '../../widgets/catalog/book_form_dialog.dart';
import '../../widgets/catalog/delete_book_dialog.dart';
import '../../widgets/circulation/borrow_confirmation_sheet.dart';

/// Screen displaying comprehensive details for a selected [Book], circulation actions,
/// and staff management actions (editing details and deleting books).
class BookDetailsScreen extends StatefulWidget {
  const BookDetailsScreen({
    super.key,
    required this.book,
    this.circulationService,
    this.onConfirmBorrow,
    this.bookService,
    this.isStaff,
    this.memberId,
  });

  /// The book to display.
  final Book book;

  /// Optional circulation service instance.
  final CirculationService? circulationService;

  /// Optional custom borrow callback for testing or custom pipelines.
  final Future<void> Function()? onConfirmBorrow;

  /// Optional custom book service instance.
  final BookService? bookService;

  /// Optional staff status override (useful for testing or direct permission pass-through).
  final bool? isStaff;

  /// Optional member identifier for borrowing.
  final String? memberId;

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  late Book _currentBook;
  bool _isStaff = false;
  bool _hasModified = false;

  @override
  void initState() {
    super.initState();
    _currentBook = widget.book;
    _checkStaffStatus();
  }

  @override
  void didUpdateWidget(covariant BookDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStaff != oldWidget.isStaff ||
        widget.bookService != oldWidget.bookService) {
      _checkStaffStatus();
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

  Future<void> _openBorrowSheet() async {
    final borrowed = await BorrowConfirmationSheet.show(
      context,
      book: _currentBook,
      onConfirmBorrow: widget.onConfirmBorrow,
      circulationService: widget.circulationService,
      memberId: widget.memberId,
    );

    // Propagate a successful borrow to the previous route (e.g.
    // MemberCirculationScreen) so it can refresh the active loans stream.
    if (borrowed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleEdit() async {
    final updated = await BookFormDialog.show(
      context,
      book: _currentBook,
      bookService: widget.bookService,
    );

    if (updated != null && mounted) {
      setState(() {
        _currentBook = updated;
        _hasModified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${updated.title}" updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    final deleted = await DeleteBookConfirmationDialog.show(
      context,
      book: _currentBook,
      bookService: widget.bookService,
    );

    if (deleted == true && mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${_currentBook.title}" deleted from catalog.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isReady =
        _currentBook.isAvailable && _currentBook.availableCopies > 0;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(_hasModified),
        ),
        title: Text(
          _currentBook.title.isNotEmpty ? _currentBook.title : 'Book Details',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isStaff) ...[
            IconButton(
              key: const Key('book_details_edit_btn'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Book',
              onPressed: _handleEdit,
            ),
            IconButton(
              key: const Key('book_details_delete_btn'),
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete Book',
              onPressed: _handleDelete,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Header Section (Cover + Primary Info) ───────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 540;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LargeCover(book: _currentBook),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _HeaderInfo(
                                book: _currentBook,
                                isReady: isReady,
                                onBorrowTap: isReady
                                    ? () => _openBorrowSheet()
                                    : null,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Center(child: _LargeCover(book: _currentBook)),
                            const SizedBox(height: 20),
                            _HeaderInfo(
                              book: _currentBook,
                              isReady: isReady,
                              alignCenter: true,
                              onBorrowTap: isReady
                                  ? () => _openBorrowSheet()
                                  : null,
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 20),

                  // ── Metadata Grid / Chips ─────────────────────────────
                  Text(
                    'Book Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BookMetadataSection(book: _currentBook),
                  const SizedBox(height: 24),

                  // ── Description Section ───────────────────────────────
                  Text(
                    'Synopsis & Description',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _currentBook.description.isNotEmpty
                            ? _currentBook.description
                            : 'No synopsis available for this title.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large cover widget with hero transition and styled fallback placeholder.
class _LargeCover extends StatelessWidget {
  const _LargeCover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const width = 150.0;
    const height = 220.0;

    return Hero(
      tag: 'book_cover_${book.id}',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: (book.imageUrl != null && book.imageUrl!.trim().isNotEmpty)
              ? Image.network(
                  book.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: colorScheme.primaryContainer,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      _LargePlaceholder(book: book),
                )
              : _LargePlaceholder(book: book),
        ),
      ),
    );
  }
}

/// Detailed placeholder for wide view.
class _LargePlaceholder extends StatelessWidget {
  const _LargePlaceholder({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 48,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                book.title.isNotEmpty ? book.title : 'LibraSync Book',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header text information containing Title, Author, Status Badge, and Borrow Action.
class _HeaderInfo extends StatelessWidget {
  const _HeaderInfo({
    required this.book,
    required this.isReady,
    this.alignCenter = false,
    this.onBorrowTap,
  });

  final Book book;
  final bool isReady;
  final bool alignCenter;
  final VoidCallback? onBorrowTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final crossAxis = alignCenter
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = alignCenter ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: crossAxis,
      children: [
        // Title
        Text(
          book.title.isNotEmpty ? book.title : 'Untitled Book',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 8),

        // Author
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                book.author.isNotEmpty ? book.author : 'Unknown Author',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: textAlign,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isReady
                ? Colors.green.withAlpha(30)
                : Colors.orange.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (isReady ? Colors.green : Colors.orange).withAlpha(100),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isReady
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 16,
                color: isReady ? Colors.green.shade800 : Colors.orange.shade800,
              ),
              const SizedBox(width: 6),
              Text(
                isReady
                    ? 'Available (${book.availableCopies} of ${book.totalCopies} copies)'
                    : 'Currently Unavailable (0 of ${book.totalCopies} copies)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isReady
                      ? Colors.green.shade800
                      : Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Prominent Borrow Book Action ─────────────────────────────
        if (isReady)
          FilledButton.icon(
            key: const Key('book_details_borrow_btn'),
            onPressed: onBorrowTap,
            icon: const Icon(Icons.bookmark_add_rounded, size: 20),
            label: const Text('Borrow Book'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        else
          FilledButton.icon(
            key: const Key('book_details_borrow_btn_disabled'),
            onPressed: null,
            icon: const Icon(Icons.do_not_disturb_on_outlined, size: 20),
            label: const Text('Currently Unavailable'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }
}

/// Metadata details list (ISBN, Category, Published Year).
class _BookMetadataSection extends StatelessWidget {
  const _BookMetadataSection({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (book.category != null && book.category!.trim().isNotEmpty)
          _MetaCard(
            icon: Icons.category_outlined,
            label: 'Genre',
            value: book.category!,
          ),
        if (book.publishedYear != null)
          _MetaCard(
            icon: Icons.calendar_today_rounded,
            label: 'Published',
            value: '${book.publishedYear}',
          ),
        if (book.isbn != null && book.isbn!.trim().isNotEmpty)
          _MetaCard(
            icon: Icons.qr_code_2_rounded,
            label: 'ISBN',
            value: book.isbn!,
          ),
        _MetaCard(
          icon: Icons.inventory_2_outlined,
          label: 'Total Copies',
          value: '${book.totalCopies}',
        ),
      ],
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
