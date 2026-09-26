import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book_copy.dart';
import '../services/book_copy_service.dart';

class BookCopyRepository {
  BookCopyRepository({BookCopyService? copyService, FirebaseFirestore? firestore})
      : _copyService = copyService ?? BookCopyService(firestore: firestore),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final BookCopyService _copyService;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _copiesCol =>
      _firestore.collection('bookCopies');

  Stream<List<BookCopy>> streamCopiesForBook(String bookId) {
    return _copyService.streamCopiesForBook(bookId);
  }

  Stream<List<BookCopy>> streamAvailableCopies(String bookId, {String? branchId}) {
    Query<Map<String, dynamic>> q = _copiesCol
        .where('bookId', isEqualTo: bookId)
        .where('status', isEqualTo: BookCopy.statusAvailable);
    if (branchId != null && branchId.isNotEmpty) {
      q = q.where('branchId', isEqualTo: branchId);
    }
    return q.snapshots().map((snap) =>
        snap.docs.map((d) => BookCopy.fromFirestore(d.data(), d.id)).toList());
  }

  Future<List<BookCopy>> getCopiesForBook(String bookId) {
    return _copyService.getCopiesForBook(bookId);
  }

  Future<BookCopy> createBookCopy({
    required String bookId,
    required String branchId,
    String? barcode,
    String? condition,
  }) {
    final copy = BookCopy(
      id: '',
      bookId: bookId,
      branchId: branchId,
      barcode: barcode,
      condition: condition,
    );
    return _copyService.createCopy(copy, enforceStaffRole: false);
  }

  Future<BookCopy> updateBookCopy(BookCopy copy) {
    return _copyService.updateCopy(copy, enforceStaffRole: false);
  }

  Future<void> deleteBookCopy(String copyId) {
    return _copyService.deleteCopy(copyId, enforceStaffRole: false);
  }
}
