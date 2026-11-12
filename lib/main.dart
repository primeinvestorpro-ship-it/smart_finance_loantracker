import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/loans/loans_list_screen.dart';
import 'screens/loans/repayment_simulator_screen.dart';
import 'screens/transactions/transactions_screen.dart';
import 'screens/scanner/document_scanner_screen.dart';
import 'screens/auth/auth_lock_screen.dart';
import 'core/app_theme.dart';
import 'services/notification_service.dart';
import 'services/sms_reader_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissions();

  // Initialize background & foreground SMS auto-update listener
  await SmsReaderService.instance.startListening();

  final isRegistered = await AuthService.instance.isUserRegistered();
  final isLoggedIn = await AuthService.instance.isLoggedIn();

  runApp(
    ProviderScope(
      child: SmartFinanceApp(
        initialScreen: !isRegistered
            ? const AuthLockScreen(isRegistration: true)
            : (!isLoggedIn ? const AuthLockScreen(isRegistration: false) : const MainNavigationShell()),
      ),
    ),
  );
}

class SmartFinanceApp extends StatelessWidget {
  final Widget initialScreen;

  const SmartFinanceApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: initialScreen,
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    LoansListScreen(),
    RepaymentSimulatorScreen(),
    TransactionsScreen(),
    DocumentScannerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Loans',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up),
            selectedIcon: Icon(Icons.trending_up_rounded),
            label: 'Optimizer',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'AI Scanner',
          ),
        ],
      ),
    );
  }
}
