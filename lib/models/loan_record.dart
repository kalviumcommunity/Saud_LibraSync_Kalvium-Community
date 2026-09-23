import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a member loan / circulation record in LibraSync.
class LoanRecord {
  const LoanRecord({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    this.bookImageUrl,
    required this.borrowDate,
    required this.dueDate,
    this.returnDate,
    this.memberId,
    this.memberName,
    this.status = 'active',
    this.borrowedBranchId,
    this.returnBranchId,
    this.bookCopyId,
  });

  /// Unique loan record identifier.
  final String id;

  /// Identifier of the borrowed book.
  final String bookId;

  /// Title of the borrowed book.
  final String bookTitle;

  /// Author of the borrowed book.
  final String bookAuthor;

  /// Cover image URL of the borrowed book, if available.
  final String? bookImageUrl;

  /// Date and time when the book was borrowed.
  final DateTime borrowDate;

  /// Scheduled due date for returning the book.
  final DateTime dueDate;

  /// Actual return timestamp, or null if currently on loan.
  final DateTime? returnDate;

  /// User / member identifier who borrowed the book.
  final String? memberId;

  /// Optional display name of the borrower.
  final String? memberName;

  /// Current loan status (e.g. 'active', 'returned', 'overdue').
  final String status;

  /// Identifier of the library branch where the book was originally borrowed.
  final String? borrowedBranchId;

  /// Identifier of the library branch where the book was returned (supports cross-branch returns).
  final String? returnBranchId;

  /// Identifier of the specific physical book copy borrowed, if assigned.
  final String? bookCopyId;

  /// Whether the loan is currently overdue.
  bool get isOverdue => returnDate == null && DateTime.now().isAfter(dueDate);

  /// Number of days remaining until the due date (negative if past due).
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  /// Factory constructor to deserialize a [LoanRecord] from a Firestore map.
  factory LoanRecord.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    }

    DateTime? parseNullableDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    return LoanRecord(
      id: id,
      bookId: data['bookId'] as String? ?? '',
      bookTitle: data['bookTitle'] as String? ?? '',
      bookAuthor: data['bookAuthor'] as String? ?? '',
      bookImageUrl: data['bookImageUrl'] as String?,
      borrowDate: parseDateTime(data['borrowDate']),
      dueDate: parseDateTime(data['dueDate']),
      returnDate: parseNullableDateTime(data['returnDate']),
      memberId: data['memberId'] as String?,
      memberName: data['memberName'] as String?,
      status: data['status'] as String? ?? 'active',
      borrowedBranchId:
          data['borrowedBranchId'] as String? ?? data['branchId'] as String?,
      returnBranchId: data['returnBranchId'] as String?,
      bookCopyId: data['bookCopyId'] as String? ?? data['copyId'] as String?,
    );
  }

  /// Converts this [LoanRecord] into a map suitable for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'bookId': bookId,
      'bookTitle': bookTitle,
      'bookAuthor': bookAuthor,
      if (bookImageUrl != null) 'bookImageUrl': bookImageUrl,
      'borrowDate': Timestamp.fromDate(borrowDate),
      'dueDate': Timestamp.fromDate(dueDate),
      if (returnDate != null) 'returnDate': Timestamp.fromDate(returnDate!),
      if (memberId != null) 'memberId': memberId,
      if (memberName != null) 'memberName': memberName,
      'status': status,
      if (borrowedBranchId != null && borrowedBranchId!.trim().isNotEmpty)
        'borrowedBranchId': borrowedBranchId!.trim(),
      if (returnBranchId != null && returnBranchId!.trim().isNotEmpty)
        'returnBranchId': returnBranchId!.trim(),
      if (bookCopyId != null && bookCopyId!.trim().isNotEmpty)
        'bookCopyId': bookCopyId!.trim(),
    };
  }

  /// Creates a copy of this [LoanRecord] with updated fields.
  LoanRecord copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    String? bookAuthor,
    String? bookImageUrl,
    DateTime? borrowDate,
    DateTime? dueDate,
    DateTime? returnDate,
    String? memberId,
    String? memberName,
    String? status,
    String? borrowedBranchId,
    String? returnBranchId,
    String? bookCopyId,
  }) {
    return LoanRecord(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      bookImageUrl: bookImageUrl ?? this.bookImageUrl,
      borrowDate: borrowDate ?? this.borrowDate,
      dueDate: dueDate ?? this.dueDate,
      returnDate: returnDate ?? this.returnDate,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      status: status ?? this.status,
      borrowedBranchId: borrowedBranchId ?? this.borrowedBranchId,
      returnBranchId: returnBranchId ?? this.returnBranchId,
      bookCopyId: bookCopyId ?? this.bookCopyId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          bookId == other.bookId &&
          bookTitle == other.bookTitle &&
          bookAuthor == other.bookAuthor &&
          bookImageUrl == other.bookImageUrl &&
          borrowDate == other.borrowDate &&
          dueDate == other.dueDate &&
          returnDate == other.returnDate &&
          memberId == other.memberId &&
          memberName == other.memberName &&
          status == other.status &&
          borrowedBranchId == other.borrowedBranchId &&
          returnBranchId == other.returnBranchId &&
          bookCopyId == other.bookCopyId;

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    bookTitle,
    bookAuthor,
    bookImageUrl,
    borrowDate,
    dueDate,
    returnDate,
    memberId,
    memberName,
    status,
    borrowedBranchId,
    returnBranchId,
    bookCopyId,
  );

  @override
  String toString() {
    return 'LoanRecord(id: $id, bookTitle: $bookTitle, status: $status, borrowedBranch: $borrowedBranchId, returnBranch: $returnBranchId)';
  }
}
