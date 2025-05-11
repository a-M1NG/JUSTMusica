import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final currentTheme = themeService.currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'), // Settings
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // <--- 将 Row 更改为 Column
            crossAxisAlignment: CrossAxisAlignment.start, // 使子项左对齐
            children: [
              // 第一行：主题选择
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择主题', // Select Theme
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Consumer<ThemeService>(
                    builder: (context, themeService, _) {
                      return ResponsiveGrid(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 600 ? 6 : 3,
                        children: themeService.availableThemes.map((theme) {
                          final isSelected = theme.name == currentTheme.name;
                          return ThemeCard(
                            theme: theme,
                            isSelected: isSelected,
                            onTap: () {
                              themeService.setThemeByName(theme.name);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32), // <--- 用于两行之间的垂直间距

              // 第二行：字体大小调整
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '歌词字体大小',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Consumer<ThemeService>(
                    // 使用 Consumer 获取最新的字体大小并传递给 FontSizeSliderWidget
                    builder: (context, themeServiceInstance, child) {
                      return FontSizeSliderWidget(
                        initialSize: themeServiceInstance.getLyricFontSize(),
                        onSizeChangedFinal: (newSize) {
                          themeServiceInstance.setLyricFontSize(newSize);
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeCard extends StatefulWidget {
  final AppTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const ThemeCard({
    super.key,
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<ThemeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.theme.themeData.primaryColor;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.9),
                      primaryColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(16),
                    splashColor: primaryColor.withOpacity(0.3),
                    highlightColor: primaryColor.withOpacity(0.15),
                  ),
                ),
              ),
              if (widget.isSelected)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Text(
                  widget.theme.name,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class ResponsiveGrid extends StatelessWidget {
  final int crossAxisCount;
  final List<Widget> children;

  const ResponsiveGrid({
    super.key,
    required this.crossAxisCount,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.6,
      children: children,
    );
  }
}

class FontSizeSliderWidget extends StatefulWidget {
  final double initialSize;
  final ValueChanged<double> onSizeChangedFinal; // 滑动结束后的回调

  const FontSizeSliderWidget({
    super.key,
    required this.initialSize,
    required this.onSizeChangedFinal,
  });

  @override
  State<FontSizeSliderWidget> createState() => _FontSizeSliderWidgetState();
}

class _FontSizeSliderWidgetState extends State<FontSizeSliderWidget> {
  late double _currentSliderValue;

  @override
  void initState() {
    super.initState();
    _currentSliderValue = widget.initialSize;
  }

  // 当父Widget传入的 initialSize 发生变化时，确保滑块也更新
  // (例如，如果字体大小可以从其他地方更改)
  @override
  void didUpdateWidget(FontSizeSliderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSize != oldWidget.initialSize) {
      // 只有当外部传入的值确实改变，并且与当前滑块的值不同时才更新
      // 这样可以避免在用户拖动时被外部更新意外覆盖
      if (widget.initialSize != _currentSliderValue) {
        setState(() {
          _currentSliderValue = widget.initialSize;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Center(
            child: Text(
              _currentSliderValue.toString(),
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: _currentSliderValue,
            min: 20.0,
            max: 30.0,
            divisions: 20, // (40-20)/20 = 1.0 step size
            label: _currentSliderValue.toString(),
            onChanged: (newValue) {
              setState(() {
                _currentSliderValue = newValue; // 实时更新本地状态，使滑块跟随
              });
            },
            onChangeEnd: (finalValue) {
              // 使用_currentSliderValue确保是用户最终选择的值
              widget.onSizeChangedFinal(_currentSliderValue);
            },
          ),
        ),
      ],
    );
  }
}
