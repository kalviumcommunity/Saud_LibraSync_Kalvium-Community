import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/branch.dart';
import '../repositories/branch_repository.dart';

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository();
});

final branchesStreamProvider = StreamProvider<List<Branch>>((ref) {
  return ref.watch(branchRepositoryProvider).streamBranches();
});

final selectedBranchChipProvider = StateProvider<String>((ref) => 'Central Branch');
