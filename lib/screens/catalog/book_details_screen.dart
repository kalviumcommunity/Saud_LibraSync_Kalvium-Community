import 'package:flutter/material.dart';

import '../../models/book.dart';

/// Screen displaying comprehensive details for a selected [Book].
class BookDetailsScreen extends StatelessWidget {
  const BookDetailsScreen({
    super.key,
    required this.book,
  });

  /// The book to display.
  final Book book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isReady = book.isAvailable && book.availableCopies > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          book.title.isNotEmpty ? book.title : 'Book Details',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
                            _LargeCover(book: book),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _HeaderInfo(
                                book: book,
                                isReady: isReady,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Center(child: _LargeCover(book: book)),
                            const SizedBox(height: 20),
                            _HeaderInfo(
                              book: book,
                              isReady: isReady,
                              alignCenter: true,
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
                  _BookMetadataSection(book: book),
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
                        book.description.isNotEmpty
                            ? book.description
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

/// Header text information containing Title, Author, and Status Badge.
class _HeaderInfo extends StatelessWidget {
  const _HeaderInfo({
    required this.book,
    required this.isReady,
    this.alignCenter = false,
  });

  final Book book;
  final bool isReady;
  final bool alignCenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final crossAxis =
        alignCenter ? CrossAxisAlignment.center : CrossAxisAlignment.start;
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
        const SizedBox(height: 16),

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
                isReady ? Icons.check_circle_rounded : Icons.info_outline_rounded,
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
                  color:
                      isReady ? Colors.green.shade800 : Colors.orange.shade800,
                ),
              ),
            ],
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
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(60),
        ),
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
