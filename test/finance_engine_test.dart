import 'package:flutter_test/flutter_test.dart';
import 'package:smart_finance_app/core/finance_engine.dart';

void main() {
  group('FinancialCalculationEngine Tests', () {
    test('calculateReducingEmi accurately calculates standard Indian loan EMI', () {
      // Principal = 10,00,000 (10 Lakhs), Rate = 10.5%, Tenure = 120 months (10 years)
      final emi = FinancialCalculationEngine.calculateReducingEmi(
        principal: 1000000,
        annualInterestRatePercent: 10.5,
        tenureMonths: 120,
      );

      // Formula result is approx 13,493.50
      expect(emi, closeTo(13493.50, 1.0));
    });

    test('calculateFlatEmi computes flat rate loan accurately', () {
      // Principal = 1,00,000, Rate = 12%, Tenure = 12 months
      // Total Interest = 1,00,000 * 0.12 * 1 = 12,000. Total = 1,12,000. EMI = 9333.33
      final emi = FinancialCalculationEngine.calculateFlatEmi(
        principal: 100000,
        annualInterestRatePercent: 12,
        tenureMonths: 12,
      );

      expect(emi, closeTo(9333.33, 0.5));
    });

    test('Amortization schedule closes loan principal to zero', () {
      final schedule = FinancialCalculationEngine.generateSchedule(
        principal: 500000,
        annualInterestRatePercent: 9.0,
        tenureMonths: 36,
        startDate: DateTime(2026, 1, 1),
      );

      expect(schedule.schedule.length, 36);
      expect(schedule.schedule.last.closingPrincipal, 0.0);
      expect(schedule.totalInterest, greaterThan(0));
      expect(schedule.totalPayment, equals(500000 + schedule.totalInterest));
    });

    test('Partial prepayment reduces tenure and saves interest', () {
      final result = FinancialCalculationEngine.simulatePartialPrepayment(
        currentOutstanding: 1000000,
        annualInterestRatePercent: 10.0,
        remainingTenureMonths: 120,
        prepaymentAmount: 200000,
        reduceTenure: true,
      );

      expect(result.interestSavings, greaterThan(50000));
      expect(result.monthsSaved, greaterThan(20));
      expect(result.newRemainingMonths, lessThan(120));
    });

    test('Avalanche strategy produces maximum interest savings over base plan', () {
      final loans = [
        {'id': '1', 'name': 'Personal Loan', 'balance': 200000.0, 'interestRate': 15.0, 'emi': 5000.0},
        {'id': '2', 'name': 'Car Loan', 'balance': 500000.0, 'interestRate': 9.0, 'emi': 11000.0},
        {'id': '3', 'name': 'Credit Card EMI', 'balance': 50000.0, 'interestRate': 24.0, 'emi': 3000.0},
      ];

      final strategies = FinancialCalculationEngine.compareStrategies(
        loans: loans,
        extraMonthlyRepaymentBudget: 5000,
      );

      final current = strategies['Current']!;
      final avalanche = strategies['Avalanche']!;
      final snowball = strategies['Snowball']!;

      expect(avalanche.totalInterestPaid, lessThan(current.totalInterestPaid));
      expect(snowball.totalInterestPaid, lessThan(current.totalInterestPaid));
      expect(avalanche.interestSavingsComparedToCurrent, greaterThan(0));
    });
  });
}
