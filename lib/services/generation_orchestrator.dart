import 'dart:io';
import 'dart:typed_data';

import '../data/database/app_database.dart' as db;
import '../domain/models/chapter_manifest.dart';
import '../tts/models/tts_chunk.dart';
import '../tts/models/tts_voice.dart';
import '../tts/tts_provider.dart';
import 'manifest_store.dart';

/// 章节生成进度。
class GenerationProgress {
  final String chapterId;
  final int ready;
  final int failed;
  final int generating;
  final int total;
  final String? currentParagraphId;
  final int? currentParagraphIndex;
  final String providerId;
  final String voiceId;
  final String? error;

  const GenerationProgress({
    required this.chapterId,
    required this.ready,
    required this.failed,
    required this.generating,
    required this.total,
    required this.providerId,
    required this.voiceId,
    this.currentParagraphId,
    this.currentParagraphIndex,
    this.error,
  });

  double get percent => total == 0 ? 0 : ready / total;

  int get pending => (total - ready - failed - generating).clamp(0, total);

  int get finished => ready + failed;

  bool get isDone => total > 0 && finished >= total;
}

/// 增量生成调度器。
///
/// 策略：用户打开某章时，只生成该章；不预读下一章。
/// 存储：方案 B，每段一个音频文件 + manifest。
class GenerationOrchestrator {
  final db.AppDatabase database;
  final ManifestStore manifestStore;

  GenerationOrchestrator({required this.database, required this.manifestStore});

  /// 生成某章音频。若部分段落已生成，则断点续跑。
  Stream<GenerationProgress> generateChapter({
    required String bookId,
    required String chapterId,
    required TtsProvider provider,
    required TtsVoice voice,
    double speed = 1.0,
    int maxRetries = 3,
  }) async* {
    final paragraphs = await database.getParagraphs(chapterId);
    final existing = await manifestStore.load(bookId, chapterId);
    final fadeInEnabled =
        await database.getSetting('audio_fade_in_enabled') != 'false';

    var segments = <SegmentEntry>[];
    if (existing != null &&
        existing.providerId == provider.id &&
        existing.voiceId == voice.id &&
        existing.speed == speed &&
        existing.segments.length == paragraphs.length) {
      segments = [...existing.segments];
    } else {
      segments = paragraphs.map((p) {
        return SegmentEntry(
          paragraphId: p.id,
          audioFile: '$chapterId/${p.id}.mp3',
          durationMs: 0,
          state: ParagraphAudioState.notGenerated,
        );
      }).toList();
    }

    ChapterManifest manifest() => ChapterManifest(
      chapterId: chapterId,
      bookId: bookId,
      providerId: provider.id,
      voiceId: voice.id,
      speed: speed,
      segments: segments,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await manifestStore.save(manifest());
    yield _progressFromSegments(
      chapterId: chapterId,
      providerId: provider.id,
      voiceId: voice.id,
      segments: segments,
    );

    for (var i = 0; i < paragraphs.length; i++) {
      final para = paragraphs[i];
      final current = segments[i];
      if (current.state == ParagraphAudioState.ready &&
          await File(await _absoluteSegmentPath(bookId, current)).exists()) {
        continue;
      }

      segments[i] = current.copyWith(
        state: ParagraphAudioState.generating,
        error: null,
      );
      await manifestStore.save(manifest());
      yield _progressFromSegments(
        chapterId: chapterId,
        providerId: provider.id,
        voiceId: voice.id,
        segments: segments,
        currentParagraphId: para.id,
        currentParagraphIndex: i,
      );

      try {
        final chunks = await _synthesizePossiblySplit(
          provider: provider,
          voice: voice,
          text: para.content,
          speed: speed,
          maxRetries: maxRetries,
        );

        // 段落内若因超长被切成多个请求，需要按格式正确拼接。
        final format = chunks.isNotEmpty ? chunks.first.format : 'mp3';
        final bytes = format == 'wav'
            ? _prepareWavForCache(
                chunks.map((c) => c.audioBytes).toList(),
                fadeInEnabled: fadeInEnabled,
              )
            : chunks.expand((c) => c.audioBytes).toList(growable: false);
        final duration = chunks.fold<int>(0, (sum, c) => sum + c.durationMs);
        final billed = chunks.fold<int>(
          0,
          (sum, c) => sum + (c.billedCharacters ?? 0),
        );

        final absPath = await manifestStore.segmentPath(
          bookId: bookId,
          chapterId: chapterId,
          paragraphId: para.id,
          format: format,
        );
        await File(absPath).writeAsBytes(bytes);

        segments[i] = SegmentEntry(
          paragraphId: para.id,
          audioFile: '$chapterId/${para.id}.$format',
          durationMs: duration,
          state: ParagraphAudioState.ready,
          format: format,
          billedCharacters: billed == 0 ? null : billed,
          generatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        if (billed > 0) {
          await database.recordCost(
            db.CostRecordsCompanion.insert(
              bookId: bookId,
              chapterId: chapterId,
              providerId: provider.id,
              characters: billed,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
      } catch (e) {
        segments[i] = current.copyWith(
          state: ParagraphAudioState.failed,
          error: e.toString(),
        );
      }

      await manifestStore.save(manifest());
      yield _progressFromSegments(
        chapterId: chapterId,
        providerId: provider.id,
        voiceId: voice.id,
        segments: segments,
        currentParagraphId: para.id,
        currentParagraphIndex: i,
        error: segments[i].error,
      );
    }
  }

  GenerationProgress _progressFromSegments({
    required String chapterId,
    required String providerId,
    required String voiceId,
    required List<SegmentEntry> segments,
    String? currentParagraphId,
    int? currentParagraphIndex,
    String? error,
  }) {
    return GenerationProgress(
      chapterId: chapterId,
      ready: segments.where((s) => s.state == ParagraphAudioState.ready).length,
      failed: segments
          .where((s) => s.state == ParagraphAudioState.failed)
          .length,
      generating: segments
          .where((s) => s.state == ParagraphAudioState.generating)
          .length,
      total: segments.length,
      providerId: providerId,
      voiceId: voiceId,
      currentParagraphId: currentParagraphId,
      currentParagraphIndex: currentParagraphIndex,
      error: error,
    );
  }

  /// 将多段 WAV 文件的 PCM 数据拼接成单个合法 WAV。
  ///
  /// 保留第一段的 WAV 头（含 fmt chunk），去掉后续段的 header，
  /// 只把 data chunk 的原始 PCM 字节追加进去，并修正 RIFF/data size。
  static Uint8List concatWavPcm(List<Uint8List> wavs) {
    if (wavs.length == 1) return wavs.first;

    final first = wavs.first;
    if (first.length < 44) return first;

    final firstData = ByteData.sublistView(first);
    final sampleRate = firstData.getUint32(24, Endian.little);
    final channels = firstData.getUint16(22, Endian.little);
    final bitsPerSample = firstData.getUint16(34, Endian.little);
    final byteRate = firstData.getUint32(28, Endian.little);
    final blockAlign = firstData.getUint16(32, Endian.little);

    // 找到第一段的 data chunk 起始位置
    int dataOffset = 12;
    while (dataOffset + 8 <= first.length) {
      final chunkId = String.fromCharCodes(
        first.sublist(dataOffset, dataOffset + 4),
      );
      final chunkSize = firstData
          .getUint32(dataOffset + 4, Endian.little)
          .toInt();
      if (chunkId == 'data') break;
      dataOffset += 8 + chunkSize;
      if (chunkSize.isOdd) dataOffset += 1;
    }
    if (dataOffset + 8 > first.length) return first;

    final firstDataSize = firstData
        .getUint32(dataOffset + 4, Endian.little)
        .toInt();
    final firstPcmStart = dataOffset + 8;
    final firstPcm = first.sublist(
      firstPcmStart,
      firstPcmStart + firstDataSize,
    );

    // 收集后续段的 PCM 数据
    final pcmParts = <List<int>>[firstPcm];
    for (var i = 1; i < wavs.length; i++) {
      final wav = wavs[i];
      if (wav.length < 44) continue;
      final wd = ByteData.sublistView(wav);
      int off = 12;
      while (off + 8 <= wav.length) {
        final cid = String.fromCharCodes(wav.sublist(off, off + 4));
        final csz = wd.getUint32(off + 4, Endian.little).toInt();
        if (cid == 'data') {
          final pcmStart = off + 8;
          pcmParts.add(wav.sublist(pcmStart, pcmStart + csz));
          break;
        }
        off += 8 + csz;
        if (csz.isOdd) off += 1;
      }
    }

    final totalPcmSize = pcmParts.fold<int>(0, (sum, p) => sum + p.length);
    final headerSize = 44;
    final out = Uint8List(headerSize + totalPcmSize);
    final od = ByteData.sublistView(out);

    // RIFF header
    out[0] = 0x52; // R
    out[1] = 0x49; // I
    out[2] = 0x46; // F
    out[3] = 0x46; // F
    od.setUint32(4, 36 + totalPcmSize, Endian.little);
    out[8] = 0x57; // W
    out[9] = 0x41; // A
    out[10] = 0x56; // V
    out[11] = 0x45; // E

    // fmt chunk
    out[12] = 0x66; // f
    out[13] = 0x6D; // m
    out[14] = 0x74; // t
    out[15] = 0x20; // (space)
    od.setUint32(16, 16, Endian.little);
    od.setUint16(20, 1, Endian.little); // PCM
    od.setUint16(22, channels, Endian.little);
    od.setUint32(24, sampleRate, Endian.little);
    od.setUint32(28, byteRate, Endian.little);
    od.setUint16(32, blockAlign, Endian.little);
    od.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    out[36] = 0x64; // d
    out[37] = 0x61; // a
    out[38] = 0x74; // t
    out[39] = 0x61; // a
    od.setUint32(40, totalPcmSize, Endian.little);

    var pos = headerSize;
    for (final part in pcmParts) {
      out.setRange(pos, pos + part.length, part);
      pos += part.length;
    }

    return out;
  }

  static Uint8List _prepareWavForCache(
    List<Uint8List> wavs, {
    required bool fadeInEnabled,
  }) {
    final wav = concatWavPcm(wavs);
    return fadeInEnabled ? applyWavFadeIn(wav) : wav;
  }

  /// 对标准 16-bit PCM WAV 添加段首淡入，降低段落切换时的突兀感。
  ///
  /// 当前本地 Kokoro、Fish 本地和 Fish API 都输出 WAV PCM。无法识别或非
  /// 16-bit PCM 的 WAV 保持原样，避免破坏文件。
  static Uint8List applyWavFadeIn(Uint8List wav, {int fadeInMs = 80}) {
    if (fadeInMs <= 0 || wav.length < 44) return wav;
    if (String.fromCharCodes(wav.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(wav.sublist(8, 12)) != 'WAVE') {
      return wav;
    }

    final data = ByteData.sublistView(wav);
    int? formatCode;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? blockAlign;
    int? dataOffset;
    int? dataSize;

    var offset = 12;
    while (offset + 8 <= wav.length) {
      final chunkId = String.fromCharCodes(wav.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little).toInt();
      final chunkDataOffset = offset + 8;
      if (chunkDataOffset + chunkSize > wav.length) return wav;

      if (chunkId == 'fmt ' && chunkSize >= 16) {
        formatCode = data.getUint16(chunkDataOffset, Endian.little);
        channels = data.getUint16(chunkDataOffset + 2, Endian.little);
        sampleRate = data.getUint32(chunkDataOffset + 4, Endian.little);
        blockAlign = data.getUint16(chunkDataOffset + 12, Endian.little);
        bitsPerSample = data.getUint16(chunkDataOffset + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = chunkDataOffset;
        dataSize = chunkSize;
      }

      offset += 8 + chunkSize;
      if (chunkSize.isOdd) offset += 1;
    }

    if (formatCode != 1 ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample != 16 ||
        blockAlign == null ||
        dataOffset == null ||
        dataSize == null ||
        dataSize <= 0) {
      return wav;
    }

    final frameCount = dataSize ~/ blockAlign;
    if (frameCount <= 1) return wav;
    final fadeFrames = ((sampleRate * fadeInMs) / 1000)
        .round()
        .clamp(1, frameCount)
        .toInt();
    if (fadeFrames <= 1) return wav;

    final out = Uint8List.fromList(wav);
    final outData = ByteData.sublistView(out);
    for (var frame = 0; frame < fadeFrames; frame++) {
      final gain = frame / (fadeFrames - 1);
      final frameOffset = dataOffset + frame * blockAlign;
      for (var channel = 0; channel < channels; channel++) {
        final sampleOffset = frameOffset + channel * 2;
        final sample = outData.getInt16(sampleOffset, Endian.little);
        outData.setInt16(
          sampleOffset,
          (sample * gain).round().clamp(-32768, 32767).toInt(),
          Endian.little,
        );
      }
    }
    return out;
  }

  Future<List<TtsChunk>> _synthesizePossiblySplit({
    required TtsProvider provider,
    required TtsVoice voice,
    required String text,
    required double speed,
    required int maxRetries,
  }) async {
    final pieces = splitTextForTts(text, provider.capabilities.maxCharsPerCall);
    final chunks = <TtsChunk>[];
    for (final piece in pieces) {
      chunks.add(
        await _retry(
          () => provider.synthesize(text: piece, voice: voice, speed: speed),
          maxRetries,
        ),
      );
    }
    return chunks;
  }

  Future<T> _retry<T>(Future<T> Function() fn, int maxRetries) async {
    Object? last;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await fn();
      } catch (e) {
        last = e;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw last ?? StateError('unknown error');
  }

  Future<String> _absoluteSegmentPath(String bookId, SegmentEntry entry) async {
    return manifestStore.segmentPath(
      bookId: bookId,
      chapterId: entry.audioFile.split('/').first,
      paragraphId: entry.paragraphId,
      format: entry.format,
    );
  }
}

/// 按 TTS 单次字符上限切分文本。
///
/// [maxChars] 是软上限：优先保证一句话不被拆成多个音频请求。
/// 只有当单句长到明显异常时，才按逗号/空格等弱边界兜底，最后才硬切。
List<String> splitTextForTts(String text, int maxChars, {int? hardMaxChars}) {
  final trimmed = text.trim();
  if (trimmed.length <= maxChars) return [trimmed];
  final hardLimit = hardMaxChars ?? (maxChars * 4).clamp(maxChars, 4000);

  final sentences = trimmed
      .split(RegExp(r'(?<=[。！？!?；;\n])'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final out = <String>[];
  final buffer = StringBuffer();

  for (final sentence in sentences) {
    if (buffer.isNotEmpty && buffer.length + sentence.length > maxChars) {
      out.add(buffer.toString());
      buffer.clear();
    }

    if (sentence.length > hardLimit) {
      out.addAll(_splitOversizedSentence(sentence, hardLimit));
      continue;
    }

    buffer.write(sentence);
  }

  if (buffer.isNotEmpty) out.add(buffer.toString());
  return out;
}

List<String> _splitOversizedSentence(String sentence, int hardLimit) {
  final parts = sentence
      .split(RegExp(r'(?<=[，,、：:])|\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (parts.length <= 1) {
    return _hardSplit(sentence, hardLimit);
  }

  final out = <String>[];
  final buffer = StringBuffer();
  for (final part in parts) {
    if (part.length > hardLimit) {
      if (buffer.isNotEmpty) {
        out.add(buffer.toString());
        buffer.clear();
      }
      out.addAll(_hardSplit(part, hardLimit));
      continue;
    }

    if (buffer.isNotEmpty && buffer.length + part.length > hardLimit) {
      out.add(buffer.toString());
      buffer.clear();
    }
    buffer.write(part);
  }
  if (buffer.isNotEmpty) out.add(buffer.toString());
  return out;
}

List<String> _hardSplit(String text, int limit) {
  final out = <String>[];
  for (var i = 0; i < text.length; i += limit) {
    out.add(text.substring(i, (i + limit).clamp(0, text.length)));
  }
  return out;
}
