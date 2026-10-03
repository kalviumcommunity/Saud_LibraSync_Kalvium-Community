import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/demo_data.dart';
import '../models/book_copy.dart';
import '../services/book_copy_service.dart';

class BookCopyRepository {
  BookCopyRepository({
    BookCopyService? copyService,
    FirebaseFirestore? firestore,
    this.useStaticData = true,
  })  : _copyService = copyService ?? BookCopyService(firestore: firestore),
        _customFirestore = firestore;

  final BookCopyService _copyService;
  final FirebaseFirestore? _customFirestore;
  final bool useStaticData;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _copiesCol =>
      _firestore.collection('bookCopies');

  Stream<List<BookCopy>> streamCopiesForBook(String bookId) {
    if (useStaticData) {
      return Stream.value(
        demoBookCopies.where((c) => c.bookId == bookId).toList(),
      );
    }
    return _copyService.streamCopiesForBook(bookId);
  }

  Stream<List<BookCopy>> streamAvailableCopies(String bookId, {String? branchId}) {
    if (useStaticData) {
      return Stream.value(
        demoBookCopies.where((c) {
          if (c.bookId != bookId) return false;
          if (c.status != BookCopy.statusAvailable) return false;
          if (branchId != null && branchId.isNotEmpty && c.branchId != branchId) {
            return false;
          }
          return true;
        }).toList(),
      );
    }
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
    if (useStaticData) {
      return Future.value(
        demoBookCopies.where((c) => c.bookId == bookId).toList(),
      );
    }
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

  Future<BookCopy> upsertBookCopy(BookCopy copy, {bool enforceStaffRole = false}) {
    return _copyService.upsertCopy(copy, enforceStaffRole: enforceStaffRole);
  }

  Future<void> deleteBookCopy(String copyId) {
    return _copyService.deleteCopy(copyId, enforceStaffRole: false);
  }
}
