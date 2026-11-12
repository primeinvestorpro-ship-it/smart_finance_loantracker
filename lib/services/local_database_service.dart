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

        // Notification schedules table
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
      orderBy: 'annual_interest_rate DESC',
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

  Future<void> clearAllLoans() async {
    final db = await database;
    await db.delete('loans');
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

  Future<void> clearAllTransactions() async {
    final db = await database;
    await db.delete('transactions');
  }

  /// Clean wipe of any dummy/demo records
  Future<void> clearAllDemoData() async {
    await clearAllLoans();
    await clearAllTransactions();
  }
}
