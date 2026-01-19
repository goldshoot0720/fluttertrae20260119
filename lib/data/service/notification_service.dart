import 'dart:async';
import 'dart:io';
import 'package:local_notifier/local_notifier.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'appwrite_service.dart';
import '../model/subscription_item.dart';

class NotificationService {
  final AppwriteService _appwriteService = AppwriteService();
  Timer? _timer;

  Future<void> init() async {
    await localNotifier.setup(
      appName: 'SubscriptionManager',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    
    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
      packageName: packageInfo.packageName,
    );
    await launchAtStartup.enable();

    // Step 6: Startup notification
    await _checkAndNotify(force: true);

    // Step 5: Background check
    _startBackgroundTimer();
  }

  void _startBackgroundTimer() {
    // Check every hour
    _timer = Timer.periodic(const Duration(hours: 1), (timer) async {
       final now = DateTime.now();
       if (now.hour >= 6) {
         await _checkAndNotify();
       }
    });
  }

  Future<void> _checkAndNotify({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString('last_notification_date');
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";

    if (!force && lastCheck == todayStr) {
      // Already notified today
      return;
    }

    try {
      final subscriptions = await _appwriteService.getSubscriptions();
      
      // Step 5 & 6: Check for expiring in 3 days.
      final threeDaysLater = now.add(const Duration(days: 3));

      List<SubscriptionItem> expiringItems = subscriptions.where((item) {
        // Simple comparison
        return item.nextDate.isAfter(now.subtract(const Duration(days: 1))) && item.nextDate.isBefore(threeDaysLater);
      }).toList();

      if (expiringItems.isNotEmpty) {
        for (var item in expiringItems) {
           _showNotification(item);
        }
        await prefs.setString('last_notification_date', todayStr);
      }
    } catch (e) {
      print('Error checking subscriptions: $e');
    }
  }

  void _showNotification(SubscriptionItem item) {
    LocalNotification notification = LocalNotification(
      identifier: item.id,
      title: 'Subscription Expiring Soon',
      body: '${item.name} expires on ${item.nextDate.toLocal().toString().split(' ')[0]}',
      actions: [
        LocalNotificationAction(
          text: 'Open',
        ),
      ],
    );
    notification.onClick = () {
      windowManager.show();
      windowManager.focus();
    };
    notification.show();
  }
}
