import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  Stream<UserProfile?> streamUserProfile(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _usersCol.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromFirestore(doc.data()!, doc.id);
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _usersCol.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromFirestore(doc.data()!, doc.id);
  }

  Future<void> createUserProfile(UserProfile profile) async {
    await _usersCol.doc(profile.uid).set(profile.toFirestore(), SetOptions(merge: true));
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    // Only update non-role fields for normal self updates
    final map = profile.toFirestore();
    map.remove('role'); // Safeguard against self-elevation
    await _usersCol.doc(profile.uid).update(map);
  }

  /// Staff/admin action to promote another user to staff
  Future<void> promoteUserToStaff(String targetUid) async {
    await _usersCol.doc(targetUid).update({'role': 'staff'});
  }

  /// Search patrons by name or card number/barcode for staff borrow flow
  Future<List<UserProfile>> searchPatrons(String query) async {
    final trimmed = query.trim().toLowerCase();
    final snapshot = await _usersCol.get();
    final all = snapshot.docs
        .map((d) => UserProfile.fromFirestore(d.data(), d.id))
        .toList();
    if (trimmed.isEmpty) return all;
    return all.where((p) {
      final name = p.displayName.toLowerCase();
      final email = p.email.toLowerCase();
      final card = p.libraryCardNumber.toLowerCase();
      return name.contains(trimmed) || email.contains(trimmed) || card.contains(trimmed);
    }).toList();
  }
}
