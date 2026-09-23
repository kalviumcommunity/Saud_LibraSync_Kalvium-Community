import 'package:flutter/material.dart';

import '../../models/loan_record.dart';
import '../../services/auth_service.dart';
import '../../services/circulation_service.dart';
import '../../widgets/circulation/borrowed_book_card.dart';
import '../../widgets/circulation/return_confirmation_dialog.dart';
import '../catalog/book_catalog_screen.dart';

/// Screen displaying all currently borrowed books for the authenticated member.
///
/// Handles real-time active loan streams, loading, empty, and error states,
/// and provides the return book confirmation action.
class MemberCirculationScreen extends StatefulWidget {
  const MemberCirculationScreen({
    super.key,
    this.circulationService,
    this.loansStream,
    this.memberId,
  });

  /// Optional circulation service instance.
  final CirculationService? circulationService;

  /// Optional custom stream of active loan records (useful for testing or custom member filters).
  final Stream<List<LoanRecord>>? loansStream;

  /// Optional member identifier. Defaults to the current logged-in user.
  final String? memberId;

  @override
  State<MemberCirculationScreen> createState() =>
      _MemberCirculationScreenState();
}

class _MemberCirculationScreenState extends State<MemberCirculationScreen> {
  late Stream<List<LoanRecord>> _stream;
  Key _streamKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant MemberCirculationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loansStream != oldWidget.loansStream ||
        widget.circulationService != oldWidget.circulationService ||
        widget.memberId != oldWidget.memberId) {
      _retryStream();
    }
  }

  void _initStream() {
    if (widget.loansStream != null) {
      _stream = widget.loansStream!;
    } else {
      final service = widget.circulationService ?? CirculationService();
      final currentMemberId = widget.memberId ?? AuthService().currentUser?.uid;
      _stream = service.streamActiveLoans(memberId: currentMemberId);
    }
  }

  void _retryStream() {
    setState(() {
      _streamKey = UniqueKey();
      _initStream();
    });
  }

  Future<void> _handleReturn(LoanRecord loan) async {
    final returned = await ReturnConfirmationDialog.show(
      context,
      loan: loan,
      circulationService: widget.circulationService,
    );

    if (returned == true && mounted) {
      _retryStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Borrowed Books'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh loans',
            onPressed: _retryStream,
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<LoanRecord>>(
          key: _streamKey,
          stream: _stream,
          builder: (context, snapshot) {
            // ── Loading State ──────────────────────────────────────────
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _CirculationLoadingView();
            }

            // ── Error State ────────────────────────────────────────────
            if (snapshot.hasError) {
              return _CirculationErrorView(
                error: snapshot.error.toString(),
                onRetry: _retryStream,
              );
            }

            final activeLoans = snapshot.data ?? [];

            // ── Empty State ────────────────────────────────────────────
            if (activeLoans.isEmpty) {
              return _CirculationEmptyView(
                onBrowseCatalog: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const BookCatalogScreen(),
                    ),
                  );
                },
              );
            }

            // ── Populated Active Loans View ────────────────────────────
            return _CirculationListView(
              loans: activeLoans,
              onReturnTap: _handleReturn,
            );
          },
        ),
      ),
    );
  }
}

// ── Populated Loans List View ───────────────────────────────────────────────

class _CirculationListView extends StatelessWidget {
  const _CirculationListView({required this.loans, required this.onReturnTap});

  final List<LoanRecord> loans;
  final void Function(LoanRecord loan) onReturnTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final overdueCount = loans.where((l) => l.isOverdue).length;

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
                color: overdueCount > 0
                    ? colorScheme.errorContainer.withAlpha(120)
                    : colorScheme.primaryContainer.withAlpha(100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    overdueCount > 0
                        ? Icons.warning_amber_rounded
                        : Icons.auto_stories_rounded,
                    color: overdueCount > 0
                        ? colorScheme.error
                        : colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      overdueCount > 0
                          ? 'You have $overdueCount overdue book(s) requiring attention.'
                          : 'You currently have ${loans.length} active borrowed book(s).',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: overdueCount > 0
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Loan Cards List
            ...loans.map(
              (loan) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BorrowedBookCard(
                  key: Key('loan_card_${loan.id}'),
                  loan: loan,
                  onReturn: () => onReturnTap(loan),
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

class _CirculationLoadingView extends StatelessWidget {
  const _CirculationLoadingView();

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
            'Loading your borrowed books...',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CirculationEmptyView extends StatelessWidget {
  const _CirculationEmptyView({required this.onBrowseCatalog});

  final VoidCallback onBrowseCatalog;

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
              Icons.bookmark_border_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withAlpha(140),
            ),
            const SizedBox(height: 16),
            Text(
              'No Books Borrowed',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have any books currently borrowed from the library.\nBrowse the catalog to find your next great read!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('circulation_browse_catalog_btn'),
              onPressed: onBrowseCatalog,
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Browse Book Catalog'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CirculationErrorView extends StatelessWidget {
  const _CirculationErrorView({required this.error, required this.onRetry});

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
              'Failed to load borrowed books',
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
              key: const Key('circulation_retry_btn'),
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
