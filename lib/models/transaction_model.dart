import 'dart:convert';

enum TransactionType {
  income,
  expense,
  transfer;

  static TransactionType fromString(String val) {
    return TransactionType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => TransactionType.expense,
    );
  }
}

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String paymentMethod;
  final String account;
  final String merchant;
  final String notes;
  final String? loanId;
  final bool isRecurring;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.paymentMethod = 'UPI',
    this.account = 'Main Account',
    this.merchant = '',
    this.notes = '',
    this.loanId,
    this.isRecurring = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'category': category,
        'date': date.toIso8601String(),
        'payment_method': paymentMethod,
        'account': account,
        'merchant': merchant,
        'notes': notes,
        'loan_id': loanId,
        'is_recurring': isRecurring ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) => TransactionModel(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        type: TransactionType.fromString(map['type'] as String? ?? 'expense'),
        category: map['category'] as String? ?? 'Other',
        date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
        paymentMethod: map['payment_method'] as String? ?? 'UPI',
        account: map['account'] as String? ?? 'Main Account',
        merchant: map['merchant'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
        loanId: map['loan_id'] as String?,
        isRecurring: (map['is_recurring'] as num?)?.toInt() == 1,
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  String toJson() => jsonEncode(toMap());
  factory TransactionModel.fromJson(String source) => TransactionModel.fromMap(jsonDecode(source));
}
