import 'package:flutter/material.dart';
import 'package:just_musica/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:just_musica/services/playback_service.dart';

class LyricsDisplay extends StatefulWidget {
  final Future<String> lyricsFuture;
  final Function(int) onTapLyric;
  final PlaybackService playbackService;

  const LyricsDisplay({
    super.key,
    required this.lyricsFuture,
    required this.onTapLyric,
    required this.playbackService,
  });

  @override
  State<LyricsDisplay> createState() => _LyricsDisplayState();
}

class _LyricsDisplayState extends State<LyricsDisplay> {
  final ItemScrollController itemScrollController = ItemScrollController();
  List<LrcLine>? _lines;
  int? _currentHighlightIndex; // 存储纯歌词列表中的高亮索引
  bool _needsInitialJump = true;
  double _lyricSize = 20.0; // 字体大小，会被 ThemeService 更新

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(LyricsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyricsFuture != oldWidget.lyricsFuture) {
      _loadLyrics();
    }
  }

  void _loadLyrics() {
    widget.lyricsFuture.then((lyrics) {
      if (!mounted) return;
      _needsInitialJump = true; // 新歌词加载，需要初始跳转
      _currentHighlightIndex = null; // 重置高亮索引
      setState(() {
        _lines = _parseLyrics(lyrics);
        // 不再在这里添加padding lines
      });
      // 可以在这里根据播放状态尝试进行一次初始跳转，如果歌曲已在播放
      // 但通常StreamBuilder会处理首次更新
    });
  }

  List<LrcLine> _parseLyrics(String lyrics) {
    final lines = lyrics.split('\n');
    final result = <LrcLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)'); // 兼容毫秒两位或三位

    for (var line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final text = match.group(4)!.trim();
        if (text.isEmpty) continue; // 跳过文本为空的歌词行
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centisecondsOrMilliseconds = int.parse(match.group(3)!);
        // 根据匹配长度判断是厘秒还是毫秒
        final timeInMs = (minutes * 60 + seconds) * 1000 +
            (match.group(3)!.length == 2
                ? centisecondsOrMilliseconds * 10
                : centisecondsOrMilliseconds);
        result.add(
            LrcLine(time: timeInMs ~/ 1000, text: text)); // time in seconds
      }
    }
    result.sort((a, b) => a.time.compareTo(b.time)); // 确保歌词按时间排序
    return result;
  }

  int _findCurrentIndex(List<LrcLine> lines, int currentTimeInSeconds) {
    if (lines.isEmpty) return -1;
    // 如果当前时间早于第一句歌词的开始时间，则高亮第一句
    if (currentTimeInSeconds < lines[0].time) return 0;
    for (int i = 0; i < lines.length - 1; i++) {
      if (lines[i].time <= currentTimeInSeconds &&
          currentTimeInSeconds < lines[i + 1].time) {
        return i;
      }
    }
    // 如果当前时间晚于或等于最后一句歌词的开始时间，则高亮最后一句
    return lines.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    _lyricSize = themeService.lyricFontSize;

    if (_lines == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lines!.isEmpty) {
      return Center(
          child: Text('暂无歌词', style: TextStyle(fontSize: _lyricSize)));
    }

    return StreamBuilder<PlaybackState>(
      stream: widget.playbackService.playbackStateStream,
      builder: (context, playbackSnapshot) {
        int currentTime = 0;
        final state = playbackSnapshot.data;
        final pos = state?.position ?? Duration.zero;
        currentTime = pos.inSeconds;

        final newCalculatedHighlightIndex =
            _lines!.isEmpty ? -1 : _findCurrentIndex(_lines!, currentTime);
        if ((newCalculatedHighlightIndex != _currentHighlightIndex ||
                _needsInitialJump) &&
            newCalculatedHighlightIndex != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (newCalculatedHighlightIndex != _currentHighlightIndex) {
              setState(() {
                _currentHighlightIndex = newCalculatedHighlightIndex;
              });
            }
            bool isInitialAction = _needsInitialJump;

            if (itemScrollController.isAttached) {
              final scrollTargetListIndex =
                  newCalculatedHighlightIndex + 1; // 目标列表索引（包括顶部padding）
              if (isInitialAction) {
                itemScrollController.jumpTo(
                  index: scrollTargetListIndex,
                  alignment: 0.5,
                );
                _needsInitialJump = false;
              } else {
                itemScrollController.scrollTo(
                  index: scrollTargetListIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: 0.5,
                );
              }
            } else if (isInitialAction) {
              _needsInitialJump = false;
            }
          });
        } else if (newCalculatedHighlightIndex == -1 &&
            _currentHighlightIndex != null) {
          // 特殊情况：如果当前时间没有匹配的歌词行 (newCalculatedHighlightIndex == -1)
          // 但之前有高亮的歌词 (_currentHighlightIndex != null)，则清除高亮
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _currentHighlightIndex =
                  null; // 或设置为 -1，与 newCalculatedHighlightIndex 一致
            });
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight;
            // 确保 paddingHeight 不为负或过小
            final paddingHeight = (viewportHeight > _lyricSize * 2)
                ? (viewportHeight / 2.0 - _lyricSize)
                : 50.0; // 大致使歌词项能在中间

            return ScrollConfiguration(
              behavior:
                  ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ScrollablePositionedList.builder(
                itemCount:
                    _lines!.length + 2, // +2 for top/bottom SizedBox padding
                itemScrollController: itemScrollController,
                itemBuilder: (context, index) {
                  if (index == 0 || index == _lines!.length + 1) {
                    // Top or Bottom padding
                    return SizedBox(height: paddingHeight);
                  }
                  final actualLyricIndex = index - 1;
                  final line = _lines![actualLyricIndex];
                  final isCurrent = actualLyricIndex == _currentHighlightIndex;
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;

                  return GestureDetector(
                    onTap: () =>
                        widget.onTapLyric(line.time), // time is in seconds
                    child: Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 10.0),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontFamily: "HarmonyOS_Sans_SC", // 确保字体可用
                            fontSize: isCurrent ? _lyricSize : _lyricSize - 1.5,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent
                                ? Theme.of(context).primaryColor
                                : (isDark
                                    ? Colors.white70
                                    : Colors.black87), // 调整未选中歌词颜色以示区分
                            shadows: isCurrent // 阴影效果保持不变
                                ? [
                                    Shadow(
                                        color: Colors.black.withOpacity(0.2),
                                        offset: const Offset(1.0, 1.0),
                                        blurRadius: 1.0),
                                    Shadow(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.5),
                                        blurRadius: 4),
                                  ]
                                : (isDark // 给未选中的深色模式歌词也加一点描边，使其更清晰
                                    ? [
                                        Shadow(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            offset: const Offset(0.5, 0.5),
                                            blurRadius: 0.5)
                                      ]
                                    : null),
                          ),
                          child: Text(
                            line.text,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class LrcLine {
  final int time; // seconds
  final String text;

  LrcLine({required this.time, required this.text});
}
