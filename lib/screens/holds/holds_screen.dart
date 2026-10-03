import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/hold_record.dart';
import '../../providers/hold_providers.dart';
import '../../theme/app_colors.dart';

/// Screen displaying active member holds and reservations.
class HoldsScreen extends ConsumerWidget {
  const HoldsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHolds = ref.watch(myHoldsStreamProvider);
    final holds = asyncHolds.value ?? [];
    final activeHolds = holds.where((h) => !h.isCancelled && !h.isFulfilled).toList();

    // Standard demo holds if none in firestore yet
    final displayHolds = activeHolds.isNotEmpty
        ? activeHolds
        : [
            HoldRecord(
              id: 'h1',
              memberId: 'm1',
              bookId: 'b1',
              bookTitle: 'Tomorrow, and Tomorrow, and Tomorrow',
              bookAuthor: 'Gabrielle Zevin',
              branchId: 'Central Branch',
              status: HoldRecord.statusReady,
              requestedDate: DateTime.now().subtract(const Duration(days: 4)),
              notifiedDate: DateTime.now().subtract(const Duration(days: 1)),
              pickupLocation: 'Lockers (#14)',
            ),
            HoldRecord(
              id: 'h2',
              memberId: 'm1',
              bookId: 'b2',
              bookTitle: 'Demon Copperhead',
              bookAuthor: 'Barbara Kingsolver',
              branchId: 'Downtown Central',
              status: HoldRecord.statusPending,
              requestedDate: DateTime.now().subtract(const Duration(days: 2)),
              pickupLocation: 'Main Desk',
            ),
          ];

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
          child: const Icon(Icons.bookmark_rounded, color: AppColors.primaryPurple, size: 20),
        ),
        title: const Text(
          'My Holds & Reservations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${displayHolds.length} Active Reservations',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayHolds.length,
                itemBuilder: (context, index) {
                  final hold = displayHolds[index];
                  final isReady = hold.isReady;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isReady ? AppColors.statusGreenBg : AppColors.statusOrangeBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isReady ? Icons.check_circle : Icons.hourglass_top_rounded,
                                    size: 12,
                                    color: isReady ? AppColors.statusGreen : AppColors.statusOrange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isReady ? 'Ready for Pickup' : 'Waitlist / Pending',
                                    style: TextStyle(
                                      color: isReady ? AppColors.statusGreen : AppColors.statusOrange,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Cancel Hold'),
                                    content: Text('Cancel your hold for "${hold.bookTitle}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Keep Hold'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        style: FilledButton.styleFrom(backgroundColor: AppColors.statusRed),
                                        child: const Text('Cancel Hold'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref.read(holdRepositoryProvider).cancelHold(hold.id);
                                }
                              },
                              child: const Text('Cancel Hold', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          hold.bookTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hold.bookAuthor,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primaryPurple),
                            const SizedBox(width: 4),
                            Text(
                              '${hold.branchId} • ${hold.pickupLocation ?? 'Lockers (#14)'}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
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
}
