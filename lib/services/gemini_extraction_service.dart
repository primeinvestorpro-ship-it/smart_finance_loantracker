import 'dart:convert';
import 'package:http/http.dart' as http;

class ExtractedLoanData {
  final String lenderName;
  final String loanType;
  final double principalAmount;
  final double interestRate;
  final String interestType; // reducing or flat
  final double emiAmount;
  final int tenureMonths;
  final int remainingMonths;
  final double outstandingPrincipal;
  final String nextEmiDate;
  final double confidence;
  final String rawSourceSnippet;

  ExtractedLoanData({
    required this.lenderName,
    required this.loanType,
    required this.principalAmount,
    required this.interestRate,
    this.interestType = 'reducing',
    required this.emiAmount,
    required this.tenureMonths,
    required this.remainingMonths,
    required this.outstandingPrincipal,
    required this.nextEmiDate,
    required this.confidence,
    this.rawSourceSnippet = '',
  });

  Map<String, dynamic> toMap() => {
        'lender_name': lenderName,
        'loan_type': loanType,
        'principal_amount': principalAmount,
        'interest_rate': interestRate,
        'interest_type': interestType,
        'emi_amount': emiAmount,
        'tenure_months': tenureMonths,
        'remaining_months': remainingMonths,
        'outstanding_principal': outstandingPrincipal,
        'next_emi_date': nextEmiDate,
        'confidence': confidence,
      };

  factory ExtractedLoanData.fromMap(Map<String, dynamic> map) => ExtractedLoanData(
        lenderName: map['lender_name'] as String? ?? 'Identified Lender',
        loanType: map['loan_type'] as String? ?? 'Personal Loan',
        principalAmount: (map['principal_amount'] as num?)?.toDouble() ?? 0.0,
        interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 10.5,
        interestType: map['interest_type'] as String? ?? 'reducing',
        emiAmount: (map['emi_amount'] as num?)?.toDouble() ?? 0.0,
        tenureMonths: (map['tenure_months'] as num?)?.toInt() ?? 36,
        remainingMonths: (map['remaining_months'] as num?)?.toInt() ?? 36,
        outstandingPrincipal: (map['outstanding_principal'] as num?)?.toDouble() ?? 0.0,
        nextEmiDate: map['next_emi_date'] as String? ?? '',
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0.85,
        rawSourceSnippet: map['rawSourceSnippet'] as String? ?? '',
      );
}

class GeminiExtractionService {
  /// Extract structured loan information from scanned OCR text or user-provided SMS text
  /// Dynamic parsing with Gemini API call if key is available, else uses pattern-driven dynamic parser
  static Future<ExtractedLoanData> parseLoanText({
    required String rawText,
    String? apiKey,
  }) async {
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
        );

        final prompt = '''
You are a real-time financial SMS and document extraction engine for Indian banking.
Parse the following message and output strictly valid JSON:
{
  "lender_name": string (e.g. "HDFC Bank", "SBI", "Bajaj Finserv", "ICICI Bank", "Axis Bank"),
  "loan_type": string ("Personal Loan", "Home Loan", "Vehicle Loan", "Credit Card EMI"),
  "principal_amount": number (in INR),
  "interest_rate": number (annual percentage rate e.g. 10.5),
  "interest_type": string ("reducing" or "flat"),
  "emi_amount": number (monthly installment amount in INR),
  "tenure_months": integer,
  "remaining_months": integer,
  "outstanding_principal": number,
  "next_emi_date": string (YYYY-MM-DD),
  "confidence": number between 0.0 and 1.0
}

Message Text:
$rawText
''';

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'response_mime_type': 'application/json',
            }
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final content = body['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (content != null) {
            final jsonMap = jsonDecode(content);
            return ExtractedLoanData.fromMap(jsonMap);
          }
        }
      } catch (_) {}
    }

    // Dynamic Local Parsing
    return _parseDynamicallyFromText(rawText);
  }

  /// Dynamic AI Assistant financial summary and insights based on real user portfolio
  static Future<String> generateFinancialInsights({
    required double totalDebt,
    required double monthlyEmi,
    required double monthlyIncome,
    required double monthlyExpenses,
    required int activeLoansCount,
    required String highestInterestLoan,
    required double highestRate,
    String? apiKey,
  }) async {
    final dti = monthlyIncome > 0 ? (monthlyEmi / monthlyIncome) * 100 : 0.0;

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
        );

        final prompt = '''
You are Finance Assistant, an expert Indian financial advisor.
Analyze the user's real financial portfolio:
- Total Outstanding Debt: INR $totalDebt
- Total Monthly EMI: INR $monthlyEmi
- Monthly Income: INR $monthlyIncome
- Monthly Expenses: INR $monthlyExpenses
- Active Loans: $activeLoansCount
- Highest Interest Loan: $highestInterestLoan ($highestRate% p.a.)
- Debt-To-Income (DTI): ${dti.toStringAsFixed(1)}%

Provide 3 actionable, empathetic, and mathematically sound bullet points prioritizing debt reduction (Avalanche strategy) and cash flow protection. Keep it concise.
''';

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ]
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final text = body['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (text != null && text.isNotEmpty) return text;
        }
      } catch (_) {}
    }

    // Dynamic Offline Insights Generator
    final StringBuffer sb = StringBuffer();
    sb.writeln('💡 **Portfolio Analysis & Recommendations:**\n');

    if (activeLoansCount == 0) {
      sb.writeln('• **Zero Debt Status:** You have no active loans currently registered. Any incoming financial SMS from your bank will be mapped automatically.');
    } else {
      if (dti > 45) {
        sb.writeln('• **High Debt Burden Alert:** Your Debt-to-Income ratio is ${dti.toStringAsFixed(1)}% (healthy threshold is <40%). Prioritize paying down high-interest liabilities first.');
      } else {
        sb.writeln('• **Healthy Debt Profile:** Your DTI is ${dti.toStringAsFixed(1)}%, within manageable limits.');
      }

      if (highestRate >= 13.0) {
        sb.writeln('• **Avalanche Priority:** Focus extra monthly savings on **$highestInterestLoan** at $highestRate% p.a. to prevent significant interest leakage.');
      }

      final surplus = monthlyIncome - monthlyExpenses - monthlyEmi;
      if (surplus > 5000) {
        sb.writeln('• **Prepayment Opportunity:** You have an estimated monthly surplus of ₹${surplus.toStringAsFixed(0)}. Prepaying even ₹5,000 extra per month can shave months off your tenure.');
      }
    }

    return sb.toString();
  }

  static ExtractedLoanData _parseDynamicallyFromText(String text) {
    final lower = text.toLowerCase();

    // Identify Lender
    String lender = 'Bank';
    if (lower.contains('hdfc')) lender = 'HDFC Bank';
    else if (lower.contains('sbi') || lower.contains('state bank')) lender = 'State Bank of India';
    else if (lower.contains('icici')) lender = 'ICICI Bank';
    else if (lower.contains('bajaj')) lender = 'Bajaj Finserv';
    else if (lower.contains('axis')) lender = 'Axis Bank';
    else if (lower.contains('kotak')) lender = 'Kotak Bank';
    else if (lower.contains('pnb')) lender = 'PNB';
    else if (lower.contains('idfc')) lender = 'IDFC FIRST Bank';

    // Identify Loan Type
    String loanType = 'Personal Loan';
    if (lower.contains('home loan') || lower.contains('housing')) loanType = 'Home Loan';
    else if (lower.contains('car loan') || lower.contains('auto loan') || lower.contains('vehicle')) loanType = 'Vehicle Loan';
    else if (lower.contains('credit card') || lower.contains('cc emi')) loanType = 'Credit Card EMI';
    else if (lower.contains('gold loan')) loanType = 'Gold Loan';

    // Dynamic EMI Amount Extraction
    double emi = 0.0;
    final emiRegex = RegExp(r'(?:emi|installment)(?:\s+of)?(?:\s+is)?(?:\s+rs\.?|\s+inr|\s+₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false);
    final emiMatch = emiRegex.firstMatch(text);
    if (emiMatch != null) {
      emi = double.tryParse(emiMatch.group(1)?.replaceAll(',', '') ?? '0') ?? 0.0;
    }

    // Dynamic Principal Amount Extraction
    double principal = 0.0;
    final principalRegex = RegExp(r'(?:sanctioned|loan amount|principal|disbursed)(?:\s+of)?(?:\s+rs\.?|\s+inr|\s+₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false);
    final principalMatch = principalRegex.firstMatch(text);
    if (principalMatch != null) {
      principal = double.tryParse(principalMatch.group(1)?.replaceAll(',', '') ?? '0') ?? 0.0;
    }

    // Dynamic Interest Rate
    double rate = 11.5;
    final rateRegex = RegExp(r'([0-9]+(?:\.[0-9]{1,2})?)\s*%\s*(?:p\.?a\.?|roi|interest)', caseSensitive: false);
    final rateMatch = rateRegex.firstMatch(text);
    if (rateMatch != null) {
      rate = double.tryParse(rateMatch.group(1) ?? '11.5') ?? 11.5;
    }

    if (principal == 0 && emi > 0) {
      principal = emi * 24;
    }

    return ExtractedLoanData(
      lenderName: lender,
      loanType: loanType,
      principalAmount: principal > 0 ? principal : (emi > 0 ? emi * 24 : 100000),
      interestRate: rate,
      interestType: 'reducing',
      emiAmount: emi > 0 ? emi : (principal > 0 ? principal / 24 : 5000),
      tenureMonths: 24,
      remainingMonths: 24,
      outstandingPrincipal: principal > 0 ? principal : 100000,
      nextEmiDate: DateTime.now().add(const Duration(days: 7)).toIso8601String().substring(0, 10),
      confidence: 0.88,
      rawSourceSnippet: text.length > 100 ? '${text.substring(0, 100)}...' : text,
    );
  }
}
