// One-shot generator for assets/sounds/beep.wav — a short 880 Hz sine
// suitable as the scan-success tone. Run: `dart run tool/gen_beep.dart`
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  const int sampleRate = 44100;
  const double seconds = 0.15;
  final int count = (sampleRate * seconds).round();

  final ByteData pcm = ByteData(count * 2);
  for (int i = 0; i < count; i++) {
    final double t = i / sampleRate;
    // Fade out the last 40% so the tone doesn't click when it ends.
    final double fade =
        i < count * 0.6 ? 1.0 : 1.0 - (i - count * 0.6) / (count * 0.4);
    final double sample = sin(2 * pi * 880 * t) * 0.6 * fade;
    pcm.setInt16(i * 2, (sample * 32767).round(), Endian.little);
  }

  final Uint8List header = _wavHeader(count * 2, sampleRate);
  final File file = File('assets/sounds/beep.wav');
  file.createSync(recursive: true);
  file.writeAsBytesSync(<int>[...header, ...pcm.buffer.asUint8List()]);
  stdout.writeln('Wrote ${file.path} (${file.lengthSync()} bytes)');
}

Uint8List _wavHeader(int dataLength, int sampleRate) {
  final ByteData b = ByteData(44);
  void str(int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      b.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + dataLength, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  b.setUint16(32, 2, Endian.little); // block align
  b.setUint16(34, 16, Endian.little); // bits per sample
  str(36, 'data');
  b.setUint32(40, dataLength, Endian.little);
  return b.buffer.asUint8List();
}
