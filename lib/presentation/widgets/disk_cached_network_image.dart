import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/image_disk_cache.dart';

class DiskCachedNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget placeholder;
  final ImageDiskCache? cache;
  final AlignmentGeometry alignment;

  const DiskCachedNetworkImage({
    super.key,
    required this.url,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.cache,
    this.alignment = Alignment.center,
  });

  @override
  State<DiskCachedNetworkImage> createState() => _DiskCachedNetworkImageState();
}

class _DiskCachedNetworkImageState extends State<DiskCachedNetworkImage> {
  File? _file;
  int _loadGeneration = 0;

  ImageDiskCache get _cache => widget.cache ?? appImageDiskCache;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DiskCachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.cache != widget.cache) {
      _load();
    }
  }

  void _load() {
    final generation = ++_loadGeneration;
    final cached = _cache.peek(widget.url);
    _file = cached;
    if (cached != null) return;

    _cache.load(widget.url).then((file) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _file = file);
    }, onError: (_, _) {});
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) return widget.placeholder;

    return LayoutBuilder(
      builder: (context, constraints) {
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        int? cachePixels(double extent) {
          if (!extent.isFinite || extent <= 0) return null;
          return (extent * pixelRatio).ceil().clamp(1, 4096).toInt();
        }

        return Image.file(
          file,
          fit: widget.fit,
          alignment: widget.alignment,
          width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          cacheWidth: cachePixels(constraints.maxWidth),
          cacheHeight: cachePixels(constraints.maxHeight),
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => widget.placeholder,
        );
      },
    );
  }
}
