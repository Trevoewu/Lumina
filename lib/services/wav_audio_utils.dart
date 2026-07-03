import 'dart:typed_data';

const int _streamingDataSize = 0xFFFFFFFF;

/// Returns the playable duration of a PCM WAV stream in milliseconds.
///
/// Streaming encoders may use `0xFFFFFFFF` for the data chunk size because the
/// final size is unknown when the header is emitted. The available byte length
/// is authoritative in that case.
int wavDurationMs(Uint8List headerBytes, {int? totalBytes}) {
  if (headerBytes.length < 12) return 0;
  if (String.fromCharCodes(headerBytes.sublist(0, 4)) != 'RIFF') return 0;
  if (String.fromCharCodes(headerBytes.sublist(8, 12)) != 'WAVE') return 0;

  final data = ByteData.sublistView(headerBytes);
  final streamLength = totalBytes ?? headerBytes.length;
  var offset = 12;
  int? byteRate;

  while (offset + 8 <= headerBytes.length) {
    final chunkId = String.fromCharCodes(
      headerBytes.sublist(offset, offset + 4),
    );
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    final chunkDataOffset = offset + 8;

    if (chunkId == 'fmt ' && chunkDataOffset + 12 <= headerBytes.length) {
      byteRate = data.getUint32(chunkDataOffset + 8, Endian.little);
    } else if (chunkId == 'data') {
      if (byteRate == null || byteRate <= 0) return 0;
      final availableBytes = (streamLength - chunkDataOffset).clamp(
        0,
        streamLength,
      );
      final audioBytes =
          chunkSize == _streamingDataSize || chunkSize > availableBytes
          ? availableBytes
          : chunkSize;
      return ((audioBytes / byteRate) * 1000).round();
    }

    if (chunkSize == _streamingDataSize) return 0;
    offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
  }
  return 0;
}
