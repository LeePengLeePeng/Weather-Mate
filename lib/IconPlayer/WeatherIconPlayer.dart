import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WeatherIconPlayer extends StatefulWidget {
  final String introAsset;
  final String loopAsset;
  final String replayKey;

  const WeatherIconPlayer({
    super.key,
    required this.introAsset,
    required this.loopAsset,
    required this.replayKey,
  });

  @override
  State<WeatherIconPlayer> createState() => _WeatherIconPlayerState();
}

class _WeatherIconPlayerState extends State<WeatherIconPlayer> {
  int _playState = 0;
  double _opacity = 0.0;
  int _playbackId = 0;
  
  Timer? _safetyTimer;
  bool _introCompleted = false;
  int? _totalFrames;
  
  static final Map<String, int> _frameCountCache = {};

  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  @override
  void didUpdateWidget(covariant WeatherIconPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayKey != widget.replayKey) {
      _startSequence();
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSequence() async {
    _safetyTimer?.cancel();
    _introCompleted = false;
    _totalFrames = null;

    if (mounted) {
      setState(() {
        _playState = 0;
        _opacity = 0.0;
      });
    }

    await Future.delayed(const Duration(milliseconds: 50));

    try {
      if (_frameCountCache.containsKey(widget.introAsset)) {
        _totalFrames = _frameCountCache[widget.introAsset]!;
      } else {
        final ByteData data = await rootBundle.load(widget.introAsset);
        final bytes = data.buffer.asUint8List();
        final codec = await ui.instantiateImageCodec(bytes);
        _totalFrames = codec.frameCount;
        _frameCountCache[widget.introAsset] = _totalFrames!;
        codec.dispose();
        
        debugPrint(" ${widget.introAsset}");
        debugPrint("   幀數: $_totalFrames frames");
      }

      if (mounted) {
        final introProvider = AssetImage(widget.introAsset);
        await introProvider.evict();
        await Future.delayed(const Duration(milliseconds: 100));
        
        setState(() {
          _playState = 1;
          _opacity = 1.0;
          _playbackId++;
        });

        final safetyDuration = Duration(milliseconds: (_totalFrames! * 40) + 800);
        _safetyTimer = Timer(safetyDuration, () {
          if (mounted && !_introCompleted) {
            debugPrint("安全計時器觸發，強制切換到 Loop");
            _switchToLoop();
          }
        });
      }
    } catch (e) {
      debugPrint("動畫載入失敗: $e");
      if (mounted) {
        setState(() {
          _playState = 2;
          _opacity = 1.0;
        });
      }
    }
  }

  void _onIntroFrameUpdate(int currentFrame) {
    if (_introCompleted || _totalFrames == null) return;
    
    if (currentFrame >= _totalFrames! - 1) {
      debugPrint("Intro 播放完成 (frame $currentFrame/$_totalFrames)");
      _introCompleted = true;
      _switchToLoop();
    }
  }

  Future<void> _switchToLoop() async {
    _safetyTimer?.cancel();
    
    if (mounted) {
      await precacheImage(AssetImage(widget.loopAsset), context);
      
      await Future.delayed(const Duration(milliseconds: 16));
      
      if (mounted) {
        setState(() {
          _playState = 2;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_playState == 1) {
      content = Image.asset(
        widget.introAsset,
        key: ValueKey('${widget.introAsset}_$_playbackId'),
        fit: BoxFit.contain,
        gaplessPlayback: false,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onIntroFrameUpdate(frame);
            });
            return child;
          }
          
          return const SizedBox();
        },
      );
    } else if (_playState == 2) {
      content = Image.asset(
        widget.loopAsset,
        key: ValueKey(widget.loopAsset),
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    } else {
      content = const SizedBox();
    }

    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: content,
    );
  }
}