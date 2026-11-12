import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/transaction_model.dart';
import '../../providers/finance_providers.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _filter = 'all'; // 'all', 'income', 'expense'

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(transactionsProvider);
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income & Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Transaction',
            onPressed: () => _showAddTransactionModal(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Income'),
                  selected: _filter == 'income',
                  onSelected: (_) => setState(() => _filter = 'income'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Expenses'),
                  selected: _filter == 'expense',
                  onSelected: (_) => setState(() => _filter = 'expense'),
                ),
              ],
            ),
          ),
          Expanded(
            child: txnsAsync.when(
              data: (txns) {
                final filtered = txns.where((t) {
                  if (_filter == 'income') return t.type == TransactionType.income;
                  if (_filter == 'expense') return t.type == TransactionType.expense;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No transactions recorded', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final t = filtered[index];
                    final isIncome = t.type == TransactionType.income;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isIncome
                              ? const Color(0xFF10B981).withOpacity(0.15)
                              : const Color(0xFFEF4444).withOpacity(0.15),
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          t.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${t.category} • ${DateFormat('dd MMM yyyy').format(t.date)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Text(
                          '${isIncome ? '+' : '-'} ${inr.format(t.amount)}',
                          style: TextStyle(
                            color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionModal(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    TransactionType selectedType = TransactionType.expense;
    String selectedCategory = 'Groceries';

    final expenseCategories = [
      'Groceries',
      'Food & Dining',
      'Rent',
      'Fuel',
      'Shopping',
      'Utilities',
      'Loan EMI',
      'Credit Card Payment',
      'Entertainment',
      'Medical',
      'Other'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
                top: 20,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Record Transaction',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Expense')),
                          selected: selectedType == TransactionType.expense,
                          onSelected: (_) => setModalState(() {
                            selectedType = TransactionType.expense;
                            selectedCategory = 'Groceries';
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Income')),
                          selected: selectedType == TransactionType.income,
                          onSelected: (_) => setModalState(() {
                            selectedType = TransactionType.income;
                            selectedCategory = 'Salary';
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title / Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: (selectedType == TransactionType.expense
                            ? expenseCategories
                            : ['Salary', 'Business Income', 'Freelance', 'Dividends', 'Other Income'])
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save Transaction', style: TextStyle(color: Colors.white)),
                      onPressed: () async {
                        final amt = double.tryParse(amountController.text);
                        if (titleController.text.isNotEmpty && amt != null && amt > 0) {
                          final txn = TransactionModel(
                            id: const Uuid().v4(),
                            title: titleController.text.trim(),
                            amount: amt,
                            type: selectedType,
                            category: selectedCategory,
                            date: DateTime.now(),
                          );
                          await ref.read(transactionsProvider.notifier).addTransaction(txn);
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
