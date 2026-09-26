import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hold_record.dart';

class HoldRepository {
  HoldRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _holdsCol =>
      _firestore.collection('holds');

  Stream<List<HoldRecord>> streamMemberHolds(String memberId) {
    if (memberId.isEmpty) return Stream.value([]);
    return _holdsCol
        .where('memberId', isEqualTo: memberId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => HoldRecord.fromFirestore(d.data(), d.id)).toList());
  }

  Stream<List<HoldRecord>> streamBookHolds(String bookId) {
    return _holdsCol
        .where('bookId', isEqualTo: bookId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => HoldRecord.fromFirestore(d.data(), d.id)).toList());
  }

  Stream<List<HoldRecord>> streamAllHolds({String? branchId}) {
    Query<Map<String, dynamic>> q = _holdsCol;
    if (branchId != null && branchId.isNotEmpty && branchId != 'all') {
      q = q.where('branchId', isEqualTo: branchId);
    }
    return q.snapshots().map((snap) =>
        snap.docs.map((d) => HoldRecord.fromFirestore(d.data(), d.id)).toList());
  }

  Future<void> createHold(HoldRecord hold) async {
    final ref = hold.id.isNotEmpty ? _holdsCol.doc(hold.id) : _holdsCol.doc();
    await ref.set(hold.toFirestore());
  }

  Future<void> cancelHold(String holdId) async {
    await _holdsCol.doc(holdId).update({'status': HoldRecord.statusCancelled});
  }

  Future<void> updateHoldStatus(String holdId, String newStatus) async {
    await _holdsCol.doc(holdId).update({'status': newStatus});
  }
}
