import 'dart:async';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/loan_model.dart';
import '../models/transaction_model.dart';
import 'local_database_service.dart';
import 'notification_service.dart';
import 'gemini_extraction_service.dart';

// Top-level background SMS message handler required by another_telephony
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  final body = message.body ?? '';
  if (body.isEmpty) return;
  await SmsReaderService.instance.processIncomingSmsText(body, isBackground: true);
}

class SmsReaderService {
  static final SmsReaderService instance = SmsReaderService._internal();
  SmsReaderService._internal();

  final Telephony _telephony = Telephony.instance;
  bool _isListening = false;

  // Stream controller to notify UI in real-time when a new financial SMS is parsed
  final StreamController<String> _smsUpdatesStreamController = StreamController<String>.broadcast();
  Stream<String> get onNewFinancialMessage => _smsUpdatesStreamController.stream;

  /// Request SMS permissions
  Future<bool> requestSmsPermissions() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Start background & foreground listener for incoming SMS
  Future<void> startListening() async {
    if (_isListening) return;

    final hasPerm = await requestSmsPermissions();
    if (!hasPerm) return;

    try {
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          final body = message.body ?? '';
          if (body.isNotEmpty) {
            await processIncomingSmsText(body, isBackground: false);
          }
        },
        onBackgroundMessage: backgroundMessageHandler,
      );
      _isListening = true;
    } catch (_) {}
  }

  /// Scan existing local SMS inbox on device and import historical loans/expenses
  Future<int> scanExistingInbox({int limit = 150}) async {
    final hasPerm = await requestSmsPermissions();
    if (!hasPerm) return 0;

    int importedCount = 0;
    try {
      final List<SmsMessage> messages = await _telephony.getInboxSms(
        columns: [SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      final toProcess = messages.take(limit).toList();
      for (final msg in toProcess) {
        final body = msg.body ?? '';
        final imported = await processIncomingSmsText(body, isBackground: false);
        if (imported) importedCount++;
      }
    } catch (_) {}
    return importedCount;
  }

  /// Analyze raw SMS text: identify if it is loan-related or expense/income, and store dynamically
  Future<bool> processIncomingSmsText(String text, {bool isBackground = false}) async {
    final lower = text.toLowerCase();

    // Check if message is a financial communication
    final isFinancial = lower.contains('rs.') ||
        lower.contains('inr') ||
        lower.contains('emi') ||
        lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('loan') ||
        lower.contains('spent') ||
        lower.contains('ac ');

    if (!isFinancial) return false;

    // 1. Is it a Loan Disbursement, Sanction, or EMI schedule message?
    final isLoanMessage = lower.contains('emi') ||
        lower.contains('loan') ||
        lower.contains('sanction') ||
        lower.contains('disbursed');

    if (isLoanMessage && (lower.contains('sanctioned') || lower.contains('disbursed') || lower.contains('scheduled for debit'))) {
      final loanData = await GeminiExtractionService.parseLoanText(rawText: text);
      if (loanData.emiAmount > 0 || loanData.principalAmount > 0) {
        // Prevent duplicate loan records by checking lender & category
        final db = LocalDatabaseService.instance;
        final existingLoans = await db.getAllLoans();
        final duplicate = existingLoans.any((l) =>
            l.lenderName.toLowerCase() == loanData.lenderName.toLowerCase() &&
            (l.emiAmount - loanData.emiAmount).abs() < 50);

        if (!duplicate) {
          final newLoan = LoanModel(
            id: const Uuid().v4(),
            name: '${loanData.lenderName} ${loanData.loanType}',
            lenderName: loanData.lenderName,
            accountNumberMasked: 'SMS-AUTO',
            category: LoanCategory.fromString(loanData.loanType),
            originalPrincipal: loanData.principalAmount,
            currentOutstanding: loanData.outstandingPrincipal > 0 ? loanData.outstandingPrincipal : loanData.principalAmount,
            annualInterestRate: loanData.interestRate,
            interestType: loanData.interestType == 'flat' ? 'flat_rate' : 'reducing_balance',
            emiAmount: loanData.emiAmount,
            emiDebitDay: 5,
            commencementDate: DateTime.now(),
            firstEmiDate: DateTime.tryParse(loanData.nextEmiDate) ?? DateTime.now(),
            totalTenureMonths: loanData.tenureMonths,
            remainingTenureMonths: loanData.remainingMonths,
            notes: 'Auto-detected from real-time SMS',
          );

          await db.insertLoan(newLoan);
          await NotificationService.instance.scheduleMultiStageEmiRenameReminders(newLoan);
          _smsUpdatesStreamController.add('New loan detected: ${newLoan.name}');
          return true;
        }
      }
    }

    // 2. Is it a Debit (Expense) or Credit (Income) transaction?
    final isDebit = lower.contains('debited') || lower.contains('spent') || lower.contains('paid');
    final isCredit = lower.contains('credited') || lower.contains('received') || lower.contains('salary');

    if (isDebit || isCredit) {
      double amount = 0.0;
      final amtRegex = RegExp(r'(?:rs\.?|inr|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false);
      final match = amtRegex.firstMatch(text);
      if (match != null) {
        amount = double.tryParse(match.group(1)?.replaceAll(',', '') ?? '0') ?? 0.0;
      }

      if (amount > 0) {
        String category = 'Other';
        if (lower.contains('emi') || lower.contains('loan')) {
          category = 'Loan EMI';
        } else if (lower.contains('swiggy') || lower.contains('zomato') || lower.contains('food')) {
          category = 'Food & Dining';
        } else if (lower.contains('grocery') || lower.contains('blinkit') || lower.contains('zepto') || lower.contains('dmart')) {
          category = 'Groceries';
        } else if (lower.contains('petrol') || lower.contains('fuel') || lower.contains('hpcl') || lower.contains('bpcl')) {
          category = 'Fuel';
        } else if (lower.contains('salary')) {
          category = 'Salary';
        } else if (lower.contains('rent')) {
          category = 'Rent';
        }

        final txn = TransactionModel(
          id: const Uuid().v4(),
          title: isDebit ? 'Debited via SMS' : 'Credited via SMS',
          amount: amount,
          type: isDebit ? TransactionType.expense : TransactionType.income,
          category: category,
          date: DateTime.now(),
          notes: text.length > 80 ? '${text.substring(0, 80)}...' : text,
        );

        await LocalDatabaseService.instance.insertTransaction(txn);
        _smsUpdatesStreamController.add('New transaction logged: ₹$amount ($category)');
        return true;
      }
    }

    return false;
  }
}
