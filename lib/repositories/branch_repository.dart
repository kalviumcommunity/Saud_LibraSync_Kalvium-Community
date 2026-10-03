import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/demo_data.dart';
import '../models/branch.dart';
import '../services/branch_service.dart';

class BranchRepository {
  BranchRepository({
    BranchService? branchService,
    FirebaseFirestore? firestore,
    this.useStaticData = true,
  }) : _branchService = branchService ?? BranchService(firestore: firestore);

  final BranchService _branchService;
  final bool useStaticData;

  Stream<List<Branch>> streamBranches() {
    if (useStaticData) {
      return Stream.value(demoBranches);
    }
    return _branchService.streamBranches();
  }

  Future<List<Branch>> getBranches() async {
    if (useStaticData) {
      return demoBranches;
    }
    return _branchService.getBranches();
  }

  Future<Branch?> getBranchById(String id) async {
    if (useStaticData) {
      try {
        return demoBranches.firstWhere((b) => b.id == id);
      } catch (_) {
        return null;
      }
    }
    return _branchService.getBranchById(id);
  }

  Future<Branch> upsertBranch(Branch branch) => _branchService.upsertBranch(branch);
}


