/// Data model representing an individual physical book copy in LibraSync.
class BookCopy {
  const BookCopy({
    required this.id,
    required this.bookId,
    required this.branchId,
    this.status = statusAvailable,
    this.barcode,
    this.condition,
  });

  /// Standard status values for a book copy.
  static const String statusAvailable = 'available';
  static const String statusBorrowed = 'borrowed';
  static const String statusMaintenance = 'maintenance';
  static const String statusLost = 'lost';

  /// Centralized set of recognized copy statuses.
  static const Set<String> validStatuses = {
    statusAvailable,
    statusBorrowed,
    statusMaintenance,
    statusLost,
  };

  /// Validates whether a status string is a known valid status.
  static bool isValidStatus(String status) =>
      validStatuses.contains(status.trim().toLowerCase());

  /// Unique identifier for the physical book copy document.
  final String id;

  /// Identifier of the catalog book title this copy belongs to.
  final String bookId;

  /// Identifier of the library branch where this physical copy is located.
  final String branchId;

  /// Current availability status of this physical copy (e.g. 'available', 'borrowed').
  final String status;

  /// Optional barcode or accession number on the physical copy.
  final String? barcode;

  /// Optional physical condition notes (e.g. 'new', 'good', 'fair').
  final String? condition;

  /// Whether the copy is currently available for borrowing on shelf.
  bool get isAvailable => status.toLowerCase() == statusAvailable;

  /// Validates all book copy fields according to system invariants.
  ///
  /// Throws an [ArgumentError] if any requirement is violated.
  void validate() {
    validateBookCopyData(bookId: bookId, branchId: branchId, status: status);
  }

  /// Static helper to validate book copy parameters prior to creation or persistence.
  ///
  /// Throws an [ArgumentError] if any requirement is violated.
  static void validateBookCopyData({
    required String bookId,
    required String branchId,
    String status = statusAvailable,
  }) {
    if (bookId.trim().isEmpty) {
      throw ArgumentError('Book ID cannot be empty.');
    }
    if (branchId.trim().isEmpty) {
      throw ArgumentError('Branch ID cannot be empty.');
    }
    if (status.trim().isEmpty) {
      throw ArgumentError('Status cannot be empty.');
    }
    if (!isValidStatus(status)) {
      throw ArgumentError(
        'Invalid copy status: "$status". Allowed statuses are: ${validStatuses.join(", ")}.',
      );
    }
  }

  /// Factory constructor to deserialize a [BookCopy] from a Firestore document map.
  factory BookCopy.fromFirestore(Map<String, dynamic> data, String id) {
    return BookCopy(
      id: id,
      bookId: data['bookId'] as String? ?? '',
      branchId: data['branchId'] as String? ?? '',
      status: data['status'] as String? ?? statusAvailable,
      barcode: data['barcode'] as String?,
      condition: data['condition'] as String?,
    );
  }

  /// Converts this [BookCopy] into a map suitable for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'bookId': bookId.trim(),
      'branchId': branchId.trim(),
      'status': status.trim(),
      if (barcode != null && barcode!.trim().isNotEmpty)
        'barcode': barcode!.trim(),
      if (condition != null && condition!.trim().isNotEmpty)
        'condition': condition!.trim(),
    };
  }

  /// Creates a copy of this [BookCopy] with the given fields replaced.
  BookCopy copyWith({
    String? id,
    String? bookId,
    String? branchId,
    String? status,
    String? barcode,
    String? condition,
  }) {
    return BookCopy(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      branchId: branchId ?? this.branchId,
      status: status ?? this.status,
      barcode: barcode ?? this.barcode,
      condition: condition ?? this.condition,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookCopy &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          bookId == other.bookId &&
          branchId == other.branchId &&
          status == other.status &&
          barcode == other.barcode &&
          condition == other.condition;

  @override
  int get hashCode =>
      Object.hash(id, bookId, branchId, status, barcode, condition);

  @override
  String toString() {
    return 'BookCopy(id: $id, bookId: $bookId, branchId: $branchId, status: $status, barcode: $barcode)';
  }
}
