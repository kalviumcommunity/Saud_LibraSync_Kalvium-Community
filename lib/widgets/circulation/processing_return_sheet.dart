import 'package:flutter/material.dart';
import '../../models/loan_record.dart';
import '../../theme/app_colors.dart';

/// Modal bottom sheet for staff desk circulation return matching Mockup 4.
class ProcessingReturnSheet extends StatefulWidget {
  const ProcessingReturnSheet({
    super.key,
    required this.loan,
    this.currentBranch = 'Central Library (Current Desk)',
    required this.onConfirmReturn,
  });

  final LoanRecord loan;
  final String currentBranch;
  final Future<void> Function({
    required String returnBranchId,
    required bool waiveFine,
    required double fineAmount,
  }) onConfirmReturn;

  static Future<bool?> show(
    BuildContext context, {
    required LoanRecord loan,
    required Future<void> Function({
      required String returnBranchId,
      required bool waiveFine,
      required double fineAmount,
    }) onConfirmReturn,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProcessingReturnSheet(
        loan: loan,
        onConfirmReturn: onConfirmReturn,
      ),
    );
  }

  @override
  State<ProcessingReturnSheet> createState() => _ProcessingReturnSheetState();
}

class _ProcessingReturnSheetState extends State<ProcessingReturnSheet> {
  late String _selectedLocation;
  bool _waiveFine = true;
  double _fineAmount = 1.50;
  bool _isLoading = false;

  final List<String> _branches = [
    'Central Library (Current Desk)',
    'Northside Branch',
    'Downtown Central',
  ];

  @override
  void initState() {
    super.initState();
    _selectedLocation = _branches.first;
    _fineAmount = widget.loan.fineAmount ?? 1.50;
  }

  Future<void> _handleConfirm() async {
    setState(() => _isLoading = true);
    try {
      final branchId = _selectedLocation.contains('Northside')
          ? 'northside'
          : (_selectedLocation.contains('Downtown') ? 'downtown' : 'central');

      await widget.onConfirmReturn(
        returnBranchId: branchId,
        waiveFine: _waiveFine,
        fineAmount: _fineAmount,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return error: ${e.toString()}'),
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
    final isCrossBranch = widget.loan.borrowedBranchId != null &&
        !widget.loan.borrowedBranchId!.toLowerCase().contains('central');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROCESSING RETURN',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.loan.bookTitle.isNotEmpty
                        ? widget.loan.bookTitle
                        : 'Project Hail Mary',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F0F8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                ),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cross-Branch Routing Banner
          if (isCrossBranch) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F5FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.statusOrangeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryOrange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Cross-Branch Return',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.statusOrangeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Inter-Branch',
                                style: TextStyle(color: AppColors.statusOrange, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.loan.borrowedBranchId ?? 'Northside Branch'} → Central Branch (Transit will be routed)',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Restock / Transit Location Dropdown
          const Text(
            'Restock / Transit Location',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: AppColors.primaryPurple, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLocation,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                      items: _branches.map((b) {
                        return DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 14)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedLocation = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Condition Confirmation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.statusGreen, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Item Condition: Normal wear, no damages',
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Edit', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Fine & Staff Waive Fine Row
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.statusOrange, size: 18),
              const SizedBox(width: 6),
              Text(
                'Fine: \$${_fineAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.statusOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _waiveFine,
                  activeColor: AppColors.primaryPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) => setState(() => _waiveFine = val ?? false),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Waive Fine (Staff)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Confirm Return & Restock Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 2,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Confirm Return & Restock',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),

          // Cancel Link
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
