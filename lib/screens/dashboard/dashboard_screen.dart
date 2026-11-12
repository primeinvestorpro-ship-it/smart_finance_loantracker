import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/loan_model.dart';
import '../../providers/finance_providers.dart';
import '../../services/notification_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final loansAsync = ref.watch(loansProvider);
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Finance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Loan Portfolio & Cash Flow',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notification_add_outlined),
            tooltip: 'Send Test 7-Day & 1-Day EMI Alerts',
            onPressed: () async {
              if (metrics.nextUpcomingEmiLoan != null) {
                await NotificationService.instance.showTestReminderNow(
                  loanName: metrics.nextUpcomingEmiLoan!.name,
                  emiAmount: metrics.nextUpcomingEmiLoan!.emiAmount,
                  daysLeft: metrics.nextUpcomingEmiLoan!.daysUntilNextEmi,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Reminder triggered for ${metrics.nextUpcomingEmiLoan!.name} (T-${metrics.nextUpcomingEmiLoan!.daysUntilNextEmi} days)',
                      ),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(loansProvider.notifier).loadLoans();
          await ref.read(transactionsProvider.notifier).loadTransactions();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Next Upcoming EMI Alert Banner (Week-before & Due-date status)
            if (metrics.nextUpcomingEmiLoan != null)
              _buildUpcomingEmiBanner(context, metrics.nextUpcomingEmiLoan!, inr),

            const SizedBox(height: 16),

            // 2. Financial Overview Hero Cards
            _buildFinancialOverviewGrid(metrics, inr),

            const SizedBox(height: 20),

            // 3. Debt Analytics Card
            _buildDebtAnalyticsCard(metrics, inr),

            const SizedBox(height: 20),

            // 4. Interactive Portfolio Distribution Chart
            _buildPortfolioDonutChart(loansAsync, inr),

            const SizedBox(height: 20),

            // 5. Highest Interest First Spotlight (Avalanche Candidate)
            if (metrics.highestInterestLoan != null)
              _buildHighestInterestSpotlight(context, metrics.highestInterestLoan!, inr),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEmiBanner(BuildContext context, dynamic loan, NumberFormat inr) {
    final daysLeft = loan.daysUntilNextEmi;
    final isWithinWeek = daysLeft <= 7;
    final isTomorrowOrToday = daysLeft <= 1;

    final bannerBg = isTomorrowOrToday
        ? const Color(0xFFEF4444)
        : isWithinWeek
            ? const Color(0xFFF59E0B)
            : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bannerBg.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTomorrowOrToday ? Icons.warning_rounded : Icons.calendar_month_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isTomorrowOrToday
                          ? 'URGENT: EMI DUE SOON'
                          : 'UPCOMING EMI (7-DAY WINDOW)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        daysLeft == 0 ? 'Today' : '$daysLeft days left',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  loan.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${inr.format(loan.emiAmount)} debit scheduled on ${DateFormat('dd MMM').format(loan.nextEmiDate)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialOverviewGrid(DashboardMetrics metrics, NumberFormat inr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Financial Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Total Outstanding Debt',
                value: inr.format(metrics.totalOutstandingDebt),
                icon: Icons.account_balance_wallet_outlined,
                accentColor: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Monthly EMI Outflow',
                value: inr.format(metrics.totalMonthlyEmi),
                icon: Icons.payments_outlined,
                accentColor: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Monthly Income',
                value: inr.format(metrics.monthlyIncome),
                icon: Icons.trending_up,
                accentColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Monthly Surplus',
                value: inr.format(metrics.availableBalance),
                icon: Icons.savings_outlined,
                accentColor: const Color(0xFF06B6D4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: accentColor, size: 22),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtAnalyticsCard(DashboardMetrics metrics, NumberFormat inr) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debt Profile & Ratio',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Active Loans', '${metrics.activeLoansCount}'),
              _buildStatItem('Debt-to-Income', '${metrics.debtToIncomeRatio.toStringAsFixed(1)}%'),
              _buildStatItem(
                'Safety Status',
                metrics.debtToIncomeRatio < 40 ? 'Healthy' : 'High Burden',
                color: metrics.debtToIncomeRatio < 40
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioDonutChart(AsyncValue<List<LoanModel>> loansAsync, NumberFormat inr) {
    return loansAsync.when(
      data: (loans) {
        if (loans.isEmpty) return const SizedBox.shrink();

        final colors = [
          const Color(0xFF10B981),
          const Color(0xFF06B6D4),
          const Color(0xFFF59E0B),
          const Color(0xFFEF4444),
          const Color(0xFF8B5CF6),
        ];

        final sections = loans.asMap().entries.map((entry) {
          final index = entry.key;
          final loan = entry.value;
          return PieChartSectionData(
            value: loan.currentOutstanding,
            title: '${loan.annualInterestRate}%',
            color: colors[index % colors.length],
            radius: 40,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Loan Distribution & Interest Rates',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Legends
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: loans.asMap().entries.map((e) {
                  final idx = e.key;
                  final l = e.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[idx % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${l.name} (${l.annualInterestRate}%)',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildHighestInterestSpotlight(BuildContext context, dynamic loan, NumberFormat inr) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C1E3C), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.flash_on, color: Color(0xFFEF4444), size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Highest Interest Rate Alert',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${loan.annualInterestRate}% p.a.',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            loan.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Outstanding: ${inr.format(loan.currentOutstanding)} • Recommended for Avalanche Prepayment Priority',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
