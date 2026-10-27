import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Captured bytes, never a temporary URL. Safe to persist as demo data.
class MediaPayload {
  final String kind, mimeType, name;
  final Uint8List bytes;
  final int? durationMs;
  final bool synthetic;
  final String? transcript;
  const MediaPayload({
    required this.kind,
    required this.bytes,
    required this.mimeType,
    required this.name,
    this.durationMs,
    this.synthetic = false,
    this.transcript,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'bytes': base64Encode(bytes),
    'mimeType': mimeType,
    'name': name,
    'durationMs': durationMs,
    'synthetic': synthetic,
    'transcript': transcript,
  };
  factory MediaPayload.fromJson(Map<String, dynamic> json) => MediaPayload(
    kind: json['kind'] as String,
    bytes: base64Decode(json['bytes'] as String),
    mimeType: json['mimeType'] as String,
    name: json['name'] as String,
    durationMs: json['durationMs'] as int?,
    synthetic: json['synthetic'] == true,
    transcript: json['transcript'] as String?,
  );

  static MediaPayload samplePhoto() => MediaPayload(
    kind: 'photo',
    bytes: base64Decode(
      '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',
    ),
    mimeType: 'image/png',
    name: 'Synthetic document sample',
    synthetic: true,
  );

  static MediaPayload sampleAudio() {
    const samples = 16000;
    final pcm = ByteData(samples * 2);
    for (var i = 0; i < samples; i++) {
      final envelope = math.sin(math.pi * i / samples);
      pcm.setInt16(
        i * 2,
        (1600 * envelope * math.sin(2 * math.pi * 440 * i / 16000)).round(),
        Endian.little,
      );
    }
    return MediaPayload(
      kind: 'audio',
      bytes: wavBytes(pcm.buffer.asUint8List()),
      mimeType: 'audio/wav',
      name: 'Synthetic audio sample',
      durationMs: 1000,
      synthetic: true,
      transcript: 'Synthetic tone. No speech was recorded.',
    );
  }
}

/// PCM16 little endian, mono, 16 kHz. Browser and native playback receive WAV.
Uint8List wavBytes(Uint8List pcm, {int sampleRate = 16000, int channels = 1}) {
  final header = ByteData(44);
  void textAt(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  textAt(0, 'RIFF');
  header.setUint32(4, pcm.length + 36, Endian.little);
  textAt(8, 'WAVE');
  textAt(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * channels * 2, Endian.little);
  header.setUint16(32, channels * 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  textAt(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
}
