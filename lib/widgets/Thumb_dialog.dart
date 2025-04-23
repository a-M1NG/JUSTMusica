import 'package:flutter/material.dart';

class ImportProgressDialog extends StatelessWidget {
  const ImportProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('正在扫描音乐文件...'),
          const SizedBox(height: 8),
          // TextButton(
          //   onPressed: () => Navigator.pop(context),
          //   child: const Text('取消'),
          // ),
        ],
      ),
    );
  }
}

class ThumbnailGenerationDialog extends StatefulWidget {
  final int totalSongs;
  final Stream<int> progressStream;

  const ThumbnailGenerationDialog({
    super.key,
    required this.totalSongs,
    required this.progressStream,
  });

  @override
  State<ThumbnailGenerationDialog> createState() =>
      _ThumbnailGenerationDialogState();
}

class _ThumbnailGenerationDialogState extends State<ThumbnailGenerationDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: StreamBuilder<int>(
        stream: widget.progressStream,
        builder: (context, snapshot) {
          final value = snapshot.data ?? 0;
          final fraction =
              widget.totalSongs > 0 ? value / widget.totalSongs : 0.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('正在生成歌曲缩略图...'),
              const SizedBox(height: 8),
              Text('$value / ${widget.totalSongs}'),
              LinearProgressIndicator(
                value: fraction,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                color: Theme.of(context).primaryColor,
                minHeight: 4,
              ),
            ],
          );
        },
      ),
    );
  }
}
