import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book.dart';
import '../../models/book_copy.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../providers/book_providers.dart';
import '../../providers/circulation_providers.dart';
import '../../theme/app_colors.dart';

/// 3-Step Horizontal Stepper for Staff Borrow Flow matching Mockup 8.
class BorrowFlowScreen extends ConsumerStatefulWidget {
  const BorrowFlowScreen({
    super.key,
    this.initialBook,
    this.initialMember,
  });

  final Book? initialBook;
  final UserProfile? initialMember;

  @override
  ConsumerState<BorrowFlowScreen> createState() => _BorrowFlowScreenState();
}

class _BorrowFlowScreenState extends ConsumerState<BorrowFlowScreen> {
  int _currentStep = 1; // 0 = Member, 1 = Copy, 2 = Confirm
  UserProfile? _selectedMember;
  Book? _selectedBook;
  BookCopy? _selectedCopy;
  int _loanDays = 14;
  bool _isLoading = false;

  final TextEditingController _patronSearchController = TextEditingController();
  List<UserProfile> _foundPatrons = [];
  bool _isSearchingPatron = false;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.initialBook;
    _selectedMember = widget.initialMember ??
        const UserProfile(
          uid: 'sample_amara',
          email: 'amara.vance@example.com',
          displayName: 'Amara Vance',
          libraryCardNumber: 'LS-89412',
          standing: 'Good Standing',
        );
    if (_selectedBook != null && _selectedMember != null) {
      _currentStep = 1; // On Step 2: Copy
    }
  }

  @override
  void dispose() {
    _patronSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchPatrons(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _foundPatrons = []);
      return;
    }
    setState(() => _isSearchingPatron = true);
    final userRepo = ref.read(userRepositoryProvider);
    final list = await userRepo.searchPatrons(query);
    if (mounted) {
      setState(() {
        _foundPatrons = list;
        _isSearchingPatron = false;
      });
    }
  }

  Future<void> _handleConfirmBorrow() async {
    if (_selectedBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a book.')),
      );
      return;
    }
    if (_selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a library patron.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final loanRepo = ref.read(loanRepositoryProvider);
      await loanRepo.borrowBook(
        book: _selectedBook!,
        memberId: _selectedMember!.uid,
        memberName: _selectedMember!.displayName,
        branchId: _selectedCopy?.branchId ?? 'central',
        bookCopyId: _selectedCopy?.id,
        loanDays: _loanDays,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully checked out "${_selectedBook!.title}" for ${_selectedMember!.displayName}.',
            ),
            backgroundColor: AppColors.statusGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: ${e.toString()}'),
            backgroundColor: AppColors.statusRed,
            behavior: SnackBarBehavior.floating,
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
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryPurple),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Borrow Book',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          // Staff Mode pill
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.pillPurpleBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: AppColors.primaryPurple),
                SizedBox(width: 6),
                Text(
                  'Staff Mode',
                  style: TextStyle(
                    color: AppColors.primaryPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3-Step Horizontal Stepper Header
              _buildStepperHeader(),
              const SizedBox(height: 24),

              // Step 1: Patron Selection Search
              if (_currentStep == 0) ...[
                _buildPatronSearchSection(),
              ] else ...[
                // Patron Card with Change button
                _buildSelectedPatronCard(),
                const SizedBox(height: 20),

                // Select Available Copy Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Available Copy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Barcode scanner active. Point camera at copy barcode.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                      label: const Text('Scan Barcode', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Book Summary Card
                if (_selectedBook != null) _buildSelectedBookCard(_selectedBook!),
                const SizedBox(height: 16),

                // Copies Radio List
                if (_selectedBook != null) _buildCopiesList(_selectedBook!.id),
                const SizedBox(height: 16),

                // Due Date Standard Loan card
                _buildDueDateCard(),
                const SizedBox(height: 24),

                // Confirm Borrow CTA Button
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    key: const Key('confirm_borrow_cta'),
                    onPressed: _isLoading ? null : _handleConfirmBorrow,
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
                                'Confirm Borrow',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Row(
      children: [
        // Step 1: Member
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.primaryPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 6),
            const Text(
              '1. Member',
              style: TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.primaryOrange,
          ),
        ),
        // Step 2: Copy
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                '2',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '2. Copy',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.cardBorder,
          ),
        ),
        // Step 3: Confirm
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFE2E0EF),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '3',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '3. Confirm',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPatronSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search Library Patron',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _patronSearchController,
          onChanged: _searchPatrons,
          decoration: InputDecoration(
            hintText: 'Search patron name or barcode...',
            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
            suffixIcon: _isSearchingPatron
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        if (_foundPatrons.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _foundPatrons.length,
            itemBuilder: (context, i) {
              final patron = _foundPatrons[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.pillPurpleBg,
                    child: Icon(Icons.person, color: AppColors.primaryPurple),
                  ),
                  title: Text(patron.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Card #${patron.libraryCardNumber} • ${patron.standing}'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    setState(() {
                      _selectedMember = patron;
                      _currentStep = 1;
                    });
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSelectedPatronCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPurple, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.primaryPurple.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.pillPurpleBg,
            child: const Icon(Icons.person, color: AppColors.primaryPurple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedMember?.displayName ?? 'Patron',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Card #${_selectedMember?.libraryCardNumber ?? 'LS-89412'} • ',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const Text(
                      'Good Standing',
                      style: TextStyle(color: AppColors.statusGreen, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _currentStep = 0),
            child: const Text('Change', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedBookCard(Book book) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  book.author,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hardcover • Stack 4B • ${book.category ?? 'General'}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopiesList(String bookId) {
    final copyRepo = ref.watch(bookCopyRepositoryProvider);
    return StreamBuilder<List<BookCopy>>(
      stream: copyRepo.streamCopiesForBook(bookId),
      builder: (context, snapshot) {
        final copies = snapshot.data ?? [];
        if (copies.isEmpty) {
          // Provide standard mock copies if Firestore has none seeded yet
          final defaultCopies = [
            const BookCopy(
              id: 'copy-1',
              bookId: '1',
              branchId: 'central',
              barcode: '39002148',
              status: 'available',
              condition: 'Stack 4B (Shelf 02)',
            ),
            const BookCopy(
              id: 'copy-2',
              bookId: '1',
              branchId: 'central',
              barcode: '39002149',
              status: 'available',
              condition: 'Display Shelf',
            ),
            const BookCopy(
              id: 'copy-3',
              bookId: '1',
              branchId: 'central',
              barcode: '39002991',
              status: 'available',
              condition: 'Fast Locker #04',
            ),
          ];
          return _buildRadioList(defaultCopies);
        }
        return _buildRadioList(copies);
      },
    );
  }

  Widget _buildRadioList(List<BookCopy> copies) {
    if (_selectedCopy == null && copies.isNotEmpty) {
      _selectedCopy = copies.first;
    }

    return Column(
      children: copies.map((copy) {
        final isSelected = _selectedCopy?.barcode == copy.barcode;
        return GestureDetector(
          onTap: () => setState(() => _selectedCopy = copy),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primaryOrange : AppColors.cardBorder,
                width: isSelected ? 1.8 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Radio indicator
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primaryOrange : AppColors.textMuted,
                      width: 2,
                    ),
                    color: isSelected ? AppColors.primaryOrange : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Barcode #${copy.barcode ?? '39002148'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Central Branch — ${copy.condition ?? 'Stack 4B (Shelf 02)'}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusGreenBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: AppColors.statusGreen),
                      SizedBox(width: 4),
                      Text(
                        'Available',
                        style: TextStyle(
                          color: AppColors.statusGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDueDateCard() {
    final now = DateTime.now();
    final due = now.add(Duration(days: _loanDays));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dueFormatted = '${months[due.month - 1]} ${due.day}, ${due.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pillPurpleBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_today_rounded, color: AppColors.primaryPurple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Due Date: $_loanDays Days (Standard Loan)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Due back: $dueFormatted • Auto-renew eligible',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: due,
                firstDate: now,
                lastDate: now.add(const Duration(days: 90)),
              );
              if (picked != null) {
                setState(() {
                  _loanDays = picked.difference(now).inDays.clamp(1, 90);
                });
              }
            },
            child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
          ),
        ],
      ),
    );
  }
}
