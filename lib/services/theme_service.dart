import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  // SharedPreferences 键名，用于存储主题颜色
  static const String _themeColorKey = 'theme_color';

  /// 设置主题颜色
  /// [color] 为颜色字符串，例如 '#FF0000'（红色）
  Future<void> setThemeColor(String color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeColorKey, color);
    } catch (e) {
      throw Exception('Failed to set theme color: $e');
    }
  }

  /// 获取当前主题颜色
  /// 返回颜色字符串，例如 '#FF0000'，如果未设置则返回默认颜色 '#2196F3'（蓝色）
  Future<String> getThemeColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_themeColorKey) ?? '#2196F3'; // 默认蓝色
    } catch (e) {
      throw Exception('Failed to get theme color: $e');
    }
  }
}