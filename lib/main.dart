import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:workmanager/workmanager.dart';
import 'data/service/notification_service.dart';
import 'ui/home_screen.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: $task");
    try {
      await checkAndNotifyBackground();
    } catch (e) {
      print("Error in background task: $e");
    }
    return Future.value(true);
  });
}

/// Kill other instances of this app on Windows
Future<void> _killOtherInstances() async {
  if (!Platform.isWindows) return;
  
  final currentPid = pid;
  final exeName = Platform.resolvedExecutable.split(Platform.pathSeparator).last;
  
  try {
    final result = await Process.run('tasklist', ['/FI', 'IMAGENAME eq $exeName', '/FO', 'CSV', '/NH']);
    final lines = (result.stdout as String).trim().split('\n');
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(',');
      if (parts.length >= 2) {
        final processPid = int.tryParse(parts[1].replaceAll('"', '').trim());
        if (processPid != null && processPid != currentPid) {
          try {
            await Process.run('taskkill', ['/PID', '$processPid', '/F']);
            print('Killed duplicate process: $processPid');
          } catch (e) {
            print('Failed to kill process $processPid: $e');
          }
        }
      }
    }
  } catch (e) {
    print('Error checking for duplicate processes: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Init Window Manager (Desktop Only)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await _killOtherInstances();
    
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(900, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.hide();
    });
  } else if (Platform.isAndroid) {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true
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
  
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Premium dark theme
    final baseTextTheme = GoogleFonts.interTextTheme();
    
    return MaterialApp(
      title: 'Subscription Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF7C4DFF),
          secondary: const Color(0xFF448AFF),
          tertiary: const Color(0xFF00E5FF),
          surface: const Color(0xFF1A1A2E),
          onSurface: Colors.white,
          error: const Color(0xFFFF5252),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F23),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A2E),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: baseTextTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF16213E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF8899AA)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C4DFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF8899AA),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          elevation: 8,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1A1A2E),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
