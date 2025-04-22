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
  List strengths = <double>[.05];
  final swatch = <int, Color>{};
  final int r = color.red, g = color.green, b = color.blue;
  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
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
          return MaterialApp(
            title: 'JUST Music',
            // 直接根据 themeService.themeColor 构建主题
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: createMaterialColor(themeService.themeColor),
              fontFamily: 'HarmonyOS_Sans_SC',
              visualDensity: VisualDensity.adaptivePlatformDensity,
              brightness: Brightness.light,
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
