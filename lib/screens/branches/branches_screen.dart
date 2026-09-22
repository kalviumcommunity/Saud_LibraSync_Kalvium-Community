import 'package:flutter/material.dart';

import '../../models/branch.dart';
import '../../services/branch_service.dart';
import '../../widgets/branches/branch_card.dart';

/// Screen displaying all library branches available in LibraSync.
///
/// Features real-time Firestore stream integration, loading, error, and empty states,
/// and support for manual stream refresh.
class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key, this.branchService, this.branchesStream});

  /// Optional branch service instance for dependency injection.
  final BranchService? branchService;

  /// Optional custom stream of branches for testing or custom filtering.
  final Stream<List<Branch>>? branchesStream;

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  late Stream<List<Branch>> _stream;
  Key _streamKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    if (widget.branchesStream != null) {
      _stream = widget.branchesStream!;
    } else {
      final service = widget.branchService ?? BranchService();
      _stream = service.streamBranches();
    }
  }

  void _retryStream() {
    setState(() {
      _streamKey = UniqueKey();
      _initStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Branches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh branches',
            onPressed: _retryStream,
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Branch>>(
          key: _streamKey,
          stream: _stream,
          builder: (context, snapshot) {
            // ── Loading State ──────────────────────────────────────────
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _BranchesLoadingView();
            }

            // ── Error State ────────────────────────────────────────────
            if (snapshot.hasError) {
              return _BranchesErrorView(
                error: snapshot.error.toString(),
                onRetry: _retryStream,
              );
            }

            final branches = snapshot.data ?? [];

            // ── Empty State ────────────────────────────────────────────
            if (branches.isEmpty) {
              return const _BranchesEmptyView();
            }

            // ── Populated Branches List ────────────────────────────────
            return _BranchesListView(branches: branches);
          },
        ),
      ),
    );
  }
}

// ── Populated Branches List View ─────────────────────────────────────────────

class _BranchesListView extends StatelessWidget {
  const _BranchesListView({required this.branches});

  final List<Branch> branches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Summary Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${branches.length} ${branches.length == 1 ? 'branch' : 'branches'} currently active in the LibraSync network.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Branch Cards List
            ...branches.map(
              (branch) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BranchCard(
                  key: Key('branch_card_${branch.id}'),
                  branch: branch,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── State Views ─────────────────────────────────────────────────────────────

class _BranchesLoadingView extends StatelessWidget {
  const _BranchesLoadingView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading library branches...',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _BranchesEmptyView extends StatelessWidget {
  const _BranchesEmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withAlpha(140),
            ),
            const SizedBox(height: 16),
            Text(
              'No Branches Available',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no library branches registered at the moment.\nPlease check back later.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchesErrorView extends StatelessWidget {
  const _BranchesErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load library branches',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('branches_retry_btn'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
