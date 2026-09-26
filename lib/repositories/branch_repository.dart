import '../models/branch.dart';
import '../services/branch_service.dart';

class BranchRepository {
  BranchRepository({BranchService? branchService})
      : _branchService = branchService ?? BranchService();

  final BranchService _branchService;

  Stream<List<Branch>> streamBranches() => _branchService.streamBranches();

  Future<List<Branch>> getBranches() => _branchService.getBranches();

  Future<Branch?> getBranchById(String id) => _branchService.getBranchById(id);
}
