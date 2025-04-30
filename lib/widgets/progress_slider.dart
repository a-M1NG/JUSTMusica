import 'package:flutter/material.dart';
import '../services/playback_service.dart';

/// A custom track shape that makes the slider track full-width and
/// centers it vertically within its parent.
class CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 2;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

/// A reusable playback progress bar widget.
///
/// Listens to [playbackService.playbackStateStream] to render and control
/// the current playback position. On drag end it seeks to the chosen position.
class PlaybackProgressBar extends StatefulWidget {
  final PlaybackService playbackService;
  const PlaybackProgressBar({
    Key? key,
    required this.playbackService,
  }) : super(key: key);

  @override
  _PlaybackProgressBarState createState() => _PlaybackProgressBarState();
}

class _PlaybackProgressBarState extends State<PlaybackProgressBar> {
  double? _dragValue;
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: widget.playbackService.playbackStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) {
          return const SizedBox(height: 4);
        }

        final pos = _dragValue ?? state.position.inSeconds.toDouble();
        final dur = state.duration.inSeconds.toDouble();

        // 关键：用 SizedBox（或 Container）强制高度为 4
        return SizedBox(
          height: 4,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: (_isHovering || _isDragging) ? 6 : 0,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                trackShape: CustomTrackShape(),
              ),
              child: Slider(
                min: 0,
                max: dur,
                value: pos.clamp(0.0, dur),
                onChangeStart: (value) {
                  setState(() => _isDragging = true);
                },
                onChanged: (value) {
                  setState(() => _dragValue = value);
                },
                onChangeEnd: (value) {
                  widget.playbackService.seekTo(value.toInt()).then((_) {
                    setState(() {
                      _dragValue = null;
                      _isDragging = false;
                    });
                  });
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
