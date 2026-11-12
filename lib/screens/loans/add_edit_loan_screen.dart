import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/loan_model.dart';
import '../../providers/finance_providers.dart';
import '../../core/finance_engine.dart';

class AddEditLoanScreen extends ConsumerStatefulWidget {
  final LoanModel? initialLoan;

  const AddEditLoanScreen({super.key, this.initialLoan});

  @override
  ConsumerState<AddEditLoanScreen> createState() => _AddEditLoanScreenState();
}

class _AddEditLoanScreenState extends ConsumerState<AddEditLoanScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _lenderController;
  late TextEditingController _accountMaskedController;
  late TextEditingController _principalController;
  late TextEditingController _outstandingController;
  late TextEditingController _interestRateController;
  late TextEditingController _emiController;
  late TextEditingController _debitDayController;
  late TextEditingController _tenureController;
  late TextEditingController _remainingTenureController;
  late TextEditingController _notesController;

  LoanCategory _selectedCategory = LoanCategory.personal;
  String _interestType = 'reducing_balance';

  @override
  void initState() {
    super.initState();
    final loan = widget.initialLoan;
    _nameController = TextEditingController(text: loan?.name ?? '');
    _lenderController = TextEditingController(text: loan?.lenderName ?? '');
    _accountMaskedController = TextEditingController(text: loan?.accountNumberMasked ?? 'XXXX-XXXX-');
    _principalController = TextEditingController(text: loan != null ? loan.originalPrincipal.toString() : '');
    _outstandingController = TextEditingController(text: loan != null ? loan.currentOutstanding.toString() : '');
    _interestRateController = TextEditingController(text: loan != null ? loan.annualInterestRate.toString() : '10.5');
    _emiController = TextEditingController(text: loan != null ? loan.emiAmount.toString() : '');
    _debitDayController = TextEditingController(text: loan != null ? loan.emiDebitDay.toString() : '5');
    _tenureController = TextEditingController(text: loan != null ? loan.totalTenureMonths.toString() : '36');
    _remainingTenureController = TextEditingController(text: loan != null ? loan.remainingTenureMonths.toString() : '36');
    _notesController = TextEditingController(text: loan?.notes ?? '');

    if (loan != null) {
      _selectedCategory = loan.category;
      _interestType = loan.interestType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lenderController.dispose();
    _accountMaskedController.dispose();
    _principalController.dispose();
    _outstandingController.dispose();
    _interestRateController.dispose();
    _emiController.dispose();
    _debitDayController.dispose();
    _tenureController.dispose();
    _remainingTenureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recalculateEmi() {
    final principal = double.tryParse(_outstandingController.text) ?? 0.0;
    final rate = double.tryParse(_interestRateController.text) ?? 0.0;
    final months = int.tryParse(_remainingTenureController.text) ?? 0;

    if (principal > 0 && rate > 0 && months > 0) {
      final calculated = FinancialCalculationEngine.calculateReducingEmi(
        principal: principal,
        annualInterestRatePercent: rate,
        tenureMonths: months,
      );
      setState(() {
        _emiController.text = calculated.toStringAsFixed(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialLoan == null ? 'Add New Loan' : 'Edit Loan Details'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Loan Name',
                hintText: 'e.g. HDFC Home Loan or Axis Car Loan',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Please enter loan name' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lenderController,
                    decoration: const InputDecoration(
                      labelText: 'Lender / Bank / NBFC',
                      hintText: 'e.g. HDFC Bank',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _accountMaskedController,
                    decoration: const InputDecoration(
                      labelText: 'Account No. (Masked)',
                      hintText: 'XXXX-XXXX-1234',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<LoanCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Loan Category',
                border: OutlineInputBorder(),
              ),
              items: LoanCategory.values.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat.displayName),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _outstandingController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Outstanding Balance (₹)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || double.tryParse(val) == null ? 'Enter amount' : null,
                    onChanged: (_) => _recalculateEmi(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _interestRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Annual Interest Rate (%)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || double.tryParse(val) == null ? 'Enter rate' : null,
                    onChanged: (_) => _recalculateEmi(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _remainingTenureController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Remaining Months',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _recalculateEmi(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _emiController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Monthly EMI (₹)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calculate_outlined),
                        tooltip: 'Recalculate EMI',
                        onPressed: _recalculateEmi,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _debitDayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Debit Day (1 - 31)',
                      hintText: 'e.g. 5',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      final n = int.tryParse(val ?? '');
                      if (n == null || n < 1 || n > 31) return '1 to 31';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _interestType,
                    decoration: const InputDecoration(
                      labelText: 'Calculation Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'reducing_balance',
                        child: Text('Reducing Balance'),
                      ),
                      DropdownMenuItem(
                        value: 'flat_rate',
                        child: Text('Flat Interest Rate'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _interestType = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes / Sanction Details',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.initialLoan == null ? 'Save Loan & Set EMI Reminders' : 'Update Loan',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              onPressed: _saveLoan,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.initialLoan?.id ?? const Uuid().v4();
    final outstanding = double.parse(_outstandingController.text);
    final principal = double.tryParse(_principalController.text) ?? outstanding;
    final rate = double.parse(_interestRateController.text);
    final emi = double.tryParse(_emiController.text) ??
        FinancialCalculationEngine.calculateReducingEmi(
          principal: outstanding,
          annualInterestRatePercent: rate,
          tenureMonths: int.tryParse(_remainingTenureController.text) ?? 36,
        );
    final debitDay = int.parse(_debitDayController.text);
    final totalMonths = int.tryParse(_tenureController.text) ?? 36;
    final remainingMonths = int.tryParse(_remainingTenureController.text) ?? totalMonths;

    final loan = LoanModel(
      id: id,
      name: _nameController.text.trim(),
      lenderName: _lenderController.text.trim(),
      accountNumberMasked: _accountMaskedController.text.trim(),
      category: _selectedCategory,
      originalPrincipal: principal,
      currentOutstanding: outstanding,
      annualInterestRate: rate,
      interestType: _interestType,
      emiAmount: emi,
      emiDebitDay: debitDay,
      commencementDate: widget.initialLoan?.commencementDate ?? DateTime.now(),
      firstEmiDate: widget.initialLoan?.firstEmiDate ?? DateTime.now(),
      totalTenureMonths: totalMonths,
      remainingTenureMonths: remainingMonths,
      notes: _notesController.text.trim(),
    );

    if (widget.initialLoan == null) {
      await ref.read(loansProvider.notifier).addLoan(loan);
    } else {
      await ref.read(loansProvider.notifier).updateLoan(loan);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${loan.name}". Multi-stage EMI reminders (T-7 to Due Date) scheduled!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    }
  }
}
