import 'package:flutter/material.dart';
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
  int? _currentIndex;
  List<LrcLine>? _lines;
  static const int _paddingLines = 5; // 上下各留两行

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
      setState(() {
        _lines = _parseLyrics(lyrics);
        if (_lines != null && _lines!.isNotEmpty) {
          // 在头尾插入空白行
          for (int i = 0; i < _paddingLines; i++) {
            _lines!.insert(0, LrcLine(time: -1, text: ""));
            _lines!.add(LrcLine(time: 999999, text: ""));
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_lines == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lines!.isEmpty) {
      return const Center(child: Text('暂无歌词', style: TextStyle(fontSize: 18)));
    }

    return StreamBuilder<PlaybackState>(
      stream: widget.playbackService.playbackStateStream,
      builder: (context, playbackSnapshot) {
        int currentTime = 0;
        final state = playbackSnapshot.data;
        final pos = state?.position ?? Duration.zero;
        currentTime = pos.inSeconds;

        final currentIndex = _findCurrentIndex(_lines!, currentTime);
        if (_currentIndex != currentIndex && currentIndex >= 0) {
          _currentIndex = currentIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            itemScrollController.scrollTo(
              index: currentIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          });
        }

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false, // 隐藏滚动条
          ),
          child: ScrollablePositionedList.builder(
            itemCount: _lines!.length,
            itemBuilder: (context, index) {
              final line = _lines![index];
              final isCurrent = index == currentIndex;
              return GestureDetector(
                onTap: () => widget.onTapLyric(line.time),
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 10.0,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: "HarmonyOS_Sans_SC",
                        fontSize: 20,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent
                            ? Theme.of(context).primaryColor
                            : Colors.black87,
                        shadows: isCurrent
                            ? [
                                // 添加四个方向的黑色阴影形成描边
                                Shadow(
                                  color: Colors.white,
                                  offset: const Offset(1.0, 0.0),
                                  blurRadius: 1.0,
                                ),
                                Shadow(
                                  color: Colors.white,
                                  offset: const Offset(-1.0, 0.0),
                                  blurRadius: 1.0,
                                ),
                                Shadow(
                                  color: Colors.white,
                                  offset: const Offset(0.0, 1.0),
                                  blurRadius: 1.0,
                                ),
                                Shadow(
                                  color: Colors.white,
                                  offset: const Offset(0.0, -1.0),
                                  blurRadius: 1.0,
                                ),
                                // 保留原有的发光效果
                                Shadow(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
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
            itemScrollController: itemScrollController,
          ),
        );
      },
    );
  }

  List<LrcLine> _parseLyrics(String lyrics) {
    final lines = lyrics.split('\n');
    final result = <LrcLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\](.*)');

    for (var line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final text = match.group(4)!.trim();
        if (text == "") continue; // 跳过空行
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centiseconds = int.parse(match.group(3)!);
        final time = (minutes * 60 + seconds) * 1000 + centiseconds * 10; // ms
        result.add(LrcLine(time: time ~/ 1000, text: text)); // time in seconds
      }
    }
    return result;
  }

  int _findCurrentIndex(List<LrcLine> lines, int currentTime) {
    if (lines.isEmpty) return -1;
    // 跳过前面的空白行
    int start = _paddingLines;
    int end = lines.length - _paddingLines;
    if (currentTime < lines[start].time) return start;
    for (int i = start; i < end - 1; i++) {
      if (lines[i].time <= currentTime && currentTime < lines[i + 1].time) {
        return i;
      }
    }
    return end - 1;
  }
}

class LrcLine {
  final int time; // seconds
  final String text;

  LrcLine({required this.time, required this.text});
}
