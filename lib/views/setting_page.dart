import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // 预定义颜色选项
  static const List<Map<String, dynamic>> colorOptions = [
    {'name': '蓝色', 'hex': '#2196F3', 'color': Colors.blue},
    {'name': '红色', 'hex': '#F44336', 'color': Colors.red},
    {'name': '绿色', 'hex': '#4CAF50', 'color': Colors.green},
    {'name': '紫色', 'hex': '#9C27B0', 'color': Colors.purple},
    {'name': '橙色', 'hex': '#FF9800', 'color': Colors.orange},
    {'name': '青色', 'hex': '#00BCD4', 'color': Colors.cyan},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '主题颜色',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<ThemeService>(
              builder: (context, themeService, _) {
                return GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: colorOptions.length,
                  itemBuilder: (context, index) {
                    final option = colorOptions[index];
                    final isSelected =
                        themeService.themeColor.value == option['color'].value;
                    return GestureDetector(
                      onTap: () {
                        themeService.setThemeColor(option['hex']);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: option['color'],
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
