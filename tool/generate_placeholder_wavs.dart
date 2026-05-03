/// One-shot script to generate minimal placeholder WAV files.
/// Run with: dart tool/generate_placeholder_wavs.dart
///
/// Produces 8 kHz, 8-bit mono, 1-sample WAV files as silence placeholders.
/// Replace the output files with real sounds before shipping.

import 'dart:io';
import 'dart:typed_data';

/// Writes a minimal WAV file (8 kHz, 8-bit mono, [sampleCount] samples).
void writeWav(String path, int sampleCount) {
  final dataSize = sampleCount;
  final chunkSize = 36 + dataSize;

  final buffer = ByteData(44 + dataSize);
  int offset = 0;

  // RIFF chunk descriptor
  buffer.setUint8(offset++, 0x52); // 'R'
  buffer.setUint8(offset++, 0x49); // 'I'
  buffer.setUint8(offset++, 0x46); // 'F'
  buffer.setUint8(offset++, 0x46); // 'F'
  buffer.setUint32(offset, chunkSize, Endian.little);
  offset += 4;
  buffer.setUint8(offset++, 0x57); // 'W'
  buffer.setUint8(offset++, 0x41); // 'A'
  buffer.setUint8(offset++, 0x56); // 'V'
  buffer.setUint8(offset++, 0x45); // 'E'

  // fmt sub-chunk
  buffer.setUint8(offset++, 0x66); // 'f'
  buffer.setUint8(offset++, 0x6D); // 'm'
  buffer.setUint8(offset++, 0x74); // 't'
  buffer.setUint8(offset++, 0x20); // ' '
  buffer.setUint32(offset, 16, Endian.little); // sub-chunk size = 16
  offset += 4;
  buffer.setUint16(offset, 1, Endian.little); // PCM format = 1
  offset += 2;
  buffer.setUint16(offset, 1, Endian.little); // num channels = 1 (mono)
  offset += 2;
  buffer.setUint32(offset, 8000, Endian.little); // sample rate = 8 kHz
  offset += 4;
  buffer.setUint32(offset, 8000, Endian.little); // byte rate = 8000 * 1 * 1
  offset += 4;
  buffer.setUint16(offset, 1, Endian.little); // block align = 1
  offset += 2;
  buffer.setUint16(offset, 8, Endian.little); // bits per sample = 8
  offset += 2;

  // data sub-chunk
  buffer.setUint8(offset++, 0x64); // 'd'
  buffer.setUint8(offset++, 0x61); // 'a'
  buffer.setUint8(offset++, 0x74); // 't'
  buffer.setUint8(offset++, 0x61); // 'a'
  buffer.setUint32(offset, dataSize, Endian.little);
  offset += 4;

  // Write silence (8-bit PCM silence = 0x80 = mid-point)
  for (var i = 0; i < sampleCount; i++) {
    buffer.setUint8(offset++, 0x80);
  }

  File(path).writeAsBytesSync(buffer.buffer.asUint8List());
  print('Written: $path (${44 + dataSize} bytes, $sampleCount sample(s))');
}

void main() {
  const outputDir = 'assets/audio';
  Directory(outputDir).createSync(recursive: true);

  // 1 sample at 8 kHz = ~0.125 ms — genuine silence placeholder
  writeWav('$outputDir/start.wav', 1);
  writeWav('$outputDir/ending.wav', 1);

  print('Done. Replace with real audio assets before shipping.');
}
