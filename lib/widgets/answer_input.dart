import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AnswerInput extends StatefulWidget {
  final void Function(Uint8List audioBytes) onSubmit;
  final bool enabled;

  const AnswerInput({
    super.key,
    required this.onSubmit,
    this.enabled = true,
  });

  @override
  State<AnswerInput> createState() => _AnswerInputState();
}

class _AnswerInputState extends State<AnswerInput>
    with SingleTickerProviderStateMixin {
  static const _maxRecordingDuration = Duration(seconds: 120);

  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _hasPermission = false;
  bool _permissionChecked = false;
  Timer? _autoStopTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 120;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final ok = await _recorder.hasPermission();
    if (mounted) {
      setState(() {
        _hasPermission = ok;
        _permissionChecked = true;
      });
    }
  }

  Future<void> _startRecording() async {
    if (!_hasPermission || !widget.enabled) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/answer_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    if (mounted) setState(() => _isRecording = true);

    _autoStopTimer = Timer(_maxRecordingDuration, () {
      if (_isRecording) _stopAndSubmit();
    });

    setState(() => _secondsLeft = _maxRecordingDuration.inSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft = (_secondsLeft - 1).clamp(0, _maxRecordingDuration.inSeconds);
      });
    });
  }

  Future<void> _stopAndSubmit() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (!_isRecording) return;
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    widget.onSubmit(bytes);
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canRecord = widget.enabled && _hasPermission;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _isRecording
              ? _stopAndSubmit
              : (canRecord ? _startRecording : null),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale =
                  _isRecording ? 1.0 + _pulseController.value * 0.12 : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? colors.error
                    : canRecord
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                boxShadow: (canRecord || _isRecording)
                    ? [
                        BoxShadow(
                          color: (_isRecording ? colors.error : colors.primary)
                              .withOpacity(0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: !_permissionChecked
                  ? Padding(
                      padding: const EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      size: 32,
                      color: _isRecording
                          ? colors.onError
                          : canRecord
                              ? colors.onPrimary
                              : colors.onSurfaceVariant,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          !_permissionChecked
              ? 'Initializing mic...'
              : !_hasPermission
                  ? 'Microphone unavailable'
                  : _isRecording
                      ? 'Tap to submit'
                      : 'Tap to answer',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
        if (_isRecording) ...[
          const SizedBox(height: 6),
          Text(
            '${_secondsLeft}s left',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _secondsLeft <= 10 ? colors.error : colors.onSurfaceVariant,
                  fontWeight: _secondsLeft <= 10 ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
        ],
      ],
    );
  }
}
