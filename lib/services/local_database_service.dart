import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/loan_model.dart';
import '../models/transaction_model.dart';

class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._internal();
  LocalDatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'smart_finance.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // Loans table
        await db.execute('''
          CREATE TABLE loans (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            lender_name TEXT NOT NULL,
            account_number_masked TEXT,
            category TEXT NOT NULL,
            original_principal REAL NOT NULL,
            current_outstanding REAL NOT NULL,
            annual_interest_rate REAL NOT NULL,
            interest_type TEXT NOT NULL,
            emi_amount REAL NOT NULL,
            emi_debit_day INTEGER NOT NULL,
            commencement_date TEXT NOT NULL,
            first_emi_date TEXT NOT NULL,
            total_tenure_months INTEGER NOT NULL,
            remaining_tenure_months INTEGER NOT NULL,
            processing_charges REAL,
            prepayment_charges_percentage REAL,
            is_active INTEGER NOT NULL DEFAULT 1,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // Transactions table
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL,
            payment_method TEXT,
            account TEXT,
            merchant TEXT,
            notes TEXT,
            loan_id TEXT,
            is_recurring INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

        // Notification logs & reminder schedules table
        await db.execute('''
          CREATE TABLE notification_schedules (
            id TEXT PRIMARY KEY,
            loan_id TEXT NOT NULL,
            reminder_stage TEXT NOT NULL,
            trigger_date TEXT NOT NULL,
            is_delivered INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // --- LOAN CRUD ---
  Future<int> insertLoan(LoanModel loan) async {
    final db = await database;
    return await db.insert('loans', loan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LoanModel>> getAllLoans({bool onlyActive = true}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'loans',
      where: onlyActive ? 'is_active = 1' : null,
      orderBy: 'annual_interest_rate DESC', // Default sort: highest interest rate first
    );
    return maps.map((m) => LoanModel.fromMap(m)).toList();
  }

  Future<LoanModel?> getLoanById(String id) async {
    final db = await database;
    final maps = await db.query('loans', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isNotEmpty) {
      return LoanModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateLoan(LoanModel loan) async {
    final db = await database;
    return await db.update('loans', loan.toMap(), where: 'id = ?', whereArgs: [loan.id]);
  }

  Future<int> deleteLoan(String id) async {
    final db = await database;
    return await db.delete('loans', where: 'id = ?', whereArgs: [id]);
  }

  // --- TRANSACTION CRUD ---
  Future<int> insertTransaction(TransactionModel txn) async {
    final db = await database;
    return await db.insert('transactions', txn.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TransactionModel>> getAllTransactions({int limit = 100}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
    );
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<int> deleteTransaction(String id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Seed sample data if database is empty
  Future<void> seedInitialDataIfEmpty() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM loans')) ?? 0;
    if (count > 0) return;

    final now = DateTime.now();

    // Sample Indian Loans
    final sampleLoans = [
      LoanModel(
        id: 'loan-hdfc-home',
        name: 'HDFC Home Loan',
        lenderName: 'HDFC Bank',
        accountNumberMasked: 'XXXX-XXXX-4512',
        category: LoanCategory.home,
        originalPrincipal: 4500000,
        currentOutstanding: 3850000,
        annualInterestRate: 8.75,
        emiAmount: 39820,
        emiDebitDay: 5,
        commencementDate: DateTime(now.year - 2, now.month, 5),
        firstEmiDate: DateTime(now.year - 2, now.month + 1, 5),
        totalTenureMonths: 240,
        remainingTenureMonths: 216,
        notes: '3BHK apartment loan at repo-linked reducing rate',
      ),
      LoanModel(
        id: 'loan-bajaj-personal',
        name: 'Bajaj Personal Loan',
        lenderName: 'Bajaj Finserv',
        accountNumberMasked: 'XXXX-XXXX-8921',
        category: LoanCategory.personal,
        originalPrincipal: 400000,
        currentOutstanding: 260000,
        annualInterestRate: 14.5,
        emiAmount: 11025,
        emiDebitDay: 10,
        commencementDate: DateTime(now.year - 1, now.month, 10),
        firstEmiDate: DateTime(now.year - 1, now.month + 1, 10),
        totalTenureMonths: 48,
        remainingTenureMonths: 36,
        notes: 'High interest personal loan - prime candidate for Avalanche prepayment',
      ),
      LoanModel(
        id: 'loan-sbi-car',
        name: 'SBI Auto Loan',
        lenderName: 'State Bank of India',
        accountNumberMasked: 'XXXX-XXXX-1102',
        category: LoanCategory.vehicle,
        originalPrincipal: 850000,
        currentOutstanding: 510000,
        annualInterestRate: 9.15,
        emiAmount: 17740,
        emiDebitDay: 15,
        commencementDate: DateTime(now.year - 2, now.month, 15),
        firstEmiDate: DateTime(now.year - 2, now.month + 1, 15),
        totalTenureMonths: 60,
        remainingTenureMonths: 36,
        notes: 'SUV financing at reducing rate',
      ),
      LoanModel(
        id: 'loan-icici-cc-emi',
        name: 'ICICI Amazon Credit Card EMI',
        lenderName: 'ICICI Bank',
        accountNumberMasked: 'XXXX-XXXX-6701',
        category: LoanCategory.creditCardEmi,
        originalPrincipal: 65000,
        currentOutstanding: 32000,
        annualInterestRate: 16.0,
        emiAmount: 5900,
        emiDebitDay: 20,
        commencementDate: DateTime(now.year, now.month - 6, 20),
        firstEmiDate: DateTime(now.year, now.month - 5, 20),
        totalTenureMonths: 12,
        remainingTenureMonths: 6,
        notes: 'Laptop purchase converted to EMI',
      ),
    ];

    for (final loan in sampleLoans) {
      await insertLoan(loan);
    }

    // Sample Transactions
    final sampleTxns = [
      TransactionModel(
        id: 'txn-1',
        title: 'Monthly Salary Credit',
        amount: 145000,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime(now.year, now.month, 1),
        account: 'Salary HDFC',
      ),
      TransactionModel(
        id: 'txn-2',
        title: 'House Rent',
        amount: 22000,
        type: TransactionType.expense,
        category: 'Rent',
        date: DateTime(now.year, now.month, 2),
        paymentMethod: 'UPI',
      ),
      TransactionModel(
        id: 'txn-3',
        title: 'HDFC Home Loan EMI',
        amount: 39820,
        type: TransactionType.expense,
        category: 'Loan EMI',
        date: DateTime(now.year, now.month, 5),
        loanId: 'loan-hdfc-home',
      ),
      TransactionModel(
        id: 'txn-4',
        title: 'Groceries - Nature Basket',
        amount: 6450,
        type: TransactionType.expense,
        category: 'Groceries',
        date: DateTime(now.year, now.month, 6),
      ),
      TransactionModel(
        id: 'txn-5',
        title: 'Fuel - Indian Oil',
        amount: 3500,
        type: TransactionType.expense,
        category: 'Fuel',
        date: DateTime(now.year, now.month, 8),
      ),
    ];

    for (final txn in sampleTxns) {
      await insertTransaction(txn);
    }
  }
}
