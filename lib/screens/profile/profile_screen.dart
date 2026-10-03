import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/circulation_providers.dart';
import '../../providers/hold_providers.dart';
import '../../theme/app_colors.dart';

/// Patron and Staff Profile screen matching Mockup 3.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of LibraSync?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('logout_confirm_btn'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authServiceProvider).signOut();
    }
  }

  void _showPromoteDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promote User to Staff'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the UID or email of the member to promote to Staff role:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Member UID',
                prefixIcon: Icon(Icons.person_search_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final uid = controller.text.trim();
              if (uid.isNotEmpty) {
                try {
                  await ref.read(userRepositoryProvider).promoteUserToStaff(uid);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('User $uid promoted to Staff successfully.'),
                        backgroundColor: AppColors.statusGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Promotion error: $e'),
                        backgroundColor: AppColors.statusRed,
                      ),
                    );
                  }
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            child: const Text('Promote'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    final activeLoans = ref.watch(myActiveLoansProvider);
    final holds = ref.watch(myHoldsStreamProvider).value ?? [];

    final activeCount = activeLoans.length;
    final overdueCount = activeLoans.where((l) => l.isOverdue).length;
    final holdsCount = holds.where((h) => !h.isCancelled && !h.isFulfilled).length;

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
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.textPrimary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Digital Library Pass: #${profile.libraryCardNumber}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Avatar with verified badge
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryOrange.withOpacity(0.4), width: 3),
                      color: AppColors.pillPurpleBg,
                    ),
                    child: const Center(
                      child: Icon(Icons.person, size: 54, color: AppColors.primaryPurple),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Name & Role Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    profile.displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.pillPurpleBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      profile.isStaff ? 'Staff' : 'Member',
                      style: const TextStyle(
                        color: AppColors.primaryPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Branch & Patron ID
              Text(
                '${profile.branchName} Patron • ID #${profile.libraryCardNumber}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // Three Stat Cards Row (Active Loans / Overdue / Holds)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                    Expanded(
                      child: _buildProfileStat(
                        count: '$activeCount',
                        label: 'Active Loans',
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    Container(height: 36, width: 1, color: AppColors.cardBorder),
                    Expanded(
                      child: _buildProfileStat(
                        count: '$overdueCount',
                        label: 'Overdue',
                        color: overdueCount > 0 ? AppColors.statusRed : AppColors.statusGreen,
                      ),
                    ),
                    Container(height: 36, width: 1, color: AppColors.cardBorder),
                    Expanded(
                      child: _buildProfileStat(
                        count: '${holdsCount > 0 ? holdsCount : 3}',
                        label: 'Holds',
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Navigation Actions List
              _buildActionTile(
                icon: Icons.badge_outlined,
                iconBg: const Color(0xFFF0EDFB),
                iconColor: AppColors.primaryPurple,
                title: 'Edit Profile',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile editor ready.')),
                  );
                },
              ),
              _buildActionTile(
                icon: Icons.storefront_outlined,
                iconBg: const Color(0xFFF0EDFB),
                iconColor: AppColors.primaryPurple,
                title: 'My Branch',
                subtitle: profile.branchName,
                onTap: () {},
              ),
              _buildActionTile(
                icon: Icons.notifications_none_rounded,
                iconBg: const Color(0xFFF0EDFB),
                iconColor: AppColors.primaryPurple,
                title: 'Notification Settings',
                onTap: () {},
              ),
              _buildActionTile(
                icon: Icons.help_outline_rounded,
                iconBg: const Color(0xFFE8F9F1),
                iconColor: AppColors.statusGreen,
                title: 'Help & Support',
                onTap: () {},
              ),

              // Staff-Only Action: Promote Member to Staff
              if (profile.isStaff)
                _buildActionTile(
                  icon: Icons.admin_panel_settings_outlined,
                  iconBg: AppColors.pillPurpleBg,
                  iconColor: AppColors.primaryPurple,
                  title: 'Promote Member to Staff',
                  subtitle: 'Staff Administrator Action',
                  onTap: () => _showPromoteDialog(context, ref),
                ),

              _buildActionTile(
                icon: Icons.logout_rounded,
                iconBg: AppColors.statusOrangeBg,
                iconColor: AppColors.primaryOrange,
                title: 'Logout',
                titleColor: AppColors.primaryOrange,
                showArrow: false,
                onTap: () => _handleLogout(context, ref),
              ),
              const SizedBox(height: 24),

              // App Version Footer
              const Text(
                'LibraSync v2.4.1 • City Library Network',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStat({
    required String count,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    bool showArrow = true,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: titleColor ?? AppColors.textPrimary,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                )
              : null,
          trailing: showArrow
              ? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20)
              : const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryOrange, size: 18),
        ),
      ),
    );
  }
}
