import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/dashboard_card.dart';

/// The main home / dashboard screen for LibraSync.
///
/// Displays a welcoming banner and a responsive grid of category cards
/// that will be wired to real screens in future milestones.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthService().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LibraSync'),
        actions: [
          // Placeholder for future profile / settings actions.
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          // Logout Action
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Out',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome Banner ──────────────────────────────────────
              _WelcomeBanner(colorScheme: colorScheme),
              const SizedBox(height: 24),

              // ── Section Title ───────────────────────────────────────
              Text(
                'Quick Access',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // ── Dashboard Grid ──────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  // Use 2 columns on narrow screens, 4 on wide screens.
                  final crossAxisCount =
                      constraints.maxWidth >= 600 ? 4 : 2;
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
                        count: 0,
                        onTap: () => _showComingSoon(context, 'Books'),
                      ),
                      DashboardCard(
                        icon: Icons.people_alt_rounded,
                        label: 'Members',
                        count: 0,
                        onTap: () => _showComingSoon(context, 'Members'),
                      ),
                      DashboardCard(
                        icon: Icons.location_city_rounded,
                        label: 'Branches',
                        count: 0,
                        onTap: () => _showComingSoon(context, 'Branches'),
                      ),
                      DashboardCard(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Borrowing',
                        count: 0,
                        onTap: () => _showComingSoon(context, 'Borrowing'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Recent Activity Placeholder ─────────────────────────
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Card(
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
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
    );
  }

  /// Shows a floating snackbar indicating the feature is coming soon.
  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature screen coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Private Widgets ──────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final userGreeting = user?.displayName != null && user!.displayName!.trim().isNotEmpty
        ? 'Hello, ${user.displayName}! Manage your library collection.'
        : 'Your community library management hub.';

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.local_library_rounded,
              size: 48,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to LibraSync',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userGreeting,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
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
