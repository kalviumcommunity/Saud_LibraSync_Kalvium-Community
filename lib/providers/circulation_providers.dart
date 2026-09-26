import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loan_record.dart';
import '../repositories/loan_repository.dart';
import 'auth_providers.dart';

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return LoanRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Member's active and returned loans
final myLoansStreamProvider = StreamProvider<List<LoanRecord>>((ref) {
  final user = ref.watch(authStateStreamProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(loanRepositoryProvider).streamMemberLoans(user.uid);
});

/// Member's active loans only
final myActiveLoansProvider = Provider<List<LoanRecord>>((ref) {
  final allLoans = ref.watch(myLoansStreamProvider).value ?? [];
  return allLoans.where((l) => l.status == 'active').toList();
});

/// Member's loan history (returned loans)
final myReturnedLoansProvider = Provider<List<LoanRecord>>((ref) {
  final allLoans = ref.watch(myLoansStreamProvider).value ?? [];
  return allLoans.where((l) => l.status == 'returned').toList();
});

/// Member loans due soon (within 7 days)
final myDueSoonLoansProvider = Provider<List<LoanRecord>>((ref) {
  final activeLoans = ref.watch(myActiveLoansProvider);
  return activeLoans.where((l) => l.daysUntilDue <= 7).toList();
});

/// All active loans across all branches (or filtered for staff desk)
final staffDeskBranchFilterProvider = StateProvider<String>((ref) => 'all');

final allActiveLoansStreamProvider = StreamProvider<List<LoanRecord>>((ref) {
  final branchFilter = ref.watch(staffDeskBranchFilterProvider);
  return ref.watch(loanRepositoryProvider).streamAllActiveLoans(
        branchId: branchFilter == 'all' ? null : branchFilter,
      );
});

/// Desk metrics for staff
class DeskStats {
  const DeskStats({
    required this.checkedOut,
    required this.overdue,
    required this.dueToday,
  });
  final int checkedOut;
  final int overdue;
  final int dueToday;
}

final deskStatsProvider = Provider<DeskStats>((ref) {
  final loans = ref.watch(allActiveLoansStreamProvider).value ?? [];
  int overdue = 0;
  int dueToday = 0;
  final now = DateTime.now();

  for (final loan in loans) {
    if (loan.isOverdue) {
      overdue++;
    } else if (loan.dueDate.year == now.year &&
        loan.dueDate.month == now.month &&
        loan.dueDate.day == now.day) {
      dueToday++;
    }
  }

  return DeskStats(
    checkedOut: loans.length,
    overdue: overdue,
    dueToday: dueToday,
  );
});
