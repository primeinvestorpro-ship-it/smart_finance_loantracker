import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_providers.dart';
import '../../core/finance_engine.dart';

class RepaymentSimulatorScreen extends ConsumerStatefulWidget {
  const RepaymentSimulatorScreen({super.key});

  @override
  ConsumerState<RepaymentSimulatorScreen> createState() => _RepaymentSimulatorScreenState();
}

class _RepaymentSimulatorScreenState extends ConsumerState<RepaymentSimulatorScreen> {
  double _extraBudget = 10000.0;
  final TextEditingController _budgetController = TextEditingController(text: '10000');

  // Prepayment Calculator state
  double _partialPrepayAmount = 50000.0;
  bool _reduceTenureMode = true;
  String? _selectedLoanId;

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final strategyMap = ref.watch(repaymentStrategiesProvider(_extraBudget));
    final loansAsync = ref.watch(loansProvider);

    final currentPlan = strategyMap['Current'];
    final avalanchePlan = strategyMap['Avalanche'];
    final snowballPlan = strategyMap['Snowball'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repayment & Closure Simulator'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Extra Budget Slider & Input
          _buildBudgetInputCard(inr),

          const SizedBox(height: 20),

          // 2. Avalanche vs Snowball Comparison Cards
          if (avalanchePlan != null && snowballPlan != null && currentPlan != null)
            _buildStrategyComparisonCards(currentPlan, avalanchePlan, snowballPlan, inr),

          const SizedBox(height: 24),

          // 3. Single Loan Partial Prepayment Simulator
          loansAsync.when(
            data: (loans) => _buildSingleLoanPrepaySection(loans, inr),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBudgetInputCard(NumberFormat inr) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Additional Repayment Budget',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Extra surplus applied every month toward faster debt clearance',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _extraBudget,
                  min: 0,
                  max: 100000,
                  divisions: 100,
                  activeColor: const Color(0xFF10B981),
                  inactiveColor: Colors.white24,
                  onChanged: (val) {
                    setState(() {
                      _extraBudget = val;
                      _budgetController.text = val.toStringAsFixed(0);
                    });
                  },
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(color: Colors.white70),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (val) {
                    final d = double.tryParse(val) ?? 0.0;
                    setState(() {
                      _extraBudget = d;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyComparisonCards(
    RepaymentStrategyResult current,
    RepaymentStrategyResult avalanche,
    RepaymentStrategyResult snowball,
    NumberFormat inr,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repayment Strategies Comparison',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        // Avalanche Card (Recommended)
        _buildStrategyCard(
          title: 'Avalanche Strategy (Highest Interest First)',
          badgeText: 'RECOMMENDED • MAXIMUM SAVINGS',
          badgeColor: const Color(0xFF10B981),
          monthsToClear: avalanche.totalMonthsToDebtFree,
          interestSavings: avalanche.interestSavingsComparedToCurrent,
          monthsSaved: avalanche.monthsSaved,
          debtFreeDate: avalanche.estimatedDebtFreeDate,
          inr: inr,
          isHighlight: true,
        ),
        const SizedBox(height: 14),
        // Snowball Card
        _buildStrategyCard(
          title: 'Snowball Strategy (Lowest Balance First)',
          badgeText: 'FASTEST PSYCHOLOGICAL WINS',
          badgeColor: const Color(0xFF06B6D4),
          monthsToClear: snowball.totalMonthsToDebtFree,
          interestSavings: snowball.interestSavingsComparedToCurrent,
          monthsSaved: snowball.monthsSaved,
          debtFreeDate: snowball.estimatedDebtFreeDate,
          inr: inr,
          isHighlight: false,
        ),
      ],
    );
  }

  Widget _buildStrategyCard({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required int monthsToClear,
    required double interestSavings,
    required int monthsSaved,
    required DateTime debtFreeDate,
    required NumberFormat inr,
    required bool isHighlight,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlight ? badgeColor : Colors.white12,
          width: isHighlight ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Estimated Interest Saved', inr.format(interestSavings), color: badgeColor),
              _buildStatItem('Time Saved', '$monthsSaved months earlier'),
              _buildStatItem('Debt-Free By', DateFormat('MMM yyyy').format(debtFreeDate)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleLoanPrepaySection(List<dynamic> loans, NumberFormat inr) {
    if (loans.isEmpty) return const SizedBox.shrink();

    final activeLoans = loans.where((l) => l.isActive).toList();
    if (activeLoans.isEmpty) return const SizedBox.shrink();

    _selectedLoanId ??= activeLoans.first.id;
    final selectedLoan = activeLoans.firstWhere(
      (l) => l.id == _selectedLoanId,
      orElse: () => activeLoans.first,
    );

    final prepayResult = FinancialCalculationEngine.simulatePartialPrepayment(
      currentOutstanding: selectedLoan.currentOutstanding,
      annualInterestRatePercent: selectedLoan.annualInterestRate,
      remainingTenureMonths: selectedLoan.remainingTenureMonths,
      prepaymentAmount: _partialPrepayAmount,
      reduceTenure: _reduceTenureMode,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Single Loan Prepayment What-If',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedLoan.id,
            decoration: const InputDecoration(
              labelText: 'Select Loan to Prepay',
              border: OutlineInputBorder(),
            ),
            items: activeLoans.map<DropdownMenuItem<String>>((l) {
              return DropdownMenuItem(
                value: l.id,
                child: Text('${l.name} (${l.annualInterestRate}%)'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedLoanId = val);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: _partialPrepayAmount.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Lump-Sum Prepayment Amount (₹)',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              final d = double.tryParse(val) ?? 0.0;
              setState(() => _partialPrepayAmount = d);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Reduce Tenure'),
                selected: _reduceTenureMode,
                onSelected: (val) => setState(() => _reduceTenureMode = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Reduce EMI'),
                selected: !_reduceTenureMode,
                onSelected: (val) => setState(() => _reduceTenureMode = false),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Interest Saved', inr.format(prepayResult.interestSavings),
                  color: const Color(0xFF10B981)),
              _buildStatItem(
                _reduceTenureMode ? 'Tenure Reduction' : 'New EMI',
                _reduceTenureMode
                    ? '${prepayResult.monthsSaved} months saved'
                    : inr.format(prepayResult.newEmi),
              ),
              _buildStatItem(
                'New Closure',
                DateFormat('MMM yyyy').format(prepayResult.newEstimatedClosureDate),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
