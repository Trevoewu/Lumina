# Discover · Editorial Store

发现页采用 App Store Today 的编辑式内容节奏，延续 Lumina 的语义颜色、系统字体和间距 tokens。

- 公版书与有声书的空查询入口：主推书封与原始简介 → 最多六本横向书架 → 作家专题（公版书）→ 其余目录。
- 主推书籍来自当前目录首项，不标注为人工精选、每日推荐或未经核实的榜单。
- 作家专题直接使用 Gutendex 作者搜索；LibriVox 当前仅支持书名查询，因此不显示该入口。
- 搜索后使用紧凑结果列表，清空查询恢复杂志页。播客和本地书架保留原有入口。
- 所有书卡沿用已有详情、导入和播放路径。更多内容追加到当前目录，保留已加载书籍。
- 请求开始时固定查询与页码，过期请求不能污染新查询的分页缓存。
- 封面使用磁盘缓存，完整展示原始比例；缺图时显示书名占位。首屏使用静态骨架，不播放装饰性动画。
- 窄屏分类栏可横滑；书架高度随系统字体缩放，正文和长标题有明确的截断规则。

验证入口：`flutter test test/discover_screen_test.dart test/discover_editorial_feed_test.dart`。

模拟器独立预览（真实数据）：`flutter run -t tool/discover_preview.dart -d <simulator-id>`。正常入口仍是 `lib/main.dart`。

## 本次验证

- `flutter analyze --no-pub`：无问题。
- `flutter test --no-pub`：345 项通过，其中发现页及杂志组件 18 项。
- 320 宽屏幕、1× / 1.3× / 2× 字体、双主题和缺封面已通过组件测试。
- iOS 模拟器构建成功，真实数据的深浅主题首屏已检查；深色截图见 `previews/discover-editorial-dark.png`。
- 桌面交互工具发生屏幕捕获错误，完整模拟器手势录屏与帧率测量尚未完成；不将组件测试视为这两项验收的替代。
