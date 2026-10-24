import 'dart:typed_data';

/// Validates every ADTS frame's envelope and reports observed codec headers.
/// This is not an AAC decoder or an acoustic/source-match quality assertion.
Map<String, Object> inspectOwnedAdts(Uint8List bytes) {
  const rates = [
    96000,
    88200,
    64000,
    48000,
    44100,
    32000,
    24000,
    22050,
    16000,
    12000,
    11025,
    8000,
    7350,
  ];
  var offset = 0;
  var frames = 0;
  var samples = 0;
  int? sampleRate;
  int? channels;
  while (offset < bytes.length) {
    if (bytes.length - offset < 7 ||
        bytes[offset] != 0xff ||
        (bytes[offset + 1] & 0xf6) != 0xf0) {
      throw StateError('invalid ADTS frame envelope');
    }
    final rateIndex = (bytes[offset + 2] >> 2) & 15;
    final profile = (bytes[offset + 2] >> 6) + 1;
    final count = ((bytes[offset + 2] & 1) << 2) | (bytes[offset + 3] >> 6);
    final length =
        ((bytes[offset + 3] & 3) << 11) |
        (bytes[offset + 4] << 3) |
        (bytes[offset + 5] >> 5);
    final header = (bytes[offset + 1] & 1) == 1 ? 7 : 9;
    if (rateIndex >= rates.length ||
        profile != 2 ||
        count != 1 ||
        length <= header ||
        offset + length > bytes.length) {
      throw StateError('unsupported/truncated AAC-LC mono ADTS frame');
    }
    final rate = rates[rateIndex];
    if (sampleRate != null && (sampleRate != rate || channels != count)) {
      throw StateError('AAC parameters changed inside segment');
    }
    sampleRate = rate;
    channels = count;
    samples += 1024 * ((bytes[offset + 6] & 3) + 1);
    offset += length;
    frames++;
  }
  if (frames == 0) throw StateError('empty AAC stream');
  return {
    'adts_frames': frames,
    'observed_sample_rate': sampleRate!,
    'observed_channels': channels!,
    'adts_duration_ms': samples * 1000 ~/ sampleRate,
  };
}
