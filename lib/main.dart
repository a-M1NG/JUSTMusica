import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/playback_service.dart';
import 'services/theme_service.dart';
import 'views/main_page.dart';
import 'package:window_size/window_size.dart';
import 'dart:ui';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 仅在桌面平台生效
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // 设置窗口标题（可选）
    setWindowTitle('JUST Musica');

    // 设置最小尺寸
    setWindowMinSize(const Size(1160, 600));
  }
  DatabaseService.init();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// 辅助函数：根据 Color 创建 MaterialColor
MaterialColor createMaterialColor(Color color) {
  List<double> strengths = [.05, .1, .2, .3, .4, .5, .6, .7, .8, .9];
  Map<int, Color> swatch = {};
  for (double strength in strengths) {
    int value = (strength * 1000).round();
    swatch[value] = _tintColor(color, strength);
  }
  return MaterialColor(color.value, swatch);
}

Color _tintColor(Color color, double factor) {
  int tintValue(int channel) {
    return (channel + (255 - channel) * factor).round().clamp(0, 255);
  }

  return Color.fromRGBO(
    tintValue(color.red),
    tintValue(color.green),
    tintValue(color.blue),
    1,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlaybackService>(
            create: (_) => PlaybackService()),
        ChangeNotifierProvider<ThemeService>(
          create: (_) => ThemeService(),
          // 确保 ThemeService 在 MaterialApp 之前初始化完成
          lazy: false,
        ),
      ],
      child: Builder(
        builder: (context) {
          final themeService = Provider.of<ThemeService>(context, listen: true);

          return MaterialApp(
            title: "JUST Musica",
            debugShowCheckedModeBanner: false,
            theme: themeService.currentThemeData,
            home: const MainPage(),
            builder: (context, child) {
              // 确保主题加载完成后再构建UI
              return FutureBuilder(
                future: _ensureThemeLoaded(context),
                builder: (context, snapshot) {
                  return child ?? const SizedBox();
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _ensureThemeLoaded(BuildContext context) async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    // 如果当前是默认主题，等待可能正在进行的主题加载
    if (themeService.currentTheme == themeService.availableThemes.first) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}
