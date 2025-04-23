import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/playback_service.dart';
import 'services/theme_service.dart';
import 'views/main_page.dart';

void main() async {
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
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          debugPrint(
              "main: Current theme color: ${Theme.of(context).primaryColor}");
          return MaterialApp(
            title: 'JUST Music',
            // 直接根据 themeService.themeColor 构建主题
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: createMaterialColor(themeService.themeColor),
              colorScheme: ColorScheme.fromSwatch(
                primarySwatch: createMaterialColor(themeService.themeColor),
                // brightness: themeService.brightness,
              ).copyWith(
                surface: Colors.grey[100],
                onPrimary: Colors.white,
              ),
              fontFamily: 'HarmonyOS_Sans_SC',
              visualDensity: VisualDensity.adaptivePlatformDensity,
              // brightness: themeService.brightness,
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              popupMenuTheme: PopupMenuThemeData(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            // 移除 darkTheme 与 themeMode，直接使用统一主题
            home: const MainPage(),
          );
        },
      ),
    );
  }
}
