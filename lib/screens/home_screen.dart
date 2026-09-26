import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/book_service.dart';
import '../services/branch_service.dart';
import '../services/circulation_service.dart';
import '../theme/app_colors.dart';
import '../widgets/dashboard_card.dart';
import 'branches/branches_screen.dart';
import 'catalog/book_catalog_screen.dart';
import 'circulation/member_circulation_screen.dart';
import 'circulation/member_dashboard_screen.dart';
import 'circulation/staff_desk_terminal_screen.dart';
import 'holds/holds_screen.dart';
import 'profile/profile_screen.dart';

/// The main home / navigation shell screen for LibraSync.
///
/// Displays the welcoming banner, quick access cards, circulation dashboard,
/// and the 5 persistent bottom navigation tabs matching the mockups.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.authService,
    this.bookService,
    this.circulationService,
    this.branchService,
    this.isStaff,
    this.userRole,
  });

  final AuthService? authService;
  final BookService? bookService;
  final CirculationService? circulationService;
  final BranchService? branchService;
  final bool? isStaff;
  final String? userRole;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late bool _isStaff;
  late String _userRole;
  int _selectedTab = 2; // Default to Circulation tab

  AuthService get _authService => widget.authService ?? AuthService();

  @override
  void initState() {
    super.initState();
    _isStaff = widget.isStaff ?? false;
    _userRole = widget.userRole ?? 'member';
    _checkUserRole();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.authService != oldWidget.authService ||
        widget.isStaff != oldWidget.isStaff ||
        widget.userRole != oldWidget.userRole) {
      _checkUserRole();
    }
  }

  Future<void> _checkUserRole() async {
    if (widget.userRole != null || widget.isStaff != null) {
      if (mounted) {
        setState(() {
          _userRole = widget.userRole ?? (_isStaff ? 'staff' : 'member');
          _isStaff =
              widget.isStaff ?? (_userRole == 'staff' || _userRole == 'admin');
        });
      }
      return;
    }

    try {
      final role = await _authService.getUserRole();
      final isStaff = await _authService.isStaffUser();
      if (mounted) {
        setState(() {
          _userRole = role;
          _isStaff = isStaff;
        });
      }
    } catch (_) {
      // In case of unauthenticated / network / test default, fall through to member
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
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

    if (shouldLogout == true) {
      await _authService.signOut();
    }
  }

  void _onTabSelected(int index) {
    if (index == _selectedTab) return;
    if (index == 0) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BranchesScreen(branchService: widget.branchService),
        ),
      );
    } else if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookCatalogScreen(
            bookService: widget.bookService,
            circulationService: widget.circulationService,
            isStaff: _isStaff,
          ),
        ),
      );
    } else if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _isStaff
              ? const StaffDeskTerminalScreen()
              : const MemberDashboardScreen(),
        ),
      );
    } else if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HoldsScreen()),
      );
    } else if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = _authService.currentUser;

    return ProviderScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('LibraSync'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => _onTabSelected(4),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Log Out',
              onPressed: () => _handleLogout(context),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Welcome Banner ──────────────────────────────────────
                _WelcomeBanner(
                  colorScheme: colorScheme,
                  user: currentUser,
                  userRole: _userRole,
                  isStaff: _isStaff,
                ),
                const SizedBox(height: 20),

                // ── Section Title ───────────────────────────────────────
                Text(
                  'Quick Access',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // ── Dashboard Grid ──────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 600 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        DashboardCard(
                          icon: Icons.menu_book_rounded,
                          label: 'Books',
                          count: null,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => BookCatalogScreen(
                                  bookService: widget.bookService,
                                  circulationService: widget.circulationService,
                                  isStaff: _isStaff,
                                ),
                              ),
                            );
                          },
                        ),
                        DashboardCard(
                          icon: Icons.people_alt_rounded,
                          label: 'Members',
                          count: null,
                          onTap: () => _onTabSelected(4),
                        ),
                        DashboardCard(
                          icon: Icons.location_city_rounded,
                          label: 'Branches',
                          count: null,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => BranchesScreen(
                                  branchService: widget.branchService,
                                ),
                              ),
                            );
                          },
                        ),
                        DashboardCard(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Borrowing',
                          count: null,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MemberCirculationScreen(
                                  circulationService: widget.circulationService,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ── Recent Activity Section ─────────────────────────────
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 16,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 48,
                            color: colorScheme.onSurfaceVariant.withAlpha(120),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No recent activity yet.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              _buildTabItem(0, 'Branch', Icons.storefront_outlined, Icons.storefront_rounded),
              _buildTabItem(1, 'Catalogue', Icons.menu_book_outlined, Icons.menu_book_rounded),
              _buildTabItem(2, 'Circulation', Icons.swap_horiz_rounded, Icons.swap_horiz_rounded, isCirculation: true),
              _buildTabItem(3, 'Holds', Icons.bookmark_outline_rounded, Icons.bookmark_rounded),
              _buildTabItem(4, 'Profile', Icons.person_outline_rounded, Icons.person_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon, IconData activeIcon, {bool isCirculation = false}) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => _onTabSelected(index),
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

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.colorScheme,
    required this.user,
    required this.userRole,
    required this.isStaff,
  });

  final ColorScheme colorScheme;
  final User? user;
  final String userRole;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    final userGreeting =
        user?.displayName != null && user!.displayName!.trim().isNotEmpty
        ? 'Hello, ${user!.displayName}! ${isStaff ? 'Manage your library catalog and collections.' : 'Manage your library collection.'}'
        : (isStaff
              ? 'Staff Management Portal.'
              : 'Your community library management hub.');

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              isStaff
                  ? Icons.admin_panel_settings_rounded
                  : Icons.local_library_rounded,
              size: 48,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Welcome to LibraSync',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        key: Key(
                          'home_role_badge_${isStaff ? 'staff' : 'member'}',
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isStaff
                              ? colorScheme.primary
                              : colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isStaff ? 'Staff' : 'Member',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isStaff
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSecondaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userGreeting,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
