import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:workmanager/workmanager.dart';

import 'data/service/notification_service.dart';
import 'data/service/oil_price_service.dart';
import 'ui/home_screen.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: $task");
    try {
      await checkAndNotifyBackground();
      await syncOilPriceBackground();
    } catch (e) {
      print("Error in background task: $e");
    }
    return Future.value(true);
  });
}

Future<void> _killOtherInstances() async {
  if (!Platform.isWindows) return;

  final currentPid = pid;
  final exeName = Platform.resolvedExecutable.split(Platform.pathSeparator).last;

  try {
    final result = await Process.run(
      'tasklist',
      ['/FI', 'IMAGENAME eq $exeName', '/FO', 'CSV', '/NH'],
    );
    final lines = (result.stdout as String).trim().split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 2) continue;

      final processPid = int.tryParse(parts[1].replaceAll('"', '').trim());
      if (processPid == null || processPid == currentPid) continue;

      try {
        await Process.run('taskkill', ['/PID', '$processPid', '/F']);
        print('Killed duplicate process: $processPid');
      } catch (e) {
        print('Failed to kill process $processPid: $e');
      }
    }
  } catch (e) {
    print('Error checking for duplicate processes: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await _killOtherInstances();
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1200, 820),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
    });
  } else if (Platform.isAndroid) {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
    Workmanager().registerPeriodicTask(
      "1",
      "simplePeriodicTask",
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  runApp(const MyApp());
  _initializeAppServices();
}

void _initializeAppServices() {
  Future<void>(() async {
    try {
      await NotificationService().init();
    } catch (e) {
      print('Notification service init failed: $e');
    }

    try {
      await OilPriceService().init();
    } catch (e) {
      print('Oil price service init failed: $e');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.notoSansTcTextTheme();
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
      primary: const Color(0xFF0F766E),
      secondary: const Color(0xFFA16207),
      surface: const Color(0xFFF6F1E8),
    );

    return MaterialApp(
      title: 'Subscription Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF3EEE4),
        textTheme: textTheme.copyWith(
          displayLarge: GoogleFonts.spaceGrotesk(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.6,
            color: const Color(0xFF1E1B18),
          ),
          displayMedium: GoogleFonts.spaceGrotesk(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
            color: const Color(0xFF1E1B18),
          ),
          titleLarge: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E1B18),
          ),
          bodyLarge: textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF312C28),
            height: 1.45,
          ),
          bodyMedium: textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF4E4842),
            height: 1.45,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF1E1B18),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFF9F6EF),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Color(0xFFD9CFBF)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1F2937),
          contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFCF6),
          hintStyle: textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF928A80),
          ),
          labelStyle: textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF6D645B),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFD8CDBE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFD8CDBE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.4),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF1F766E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF1F766E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1E1B18),
            side: const BorderSide(color: Color(0xFFD2C6B7)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFF9F5EC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
