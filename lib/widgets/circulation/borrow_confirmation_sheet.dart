import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../services/auth_service.dart';
import '../../services/circulation_service.dart';

/// Modal bottom sheet for confirming a book borrow request.
///
/// Displays book summary, loan duration terms, calculated due date,
/// and handles initial, loading, success, and error states.
class BorrowConfirmationSheet extends StatefulWidget {
  const BorrowConfirmationSheet({
    super.key,
    required this.book,
    this.onConfirmBorrow,
    this.circulationService,
    this.memberId,
  });

  /// The book being requested for borrowing.
  final Book book;

  /// Optional custom borrow callback (useful for testing or customized pipelines).
  final Future<void> Function()? onConfirmBorrow;

  /// Optional circulation service instance.
  final CirculationService? circulationService;

  /// Optional member identifier. Defaults to the current logged-in user.
  final String? memberId;

  /// Static helper method to display the confirmation sheet.
  static Future<bool?> show(
    BuildContext context, {
    required Book book,
    Future<void> Function()? onConfirmBorrow,
    CirculationService? circulationService,
    String? memberId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BorrowConfirmationSheet(
          book: book,
          onConfirmBorrow: onConfirmBorrow,
          circulationService: circulationService,
          memberId: memberId,
        ),
      ),
    );
  }

  @override
  State<BorrowConfirmationSheet> createState() =>
      _BorrowConfirmationSheetState();
}

class _BorrowConfirmationSheetState extends State<BorrowConfirmationSheet> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  late final DateTime _borrowDate;
  late final DateTime _dueDate;

  @override
  void initState() {
    super.initState();
    _borrowDate = DateTime.now();
    // Standard library loan period: 14 days
    _dueDate = _borrowDate.add(const Duration(days: 14));
  }

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

  Future<void> _handleConfirm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.onConfirmBorrow != null) {
        await widget.onConfirmBorrow!();
      } else {
        final service = widget.circulationService ?? CirculationService();
        final currentUserId =
            widget.memberId ?? AuthService().currentUser?.uid ?? '';
        await service.requestBorrow(book: widget.book, memberId: currentUserId);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is UnimplementedError
              ? (e.message ??
                    'Borrowing transactions are coming in the backend milestone.')
              : e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag Handle ─────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Sheet Title ─────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.bookmark_add_rounded,
                  color: colorScheme.primary,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  'Confirm Borrowing',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Success State View ──────────────────────────────────────
            if (_isSuccess) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green.shade800,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Book Borrowed Successfully!',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Due date: ${_formatDate(_dueDate)}. Please enjoy your reading!',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('borrow_success_done_btn'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Done'),
                ),
              ),
            ] else ...[
              // ── Book Summary Card ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(90),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withAlpha(60),
                  ),
                ),
                child: Row(
                  children: [
                    // Mini Cover
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 52,
                        height: 74,
                        color: colorScheme.primaryContainer,
                        child:
                            (widget.book.imageUrl != null &&
                                widget.book.imageUrl!.trim().isNotEmpty)
                            ? Image.network(
                                widget.book.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _miniPlaceholder(colorScheme),
                              )
                            : _miniPlaceholder(colorScheme),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title & Author
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'by ${widget.book.author}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.book.category != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.book.category!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Loan Terms & Due Date Information ─────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      context,
                      icon: Icons.calendar_today_rounded,
                      label: 'Borrow Date',
                      value: _formatDate(_borrowDate),
                    ),
                    const Divider(height: 16),
                    _infoRow(
                      context,
                      icon: Icons.event_available_rounded,
                      label: 'Expected Due Date',
                      value: '${_formatDate(_dueDate)} (14-day loan)',
                      isHighlighted: true,
                    ),
                    const Divider(height: 16),
                    _infoRow(
                      context,
                      icon: Icons.info_outline_rounded,
                      label: 'Loan Policy',
                      value: 'Standard community loan. Renewals allowed before due date.',
                    ),
                  ],
                ),
              ),

              // ── Error Banner ──────────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Actions: Cancel & Confirm ─────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('borrow_cancel_btn'),
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('borrow_confirm_btn'),
                      onPressed: _isLoading ? null : _handleConfirm,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Confirm Borrow'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.menu_book_rounded,
        size: 24,
        color: colorScheme.primary,
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isHighlighted
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
              color: isHighlighted
                  ? colorScheme.primary
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
