import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/book.dart';
import '../models/loan_record.dart';

/// Service responsible for managing member circulation and book loan operations.
///
/// Encapsulates loan queries and provides clean UI-ready service interfaces.
class CirculationService {
  CirculationService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _loansCollection =>
      _firestore.collection('loans');

  /// Streams active loans for a specific member, or all active loans if [memberId] is null.
  Stream<List<LoanRecord>> streamActiveLoans({String? memberId}) {
    try {
      Query<Map<String, dynamic>> query =
          _loansCollection.where('status', isEqualTo: 'active');

      if (memberId != null && memberId.trim().isNotEmpty) {
        query = query.where('memberId', isEqualTo: memberId);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return LoanRecord.fromFirestore(doc.data(), doc.id);
        }).toList();
      });
    } catch (e) {
      return Stream.error(e);
    }
  }

  /// Fetches a one-time snapshot of active loans.
  Future<List<LoanRecord>> getActiveLoans({String? memberId}) async {
    Query<Map<String, dynamic>> query =
        _loansCollection.where('status', isEqualTo: 'active');

    if (memberId != null && memberId.trim().isNotEmpty) {
      query = query.where('memberId', isEqualTo: memberId);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return LoanRecord.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Initiates a borrow operation for the given [book] by [memberId].
  ///
  /// NOTE: The transactional Firestore writes (decrementing available copies
  /// and creating the loan document atomically) are reserved for the backend milestone.
  Future<void> requestBorrow({
    required Book book,
    required String memberId,
    String? memberName,
  }) async {
    // Placeholder for transactional backend milestone.
    // In UI tests and mock implementations, custom handlers can be injected.
    throw UnimplementedError(
      'Borrowing transactions will be connected in the backend circulation milestone.',
    );
  }

  /// Initiates a return operation for the given [loanId].
  ///
  /// NOTE: Transactional updates (incrementing available copies and updating
  /// loan status) are reserved for the backend milestone.
  Future<void> requestReturn({
    required String loanId,
  }) async {
    // Placeholder for transactional backend milestone.
    throw UnimplementedError(
      'Return transactions will be connected in the backend circulation milestone.',
    );
  }
}
