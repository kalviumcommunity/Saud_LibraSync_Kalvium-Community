import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/loan_record.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../providers/circulation_providers.dart';
import '../../theme/app_colors.dart';

/// Screen displaying Member's personal loans, goals, and renewals matching Mockup 5.
class MyLoansScreen extends ConsumerStatefulWidget {
  const MyLoansScreen({super.key});

  @override
  ConsumerState<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends ConsumerState<MyLoansScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _renewLoan(LoanRecord loan) async {
    try {
      final loanRepo = ref.read(loanRepositoryProvider);
      await loanRepo.renewLoan(loan.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renewed "${loan.bookTitle}" for 14 additional days.'),
            backgroundColor: AppColors.statusGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renewal failed: $e'),
            backgroundColor: AppColors.statusRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider);
    final activeLoans = ref.watch(myActiveLoansProvider);
    final dueSoonLoans = ref.watch(myDueSoonLoansProvider);
    final returnedLoans = ref.watch(myReturnedLoansProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.pillPurpleBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_library_rounded, color: AppColors.primaryPurple, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LibraSync',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
            ),
            Text(
              'Central Pass #${profile.libraryCardNumber}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Active Card Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Loans',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${activeLoans.length} borrowed items across branches',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECE7FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 6, color: AppColors.primaryOrange),
                        SizedBox(width: 4),
                        Text(
                          'Active Card',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Goal Card
              _buildGoalCard(profile, activeLoans.length),
              const SizedBox(height: 20),

              // Tab Bar (All, Due Soon, History)
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primaryPurple,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(text: 'All (${activeLoans.length})'),
                    Tab(text: 'Due Soon (${dueSoonLoans.length})'),
                    Tab(text: 'History (${returnedLoans.length})'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Views
              SizedBox(
                height: 600,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoansList(activeLoans),
                    _buildLoansList(dueSoonLoans),
                    _buildLoansList(returnedLoans, isHistory: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(UserProfile? profile, int activeCount) {
    const goalPercent = 0.40;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Progress Arc
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: goalPercent,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFFEFEFF9),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                ),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '40%',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  Text(
                    'GOAL',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Goal Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.pillPurpleBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Good Standing Patron',
                    style: TextStyle(color: AppColors.primaryPurple, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$activeCount Active in Hand',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Goal: ${profile?.booksReadThisYear ?? 8} of ${profile?.readingGoal ?? 20} read in 2023',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 14, color: AppColors.statusGreen),
                    SizedBox(width: 4),
                    Text(
                      '0 Overdue Fines',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansList(List<LoanRecord> loans, {bool isHistory = false}) {
    if (loans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              isHistory ? 'No reading history yet.' : 'No active loans in this category.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        final daysLeft = loan.daysUntilDue;
        final isDueSoon = daysLeft <= 5;
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final borrowDateFormatted = '${months[loan.borrowDate.month - 1]} ${loan.borrowDate.day.toString().padLeft(2, '0')}, ${loan.borrowDate.year}';
        final dueDateFormatted = '${months[loan.dueDate.month - 1]} ${loan.dueDate.day.toString().padLeft(2, '0')}, ${loan.dueDate.year}';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge & 3-dot row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDueSoon ? AppColors.statusOrangeBg : AppColors.statusGreenBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isDueSoon ? 'Due Soon • $daysLeft Days Left' : 'On Time • $daysLeft Days Left',
                      style: TextStyle(
                        color: isDueSoon ? AppColors.statusOrange : AppColors.statusGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.more_horiz, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 12),

              // Book Details Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book Thumbnail
                  Container(
                    width: 60,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0FC),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: AppColors.primaryPurple, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.bookTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loan.bookAuthor,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              'Borrowed: $borrowDateFormatted',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 13, color: AppColors.primaryOrange),
                            const SizedBox(width: 4),
                            Text(
                              'Due: $dueDateFormatted',
                              style: const TextStyle(
                                color: AppColors.primaryOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Location chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primaryPurple),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${loan.borrowedBranchId ?? 'Central Branch'} • Stack 4B | Call #613.2 CLE',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (loan.progressPercent != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Personal reading log', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text('${loan.progressPercent}%', style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (loan.progressPercent! / 100).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFEBE8F8),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Renew Loan & Map buttons (for active loans)
              if (!isHistory)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _renewLoan(loan),
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('Renew Loan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Branch map: Stack 4B, Level 2, Central Library'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.map_outlined, size: 18, color: AppColors.primaryPurple),
                        label: const Text('Map', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
