import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/loan_model.dart';
import '../../providers/finance_providers.dart';
import '../../services/gemini_extraction_service.dart';

class DocumentScannerScreen extends ConsumerStatefulWidget {
  const DocumentScannerScreen({super.key});

  @override
  ConsumerState<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends ConsumerState<DocumentScannerScreen> {
  final TextEditingController _rawTextController = TextEditingController();
  bool _isProcessing = false;
  ExtractedLoanData? _extractedData;

  // Sample templates to simulate real SMS alerts and document excerpts
  final String _sampleHdfcSanction = '''
Dear Customer, Congratulations! Your HDFC Bank Personal Loan account ending with 4512 has been disbursed.
Sanctioned Loan Amount: Rs 3,50,000.00
Interest Rate: 11.25% p.a. reducing
Monthly EMI: Rs 11,500.00
Tenure: 36 Months.
First EMI debit date: 05 Dec 2026.
''';

  final String _sampleSbiSms = '''
SBI Alert: EMI Rs 18,450 for Auto Loan A/C XX7891 is scheduled for auto-debit on 10-12-2026. Available balance should be maintained to avoid ECS bounce charges.
''';

  @override
  void dispose() {
    _rawTextController.dispose();
    super.dispose();
  }

  Future<void> _processText(String text) async {
    setState(() {
      _isProcessing = true;
      _extractedData = null;
    });

    // Invoke Gemini / Deterministic Document Extractor
    final data = await GeminiExtractionService.parseLoanText(rawText: text);

    setState(() {
      _isProcessing = false;
      _extractedData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI & Document Loan Scanner'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Instructions / Privacy Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.security, color: Color(0xFF10B981), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Privacy-First: Data is parsed locally or securely anonymized. Human confirmation is mandatory before any loan is committed.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Quick Test Samples
          const Text('Quick Test Scenarios:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('HDFC Sanction Letter'),
                onPressed: () {
                  _rawTextController.text = _sampleHdfcSanction;
                  _processText(_sampleHdfcSanction);
                },
              ),
              ActionChip(
                label: const Text('SBI Auto Loan SMS'),
                onPressed: () {
                  _rawTextController.text = _sampleSbiSms;
                  _processText(_sampleSbiSms);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. Raw Text Input / OCR paste
          TextField(
            controller: _rawTextController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Paste Loan SMS / Statement OCR Text',
              hintText: 'Paste SMS text, bank email, or sanction letter excerpt...',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text(
              _isProcessing ? 'Analyzing with AI...' : 'Extract Loan Parameters',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: _isProcessing || _rawTextController.text.isEmpty
                ? null
                : () => _processText(_rawTextController.text),
          ),

          const SizedBox(height: 24),

          // 4. Extracted Result Preview Card with Human Confirmation Gate
          if (_extractedData != null) _buildExtractedPreviewCard(_extractedData!, inr),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildExtractedPreviewCard(ExtractedLoanData data, NumberFormat inr) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI Extracted Loan Details',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(data.confidence * 100).toInt()}% Confidence',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Colors.white12),
          _buildPreviewRow('Lender', data.lenderName),
          _buildPreviewRow('Loan Type', data.loanType),
          _buildPreviewRow('Principal Amount', inr.format(data.principalAmount)),
          _buildPreviewRow('Interest Rate', '${data.interestRate}% p.a.'),
          _buildPreviewRow('Monthly EMI', inr.format(data.emiAmount)),
          _buildPreviewRow('Remaining Tenure', '${data.remainingMonths} Months'),
          _buildPreviewRow('Next EMI Due', data.nextEmiDate),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text(
                'Confirm & Add to Portfolio (Schedule Reminders)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _confirmAndSaveLoan(data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSaveLoan(ExtractedLoanData data) async {
    final loan = LoanModel(
      id: const Uuid().v4(),
      name: '${data.lenderName} ${data.loanType}',
      lenderName: data.lenderName,
      accountNumberMasked: 'XXXX-EXTRACTED',
      category: LoanCategory.fromString(data.loanType),
      originalPrincipal: data.principalAmount,
      currentOutstanding: data.outstandingPrincipal > 0 ? data.outstandingPrincipal : data.principalAmount,
      annualInterestRate: data.interestRate,
      interestType: data.interestType == 'flat' ? 'flat_rate' : 'reducing_balance',
      emiAmount: data.emiAmount,
      emiDebitDay: 5,
      commencementDate: DateTime.now(),
      firstEmiDate: DateTime.tryParse(data.nextEmiDate) ?? DateTime.now(),
      totalTenureMonths: data.tenureMonths,
      remainingTenureMonths: data.remainingMonths,
      notes: 'Imported via AI Document / SMS Extractor',
    );

    await ref.read(loansProvider.notifier).addLoan(loan);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully confirmed and added "${loan.name}" with 7-day alert rules!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      setState(() {
        _extractedData = null;
        _rawTextController.clear();
      });
    }
  }
}
