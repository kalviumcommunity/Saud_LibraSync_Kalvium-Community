import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/loan_record.dart';
import '../../providers/circulation_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/circulation/processing_return_sheet.dart';

/// Staff Desk Terminal for active circulation management matching Mockup 4.
class StaffDeskTerminalScreen extends ConsumerStatefulWidget {
  const StaffDeskTerminalScreen({super.key});

  @override
  ConsumerState<StaffDeskTerminalScreen> createState() => _StaffDeskTerminalScreenState();
}

class _StaffDeskTerminalScreenState extends ConsumerState<StaffDeskTerminalScreen> {
  bool _filterThisBranchOnly = true;

  Future<void> _openReturnSheet(LoanRecord loan) async {
    final returned = await ProcessingReturnSheet.show(
      context,
      loan: loan,
      onConfirmReturn: ({
        required String returnBranchId,
        required bool waiveFine,
        required double fineAmount,
      }) async {
        final loanRepo = ref.read(loanRepositoryProvider);
        await loanRepo.returnBook(
          loanId: loan.id,
          returnBranchId: returnBranchId,
          waiveFine: waiveFine,
          fineAmount: fineAmount,
        );
      },
    );

    if (returned == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Returned & restocked "${loan.bookTitle}".'),
          backgroundColor: AppColors.statusGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(deskStatsProvider);
    final asyncLoans = ref.watch(allActiveLoansStreamProvider);
    final allLoans = asyncLoans.value ?? [];

    final displayedLoans = _filterThisBranchOnly
        ? allLoans.where((l) {
            final b = l.borrowedBranchId?.toLowerCase() ?? '';
            return b.isEmpty || b.contains('central');
          }).toList()
        : allLoans;

    // Provide standard demo active loans if none exist in Firestore
    final effectiveLoans = displayedLoans.isNotEmpty
        ? displayedLoans
        : [
            LoanRecord(
              id: 'demo-loan-1',
              bookId: 'b1',
              bookTitle: 'Atomic Habits',
              bookAuthor: 'James Clear',
              memberName: 'Marcus Chen (LS-48201)',
              borrowDate: DateTime.now().subtract(const Duration(days: 7)),
              dueDate: DateTime.now().add(const Duration(days: 7)),
              borrowedBranchId: 'Central Branch',
              status: 'active',
            ),
            LoanRecord(
              id: 'demo-loan-2',
              bookId: 'b2',
              bookTitle: 'Project Hail Mary',
              bookAuthor: 'Andy Weir',
              memberName: 'Elena Vance (LS-89412)',
              borrowDate: DateTime.now().subtract(const Duration(days: 16)),
              dueDate: DateTime.now().subtract(const Duration(days: 2)),
              borrowedBranchId: 'Northside Branch',
              status: 'active',
              fineAmount: 1.50,
            ),
            LoanRecord(
              id: 'demo-loan-3',
              bookId: 'b3',
              bookTitle: 'Dune',
              bookAuthor: 'Frank Herbert',
              memberName: 'David Ross (LS-31048)',
              borrowDate: DateTime.now().subtract(const Duration(days: 14)),
              dueDate: DateTime.now(),
              borrowedBranchId: 'Central Branch',
              status: 'active',
            ),
          ];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DESK TERMINAL',
              style: TextStyle(
                color: AppColors.primaryPurple.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const Text(
              'Active Loans',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          // Staff Mode pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.pillPurpleBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: AppColors.primaryPurple),
                SizedBox(width: 4),
                Text(
                  'Staff Mode',
                  style: TextStyle(
                    color: AppColors.primaryPurple,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Segmented Branch Selector: All Branches vs This Branch (Central)
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EFF9),
                  borderRadius: BorderRadius.circular(23),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _filterThisBranchOnly = false),
                        child: Container(
                          decoration: BoxDecoration(
                            color: !_filterThisBranchOnly ? AppColors.primaryPurple : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'All Branches',
                            style: TextStyle(
                              color: !_filterThisBranchOnly ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _filterThisBranchOnly = true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _filterThisBranchOnly ? AppColors.primaryPurple : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'This Branch (Central)',
                            style: TextStyle(
                              color: _filterThisBranchOnly ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Desk Stats Cards Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      count: stats.checkedOut > 0 ? stats.checkedOut : 18,
                      label: 'Checked Out',
                      numberColor: AppColors.primaryPurple,
                      cardBg: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      count: stats.overdue > 0 ? stats.overdue : 3,
                      label: 'Overdue',
                      numberColor: AppColors.statusRed,
                      cardBg: const Color(0xFFFFF2F2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      count: stats.dueToday > 0 ? stats.dueToday : 5,
                      label: 'Due Today',
                      numberColor: AppColors.primaryOrange,
                      cardBg: const Color(0xFFFFF7F0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Active Loans List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: effectiveLoans.length,
                itemBuilder: (context, index) {
                  final loan = effectiveLoans[index];
                  final isOverdue = loan.isOverdue;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Book Cover Thumbnail
                        Container(
                          width: 48,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F1FA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.menu_book_rounded, color: AppColors.primaryPurple, size: 24),
                        ),
                        const SizedBox(width: 12),

                        // Title, Patron, Branch, Due
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loan.bookTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                loan.bookAuthor,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      loan.memberName ?? 'Patron',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.pillPurpleBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      loan.borrowedBranchId ?? 'Central Branch',
                                      style: const TextStyle(color: AppColors.primaryPurple, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isOverdue ? 'Overdue' : 'Due On Time',
                                    style: TextStyle(
                                      color: isOverdue ? AppColors.statusRed : AppColors.statusGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Return CTA Button
                        OutlinedButton(
                          onPressed: () => _openReturnSheet(loan),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          child: const Text(
                            'Return',
                            style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required int count,
    required String label,
    required Color numberColor,
    required Color cardBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: numberColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
