import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/branch.dart';

/// Service responsible for managing library branch operations and querying branch data.
///
/// Encapsulates Firestore branch collection queries and real-time streaming interfaces.
class BranchService {
  BranchService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _customFirestore = firestore,
      _customAuth = auth;

  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  FirebaseAuth get auth => _customAuth ?? FirebaseAuth.instance;

  /// Firestore collection reference for library branches.
  CollectionReference<Map<String, dynamic>> get _branchesCollection =>
      _firestore.collection('branches');

  /// Streams all library branches in real time from the Firestore `branches` collection.
  Stream<List<Branch>> streamBranches() {
    try {
      return _branchesCollection.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return Branch.fromFirestore(doc.data(), doc.id);
        }).toList();
      });
    } catch (e) {
      return Stream.error(e);
    }
  }

  /// Fetches a one-time list of all library branches from Firestore.
  Future<List<Branch>> getBranches() async {
    final snapshot = await _branchesCollection.get();
    return snapshot.docs.map((doc) {
      return Branch.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Fetches a single branch by its document [id].
  ///
  /// Returns `null` if the document does not exist or [id] is empty.
  Future<Branch?> getBranchById(String id) async {
    if (id.trim().isEmpty) return null;
    final doc = await _branchesCollection.doc(id.trim()).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return Branch.fromFirestore(doc.data()!, doc.id);
  }

  /// Streams a single branch by document [id] for real-time detail updates.
  Stream<Branch?> streamBranchById(String id) {
    if (id.trim().isEmpty) {
      return Stream.value(null);
    }
    try {
      return _branchesCollection.doc(id.trim()).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) {
          return null;
        }
        return Branch.fromFirestore(doc.data()!, doc.id);
      });
    } catch (e) {
      return Stream.error(e);
    }
  }
}
