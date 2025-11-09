import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';

  // 定义所有可用主题
  final List<AppTheme> _availableThemes = [
    AppTheme(
      name: '深空蓝',
      themeData: _buildThemeData(Colors.blue), // 使用统一的主题构建方法
    ),
    AppTheme(
      name: '烈焰红',
      themeData: _buildThemeData(Colors.red),
    ),
    AppTheme(
      name: '森林绿',
      themeData: _buildThemeData(Colors.green),
    ),
    AppTheme(
      name: '神秘紫',
      themeData: _buildThemeData(Colors.purple),
    ),
    AppTheme(
      name: '阳光橙',
      themeData: _buildThemeData(Colors.orange),
    ),
    AppTheme(
      name: '极光青',
      themeData: _buildThemeData(Colors.cyan),
    ),
    AppTheme(
      name: '炭灰黑',
      themeData: _buildDarkThemeData(Colors.blueGrey),
    ),
  ];

  late AppTheme _currentTheme;
  late SharedPreferences _prefs;

  ThemeService() {
    _currentTheme = _availableThemes.first;
    _loadTheme();
  }

  List<AppTheme> get availableThemes => _availableThemes;
  ThemeData get currentThemeData => _currentTheme.themeData;
  AppTheme get currentTheme => _currentTheme;

  Future<void> _loadTheme() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final themeIndex = _prefs.getInt(_themeKey) ?? 0;
      if (themeIndex >= 0 && themeIndex < _availableThemes.length) {
        _currentTheme = _availableThemes[themeIndex];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> setTheme(int index) async {
    if (index >= 0 && index < _availableThemes.length) {
      _currentTheme = _availableThemes[index];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, index);
      notifyListeners();
    }
  }

  double get lyricFontSize {
    final currLyricsFontSize = _prefs.getDouble('lyricFontSize') ?? 20.0;
    return currLyricsFontSize;
  }

  double getLyricFontSize() {
    final currLyricsFontSize = _prefs.getDouble('lyricFontSize') ?? 20.0;
    return currLyricsFontSize;
  }

  void setLyricFontSize(double size) {
    _prefs.setDouble('lyricFontSize', size);
  }

  Future<void> setThemeByName(String name) async {
    final index = _availableThemes.indexWhere((theme) => theme.name == name);
    if (index != -1) {
      await setTheme(index);
    }
  }

  static ThemeData _buildThemeData(Color primaryColor) {
    final colorScheme = ColorScheme.light().copyWith(
      primary: primaryColor,
      secondary: primaryColor.withOpacity(0.75),
      surface: Colors.white,
      onPrimary: Colors.white, // 文字颜色在主色上
      onSecondary: Colors.white,
      onSurface: Colors.black,
      brightness: Brightness.light,
    );

    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary, // 显式设置为 primary
        foregroundColor: colorScheme.onPrimary, // 标题和图标颜色
        elevation: 4,
      ),
    );
    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'HarmonyOS_Sans_SC'),
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // 弹出菜单主题
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      brightness: Brightness.light,
    );
  }

  // 暗色主题的构建方法（如果需要）
  static ThemeData _buildDarkThemeData(Color primaryColor) {
    final colorScheme = ColorScheme.dark().copyWith(
      primary: primaryColor,
      secondary: primaryColor.withOpacity(0.75),
      surface: Colors.grey[850],
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      brightness: Brightness.dark,
    );

    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary, // 显式设置为 primary
        foregroundColor: colorScheme.onPrimary, // 标题和图标颜色
        elevation: 4,
      ),
    );
    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
        fontFamily: 'HarmonyOS_Sans_SC',
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colorScheme.onPrimary,
          iconColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      brightness: Brightness.dark,
    );
  }
}

class AppTheme {
  final String name;
  final ThemeData themeData;

  AppTheme({
    required this.name,
    required this.themeData,
  });
}
