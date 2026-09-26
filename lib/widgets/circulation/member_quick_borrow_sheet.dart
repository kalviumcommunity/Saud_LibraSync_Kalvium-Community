import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../models/book_copy.dart';
import '../../theme/app_colors.dart';

/// Single-step borrow confirmation sheet for Members matching requirement 4.
class MemberQuickBorrowSheet extends StatefulWidget {
  const MemberQuickBorrowSheet({
    super.key,
    required this.book,
    this.availableCopy,
    this.branchName = 'Central Branch',
    required this.onConfirm,
  });

  final Book book;
  final BookCopy? availableCopy;
  final String branchName;
  final Future<void> Function({required String branchId, String? copyId}) onConfirm;

  static Future<bool?> show(
    BuildContext context, {
    required Book book,
    BookCopy? availableCopy,
    String branchName = 'Central Branch',
    required Future<void> Function({required String branchId, String? copyId}) onConfirm,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemberQuickBorrowSheet(
        book: book,
        availableCopy: availableCopy,
        branchName: branchName,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<MemberQuickBorrowSheet> createState() => _MemberQuickBorrowSheetState();
}

class _MemberQuickBorrowSheetState extends State<MemberQuickBorrowSheet> {
  bool _isLoading = false;

  Future<void> _handleBorrow() async {
    setState(() => _isLoading = true);
    try {
      await widget.onConfirm(
        branchId: widget.availableCopy?.branchId ?? 'central',
        copyId: widget.availableCopy?.id,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Borrow error: ${e.toString()}'),
            backgroundColor: AppColors.statusRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dueDate = now.add(const Duration(days: 14));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dueFormatted = '${months[dueDate.month - 1]} ${dueDate.day}, ${dueDate.year}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D0E5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.pillPurpleBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.menu_book_rounded, color: AppColors.primaryPurple, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.book.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.book.author,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.branchName} • 14 Days Loan',
                      style: const TextStyle(color: AppColors.primaryPurple, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Due Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(dueFormatted, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pickup Location', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(widget.branchName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fines for Late Return', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text('\$0.25 / day', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusOrange)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleBorrow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Confirm Borrow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
