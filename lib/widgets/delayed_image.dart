import 'dart:async';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

class LazyThumbnail extends StatefulWidget {
  final Future<ImageProvider> imageProviderFuture;
  final double size;

  const LazyThumbnail({
    super.key,
    required this.imageProviderFuture,
    this.size = 45.0,
  });

  @override
  State<LazyThumbnail> createState() => _LazyThumbnailState();
}

class _LazyThumbnailState extends State<LazyThumbnail> {
  bool _shouldLoad = false;
  ImageProvider? _image;
  late final String _visibilityKey;

  @override
  void initState() {
    super.initState();
    _visibilityKey = UniqueKey().toString();
  }

  Timer? _throttle;

  void _onVisible() {
    if (_image != null || _throttle != null) return;

    _throttle = Timer(const Duration(milliseconds: 250), () async {
      final image = await widget.imageProviderFuture;
      if (mounted) {
        setState(() => _image = image);
      }
      _throttle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(_visibilityKey),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5) {
          _onVisible();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: widget.size,
          height: widget.size,
          color: Colors.grey.shade200,
          child: _image != null
              ? Image(
                  image: _image!,
                  fit: BoxFit.cover,
                )
              : const Center(
                  child: Icon(Icons.music_note, color: Colors.grey),
                ),
        ),
      ),
    );
  }
}
