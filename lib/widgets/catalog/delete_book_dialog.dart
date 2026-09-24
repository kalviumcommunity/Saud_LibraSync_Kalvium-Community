import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../services/book_service.dart';

/// Modal dialog for confirming the deletion of a book by library staff.
///
/// Handles confirmation warning, loading spinner during deletion,
/// and inline error feedback.
class DeleteBookConfirmationDialog extends StatefulWidget {
  const DeleteBookConfirmationDialog({
    super.key,
    required this.book,
    this.bookService,
  });

  /// The book being deleted.
  final Book book;

  /// Optional custom book service instance.
  final BookService? bookService;

  /// Static helper to display the delete confirmation dialog.
  static Future<bool?> show(
    BuildContext context, {
    required Book book,
    BookService? bookService,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          DeleteBookConfirmationDialog(book: book, bookService: bookService),
    );
  }

  @override
  State<DeleteBookConfirmationDialog> createState() =>
      _DeleteBookConfirmationDialogState();
}

class _DeleteBookConfirmationDialogState
    extends State<DeleteBookConfirmationDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleDelete() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = widget.bookService ?? BookService();
      await service.deleteBook(widget.book.id);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('ArgumentError: ', '')
              .replaceAll('Invalid argument(s): ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: !_isLoading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.delete_forever_rounded,
              color: colorScheme.error,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Text('Delete Book'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
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

              Text(
                'Are you sure you want to delete "${widget.book.title}" from the catalog?',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This action will permanently remove the title and its copy tracking records from the library database. This cannot be undone.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            key: const Key('delete_book_cancel_btn'),
            onPressed: _isLoading
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('delete_book_confirm_btn'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: _isLoading ? null : _handleDelete,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Delete Book'),
          ),
        ],
      ),
    );
  }
}
