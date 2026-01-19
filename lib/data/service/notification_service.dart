import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'appwrite_service.dart';
import '../model/subscription_item.dart';

class NotificationService {
  final AppwriteService _appwriteService = AppwriteService();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;

  Future<void> init() async {
    // Desktop Setup
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
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
    } else if (Platform.isAndroid) {
      // Android Setup
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      
      await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
      
      // Request permission for Android 13+
      await _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }

    // Common Logic (Startup check)
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
      final today = DateTime(now.year, now.month, now.day);

      List<SubscriptionItem> expiringItems = subscriptions.where((item) {
        final itemDate = DateTime(item.nextDate.year, item.nextDate.month, item.nextDate.day);
        final difference = itemDate.difference(today).inDays;
        return difference >= 0 && difference <= 3;
      }).toList();

      if (expiringItems.isNotEmpty) {
        for (var item in expiringItems) {
           await _showNotification(item);
        }
        await prefs.setString('last_notification_date', todayStr);
      }
    } catch (e) {
      print('Error checking subscriptions: $e');
    }
  }

  Future<void> _showNotification(SubscriptionItem item) async {
    final title = 'Subscription Expiring Soon';
    final body = '${item.name} expires on ${item.nextDate.toLocal().toString().split(' ')[0]}';

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      LocalNotification notification = LocalNotification(
        identifier: item.id,
        title: title,
        body: body,
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
    } else if (Platform.isAndroid) {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails('subscription_channel', 'Subscription Notifications',
              channelDescription: 'Notifications for expiring subscriptions',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker');
      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);
      
      // Use hash of ID for notification ID (must be int)
      await _flutterLocalNotificationsPlugin.show(
        item.id.hashCode,
        title,
        body,
        notificationDetails,
      );
    }
  }
}
