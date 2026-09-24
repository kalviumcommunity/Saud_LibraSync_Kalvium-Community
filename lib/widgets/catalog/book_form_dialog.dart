import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../services/book_service.dart';

/// Modal dialog for adding a new book or editing an existing book in the catalog.
///
/// Features input validation matching library domain invariants, responsive sizing,
/// loading spinner during submission, and inline error feedback.
class BookFormDialog extends StatefulWidget {
  const BookFormDialog({super.key, this.book, this.bookService});

  /// Optional book to edit. If null, the dialog operates in "Add New Book" mode.
  final Book? book;

  /// Optional custom book service instance (useful for testing or dependency injection).
  final BookService? bookService;

  /// Static helper method to display the form dialog.
  static Future<Book?> show(
    BuildContext context, {
    Book? book,
    BookService? bookService,
  }) {
    return showDialog<Book>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          BookFormDialog(book: book, bookService: bookService),
    );
  }

  @override
  State<BookFormDialog> createState() => _BookFormDialogState();
}

class _BookFormDialogState extends State<BookFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _publishedYearController;
  late final TextEditingController _isbnController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _totalCopiesController;
  late final TextEditingController _availableCopiesController;

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.book != null;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    _titleController = TextEditingController(text: b?.title ?? '');
    _authorController = TextEditingController(text: b?.author ?? '');
    _descriptionController = TextEditingController(text: b?.description ?? '');
    _categoryController = TextEditingController(text: b?.category ?? '');
    _publishedYearController = TextEditingController(
      text: b?.publishedYear != null ? '${b!.publishedYear}' : '',
    );
    _isbnController = TextEditingController(text: b?.isbn ?? '');
    _imageUrlController = TextEditingController(text: b?.imageUrl ?? '');
    _totalCopiesController = TextEditingController(
      text: '${b?.totalCopies ?? 1}',
    );
    _availableCopiesController = TextEditingController(
      text: '${b?.availableCopies ?? 1}',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _publishedYearController.dispose();
    _isbnController.dispose();
    _imageUrlController.dispose();
    _totalCopiesController.dispose();
    _availableCopiesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final totalCopies = int.parse(_totalCopiesController.text.trim());
      final availableCopies = int.parse(_availableCopiesController.text.trim());
      final publishedYearText = _publishedYearController.text.trim();
      final publishedYear = publishedYearText.isNotEmpty
          ? int.tryParse(publishedYearText)
          : null;

      final service = widget.bookService ?? BookService();

      if (_isEditing) {
        final updatedBook = widget.book!.copyWith(
          title: _titleController.text.trim(),
          author: _authorController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _categoryController.text.trim().isNotEmpty
              ? _categoryController.text.trim()
              : null,
          publishedYear: publishedYear,
          isbn: _isbnController.text.trim().isNotEmpty
              ? _isbnController.text.trim()
              : null,
          imageUrl: _imageUrlController.text.trim().isNotEmpty
              ? _imageUrlController.text.trim()
              : null,
          totalCopies: totalCopies,
          availableCopies: availableCopies,
        );

        final saved = await service.updateBook(updatedBook);

        if (mounted) {
          Navigator.of(context).pop(saved);
        }
      } else {
        final newBook = Book(
          id: '',
          title: _titleController.text.trim(),
          author: _authorController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _categoryController.text.trim().isNotEmpty
              ? _categoryController.text.trim()
              : null,
          publishedYear: publishedYear,
          isbn: _isbnController.text.trim().isNotEmpty
              ? _isbnController.text.trim()
              : null,
          imageUrl: _imageUrlController.text.trim().isNotEmpty
              ? _imageUrlController.text.trim()
              : null,
          totalCopies: totalCopies,
          availableCopies: availableCopies,
        );

        final saved = await service.createBook(newBook);

        if (mounted) {
          Navigator.of(context).pop(saved);
        }
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
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            Icon(
              _isEditing ? Icons.edit_note_rounded : Icons.library_add_rounded,
              color: colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isEditing ? 'Edit Book Details' : 'Add New Book',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 520),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Error Banner ──────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
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

                  // ── Book Title ────────────────────────────────────────────
                  TextFormField(
                    key: const Key('book_form_title_field'),
                    controller: _titleController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      hintText: 'e.g., Clean Architecture',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the book title.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Author ────────────────────────────────────────────────
                  TextFormField(
                    key: const Key('book_form_author_field'),
                    controller: _authorController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Author *',
                      hintText: 'e.g., Robert C. Martin',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the author name.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Description ───────────────────────────────────────────
                  TextFormField(
                    key: const Key('book_form_description_field'),
                    controller: _descriptionController,
                    enabled: !_isLoading,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description / Synopsis *',
                      hintText: 'Summary or details of the book...',
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description for the book.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Category & Published Year Row ─────────────────────────
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: const Key('book_form_category_field'),
                          controller: _categoryController,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Genre / Category',
                            hintText: 'e.g., Computer Science',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          key: const Key('book_form_published_year_field'),
                          controller: _publishedYearController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Year',
                            hintText: 'e.g., 2023',
                            prefixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final year = int.tryParse(value.trim());
                              if (year == null ||
                                  year < 1 ||
                                  year > DateTime.now().year + 5) {
                                return 'Invalid year';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Total Copies & Available Copies Row ───────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('book_form_total_copies_field'),
                          controller: _totalCopiesController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Total Copies *',
                            hintText: 'e.g., 5',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            final numVal = int.tryParse(value.trim());
                            if (numVal == null || numVal < 1) {
                              return 'Must be >= 1';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const Key('book_form_available_copies_field'),
                          controller: _availableCopiesController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Available Copies *',
                            hintText: 'e.g., 5',
                            prefixIcon: Icon(Icons.event_available_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            final avail = int.tryParse(value.trim());
                            if (avail == null || avail < 0) {
                              return 'Must be >= 0';
                            }
                            final total = int.tryParse(
                              _totalCopiesController.text.trim(),
                            );
                            if (total != null && avail > total) {
                              return 'Cannot exceed total';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── ISBN & Image URL ──────────────────────────────────────
                  TextFormField(
                    key: const Key('book_form_isbn_field'),
                    controller: _isbnController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'ISBN',
                      hintText: 'e.g., 978-0134494166',
                      prefixIcon: Icon(Icons.qr_code_2_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    key: const Key('book_form_image_url_field'),
                    controller: _imageUrlController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Cover Image URL',
                      hintText: 'https://example.com/cover.jpg',
                      prefixIcon: Icon(Icons.image_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            key: const Key('book_form_cancel_btn'),
            onPressed: _isLoading
                ? null
                : () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('book_form_submit_btn'),
            onPressed: _isLoading ? null : _handleSubmit,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEditing ? 'Save Changes' : 'Add Book'),
          ),
        ],
      ),
    );
  }
}
