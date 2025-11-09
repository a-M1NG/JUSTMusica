import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/playback_service.dart';
import 'services/theme_service.dart';
import 'services/service_locator.dart';
import 'views/main_page.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:just_musica/utils/thumbnail_generator.dart';

BuildContext? globalProviderContext;

class MyWindowListener extends WindowListener {
  final BuildContext context;
  MyWindowListener(this.context);

  @override
  Future<bool> onWindowClose() async {
    if (globalProviderContext != null) {
      final playbackService = serviceLocator<PlaybackService>();
      await playbackService.saveStateToPrefs();
      ThumbnailGenerator().close();
    }
    return true; // 允许窗口关闭
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThumbnailGenerator().init();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      minimumSize: Size(1260, 800),
      title: 'JUST Musica',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  DatabaseService.init();
  
  // 初始化服务定位器
  await setupServiceLocator();
  
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<MainPageState> _mainPageKey = GlobalKey<MainPageState>();
  late MyWindowListener _windowListener;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // 在此处保存当前状态到文件，确保在应用退出前执行
      debugPrint('Saving state before exit...');
      debugPrint('MainPage disposed');
      _mainPageKey.currentState?.dispose();
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(_windowListener);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _windowListener = MyWindowListener(context);
    windowManager.addListener(_windowListener);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlaybackService>.value(
          value: serviceLocator<PlaybackService>(),
        ),
        ChangeNotifierProvider<ThemeService>.value(
          value: serviceLocator<ThemeService>(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final themeService = Provider.of<ThemeService>(context, listen: true);
          globalProviderContext = context; // 保存全局上下文
          return MaterialApp(
            title: "JUST Musica",
            debugShowCheckedModeBanner: false,
            theme: themeService.currentThemeData,
            home: MainPage(key: _mainPageKey),
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
