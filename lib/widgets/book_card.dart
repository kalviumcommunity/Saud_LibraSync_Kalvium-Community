import 'package:flutter/material.dart';

import '../models/book.dart';

/// A reusable, Material 3 card widget displaying book catalog summary data.
///
/// Shows cover image (or placeholder), title, author, description preview,
/// and availability status badge.
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    this.onTap,
  });

  /// The book data to display.
  final Book book;

  /// Optional callback triggered when the card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(80),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover Image / Placeholder ─────────────────────────────
              _BookCoverThumbnail(
                imageUrl: book.imageUrl,
                title: book.title,
                id: book.id,
              ),
              const SizedBox(width: 14),

              // ── Book Details ──────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      book.title.isNotEmpty ? book.title : 'Untitled Book',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Author
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            book.author.isNotEmpty
                                ? book.author
                                : 'Unknown Author',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Description snippet
                    if (book.description.isNotEmpty)
                      Expanded(
                        child: Text(
                          book.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(height: 4),

                    // Availability & Category Row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _AvailabilityChip(
                          isAvailable: book.isAvailable,
                          availableCopies: book.availableCopies,
                        ),
                        if (book.category != null &&
                            book.category!.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              book.category!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thumbnail component that renders a network image or a fallback cover.
class _BookCoverThumbnail extends StatelessWidget {
  const _BookCoverThumbnail({
    required this.imageUrl,
    required this.title,
    required this.id,
  });

  final String? imageUrl;
  final String title;
  final String id;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    const width = 72.0;
    const height = 104.0;

    return Hero(
      tag: 'book_cover_$id',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: width,
          height: height,
          color: colorScheme.primaryContainer.withAlpha(120),
          child: (imageUrl != null && imageUrl!.trim().isNotEmpty)
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      _CoverPlaceholder(title: title),
                )
              : _CoverPlaceholder(title: title),
        ),
      ),
    );
  }
}

/// Fallback placeholder when no cover image is provided or loading fails.
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.title});

  final String title;

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
      padding: const EdgeInsets.all(6),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 28,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                title.isNotEmpty ? title : 'Book',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status chip indicating book availability.
class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({
    required this.isAvailable,
    required this.availableCopies,
  });

  final bool isAvailable;
  final int availableCopies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReady = isAvailable && availableCopies > 0;

    final bgColor = isReady
        ? Colors.green.withAlpha(30)
        : Colors.orange.withAlpha(30);
    final textColor = isReady
        ? Colors.green.shade800
        : Colors.orange.shade800;
    final label = isReady ? 'Available' : 'Checked Out';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: textColor.withAlpha(60),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
