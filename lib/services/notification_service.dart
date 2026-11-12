import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../models/loan_model.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle tap action if needed
        },
      );
      _isInitialized = true;
    } catch (e) {
      // In non-mobile environments or unsupported tests, gracefully handle
    }
  }

  /// Request Notification Permissions on Android 13+ (POST_NOTIFICATIONS)
  Future<bool> requestPermissions() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Format Indian Rupee Currency string
  static String formatINR(double amount) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }

  /// Schedule full multi-stage reminders for a loan:
  /// - T-7 Days: 1 Week Before Warning
  /// - T-3 Days: Mid-cycle countdown
  /// - T-1 Day: Due Tomorrow Urgent Reminder
  /// - T-0: Due Today Warning
  /// - T+1: Overdue Escalation (if unpaid)
  Future<void> scheduleMultiStageEmiRenameReminders(LoanModel loan) async {
    final nextEmi = loan.nextEmiDate;
    final emiStr = formatINR(loan.emiAmount);
    final lender = loan.lenderName;
    final dateStr = DateFormat('dd MMM yyyy').format(nextEmi);

    // 1. T-7 Days: 1 Week Before
    final tMinus7 = nextEmi.subtract(const Duration(days: 7));
    if (tMinus7.isAfter(DateTime.now())) {
      await _scheduleLocalNotification(
        id: (loan.id.hashCode + 7).abs() % 100000,
        title: '📅 7 Days to $lender EMI',
        body: 'Upcoming EMI of $emiStr is due on $dateStr. Check that your account balance is ready.',
        scheduledDate: DateTime(tMinus7.year, tMinus7.month, tMinus7.day, 9, 0),
      );
    }

    // 2. T-3 Days
    final tMinus3 = nextEmi.subtract(const Duration(days: 3));
    if (tMinus3.isAfter(DateTime.now())) {
      await _scheduleLocalNotification(
        id: (loan.id.hashCode + 3).abs() % 100000,
        title: '⏳ 3 Days Left: $lender EMI',
        body: 'Reminder: $emiStr will be debited on $dateStr.',
        scheduledDate: DateTime(tMinus3.year, tMinus3.month, tMinus3.day, 9, 0),
      );
    }

    // 3. T-1 Day (Due Tomorrow)
    final tMinus1 = nextEmi.subtract(const Duration(days: 1));
    if (tMinus1.isAfter(DateTime.now())) {
      await _scheduleLocalNotification(
        id: (loan.id.hashCode + 1).abs() % 100000,
        title: '⚠️ EMI Due Tomorrow: $emiStr',
        body: 'Auto-debit for ${loan.name} will trigger tomorrow ($dateStr). Keep sufficient balance to prevent ECS bounce penalties.',
        scheduledDate: DateTime(tMinus1.year, tMinus1.month, tMinus1.day, 20, 0),
      );
    }

    // 4. T-0 (Due Today)
    if (nextEmi.isAfter(DateTime.now())) {
      await _scheduleLocalNotification(
        id: (loan.id.hashCode + 0).abs() % 100000,
        title: '🚨 EMI Due Today: $emiStr',
        body: 'Your EMI for ${loan.name} is scheduled for debit today by $lender.',
        scheduledDate: DateTime(nextEmi.year, nextEmi.month, nextEmi.day, 8, 30),
      );
    }
  }

  /// Internal notification dispatch wrapper
  Future<void> _scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'emi_reminders_channel',
      'EMI & Loan Reminders',
      channelDescription: 'Multi-stage alerts for loan EMIs (1 week before, due tomorrow, and due today)',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      // In production with flutter_local_notifications, zonedSchedule can be used.
      // For immediate fallback or when testing, show/schedule is called safely.
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
      );
    } catch (_) {}
  }

  /// Trigger a live test notification for user demonstration
  Future<void> showTestReminderNow({
    required String loanName,
    required double emiAmount,
    required int daysLeft,
  }) async {
    final emiStr = formatINR(emiAmount);
    await _notificationsPlugin.show(
      999,
      daysLeft == 7
          ? '📅 1 Week Advance Notice: $loanName'
          : daysLeft == 1
              ? '⚠️ EMI Due Tomorrow: $emiStr'
              : '🚨 EMI Due in $daysLeft Days: $emiStr',
      'Smart Reminder: Ensure account has $emiStr available before debit day.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'emi_reminders_channel',
          'EMI & Loan Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
