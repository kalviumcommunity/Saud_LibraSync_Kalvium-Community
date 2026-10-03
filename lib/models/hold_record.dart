import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a member book hold / reservation in LibraSync.
class HoldRecord {
  const HoldRecord({
    required this.id,
    required this.memberId,
    required this.bookId,
    required this.branchId,
    this.bookTitle = '',
    this.bookAuthor = '',
    this.bookImageUrl,
    this.status = statusPending,
    required this.requestedDate,
    this.notifiedDate,
    this.pickupLocation,
  });

  static const String statusPending = 'pending';
  static const String statusReady = 'ready';
  static const String statusFulfilled = 'fulfilled';
  static const String statusCancelled = 'cancelled';

  static const Set<String> validStatuses = {
    statusPending,
    statusReady,
    statusFulfilled,
    statusCancelled,
  };

  final String id;
  final String memberId;
  final String bookId;
  final String branchId;
  final String bookTitle;
  final String bookAuthor;
  final String? bookImageUrl;
  final String status;
  final DateTime requestedDate;
  final DateTime? notifiedDate;
  final String? pickupLocation;

  bool get isReady => status == statusReady;
  bool get isPending => status == statusPending;
  bool get isCancelled => status == statusCancelled;
  bool get isFulfilled => status == statusFulfilled;

  factory HoldRecord.fromFirestore(Map<String, dynamic> data, String id) {
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

    return HoldRecord(
      id: id,
      memberId: data['memberId'] as String? ?? '',
      bookId: data['bookId'] as String? ?? '',
      branchId: data['branchId'] as String? ?? '',
      bookTitle: data['bookTitle'] as String? ?? '',
      bookAuthor: data['bookAuthor'] as String? ?? '',
      bookImageUrl: data['bookImageUrl'] as String?,
      status: data['status'] as String? ?? statusPending,
      requestedDate: parseDateTime(data['requestedDate']),
      notifiedDate: parseNullableDateTime(data['notifiedDate']),
      pickupLocation: data['pickupLocation'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'memberId': memberId,
      'bookId': bookId,
      'branchId': branchId,
      if (bookTitle.isNotEmpty) 'bookTitle': bookTitle,
      if (bookAuthor.isNotEmpty) 'bookAuthor': bookAuthor,
      if (bookImageUrl != null) 'bookImageUrl': bookImageUrl,
      'status': status,
      'requestedDate': Timestamp.fromDate(requestedDate),
      if (notifiedDate != null)
        'notifiedDate': Timestamp.fromDate(notifiedDate!),
      if (pickupLocation != null) 'pickupLocation': pickupLocation,
    };
  }

  HoldRecord copyWith({
    String? id,
    String? memberId,
    String? bookId,
    String? branchId,
    String? bookTitle,
    String? bookAuthor,
    String? bookImageUrl,
    String? status,
    DateTime? requestedDate,
    DateTime? notifiedDate,
    String? pickupLocation,
  }) {
    return HoldRecord(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      bookId: bookId ?? this.bookId,
      branchId: branchId ?? this.branchId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      bookImageUrl: bookImageUrl ?? this.bookImageUrl,
      status: status ?? this.status,
      requestedDate: requestedDate ?? this.requestedDate,
      notifiedDate: notifiedDate ?? this.notifiedDate,
      pickupLocation: pickupLocation ?? this.pickupLocation,
    );
  }
}
