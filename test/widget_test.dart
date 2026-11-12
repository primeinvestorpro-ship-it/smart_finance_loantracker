import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_finance_app/main.dart';

void main() {
  testWidgets('App renders main navigation shell successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartFinanceApp(),
      ),
    );

    // Verify main navigation destinations exist
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Loans'), findsWidgets);
    expect(find.text('Optimizer'), findsWidgets);
    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('AI Scanner'), findsWidgets);
  });
}
