import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../core/media.dart';
import 'ui.dart';

/// On-demand capture. No permission is requested until a capture button is used.
class MediaCapture extends StatelessWidget {
  final ValueChanged<MediaPayload> onAttached;
  const MediaCapture({super.key, required this.onAttached});

  Future<void> _open(BuildContext context, bool photo) async {
    final payload = await showDialog<MediaPayload>(
      context: context,
      builder: (_) => _CaptureDialog(photo: photo),
    );
    if (payload != null) onAttached(payload);
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: () => _open(context, false),
        icon: const Icon(Icons.mic_none_rounded),
        label: Text(tr(context, 'voiceNote')),
      ),
      OutlinedButton.icon(
        onPressed: () => _open(context, true),
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(tr(context, 'takePhoto')),
      ),
    ],
  );
}

class _CaptureDialog extends StatefulWidget {
  final bool photo;
  const _CaptureDialog({required this.photo});
  @override
  State<_CaptureDialog> createState() => _CaptureDialogState();
}

class _CaptureDialogState extends State<_CaptureDialog>
    with WidgetsBindingObserver {
  CameraController? _camera;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioStream;
  Timer? _ticker;
  final BytesBuilder _bytes = BytesBuilder(copy: false);
  final TextEditingController _transcript = TextEditingController();
  MediaPayload? _payload;
  bool _loading = true, _recording = false;
  String? _error;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.photo) {
      _startCamera();
    } else {
      _loading = false;
    }
  }

  Future<void> _startCamera() async {
    setState(() {
      _loading = true;
      _error = null;
      _payload = null;
    });
    try {
      await _camera?.dispose();
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera');
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _camera = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'cameraUnavailable';
          _loading = false;
        });
      }
    }
  }

  Future<void> _capture() async {
    try {
      final controller = _camera;
      if (controller == null || !controller.value.isInitialized) return;
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(
        () => _payload = MediaPayload(
          kind: 'photo',
          bytes: bytes,
          mimeType: image.mimeType ?? 'image/jpeg',
          name: 'Event photo',
        ),
      );
      await controller.pausePreview();
    } catch (_) {
      if (mounted) setState(() => _error = 'captureFailed');
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _loading = true;
      _error = null;
      _payload = null;
    });
    try {
      _recorder ??= AudioRecorder();
      if (!await _recorder!.hasPermission()) {
        throw StateError('Permission denied');
      }
      _bytes.clear();
      final stream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _audioStream = stream.listen(
        _bytes.add,
        onError: (_) {
          if (mounted) setState(() => _error = 'recordingFailed');
          _stopRecording(discard: true);
        },
      );
      if (!mounted) {
        await _recorder!.stop();
        return;
      }
      setState(() {
        _loading = false;
        _recording = true;
        _seconds = 0;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
        if (_seconds >= 120) _stopRecording();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'microphoneUnavailable';
        });
      }
    }
  }

  Future<void> _stopRecording({bool discard = false}) async {
    _ticker?.cancel();
    if (!_recording) return;
    setState(() {
      _recording = false;
      _loading = true;
    });
    try {
      await _recorder?.stop();
      await _audioStream?.cancel();
      final pcm = _bytes.takeBytes();
      if (!mounted) return;
      if (!discard && pcm.isNotEmpty) {
        setState(
          () => _payload = MediaPayload(
            kind: 'audio',
            bytes: wavBytes(pcm),
            mimeType: 'audio/wav',
            name: 'Voice note',
            durationMs: (pcm.length / 32).round(),
          ),
        );
      } else if (!discard) {
        setState(() => _error = 'recordingFailed');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'recordingFailed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_recording) _stopRecording();
      // A permission prompt can make the app inactive during initialization.
      // Only release a camera that has finished opening.
      final cameraWasActive = _camera?.value.isInitialized == true;
      if (cameraWasActive) {
        _camera?.dispose();
        _camera = null;
      }
      if (cameraWasActive && widget.photo && _payload == null && mounted) {
        setState(() {
          _loading = false;
          _error = 'cameraInterrupted';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _audioStream?.cancel();
    _camera?.dispose();
    _recorder?.dispose();
    _transcript.dispose();
    super.dispose();
  }

  void _attach() {
    final payload = _payload;
    if (payload == null) return;
    Navigator.of(context).pop(
      MediaPayload(
        kind: payload.kind,
        bytes: payload.bytes,
        mimeType: payload.mimeType,
        name: payload.name,
        durationMs: payload.durationMs,
        synthetic: payload.synthetic,
        transcript: _transcript.text.trim().isEmpty
            ? payload.transcript
            : _transcript.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return AlertDialog(
      title: Text(tr(context, widget.photo ? 'takePhoto' : 'voiceNote')),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null) ...[
                Text(
                  tr(context, _error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: widget.photo ? _startCamera : _startRecording,
                  icon: const Icon(Icons.refresh),
                  label: Text(tr(context, 'retryCapture')),
                ),
              ],
              if (_payload != null) MediaPreview(payload: _payload!),
              if (_payload == null &&
                  !_loading &&
                  _error == null &&
                  widget.photo &&
                  camera != null &&
                  camera.value.isInitialized) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: camera.value.aspectRatio,
                    child: CameraPreview(camera),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _capture,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(tr(context, 'capturePhoto')),
                ),
              ],
              if (!widget.photo && _payload == null && !_loading) ...[
                const SizedBox(height: 12),
                Center(
                  child: Icon(
                    _recording ? Icons.mic : Icons.mic_none,
                    size: 56,
                    color: _recording
                        ? Colors.red.shade700
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _recording
                        ? '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'
                        : tr(context, 'recordingHint'),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _recording
                      ? () => _stopRecording()
                      : _startRecording,
                  icon: Icon(_recording ? Icons.stop : Icons.mic_none),
                  label: Text(
                    tr(
                      context,
                      _recording ? 'stopRecording' : 'startRecording',
                    ),
                  ),
                ),
              ],
              if (_payload?.kind == 'audio') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _transcript,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: tr(context, 'reviewedTranscript'),
                    helperText: tr(context, 'transcriptHint'),
                  ),
                ),
              ],
              if (!_loading && !_recording) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _error = null;
                    _payload = widget.photo
                        ? MediaPayload.samplePhoto()
                        : MediaPayload.sampleAudio();
                  }),
                  icon: const Icon(Icons.science_outlined),
                  label: Text(
                    tr(
                      context,
                      widget.photo ? 'useSamplePhoto' : 'useSampleAudio',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'cancelMedia')),
        ),
        if (_payload != null)
          TextButton(
            onPressed: widget.photo
                ? _startCamera
                : () => setState(() {
                    _payload = null;
                    _transcript.clear();
                  }),
            child: Text(
              tr(context, widget.photo ? 'retakePhoto' : 'discardRecording'),
            ),
          ),
        if (_payload != null)
          FilledButton(
            onPressed: _attach,
            child: Text(tr(context, 'attachMedia')),
          ),
      ],
    );
  }
}

class MediaPreview extends StatefulWidget {
  final MediaPayload payload;
  final VoidCallback? onDiscard;
  const MediaPreview({super.key, required this.payload, this.onDiscard});
  @override
  State<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completion;
  bool _playing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _completion = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _completion?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.play(
          BytesSource(widget.payload.bytes, mimeType: widget.payload.mimeType),
        );
      }
      if (mounted) {
        setState(() {
          _playing = !_playing;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'playbackFailed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff1f6f4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (payload.synthetic)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tr(context, 'syntheticMedia'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          if (payload.kind == 'photo')
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                payload.bytes,
                height: 170,
                width: double.infinity,
                fit: BoxFit.contain,
                semanticLabel: tr(
                  context,
                  payload.synthetic ? 'syntheticMedia' : 'attachedPhoto',
                ),
              ),
            )
          else
            Row(
              children: [
                IconButton(
                  onPressed: _toggle,
                  tooltip: tr(context, _playing ? 'pauseAudio' : 'playAudio'),
                  icon: Icon(
                    _playing
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(tr(context, 'voiceNote'))),
                if (payload.durationMs != null)
                  Text('${(payload.durationMs! / 1000).ceil()}s'),
              ],
            ),
          if (payload.transcript?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(payload.transcript!),
            ),
          if (_error != null)
            Text(
              tr(context, _error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (widget.onDiscard != null)
            TextButton.icon(
              onPressed: widget.onDiscard,
              icon: const Icon(Icons.close),
              label: Text(tr(context, 'removeAttachment')),
            ),
        ],
      ),
    );
  }
}
