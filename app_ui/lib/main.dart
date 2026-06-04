import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'lang/translations.dart';

part 'app_theme.dart';
part 'app_localizations.dart';
part 'app_models.dart';
part 'backend.dart';
part 'dashboard_screen.dart';
part 'dashboard_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализируем window manager для десктопа
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
  }
  
  _appendFrontendHeartbeat('main() entered');
  await _installFrontendCrashLogging();
  _appendFrontendHeartbeat('crash logging installed');
  runZonedGuarded(
    () => runApp(const FireProxyApp()),
    (error, stackTrace) {
      _appendFrontendCrashLog('ZONE', error, stackTrace);
    },
  );
}

Future<void> _installFrontendCrashLogging() async {
  FlutterError.onError = (details) {
    _appendFrontendCrashLog(
      'FLUTTER',
      details.exception,
      details.stack ?? StackTrace.current,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _appendFrontendCrashLog('PLATFORM', error, stackTrace);
    return false;
  };
}

void _appendFrontendCrashLog(String source, Object error, StackTrace stackTrace) {
  final now = DateTime.now().toIso8601String();
  final payload = StringBuffer()
    ..writeln('[$now] source=$source')
    ..writeln('error=$error')
    ..writeln(stackTrace.toString())
    ..writeln('---');
  for (final path in _frontendLogPaths()) {
    try {
      final logFile = File(path);
      logFile.parent.createSync(recursive: true);
      logFile.writeAsStringSync(
        payload.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Continue with other paths.
    }
  }
  stderr.writeln(payload.toString());
}

void _appendFrontendHeartbeat(String message) {
  final now = DateTime.now().toIso8601String();
  final payload = '[$now] heartbeat=$message\n';
  for (final path in _frontendLogPaths()) {
    try {
      final logFile = File(path);
      logFile.parent.createSync(recursive: true);
      logFile.writeAsStringSync(payload, mode: FileMode.append, flush: true);
    } catch (_) {
      // Continue with other paths.
    }
  }
}

List<String> _frontendLogPaths() {
  final home = Platform.environment['HOME'] ?? '';
  return <String>[
    '/tmp/FireProxy-frontend-crash.log',
    if (home.isNotEmpty) '$home/.cache/FireProxy/frontend-crash.log',
    if (home.isNotEmpty) '$home/FireProxy-frontend-crash.log',
  ];
}

class FireProxyApp extends StatefulWidget {
  const FireProxyApp({super.key});

  @override
  State<FireProxyApp> createState() => _FireProxyAppState();
}

class _FireProxyAppState extends State<FireProxyApp> with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      trayManager.addListener(this);
      windowManager.addListener(this);
      _initTray();
      _initWindow();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _initWindow() async {
    try {
      // Настройка поведения при закрытии окна
      await windowManager.setPreventClose(true);
      
      // Опциональные настройки
      await windowManager.setMinimumSize(const Size(800, 600));
    } catch (e) {
      print('Ошибка инициализации окна: $e');
    }
  }

  Future<void> _initTray() async {
    try {
      // Установка иконки трея
      if (Platform.isWindows) {
        await trayManager.setIcon('assets/logo_tray.ico');
      } else if (Platform.isLinux) {
        await trayManager.setIcon('assets/logo_tray.png');
      } else if (Platform.isMacOS) {
        await trayManager.setIcon('assets/logo_tray.png');
      }

      // Создание контекстного меню
      final Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show',
            label: 'Показать',
          ),
          MenuItem(
            key: 'hide',
            label: 'Скрыть',
          ),
          MenuItem(
            key: 'separator',
            label: '',
          ),
          MenuItem(
            key: 'exit',
            label: 'Выход',
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
    } catch (e) {
      print('Ошибка инициализации трея: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    // При клике на иконку трея показываем/скрываем окно
    _toggleWindowVisibility();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
        break;
      case 'hide':
        _hideWindow();
        break;
      case 'exit':
        exit(0);
      default:
        break;
    }
  }

  @override
  void onWindowClose() async {
    // Сворачиваем в трей вместо закрытия при клике на X
    await _hideWindow();
  }

  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      print('Ошибка при показе окна: $e');
    }
  }

  Future<void> _hideWindow() async {
    try {
      await windowManager.hide();
    } catch (e) {
      print('Ошибка при скрытии окна: $e');
    }
  }

  void _toggleWindowVisibility() async {
    try {
      final isVisible = await windowManager.isVisible();
      if (isVisible) {
        await _hideWindow();
      } else {
        await _showWindow();
      }
    } catch (e) {
      print('Ошибка переключения видимости: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FireProxy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppPalette.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppPalette.bg1,
        fontFamily: 'Segoe UI',
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white.withValues(alpha: 0.84),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: AppUi.primaryButton(),
        ),
        textButtonTheme: TextButtonThemeData(
          style: AppUi.textButton(),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: AppUi.outlinedButton(),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: AppUi.segmentedButton(),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppPalette.blueDark;
            }
            return const Color(0xFFD1D4DD);
          }),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppPalette.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
