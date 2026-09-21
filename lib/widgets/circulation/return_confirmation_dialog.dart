import 'package:flutter/material.dart';

import '../../models/loan_record.dart';
import '../../services/circulation_service.dart';

/// Modal dialog for confirming a book return.
///
/// Shows book summary, instructions for physical drop-off,
/// and handles initial, loading, success, and error states.
class ReturnConfirmationDialog extends StatefulWidget {
  const ReturnConfirmationDialog({
    super.key,
    required this.loan,
    this.onConfirmReturn,
    this.circulationService,
  });

  /// The loan record being returned.
  final LoanRecord loan;

  /// Optional custom return callback (useful for testing or customized pipelines).
  final Future<void> Function()? onConfirmReturn;

  /// Optional circulation service instance.
  final CirculationService? circulationService;

  /// Static helper to display the return confirmation dialog.
  static Future<bool?> show(
    BuildContext context, {
    required LoanRecord loan,
    Future<void> Function()? onConfirmReturn,
    CirculationService? circulationService,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ReturnConfirmationDialog(
        loan: loan,
        onConfirmReturn: onConfirmReturn,
        circulationService: circulationService,
      ),
    );
  }

  @override
  State<ReturnConfirmationDialog> createState() =>
      _ReturnConfirmationDialogState();
}

class _ReturnConfirmationDialogState extends State<ReturnConfirmationDialog> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  Future<void> _handleConfirm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.onConfirmReturn != null) {
        await widget.onConfirmReturn!();
      } else {
        final service = widget.circulationService ?? CirculationService();
        await service.requestReturn(loanId: widget.loan.id);
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
              ? (e.message ?? 'Return transactions are coming in the backend milestone.')
              : e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(
            Icons.assignment_return_rounded,
            color: colorScheme.primary,
            size: 26,
          ),
          const SizedBox(width: 10),
          const Text('Return Book'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Success View ──────────────────────────────────────────
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
                            'Book Marked as Returned',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Thank you for returning "${widget.loan.bookTitle}".',
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
            ] else ...[
              // ── Book Summary Details ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
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
                        width: 44,
                        height: 62,
                        color: colorScheme.primaryContainer,
                        child: (widget.loan.bookImageUrl != null &&
                                widget.loan.bookImageUrl!.trim().isNotEmpty)
                            ? Image.network(
                                widget.loan.bookImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _miniPlaceholder(colorScheme),
                              )
                            : _miniPlaceholder(colorScheme),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title & Author
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.loan.bookTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.loan.bookAuthor,
                            style: theme.textTheme.bodySmall?.copyWith(
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
              ),
              const SizedBox(height: 14),

              // Confirmation guidance
              Text(
                'Are you sure you want to return this book? Please ensure the physical copy is handed over to the library desk or deposited in the drop box.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              // ── Error Message Banner ────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.onErrorContainer,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (_isSuccess)
          FilledButton(
            key: const Key('return_success_done_btn'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          )
        else ...[
          TextButton(
            key: const Key('return_cancel_btn'),
            onPressed: _isLoading
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('return_confirm_btn'),
            onPressed: _isLoading ? null : _handleConfirm,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirm Return'),
          ),
        ],
      ],
    );
  }

  Widget _miniPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.menu_book_rounded,
        size: 20,
        color: colorScheme.primary,
      ),
    );
  }
}
