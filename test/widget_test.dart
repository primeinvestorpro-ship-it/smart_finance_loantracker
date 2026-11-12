import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_finance_app/main.dart';
import 'package:smart_finance_app/screens/auth/auth_lock_screen.dart';

void main() {
  testWidgets('App renders authentication lock screen on launch', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartFinanceApp(
          initialScreen: AuthLockScreen(isRegistration: true),
        ),
      ),
    );

    // Verify Phone & MPIN setup security UI
    expect(find.text('Secure with Phone & MPIN'), findsOneWidget);
    expect(find.text('Mobile Number'), findsOneWidget);
  });
}
