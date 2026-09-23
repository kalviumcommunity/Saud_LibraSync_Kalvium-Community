import 'package:flutter/material.dart';

import '../../models/loan_record.dart';

/// Presentation card widget displaying a borrowed book record in member circulation.
///
/// Shows book cover, title, author, borrow date, due date, loan status chip,
/// and an action button to initiate returning the book.
class BorrowedBookCard extends StatelessWidget {
  const BorrowedBookCard({
    super.key,
    required this.loan,
    required this.onReturn,
  });

  /// The active loan record to display.
  final LoanRecord loan;

  /// Callback when the user taps "Return Book".
  final VoidCallback onReturn;

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOverdue = loan.isOverdue;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue
              ? colorScheme.error.withAlpha(90)
              : colorScheme.outlineVariant.withAlpha(70),
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Book Cover Thumbnail ──────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 68,
                    height: 98,
                    color: colorScheme.primaryContainer.withAlpha(120),
                    child:
                        (loan.bookImageUrl != null &&
                            loan.bookImageUrl!.trim().isNotEmpty)
                        ? Image.network(
                            loan.bookImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _CoverPlaceholder(title: loan.bookTitle),
                          )
                        : _CoverPlaceholder(title: loan.bookTitle),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Info Column ───────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Chip
                      _LoanStatusChip(
                        isOverdue: isOverdue,
                        daysUntilDue: loan.daysUntilDue,
                        status: loan.status,
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        loan.bookTitle.isNotEmpty
                            ? loan.bookTitle
                            : 'Untitled Book',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Author
                      Text(
                        loan.bookAuthor.isNotEmpty
                            ? 'by ${loan.bookAuthor}'
                            : 'Unknown Author',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Dates and Return Action Row ───────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Borrowed: ${_formatDate(loan.borrowDate)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 14,
                            color: isOverdue
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Due: ${_formatDate(loan.dueDate)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isOverdue
                                  ? colorScheme.error
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  key: Key('return_btn_${loan.id}'),
                  onPressed: onReturn,
                  icon: const Icon(Icons.assignment_return_rounded, size: 18),
                  label: const Text('Return'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanStatusChip extends StatelessWidget {
  const _LoanStatusChip({
    required this.isOverdue,
    required this.daysUntilDue,
    required this.status,
  });

  final bool isOverdue;
  final int daysUntilDue;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isOverdue) {
      final daysPast = daysUntilDue.abs();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 13,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 4),
            Text(
              daysPast == 0 ? 'Due Today!' : 'Overdue by $daysPast day(s)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (daysUntilDue <= 3) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withAlpha(40),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.shade800.withAlpha(60)),
        ),
        child: Text(
          'Due in $daysUntilDue day(s)',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.amber.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(90),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'On Loan ($daysUntilDue days left)',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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
                size: 26,
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
