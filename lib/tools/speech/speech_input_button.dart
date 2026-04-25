import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 语音输入按钮 — 通用 Widget，可嵌入任何有文本输入的地方
///
/// 用法：
/// ```dart
/// SpeechInputButton(
///   onResult: (text) => _controller.text += text,
/// )
/// ```
///
/// 长按开始录音，松开停止并回调识别结果。
/// 也可以点击切换录音状态（开始/停止）。
class SpeechInputButton extends StatefulWidget {
  /// 识别完成后的回调，参数为识别到的文字
  final ValueChanged<String> onResult;

  /// 按钮大小，默认 24
  final double iconSize;

  /// 自定义颜色，默认跟随主题
  final Color? color;

  const SpeechInputButton({
    super.key,
    required this.onResult,
    this.iconSize = 24,
    this.color,
  });

  @override
  State<SpeechInputButton> createState() => _SpeechInputButtonState();
}

class _SpeechInputButtonState extends State<SpeechInputButton>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _initSpeech();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (_) => _stopListening(),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
          _pulseCtrl.stop();
        }
      },
    );
    if (mounted) setState(() => _isAvailable = available);
  }

  Future<void> _startListening() async {
    if (!_isAvailable || _isListening) return;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          widget.onResult(result.recognizedWords);
        }
      },
      localeId: 'zh_CN',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: false,
      ),
    );
    if (mounted) setState(() => _isListening = true);
    _pulseCtrl.repeat(reverse: true);
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
    _pulseCtrl.stop();
    _pulseCtrl.reset();
  }

  void _toggle() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAvailable) return const SizedBox.shrink();

    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: _toggle,
      onLongPressStart: (_) => _startListening(),
      onLongPressEnd: (_) => _stopListening(),
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, child) {
          return Container(
            width: widget.iconSize + 16,
            height: widget.iconSize + 16,
            decoration: _isListening
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(
                      alpha: 0.1 + 0.15 * _pulseCtrl.value,
                    ),
                  )
                : null,
            child: child,
          );
        },
        child: Icon(
          _isListening ? Icons.mic : Icons.mic_none_outlined,
          size: widget.iconSize,
          color: _isListening ? Colors.red : color,
        ),
      ),
    );
  }
}
