// Deterministic Financial Calculation Engine for Loans & Debt Optimization
import 'dart:math' as math;

enum InterestType {
  reducingBalance,
  flatRate,
}

class AmortizationScheduleItem {
  final int installmentNumber;
  final DateTime paymentDate;
  final double openingPrincipal;
  final double emiAmount;
  final double principalComponent;
  final double interestComponent;
  final double closingPrincipal;

  const AmortizationScheduleItem({
    required this.installmentNumber,
    required this.paymentDate,
    required this.openingPrincipal,
    required this.emiAmount,
    required this.principalComponent,
    required this.interestComponent,
    required this.closingPrincipal,
  });

  Map<String, dynamic> toMap() => {
        'installmentNumber': installmentNumber,
        'paymentDate': paymentDate.toIso8601String(),
        'openingPrincipal': openingPrincipal,
        'emiAmount': emiAmount,
        'principalComponent': principalComponent,
        'interestComponent': interestComponent,
        'closingPrincipal': closingPrincipal,
      };
}

class LoanCalculationResult {
  final double emi;
  final double totalInterest;
  final double totalPayment;
  final double effectiveInterestRate;
  final List<AmortizationScheduleItem> schedule;

  const LoanCalculationResult({
    required this.emi,
    required this.totalInterest,
    required this.totalPayment,
    required this.effectiveInterestRate,
    required this.schedule,
  });
}

class RepaymentStrategyResult {
  final String strategyName; // 'Current', 'Avalanche', 'Snowball'
  final int totalMonthsToDebtFree;
  final DateTime estimatedDebtFreeDate;
  final double totalInterestPaid;
  final double interestSavingsComparedToCurrent;
  final int monthsSaved;
  final Map<String, int> individualLoanClosureMonths;

  const RepaymentStrategyResult({
    required this.strategyName,
    required this.totalMonthsToDebtFree,
    required this.estimatedDebtFreeDate,
    required this.totalInterestPaid,
    required this.interestSavingsComparedToCurrent,
    required this.monthsSaved,
    required this.individualLoanClosureMonths,
  });
}

class PrepaymentScenarioResult {
  final double originalTotalInterest;
  final double newTotalInterest;
  final double interestSavings;
  final int originalRemainingMonths;
  final int newRemainingMonths;
  final int monthsSaved;
  final double newEmi;
  final DateTime newEstimatedClosureDate;

  const PrepaymentScenarioResult({
    required this.originalTotalInterest,
    required this.newTotalInterest,
    required this.interestSavings,
    required this.originalRemainingMonths,
    required this.newRemainingMonths,
    required this.monthsSaved,
    required this.newEmi,
    required this.newEstimatedClosureDate,
  });
}

class FinancialCalculationEngine {
  /// Calculate EMI for reducing balance loan
  /// Formula: EMI = P * r * (1+r)^n / ((1+r)^n - 1)
  static double calculateReducingEmi({
    required double principal,
    required double annualInterestRatePercent,
    required int tenureMonths,
  }) {
    if (principal <= 0 || tenureMonths <= 0) return 0.0;
    if (annualInterestRatePercent <= 0) {
      return principal / tenureMonths;
    }

    final double monthlyRate = (annualInterestRatePercent / 100.0) / 12.0;
    final double factor = math.pow(1.0 + monthlyRate, tenureMonths).toDouble();
    final double emi = principal * monthlyRate * factor / (factor - 1.0);
    return double.parse(emi.toStringAsFixed(2));
  }

  /// Calculate EMI for flat interest rate loan
  /// Total Interest = P * (R/100) * (tenureMonths/12)
  /// EMI = (P + Total Interest) / tenureMonths
  static double calculateFlatEmi({
    required double principal,
    required double annualInterestRatePercent,
    required int tenureMonths,
  }) {
    if (principal <= 0 || tenureMonths <= 0) return 0.0;
    final double totalInterest =
        principal * (annualInterestRatePercent / 100.0) * (tenureMonths / 12.0);
    final double emi = (principal + totalInterest) / tenureMonths;
    return double.parse(emi.toStringAsFixed(2));
  }

  /// Generate complete Amortization Schedule
  static LoanCalculationResult generateSchedule({
    required double principal,
    required double annualInterestRatePercent,
    required int tenureMonths,
    required DateTime startDate,
    InterestType interestType = InterestType.reducingBalance,
    double? customEmi,
  }) {
    if (principal <= 0 || tenureMonths <= 0) {
      return LoanCalculationResult(
        emi: 0.0,
        totalInterest: 0.0,
        totalPayment: 0.0,
        effectiveInterestRate: annualInterestRatePercent,
        schedule: const [],
      );
    }

    final double emi = customEmi ??
        (interestType == InterestType.reducingBalance
            ? calculateReducingEmi(
                principal: principal,
                annualInterestRatePercent: annualInterestRatePercent,
                tenureMonths: tenureMonths,
              )
            : calculateFlatEmi(
                principal: principal,
                annualInterestRatePercent: annualInterestRatePercent,
                tenureMonths: tenureMonths,
              ));

    final double monthlyRate = (annualInterestRatePercent / 100.0) / 12.0;
    double currentBalance = principal;
    double accumulatedInterest = 0.0;
    final List<AmortizationScheduleItem> schedule = [];

    for (int month = 1; month <= tenureMonths; month++) {
      if (currentBalance <= 0.01) break;

      double interestComponent;
      double principalComponent;

      if (interestType == InterestType.flatRate) {
        interestComponent = (principal * (annualInterestRatePercent / 100.0)) / 12.0;
        principalComponent = emi - interestComponent;
      } else {
        interestComponent = currentBalance * monthlyRate;
        principalComponent = emi - interestComponent;
      }

      // Adjustment for the last installment
      if (month == tenureMonths || principalComponent > currentBalance) {
        principalComponent = currentBalance;
      }

      final double closingBalance = math.max(0.0, currentBalance - principalComponent);
      accumulatedInterest += interestComponent;

      final paymentDate = DateTime(
        startDate.year,
        startDate.month + month,
        startDate.day,
      );

      schedule.add(
        AmortizationScheduleItem(
          installmentNumber: month,
          paymentDate: paymentDate,
          openingPrincipal: double.parse(currentBalance.toStringAsFixed(2)),
          emiAmount: double.parse((principalComponent + interestComponent).toStringAsFixed(2)),
          principalComponent: double.parse(principalComponent.toStringAsFixed(2)),
          interestComponent: double.parse(interestComponent.toStringAsFixed(2)),
          closingPrincipal: double.parse(closingBalance.toStringAsFixed(2)),
        ),
      );

      currentBalance = closingBalance;
    }

    return LoanCalculationResult(
      emi: emi,
      totalInterest: double.parse(accumulatedInterest.toStringAsFixed(2)),
      totalPayment: double.parse((principal + accumulatedInterest).toStringAsFixed(2)),
      effectiveInterestRate: annualInterestRatePercent,
      schedule: schedule,
    );
  }

  /// Partial Prepayment Simulation
  /// Mode A: Reduce Tenure (keep EMI same)
  /// Mode B: Reduce EMI (keep tenure same)
  static PrepaymentScenarioResult simulatePartialPrepayment({
    required double currentOutstanding,
    required double annualInterestRatePercent,
    required int remainingTenureMonths,
    required double prepaymentAmount,
    required bool reduceTenure, // true = reduce tenure, false = reduce EMI
  }) {
    final double originalEmi = calculateReducingEmi(
      principal: currentOutstanding,
      annualInterestRatePercent: annualInterestRatePercent,
      tenureMonths: remainingTenureMonths,
    );
    final double originalTotalInterest = (originalEmi * remainingTenureMonths) - currentOutstanding;

    final double newPrincipal = math.max(0.0, currentOutstanding - prepaymentAmount);
    if (newPrincipal <= 0) {
      return PrepaymentScenarioResult(
        originalTotalInterest: math.max(0.0, originalTotalInterest),
        newTotalInterest: 0.0,
        interestSavings: math.max(0.0, originalTotalInterest),
        originalRemainingMonths: remainingTenureMonths,
        newRemainingMonths: 0,
        monthsSaved: remainingTenureMonths,
        newEmi: 0.0,
        newEstimatedClosureDate: DateTime.now(),
      );
    }

    if (reduceTenure) {
      // Keep EMI same, calculate new reduced tenure
      final double monthlyRate = (annualInterestRatePercent / 100.0) / 12.0;
      int newMonths = 0;
      double balance = newPrincipal;
      double newInterest = 0.0;

      while (balance > 0.01 && newMonths < 600) {
        newMonths++;
        final double interest = balance * monthlyRate;
        final double principalComp = math.min(balance, originalEmi - interest);
        newInterest += interest;
        balance -= principalComp;
      }

      final int monthsSaved = math.max(0, remainingTenureMonths - newMonths);
      final double interestSavings = math.max(0.0, originalTotalInterest - newInterest);

      return PrepaymentScenarioResult(
        originalTotalInterest: double.parse(originalTotalInterest.toStringAsFixed(2)),
        newTotalInterest: double.parse(newInterest.toStringAsFixed(2)),
        interestSavings: double.parse(interestSavings.toStringAsFixed(2)),
        originalRemainingMonths: remainingTenureMonths,
        newRemainingMonths: newMonths,
        monthsSaved: monthsSaved,
        newEmi: originalEmi,
        newEstimatedClosureDate: DateTime.now().add(Duration(days: newMonths * 30)),
      );
    } else {
      // Reduce EMI, keep tenure same
      final double newEmi = calculateReducingEmi(
        principal: newPrincipal,
        annualInterestRatePercent: annualInterestRatePercent,
        tenureMonths: remainingTenureMonths,
      );
      final double newTotalInterest = (newEmi * remainingTenureMonths) - newPrincipal;
      final double interestSavings = math.max(0.0, originalTotalInterest - newTotalInterest);

      return PrepaymentScenarioResult(
        originalTotalInterest: double.parse(originalTotalInterest.toStringAsFixed(2)),
        newTotalInterest: double.parse(newTotalInterest.toStringAsFixed(2)),
        interestSavings: double.parse(interestSavings.toStringAsFixed(2)),
        originalRemainingMonths: remainingTenureMonths,
        newRemainingMonths: remainingTenureMonths,
        monthsSaved: 0,
        newEmi: newEmi,
        newEstimatedClosureDate: DateTime.now().add(Duration(days: remainingTenureMonths * 30)),
      );
    }
  }

  /// Loan Optimization: Avalanche (Highest Interest First) vs Snowball (Lowest Balance First)
  static Map<String, RepaymentStrategyResult> compareStrategies({
    required List<Map<String, dynamic>> loans, // [{id, name, balance, interestRate, emi}]
    required double extraMonthlyRepaymentBudget,
  }) {
    if (loans.isEmpty) {
      final now = DateTime.now();
      return {
        'Current': RepaymentStrategyResult(
          strategyName: 'Current',
          totalMonthsToDebtFree: 0,
          estimatedDebtFreeDate: now,
          totalInterestPaid: 0,
          interestSavingsComparedToCurrent: 0,
          monthsSaved: 0,
          individualLoanClosureMonths: {},
        ),
        'Avalanche': RepaymentStrategyResult(
          strategyName: 'Avalanche',
          totalMonthsToDebtFree: 0,
          estimatedDebtFreeDate: now,
          totalInterestPaid: 0,
          interestSavingsComparedToCurrent: 0,
          monthsSaved: 0,
          individualLoanClosureMonths: {},
        ),
        'Snowball': RepaymentStrategyResult(
          strategyName: 'Snowball',
          totalMonthsToDebtFree: 0,
          estimatedDebtFreeDate: now,
          totalInterestPaid: 0,
          interestSavingsComparedToCurrent: 0,
          monthsSaved: 0,
          individualLoanClosureMonths: {},
        ),
      };
    }

    // 1. Current Plan (Base)
    final currentResult = _simulateDebtStrategy(
      loans: loans,
      extraBudget: 0.0,
      sortBy: (a, b) => 0, // Unchanged
      strategyName: 'Current',
      baseInterest: 0.0,
      baseMonths: 0,
    );

    // 2. Avalanche: Prioritize by Highest Interest Rate descending
    final avalancheResult = _simulateDebtStrategy(
      loans: loans,
      extraBudget: extraMonthlyRepaymentBudget,
      sortBy: (a, b) => (b['interestRate'] as double).compareTo(a['interestRate'] as double),
      strategyName: 'Avalanche (Highest Interest First)',
      baseInterest: currentResult.totalInterestPaid,
      baseMonths: currentResult.totalMonthsToDebtFree,
    );

    // 3. Snowball: Prioritize by Lowest Outstanding Principal ascending
    final snowballResult = _simulateDebtStrategy(
      loans: loans,
      extraBudget: extraMonthlyRepaymentBudget,
      sortBy: (a, b) => (a['balance'] as double).compareTo(b['balance'] as double),
      strategyName: 'Snowball (Lowest Balance First)',
      baseInterest: currentResult.totalInterestPaid,
      baseMonths: currentResult.totalMonthsToDebtFree,
    );

    return {
      'Current': currentResult,
      'Avalanche': avalancheResult,
      'Snowball': snowballResult,
    };
  }

  static RepaymentStrategyResult _simulateDebtStrategy({
    required List<Map<String, dynamic>> loans,
    required double extraBudget,
    required int Function(Map<String, dynamic> a, Map<String, dynamic> b) sortBy,
    required String strategyName,
    required double baseInterest,
    required int baseMonths,
  }) {
    // Clone loan entries
    final List<Map<String, dynamic>> active = loans.map((l) => Map<String, dynamic>.from(l)).toList();
    active.sort(sortBy);

    int month = 0;
    double totalInterestPaid = 0.0;
    final Map<String, int> closureMonths = {};

    while (active.any((l) => (l['balance'] as double) > 0.01) && month < 600) {
      month++;
      double availableExtra = extraBudget;

      // Accrue monthly interest and deduct base EMIs
      for (final loan in active) {
        double balance = loan['balance'] as double;
        if (balance <= 0.01) continue;

        final double rate = (loan['interestRate'] as double) / 100.0 / 12.0;
        final double interest = balance * rate;
        totalInterestPaid += interest;
        balance += interest;

        final double minEmi = loan['emi'] as double;
        final double payment = math.min(balance, minEmi);
        balance -= payment;
        loan['balance'] = balance;

        if (balance <= 0.01 && !closureMonths.containsKey(loan['id'])) {
          closureMonths[loan['id'] as String] = month;
          // Rollover freed EMI to available extra repayment pool
          availableExtra += minEmi;
        }
      }

      // Re-sort priority for applying extra budget
      active.sort(sortBy);

      for (final loan in active) {
        if (availableExtra <= 0.01) break;
        double balance = loan['balance'] as double;
        if (balance <= 0.01) continue;

        final double extraPayment = math.min(balance, availableExtra);
        balance -= extraPayment;
        availableExtra -= extraPayment;
        loan['balance'] = balance;

        if (balance <= 0.01 && !closureMonths.containsKey(loan['id'])) {
          closureMonths[loan['id'] as String] = month;
          availableExtra += (loan['emi'] as double);
        }
      }
    }

    final now = DateTime.now();
    final estimatedDebtFreeDate = DateTime(now.year, now.month + month, now.day);
    final double savings = baseInterest > 0 ? math.max(0.0, baseInterest - totalInterestPaid) : 0.0;
    final int monthsSaved = baseMonths > 0 ? math.max(0, baseMonths - month) : 0;

    return RepaymentStrategyResult(
      strategyName: strategyName,
      totalMonthsToDebtFree: month,
      estimatedDebtFreeDate: estimatedDebtFreeDate,
      totalInterestPaid: double.parse(totalInterestPaid.toStringAsFixed(2)),
      interestSavingsComparedToCurrent: double.parse(savings.toStringAsFixed(2)),
      monthsSaved: monthsSaved,
      individualLoanClosureMonths: closureMonths,
    );
  }
}
