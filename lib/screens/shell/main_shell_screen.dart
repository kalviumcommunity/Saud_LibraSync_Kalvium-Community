import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../branches/branches_screen.dart';
import '../catalog/member_book_catalog_view.dart';
import '../catalog/staff_book_management_view.dart';
import '../circulation/member_dashboard_screen.dart';
import '../circulation/staff_desk_terminal_screen.dart';
import '../holds/holds_screen.dart';
import '../profile/profile_screen.dart';

/// Main navigation shell hosting the 5 persistent tabs matching the mockups.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key, this.initialTab = 2});

  final int initialTab;

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = ref.watch(isStaffProvider);

    final List<Widget> pages = [
      const BranchesScreen(),
      isStaff ? const StaffBookManagementView() : const MemberBookCatalogView(),
      isStaff ? const StaffDeskTerminalScreen() : const MemberDashboardScreen(),
      const HoldsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              index: 0,
              label: 'Branches',
              icon: Icons.storefront_outlined,
              activeIcon: Icons.storefront_rounded,
            ),
            _buildNavItem(
              index: 1,
              label: 'Catalogue',
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book_rounded,
            ),
            _buildNavItem(
              index: 2,
              label: 'Circulation',
              icon: Icons.swap_horiz_rounded,
              activeIcon: Icons.swap_horiz_rounded,
              showBadgeDot: true,
            ),
            _buildNavItem(
              index: 3,
              label: 'Holds',
              icon: Icons.bookmark_outline_rounded,
              activeIcon: Icons.bookmark_rounded,
            ),
            _buildNavItem(
              index: 4,
              label: 'Profile',
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    bool showBadgeDot = false,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? AppColors.primaryPurple : AppColors.textMuted,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.primaryPurple : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          if (isSelected)
            Container(
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else
            const SizedBox(height: 2),
        ],
      ),
    );
  }
}
