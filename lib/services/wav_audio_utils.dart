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

/// Sanitizes a WAV header by ensuring `RIFF` and `data` chunk sizes correctly
/// reflect the actual payload bytes in memory.
///
/// Streaming encoders (e.g. Fish Audio) often write placeholder values like
/// `0xFFFFFF00` (4294967040) or `0xFFFFFFFF` into the `data` chunk size because
/// total length is unknown at stream start. This function corrects those sizes
/// so downstream processors and audio players handle the WAV properly.
Uint8List sanitizeWavHeader(Uint8List wav) {
  if (wav.length < 44) return wav;
  if (String.fromCharCodes(wav.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(wav.sublist(8, 12)) != 'WAVE') {
    return wav;
  }

  final data = ByteData.sublistView(wav);
  var offset = 12;
  int? dataChunkOffset;
  int? dataChunkSize;

  while (offset + 8 <= wav.length) {
    final chunkId = String.fromCharCodes(wav.sublist(offset, offset + 4));
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    if (chunkId == 'data') {
      dataChunkOffset = offset;
      dataChunkSize = chunkSize;
      break;
    }
    offset += 8 + chunkSize + (chunkSize.isOdd ? 1 : 0);
  }

  if (dataChunkOffset == null || dataChunkSize == null) return wav;

  final pcmStart = dataChunkOffset + 8;
  final availableBytes = (wav.length - pcmStart).clamp(0, wav.length);

  final riffSize = data.getUint32(4, Endian.little);
  final isDataSizeValid =
      dataChunkSize > 0 && pcmStart + dataChunkSize <= wav.length;
  final isRiffSizeValid = riffSize > 0 &&
      riffSize <= wav.length - 8 &&
      riffSize >= dataChunkOffset + dataChunkSize;

  if (isDataSizeValid && isRiffSizeValid) {
    return wav;
  }

  final fixed = Uint8List.fromList(wav);
  final fixedData = ByteData.sublistView(fixed);
  fixedData.setUint32(dataChunkOffset + 4, availableBytes, Endian.little);
  fixedData.setUint32(4, dataChunkOffset + availableBytes, Endian.little);
  return fixed;
}
