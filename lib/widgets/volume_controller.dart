import 'package:flutter/material.dart';
import 'dart:async';
import 'package:just_musica/services/playback_service.dart';

class VolumeController extends StatefulWidget {
  final PlaybackService playbackService;

  const VolumeController({Key? key, required this.playbackService})
      : super(key: key);

  @override
  _VolumeControllerState createState() => _VolumeControllerState();
}

class _VolumeControllerState extends State<VolumeController> {
  double _volume = 1.0;
  double? _previousVolume;
  bool _isMuted = false;
  bool _showFlyout = false;
  Timer? _hoverTimer;
  Timer? _exitTimer; // 新增：退出延迟计时器
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isPointerOnFlyout = false; // 新增：跟踪鼠标是否在flyout上

  @override
  void initState() {
    super.initState();
    _volume = widget.playbackService.volume;
  }

  void _toggleMute() {
    setState(() {
      if (_isMuted) {
        _volume = _previousVolume ?? 1.0;
        widget.playbackService.volume = _volume;
        _isMuted = false;
        _previousVolume = null;
      } else {
        _previousVolume = _volume;
        _volume = 0.0;
        widget.playbackService.volume = _volume;
        _isMuted = true;
      }
      _overlayEntry?.markNeedsBuild();
    });
    debugPrint("Volume toggled: $_volume, Muted: $_isMuted");
  }

  void _updateVolume(double newVolume) {
    setState(() {
      _volume = newVolume;
      _isMuted = newVolume == 0.0;
      widget.playbackService.volume = newVolume;
      if (_isMuted && newVolume > 0.0) {
        _previousVolume = null;
      }
      _overlayEntry?.markNeedsBuild();
    });
  }

  void _startHoverTimer() {
    _hoverTimer?.cancel();
    _exitTimer?.cancel(); // 取消可能存在的退出计时器
    _hoverTimer = Timer(const Duration(milliseconds: 300), () {
      _showVolumeFlyout();
    });
  }

  void _showVolumeFlyout() {
    if (_showFlyout) return;

    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry();

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _showFlyout = true;
    });
  }

  void _hideVolumeFlyout() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _showFlyout = false;
      _isPointerOnFlyout = false;
    });
  }

  void _cancelHoverTimer() {
    _hoverTimer?.cancel();

    // 不立即隐藏，添加延迟让用户有时间移动鼠标到flyout
    _exitTimer?.cancel();
    _exitTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_isPointerOnFlyout) {
        // 只有在鼠标不在flyout上时才隐藏
        _hideVolumeFlyout();
      }
    });
  }

  // 设置鼠标进入flyout状态
  void _onFlyoutEnter() {
    _exitTimer?.cancel(); // 取消退出计时器
    setState(() {
      _isPointerOnFlyout = true;
    });
  }

  // 设置鼠标离开flyout状态
  void _onFlyoutExit() {
    setState(() {
      _isPointerOnFlyout = false;
    });
    // 延迟隐藏，以防用户只是临时离开又回来
    _exitTimer?.cancel();
    _exitTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_isPointerOnFlyout) {
        _hideVolumeFlyout();
      }
    });
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy - 160, // 在按钮上方显示
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(-10.0, -190.0),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: MouseRegion(
              onEnter: (_) => _onFlyoutEnter(), // 使用新方法
              onExit: (_) => _onFlyoutExit(), // 使用新方法
              child: Container(
                width: 60,
                height: 180,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderThemeData(
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 0), // 滑块大小设为 0
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 0), // 触摸反馈大小设为 0
                          ),
                          child: Slider(
                            value: _volume,
                            onChanged: _updateVolume,
                            min: 0.0,
                            max: 1.0,
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${(_volume * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getVolumeIcon() {
    if (_volume == 0.0 || _isMuted) {
      return Icons.volume_off;
    } else if (_volume < 0.5) {
      return Icons.volume_down;
    } else {
      return Icons.volume_up;
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _exitTimer?.cancel(); // 清理退出计时器
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _startHoverTimer(),
        onExit: (_) => _cancelHoverTimer(),
        child: IconButton(
          icon: Icon(_getVolumeIcon(), color: theme.iconTheme.color),
          onPressed: _toggleMute,
          // tooltip: 'Toggle Mute',
        ),
      ),
    );
  }
}

class HorizontalVolumeController extends StatefulWidget {
  final PlaybackService playbackService;

  const HorizontalVolumeController({Key? key, required this.playbackService})
      : super(key: key);

  @override
  _HorizontalVolumeControllerState createState() =>
      _HorizontalVolumeControllerState();
}

class _HorizontalVolumeControllerState
    extends State<HorizontalVolumeController> {
  double _volume = 1.0;
  double? _previousVolume;
  bool _isMuted = false;
  bool _isHoveringSlider = false;

  @override
  void initState() {
    super.initState();
    _volume = widget.playbackService.volume;
  }

  void _toggleMute() {
    setState(() {
      if (_isMuted) {
        _volume = _previousVolume ?? 1.0;
        widget.playbackService.volume = _volume;
        _isMuted = false;
        _previousVolume = null;
      } else {
        _previousVolume = _volume;
        _volume = 0.0;
        widget.playbackService.volume = _volume;
        _isMuted = true;
      }
    });
  }

  void _updateVolume(double newVolume) {
    setState(() {
      _volume = newVolume;
      _isMuted = newVolume == 0.0;
      widget.playbackService.volume = newVolume;
      if (_isMuted && newVolume > 0.0) {
        _previousVolume = null;
      }
    });
  }

  IconData _getVolumeIcon() {
    if (_volume == 0.0 || _isMuted) {
      return Icons.volume_off;
    } else if (_volume < 0.5) {
      return Icons.volume_down;
    } else {
      return Icons.volume_up;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_getVolumeIcon(), color: theme.iconTheme.color),
          onPressed: _toggleMute,
        ),
        MouseRegion(
          onEnter: (_) => setState(() => _isHoveringSlider = true),
          onExit: (_) => setState(() => _isHoveringSlider = false),
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(
              width: 100,
              height: 28, // 限制垂直高度
            ),
            child: Center(
              child: SliderTheme(
                data: SliderThemeData(
                  thumbShape: _isHoveringSlider
                      ? const RoundSliderThumbShape(enabledThumbRadius: 6)
                      : const RoundSliderThumbShape(enabledThumbRadius: 0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _volume,
                  onChanged: _updateVolume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: theme.colorScheme.primary,
                  inactiveColor: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
