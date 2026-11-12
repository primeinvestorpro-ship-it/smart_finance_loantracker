import 'dart:convert';

enum LoanCategory {
  home,
  personal,
  vehicle,
  twoWheeler,
  education,
  gold,
  creditCardEmi,
  business,
  consumerDurable,
  loanAgainstProperty,
  friendsFamily,
  other;

  String get displayName {
    switch (this) {
      case LoanCategory.home:
        return 'Home Loan';
      case LoanCategory.personal:
        return 'Personal Loan';
      case LoanCategory.vehicle:
        return 'Vehicle Loan';
      case LoanCategory.twoWheeler:
        return 'Two-Wheeler Loan';
      case LoanCategory.education:
        return 'Education Loan';
      case LoanCategory.gold:
        return 'Gold Loan';
      case LoanCategory.creditCardEmi:
        return 'Credit Card EMI';
      case LoanCategory.business:
        return 'Business Loan';
      case LoanCategory.consumerDurable:
        return 'Consumer Durable Loan';
      case LoanCategory.loanAgainstProperty:
        return 'Loan Against Property';
      case LoanCategory.friendsFamily:
        return 'Friends & Family';
      case LoanCategory.other:
        return 'Other Loan';
    }
  }

  static LoanCategory fromString(String val) {
    return LoanCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase() || e.displayName.toLowerCase() == val.toLowerCase(),
      orElse: () => LoanCategory.personal,
    );
  }
}

class LoanModel {
  final String id;
  final String name;
  final String lenderName;
  final String accountNumberMasked;
  final LoanCategory category;
  final double originalPrincipal;
  final double currentOutstanding;
  final double annualInterestRate;
  final String interestType; // 'reducing_balance' or 'flat_rate'
  final double emiAmount;
  final int emiDebitDay; // 1 to 31
  final DateTime commencementDate;
  final DateTime firstEmiDate;
  final int totalTenureMonths;
  final int remainingTenureMonths;
  final double processingCharges;
  final double prepaymentChargesPercentage;
  final bool isActive;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  LoanModel({
    required this.id,
    required this.name,
    required this.lenderName,
    required this.accountNumberMasked,
    required this.category,
    required this.originalPrincipal,
    required this.currentOutstanding,
    required this.annualInterestRate,
    this.interestType = 'reducing_balance',
    required this.emiAmount,
    required this.emiDebitDay,
    required this.commencementDate,
    required this.firstEmiDate,
    required this.totalTenureMonths,
    required this.remainingTenureMonths,
    this.processingCharges = 0.0,
    this.prepaymentChargesPercentage = 0.0,
    this.isActive = true,
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Estimated Closure Date based on remaining tenure
  DateTime get estimatedClosureDate => DateTime(
        commencementDate.year,
        commencementDate.month + totalTenureMonths,
        commencementDate.day,
      );

  /// Next Upcoming EMI Date
  DateTime get nextEmiDate {
    final now = DateTime.now();
    int year = now.year;
    int month = now.month;

    if (now.day > emiDebitDay) {
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final day = emiDebitDay > daysInMonth ? daysInMonth : emiDebitDay;
    return DateTime(year, month, day);
  }

  /// Days left until next EMI debit
  int get daysUntilNextEmi {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(nextEmiDate.year, nextEmiDate.month, nextEmiDate.day);
    return target.difference(today).inDays;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'lender_name': lenderName,
        'account_number_masked': accountNumberMasked,
        'category': category.name,
        'original_principal': originalPrincipal,
        'current_outstanding': currentOutstanding,
        'annual_interest_rate': annualInterestRate,
        'interest_type': interestType,
        'emi_amount': emiAmount,
        'emi_debit_day': emiDebitDay,
        'commencement_date': commencementDate.toIso8601String(),
        'first_emi_date': firstEmiDate.toIso8601String(),
        'total_tenure_months': totalTenureMonths,
        'remaining_tenure_months': remainingTenureMonths,
        'processing_charges': processingCharges,
        'prepayment_charges_percentage': prepaymentChargesPercentage,
        'is_active': isActive ? 1 : 0,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory LoanModel.fromMap(Map<String, dynamic> map) => LoanModel(
        id: map['id'] as String,
        name: map['name'] as String,
        lenderName: map['lender_name'] as String,
        accountNumberMasked: map['account_number_masked'] as String? ?? 'XXXX',
        category: LoanCategory.fromString(map['category'] as String? ?? 'personal'),
        originalPrincipal: (map['original_principal'] as num).toDouble(),
        currentOutstanding: (map['current_outstanding'] as num).toDouble(),
        annualInterestRate: (map['annual_interest_rate'] as num).toDouble(),
        interestType: map['interest_type'] as String? ?? 'reducing_balance',
        emiAmount: (map['emi_amount'] as num).toDouble(),
        emiDebitDay: (map['emi_debit_day'] as num?)?.toInt() ?? 5,
        commencementDate: DateTime.tryParse(map['commencement_date'] as String? ?? '') ?? DateTime.now(),
        firstEmiDate: DateTime.tryParse(map['first_emi_date'] as String? ?? '') ?? DateTime.now(),
        totalTenureMonths: (map['total_tenure_months'] as num).toInt(),
        remainingTenureMonths: (map['remaining_tenure_months'] as num).toInt(),
        processingCharges: (map['processing_charges'] as num?)?.toDouble() ?? 0.0,
        prepaymentChargesPercentage: (map['prepayment_charges_percentage'] as num?)?.toDouble() ?? 0.0,
        isActive: (map['is_active'] as num?)?.toInt() == 1,
        notes: map['notes'] as String? ?? '',
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  LoanModel copyWith({
    String? id,
    String? name,
    String? lenderName,
    String? accountNumberMasked,
    LoanCategory? category,
    double? originalPrincipal,
    double? currentOutstanding,
    double? annualInterestRate,
    String? interestType,
    double? emiAmount,
    int? emiDebitDay,
    DateTime? commencementDate,
    DateTime? firstEmiDate,
    int? totalTenureMonths,
    int? remainingTenureMonths,
    double? processingCharges,
    double? prepaymentChargesPercentage,
    bool? isActive,
    String? notes,
    DateTime? updatedAt,
  }) =>
      LoanModel(
        id: id ?? this.id,
        name: name ?? this.name,
        lenderName: lenderName ?? this.lenderName,
        accountNumberMasked: accountNumberMasked ?? this.accountNumberMasked,
        category: category ?? this.category,
        originalPrincipal: originalPrincipal ?? this.originalPrincipal,
        currentOutstanding: currentOutstanding ?? this.currentOutstanding,
        annualInterestRate: annualInterestRate ?? this.annualInterestRate,
        interestType: interestType ?? this.interestType,
        emiAmount: emiAmount ?? this.emiAmount,
        emiDebitDay: emiDebitDay ?? this.emiDebitDay,
        commencementDate: commencementDate ?? this.commencementDate,
        firstEmiDate: firstEmiDate ?? this.firstEmiDate,
        totalTenureMonths: totalTenureMonths ?? this.totalTenureMonths,
        remainingTenureMonths: remainingTenureMonths ?? this.remainingTenureMonths,
        processingCharges: processingCharges ?? this.processingCharges,
        prepaymentChargesPercentage: prepaymentChargesPercentage ?? this.prepaymentChargesPercentage,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  String toJson() => jsonEncode(toMap());
  factory LoanModel.fromJson(String source) => LoanModel.fromMap(jsonDecode(source));
}
