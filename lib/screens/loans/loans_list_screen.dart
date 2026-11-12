import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/loan_model.dart';
import '../../providers/finance_providers.dart';
import '../../core/finance_engine.dart';
import 'add_edit_loan_screen.dart';

class LoansListScreen extends ConsumerStatefulWidget {
  const LoansListScreen({super.key});

  @override
  ConsumerState<LoansListScreen> createState() => _LoansListScreenState();
}

class _LoansListScreenState extends ConsumerState<LoansListScreen> {
  String _sortBy = 'interest_high'; // 'interest_high', 'balance_high', 'emi_high', 'date_close'

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(loansProvider);
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans & Borrowings'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort Loans',
            onSelected: (val) {
              setState(() {
                _sortBy = val;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'interest_high',
                child: Text('Highest Interest Rate First (Avalanche)'),
              ),
              const PopupMenuItem(
                value: 'balance_high',
                child: Text('Highest Outstanding Balance'),
              ),
              const PopupMenuItem(
                value: 'balance_low',
                child: Text('Lowest Balance First (Snowball)'),
              ),
              const PopupMenuItem(
                value: 'emi_high',
                child: Text('Highest Monthly EMI'),
              ),
              const PopupMenuItem(
                value: 'date_close',
                child: Text('Closest EMI Due Date'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Loan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditLoanScreen()),
              );
            },
          ),
        ],
      ),
      body: loansAsync.when(
        data: (loans) {
          if (loans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No loans registered yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First Loan'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddEditLoanScreen()),
                      );
                    },
                  ),
                ],
              ),
            );
          }

          // Apply selected sorting
          final sortedLoans = List<LoanModel>.from(loans);
          if (_sortBy == 'interest_high') {
            sortedLoans.sort((a, b) => b.annualInterestRate.compareTo(a.annualInterestRate));
          } else if (_sortBy == 'balance_high') {
            sortedLoans.sort((a, b) => b.currentOutstanding.compareTo(a.currentOutstanding));
          } else if (_sortBy == 'balance_low') {
            sortedLoans.sort((a, b) => a.currentOutstanding.compareTo(b.currentOutstanding));
          } else if (_sortBy == 'emi_high') {
            sortedLoans.sort((a, b) => b.emiAmount.compareTo(a.emiAmount));
          } else if (_sortBy == 'date_close') {
            sortedLoans.sort((a, b) => a.daysUntilNextEmi.compareTo(b.daysUntilNextEmi));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: sortedLoans.length,
            itemBuilder: (context, index) {
              final loan = sortedLoans[index];
              return _buildLoanCard(context, loan, inr);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading loans: $err')),
      ),
    );
  }

  Widget _buildLoanCard(BuildContext context, LoanModel loan, NumberFormat inr) {
    final daysLeft = loan.daysUntilNextEmi;
    final isWithinWeek = daysLeft <= 7;
    final isUrgent = daysLeft <= 1;

    // Interest rate badge coloring
    final Color rateColor = loan.annualInterestRate >= 14.0
        ? const Color(0xFFEF4444)
        : loan.annualInterestRate >= 10.0
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category icon, Name, Lender, Interest Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: rateColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.account_balance, color: rateColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${loan.lenderName} • ${loan.category.displayName}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: rateColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: rateColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    '${loan.annualInterestRate}% p.a.',
                    style: TextStyle(
                      color: rateColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Middle Row: Outstanding, EMI, Remaining Months
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildColumnStat('Outstanding', inr.format(loan.currentOutstanding)),
                _buildColumnStat('Monthly EMI', inr.format(loan.emiAmount)),
                _buildColumnStat('Tenure Left', '${loan.remainingTenureMonths}m'),
              ],
            ),
            const SizedBox(height: 14),
            // Bottom Row: Next EMI Reminder pill + Amortization / Prepayment action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? const Color(0xFFEF4444).withOpacity(0.15)
                        : isWithinWeek
                            ? const Color(0xFFF59E0B).withOpacity(0.15)
                            : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        size: 14,
                        color: isUrgent
                            ? const Color(0xFFEF4444)
                            : isWithinWeek
                                ? const Color(0xFFF59E0B)
                                : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        daysLeft == 0 ? 'EMI Due Today' : 'Due in $daysLeft days',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isUrgent
                              ? const Color(0xFFEF4444)
                              : isWithinWeek
                                  ? const Color(0xFFF59E0B)
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                      label: const Text('Schedule'),
                      onPressed: () => _showAmortizationDialog(context, loan, inr),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                      onPressed: () => _confirmDelete(context, loan),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnStat(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  void _showAmortizationDialog(BuildContext context, LoanModel loan, NumberFormat inr) {
    final result = FinancialCalculationEngine.generateSchedule(
      principal: loan.currentOutstanding,
      annualInterestRatePercent: loan.annualInterestRate,
      tenureMonths: loan.remainingTenureMonths,
      startDate: DateTime.now(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${loan.name} Amortization',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Total Interest: ${inr.format(result.totalInterest)}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: result.schedule.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                    itemBuilder: (context, idx) {
                      final item = result.schedule[idx];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: Colors.white12,
                          radius: 14,
                          child: Text(
                            '${item.installmentNumber}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                        title: Text(
                          DateFormat('MMM yyyy').format(item.paymentDate),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'P: ${inr.format(item.principalComponent)} • I: ${inr.format(item.interestComponent)}',
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        trailing: Text(
                          'Bal: ${inr.format(item.closingPrincipal)}',
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, LoanModel loan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan'),
        content: Text('Are you sure you want to remove "${loan.name}"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(loansProvider.notifier).deleteLoan(loan.id);
            },
          ),
        ],
      ),
    );
  }
}
