import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeColorKey = 'theme_color';

  // 缓存当前主题色，默认为蓝色
  Color _themeColor = Colors.blue;
  Color get themeColor => _themeColor;
  Brightness get brightness =>
      _themeColor.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark;
  ThemeService() {
    _loadThemeColor();
  }

  Future<void> _loadThemeColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hexColor = prefs.getString(_themeColorKey) ?? '#2196F3';
      _themeColor = _fromHex(hexColor);
      notifyListeners();
    } catch (e) {
      // 发生异常时保留默认值
    }
  }

  Color _fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> setThemeColor(String color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeColorKey, color);
      _themeColor = _fromHex(color);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to set theme color: $e');
    }
  }
}
