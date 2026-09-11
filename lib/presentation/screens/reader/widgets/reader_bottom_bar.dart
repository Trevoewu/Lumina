import 'reader_appearance_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_localizations.dart';

/// 优雅的阅读器底栏控制器组件：
/// 1. 右下角快捷胶囊：听书播放器（耳机图标）
/// 2. 进度拖拽面板（点击 `🧭` 唤起）
/// 3. 四键操作栏：`≡` 目录、`🧭` 进度、`☀️` 主题/亮度、`A` 排版
class ReaderBottomBar extends StatefulWidget {
  final bool isVisible;
  final ValueChanged<bool>? onProgressVisibilityChanged;
  final bool isEpub;
  final double progress;
  final int currentPage;
  final int totalPages;
  final String chapterTitle;
  final bool hasPrevChapter;
  final bool hasNextChapter;
  final VoidCallback onToggleToc;
  final ValueChanged<double> onSeekProgress;
  final VoidCallback onToggleTheme;
  final VoidCallback? onOpenAi;
  final VoidCallback? onOpenTranslate;
  final VoidCallback onStartListening;
  final VoidCallback? onPrevChapter;
  final VoidCallback? onNextChapter;

  const ReaderBottomBar({
    super.key,
    required this.isVisible,
    this.onProgressVisibilityChanged,
    required this.isEpub,
    required this.progress,
    required this.currentPage,
    required this.totalPages,
    required this.chapterTitle,
    required this.hasPrevChapter,
    required this.hasNextChapter,
    required this.onToggleToc,
    required this.onSeekProgress,
    required this.onToggleTheme,
    this.onOpenAi,
    this.onOpenTranslate,
    required this.onStartListening,
    this.onPrevChapter,
    this.onNextChapter,
  });

  @override
  State<ReaderBottomBar> createState() => _ReaderBottomBarState();
}

class _ReaderBottomBarState extends State<ReaderBottomBar> {
  bool _showProgressSlider = false;
  bool _showTypography = false;
  double _dragProgress = 0.0;
  bool _isDragging = false;

  @override
  void didUpdateWidget(covariant ReaderBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isVisible && oldWidget.isVisible) {
      _showProgressSlider = false;
      _showTypography = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentProgress = _isDragging ? _dragProgress : widget.progress;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── 1. 右下角悬浮快捷操作 (听书播放器) ─────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          right: 16,
          bottom: widget.isVisible
              ? (_showTypography
                    ? 298 + bottomPadding
                    : (_showProgressSlider
                          ? 168 + bottomPadding
                          : 68 + bottomPadding))
              : -80,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.isVisible ? 1.0 : 0.0,
            child: _buildQuickActionPill(
              icon: HugeIcons.strokeRoundedHeadphones,
              tooltip: context.tr('听书播放器', 'Player', '再生プレーヤー'),
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onStartListening();
              },
            ),
          ),
        ),

        // ── 2. 进度调节滑块浮层 (点击 🧭 唤起) ──────────────────────────────────
        if (_showProgressSlider && widget.isVisible)
          Positioned(
            left: 16,
            right: 16,
            bottom: 56 + bottomPadding + 10,
            child: Container(
              key: const Key('reader-progress-panel'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.appBackground.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.appDivider.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.chapterTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(currentProgress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          size: 16,
                        ),
                        color: widget.hasPrevChapter
                            ? context.appTextPrimary
                            : context.appTextSecondary.withValues(alpha: 0.3),
                        onPressed: widget.hasPrevChapter
                            ? () {
                                HapticFeedback.selectionClick();
                                widget.onPrevChapter?.call();
                              }
                            : null,
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.5,
                            activeTrackColor: context.appAccent,
                            inactiveTrackColor: context.appTextSecondary
                                .withValues(alpha: 0.2),
                            thumbColor: context.appAccent,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                          ),
                          child: Slider(
                            value: currentProgress.clamp(0.0, 1.0),
                            onChanged: (val) {
                              setState(() {
                                _isDragging = true;
                                _dragProgress = val;
                              });
                            },
                            onChangeEnd: (val) {
                              setState(() => _isDragging = false);
                              HapticFeedback.lightImpact();
                              widget.onSeekProgress(val);
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        color: widget.hasNextChapter
                            ? context.appTextPrimary
                            : context.appTextSecondary.withValues(alpha: 0.3),
                        onPressed: widget.hasNextChapter
                            ? () {
                                HapticFeedback.selectionClick();
                                widget.onNextChapter?.call();
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        if (_showTypography && widget.isVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 56 + bottomPadding,
            child: const ReaderAppearancePanel(),
          ),

        // ── 3. 主底栏五大功能项 ───────────────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: widget.isVisible ? 0 : -(56 + bottomPadding + 20),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPadding + 6),
            decoration: BoxDecoration(
              color: context.appBackground.withValues(alpha: 0.96),
              border: Border(
                top: BorderSide(
                  color: context.appDivider.withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 1. 目录 ≡
                _buildBarItem(
                  icon: HugeIcons.strokeRoundedMenu01,
                  tooltip: context.tr('目录', 'Table of Contents', '目次'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onToggleToc();
                  },
                ),

                // 2. 进度 🧭
                _buildBarItem(
                  icon: HugeIcons.strokeRoundedCompass,
                  isActive: _showProgressSlider,
                  tooltip: context.tr('进度', 'Progress', '進捗'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _showProgressSlider = !_showProgressSlider;
                      _showTypography = false;
                    });
                    widget.onProgressVisibilityChanged?.call(
                      _showProgressSlider,
                    );
                  },
                ),

                // 3. 主题/亮度 ☀️
                _buildBarItem(
                  icon: HugeIcons.strokeRoundedSun03,
                  tooltip: context.tr('日夜模式', 'Theme', 'テーマ'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onToggleTheme();
                  },
                ),

                // 4. 排版 A
                _buildBarItem(
                  customWidget: Text(
                    'A',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _showTypography
                          ? context.appAccent
                          : context.appTextPrimary,
                    ),
                  ),
                  isActive: _showTypography,
                  tooltip: context.tr('阅读排版', 'Typography', '読書設定'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _showTypography = !_showTypography;
                      _showProgressSlider = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionPill({
    dynamic icon,
    String? label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(23),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF5F646C),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: icon != null
                  ? (icon is IconData
                      ? Icon(icon, size: 22, color: Colors.white)
                      : HugeIcon(
                          icon: icon,
                          size: 22,
                          color: Colors.white,
                        ))
                  : Text(
                      label ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarItem({
    dynamic icon,
    Widget? customWidget,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final color = isActive ? context.appAccent : context.appTextPrimary;

    Widget content;
    if (customWidget != null) {
      content = customWidget;
    } else if (icon is IconData) {
      content = Icon(icon, size: 22, color: color);
    } else {
      content = HugeIcon(icon: icon, size: 22, color: color);
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: content,
          ),
        ),
      ),
    );
  }
}
