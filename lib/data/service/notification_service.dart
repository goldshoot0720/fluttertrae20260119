import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'appwrite_service.dart';
import '../model/subscription_item.dart';

// Top-level function for background execution
@pragma('vm:entry-point')
Future<void> checkAndNotifyBackground() async {
  final notificationService = NotificationService();
  if (Platform.isAndroid) {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await notificationService._flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }
  await notificationService._checkAndNotify(force: true);
}

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
    } else if (Platform.isAndroid) {
      // Android Setup
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      
      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );
      
      // Request permission for Android 13+
      await _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }

    // Common Logic (Startup check)
    await _checkAndNotify(force: true);

    // Background check
    _startBackgroundTimer();
  }

  void _startBackgroundTimer() {
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
       return;
    }
    
    if (now.hour < 6 && !force) {
        return; 
    }

    try {
      final subscriptions = await _appwriteService.getSubscriptions();
      
      final today = DateTime(now.year, now.month, now.day);

      List<SubscriptionItem> expiringItems = subscriptions.where((item) {
        final itemDate = DateTime(item.nextDate.year, item.nextDate.month, item.nextDate.day);
        final difference = itemDate.difference(today).inDays;
        return difference >= 0 && difference <= 3;
      }).toList();

      expiringItems.sort((a, b) => a.nextDate.compareTo(b.nextDate));

      if (expiringItems.isNotEmpty) {
        for (var item in expiringItems) {
          final daysLeft = DateTime(item.nextDate.year, item.nextDate.month, item.nextDate.day)
              .difference(today).inDays;
           await _showNotification(item, daysLeft);
        }
        await prefs.setString('last_notification_date', todayStr);
      }
    } catch (e) {
      print('Error checking subscriptions: $e');
    }
  }

  Future<void> _showNotification(SubscriptionItem item, int daysLeft) async {
    final dateStr = '${item.nextDate.year}/${item.nextDate.month.toString().padLeft(2, '0')}/${item.nextDate.day.toString().padLeft(2, '0')}';
    final daysText = daysLeft == 0 ? '今天到期' : daysLeft == 1 ? '明天到期' : '$daysLeft 天後到期';
    final title = '⚠️ 訂閱即將到期：${item.name}';
    final body = '$daysText ($dateStr)\n帳號：${item.account}｜金額：\$${item.price}';

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      LocalNotification notification = LocalNotification(
        identifier: item.id,
        title: title,
        body: body,
        actions: [
          LocalNotificationAction(
            text: '開啟',
          ),
        ],
      );
      notification.onClick = () {
        windowManager.show();
        windowManager.focus();
      };
      notification.show();
    } else if (Platform.isAndroid) {
      AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails('subscription_channel_high_v2', '訂閱到期通知',
              channelDescription: '訂閱即將到期的提醒通知',
              importance: Importance.max,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(body),
              ticker: '訂閱到期提醒');
      NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);
      
      await _flutterLocalNotificationsPlugin.show(
        id: item.id.hashCode,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    }
  }
}
