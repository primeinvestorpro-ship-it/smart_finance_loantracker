import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loan_model.dart';
import '../models/transaction_model.dart';
import '../services/local_database_service.dart';
import '../services/notification_service.dart';
import '../services/sms_reader_service.dart';
import '../core/finance_engine.dart';

// --- Database & Repository Provider ---
final databaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  return LocalDatabaseService.instance;
});

// --- Loans State Notifier ---
class LoansNotifier extends StateNotifier<AsyncValue<List<LoanModel>>> {
  final LocalDatabaseService _db;

  LoansNotifier(this._db) : super(const AsyncValue.loading()) {
    loadLoans();
    // Listen to real-time incoming SMS updates
    SmsReaderService.instance.onNewFinancialMessage.listen((_) {
      loadLoans();
    });
  }

  Future<void> loadLoans() async {
    try {
      state = const AsyncValue.loading();
      final loans = await _db.getAllLoans();
      state = AsyncValue.data(loans);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addLoan(LoanModel loan) async {
    await _db.insertLoan(loan);
    await NotificationService.instance.scheduleMultiStageEmiRenameReminders(loan);
    await loadLoans();
  }

  Future<void> updateLoan(LoanModel loan) async {
    await _db.updateLoan(loan);
    await NotificationService.instance.scheduleMultiStageEmiRenameReminders(loan);
    await loadLoans();
  }

  Future<void> deleteLoan(String id) async {
    await _db.deleteLoan(id);
    await loadLoans();
  }

  Future<void> clearAll() async {
    await _db.clearAllLoans();
    await loadLoans();
  }
}

final loansProvider = StateNotifierProvider<LoansNotifier, AsyncValue<List<LoanModel>>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return LoansNotifier(db);
});

// --- Transactions State Notifier ---
class TransactionsNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final LocalDatabaseService _db;

  TransactionsNotifier(this._db) : super(const AsyncValue.loading()) {
    loadTransactions();
    // Listen to real-time incoming SMS updates
    SmsReaderService.instance.onNewFinancialMessage.listen((_) {
      loadTransactions();
    });
  }

  Future<void> loadTransactions() async {
    try {
      state = const AsyncValue.loading();
      final txns = await _db.getAllTransactions();
      state = AsyncValue.data(txns);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTransaction(TransactionModel txn) async {
    await _db.insertTransaction(txn);
    await loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await _db.deleteTransaction(id);
    await loadTransactions();
  }

  Future<void> clearAll() async {
    await _db.clearAllTransactions();
    await loadTransactions();
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return TransactionsNotifier(db);
});

// --- Financial Aggregates & Dashboard Metrics Provider ---
class DashboardMetrics {
  final double totalOutstandingDebt;
  final double totalMonthlyEmi;
  final double monthlyIncome;
  final double monthlyExpenses;
  final double availableBalance;
  final int activeLoansCount;
  final LoanModel? highestInterestLoan;
  final LoanModel? nextUpcomingEmiLoan;
  final double debtToIncomeRatio;

  DashboardMetrics({
    required this.totalOutstandingDebt,
    required this.totalMonthlyEmi,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.availableBalance,
    required this.activeLoansCount,
    this.highestInterestLoan,
    this.nextUpcomingEmiLoan,
    required this.debtToIncomeRatio,
  });
}

final dashboardMetricsProvider = Provider<DashboardMetrics>((ref) {
  final loansAsync = ref.watch(loansProvider);
  final txnsAsync = ref.watch(transactionsProvider);

  final loans = loansAsync.value ?? [];
  final txns = txnsAsync.value ?? [];

  double totalDebt = 0.0;
  double totalEmi = 0.0;
  LoanModel? highestInterest;
  LoanModel? nextEmiLoan;
  int minDaysToEmi = 9999;

  for (final l in loans) {
    if (l.isActive) {
      totalDebt += l.currentOutstanding;
      totalEmi += l.emiAmount;

      if (highestInterest == null || l.annualInterestRate > highestInterest.annualInterestRate) {
        highestInterest = l;
      }

      final days = l.daysUntilNextEmi;
      if (days < minDaysToEmi) {
        minDaysToEmi = days;
        nextEmiLoan = l;
      }
    }
  }

  double income = 0.0;
  double expenses = 0.0;

  for (final t in txns) {
    if (t.type == TransactionType.income) {
      income += t.amount;
    } else if (t.type == TransactionType.expense) {
      expenses += t.amount;
    }
  }

  final available = income - expenses;
  final dtiRatio = income > 0 ? (totalEmi / income) * 100 : 0.0;

  return DashboardMetrics(
    totalOutstandingDebt: totalDebt,
    totalMonthlyEmi: totalEmi,
    monthlyIncome: income,
    monthlyExpenses: expenses,
    availableBalance: available,
    activeLoansCount: loans.where((l) => l.isActive).length,
    highestInterestLoan: highestInterest,
    nextUpcomingEmiLoan: nextEmiLoan,
    debtToIncomeRatio: dtiRatio,
  );
});

// --- Repayment Strategies Provider (Avalanche vs Snowball) ---
final repaymentStrategiesProvider =
    Provider.family<Map<String, RepaymentStrategyResult>, double>((ref, extraBudget) {
  final loansAsync = ref.watch(loansProvider);
  final loans = loansAsync.value ?? [];

  final activeLoans = loans
      .where((l) => l.isActive && l.currentOutstanding > 0)
      .map((l) => {
            'id': l.id,
            'name': l.name,
            'balance': l.currentOutstanding,
            'interestRate': l.annualInterestRate,
            'emi': l.emiAmount,
          })
      .toList();

  return FinancialCalculationEngine.compareStrategies(
    loans: activeLoans,
    extraMonthlyRepaymentBudget: extraBudget,
  );
});
