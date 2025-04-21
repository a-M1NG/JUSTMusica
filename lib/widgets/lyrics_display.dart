import 'package:flutter/material.dart';

class LyricsDisplay extends StatelessWidget {
  final Future<String> lyricsFuture;
  final Function(int) onTapLyric;

  const LyricsDisplay({
    super.key,
    required this.lyricsFuture,
    required this.onTapLyric,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text('暂无歌词', style: TextStyle(fontSize: 18)));
        }

        final lyrics = snapshot.data!;
        final lines = _parseLyrics(lyrics);

        return ListView.builder(
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final line = lines[index];
            return GestureDetector(
              onTap: () => onTapLyric(line.time),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  line.text,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<LrcLine> _parseLyrics(String lyrics) {
    // 简单解析 LRC 歌词，格式为 [mm:ss.xx]歌词
    final lines = lyrics.split('\n');
    final result = <LrcLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\](.*)');

    for (var line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centiseconds = int.parse(match.group(3)!);
        final text = match.group(4)!.trim();
        final time =
            (minutes * 60 + seconds) * 1000 + centiseconds * 10; // 转换为毫秒
        result.add(LrcLine(time: time ~/ 1000, text: text));
      }
    }

    return result.isEmpty ? [LrcLine(time: 0, text: '暂无歌词')] : result;
  }
}

class LrcLine {
  final int time; // 秒
  final String text;

  LrcLine({required this.time, required this.text});
}
