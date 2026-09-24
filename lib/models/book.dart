/// Data model representing a book in the LibraSync catalog.
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    this.imageUrl,
    this.isbn,
    this.category,
    this.publishedYear,
    this.isAvailable = true,
    this.totalCopies = 1,
    this.availableCopies = 1,
  });

  /// Unique identifier for the book document.
  final String id;

  /// The title of the book.
  final String title;

  /// The author or creators of the book.
  final String author;

  /// Detailed summary or description of the book.
  final String description;

  /// Optional URL pointing to the book's cover image.
  final String? imageUrl;

  /// International Standard Book Number.
  final String? isbn;

  /// Genre or category of the book (e.g., Fiction, Science, History).
  final String? category;

  /// Year of publication.
  final int? publishedYear;

  /// Whether the book is currently available for borrowing.
  final bool isAvailable;

  /// Total count of physical copies in the library system.
  final int totalCopies;

  /// Number of copies currently available on shelf.
  final int availableCopies;

  /// Validates all book data fields according to library system invariants.
  ///
  /// Throws an [ArgumentError] if any requirement is violated.
  void validate() {
    validateBookData(
      title: title,
      author: author,
      description: description,
      totalCopies: totalCopies,
      availableCopies: availableCopies,
      publishedYear: publishedYear,
    );
  }

  /// Static helper to validate book input parameters prior to model creation or persistence.
  ///
  /// Throws an [ArgumentError] if any requirement is violated.
  static void validateBookData({
    required String title,
    required String author,
    required String description,
    required int totalCopies,
    required int availableCopies,
    int? publishedYear,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError('Book title cannot be empty.');
    }
    if (author.trim().isEmpty) {
      throw ArgumentError('Book author cannot be empty.');
    }
    if (description.trim().isEmpty) {
      throw ArgumentError('Book description cannot be empty.');
    }
    if (totalCopies < 1) {
      throw ArgumentError('Total copies must be at least 1.');
    }
    if (availableCopies < 0) {
      throw ArgumentError('Available copies cannot be negative.');
    }
    if (availableCopies > totalCopies) {
      throw ArgumentError(
        'Available copies ($availableCopies) cannot exceed total copies ($totalCopies).',
      );
    }
    if (publishedYear != null &&
        (publishedYear < 1 || publishedYear > DateTime.now().year + 5)) {
      throw ArgumentError('Invalid publication year: $publishedYear.');
    }
  }

  /// Factory constructor to deserialize a [Book] from a Firestore document map.
  factory Book.fromFirestore(Map<String, dynamic> data, String id) {
    final total = (data['totalCopies'] as num?)?.toInt() ?? 1;
    final available = (data['availableCopies'] as num?)?.toInt() ?? 1;

    return Book(
      id: id,
      title: data['title'] as String? ?? '',
      author: data['author'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      isbn: data['isbn'] as String?,
      category: data['category'] as String?,
      publishedYear: (data['publishedYear'] as num?)?.toInt(),
      isAvailable: data['isAvailable'] as bool? ?? (available > 0),
      totalCopies: total,
      availableCopies: available,
    );
  }

  /// Converts this [Book] into a map suitable for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title.trim(),
      'author': author.trim(),
      'description': description.trim(),
      if (imageUrl != null && imageUrl!.trim().isNotEmpty)
        'imageUrl': imageUrl!.trim(),
      if (isbn != null && isbn!.trim().isNotEmpty) 'isbn': isbn!.trim(),
      if (category != null && category!.trim().isNotEmpty)
        'category': category!.trim(),
      if (publishedYear != null) 'publishedYear': publishedYear,
      'isAvailable': availableCopies > 0,
      'totalCopies': totalCopies,
      'availableCopies': availableCopies,
    };
  }

  /// Creates a copy of this [Book] with the given fields replaced.
  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? description,
    String? imageUrl,
    String? isbn,
    String? category,
    int? publishedYear,
    bool? isAvailable,
    int? totalCopies,
    int? availableCopies,
  }) {
    final updatedAvailableCopies = availableCopies ?? this.availableCopies;
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isbn: isbn ?? this.isbn,
      category: category ?? this.category,
      publishedYear: publishedYear ?? this.publishedYear,
      isAvailable: isAvailable ?? (updatedAvailableCopies > 0),
      totalCopies: totalCopies ?? this.totalCopies,
      availableCopies: updatedAvailableCopies,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          author == other.author &&
          description == other.description &&
          imageUrl == other.imageUrl &&
          isbn == other.isbn &&
          category == other.category &&
          publishedYear == other.publishedYear &&
          isAvailable == other.isAvailable &&
          totalCopies == other.totalCopies &&
          availableCopies == other.availableCopies;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    description,
    imageUrl,
    isbn,
    category,
    publishedYear,
    isAvailable,
    totalCopies,
    availableCopies,
  );

  @override
  String toString() {
    return 'Book(id: $id, title: $title, author: $author, isAvailable: $isAvailable, availableCopies: $availableCopies/$totalCopies)';
  }
}
