import 'package:flutter/services.dart';

const appIconOptions = <AppIconOption>[
  AppIconOption(
    id: 'default',
    englishLabel: 'Original',
    chineseLabel: '当前图标',
    japaneseLabel: '現在のアイコン',
    assetPath: 'assets/app_icon/lumina_app_icon_1024.png',
  ),
  AppIconOption(
    id: 'a1',
    englishLabel: 'Quiet A1',
    chineseLabel: '静听 A1',
    japaneseLabel: '静聴 A1',
    assetPath: 'assets/app_icon_concepts/lumina-a1.png',
  ),
  AppIconOption(
    id: 'a2',
    englishLabel: 'Quiet A2',
    chineseLabel: '静听 A2',
    japaneseLabel: '静聴 A2',
    assetPath: 'assets/app_icon_concepts/lumina-a2.png',
  ),
  AppIconOption(
    id: 'b1',
    englishLabel: 'Wave B1',
    chineseLabel: '声波 B1',
    japaneseLabel: '音波 B1',
    assetPath: 'assets/app_icon_concepts/lumina-b1.png',
  ),
  AppIconOption(
    id: 'b2',
    englishLabel: 'Wave B2',
    chineseLabel: '声波 B2',
    japaneseLabel: '音波 B2',
    assetPath: 'assets/app_icon_concepts/lumina-b2.png',
  ),
  AppIconOption(
    id: 'c1',
    englishLabel: 'Page C1',
    chineseLabel: '书页 C1',
    japaneseLabel: 'ページ C1',
    assetPath: 'assets/app_icon_concepts/lumina-c1.png',
  ),
  AppIconOption(
    id: 'c2',
    englishLabel: 'Page C2',
    chineseLabel: '书页 C2',
    japaneseLabel: 'ページ C2',
    assetPath: 'assets/app_icon_concepts/lumina-c2.png',
  ),
];

class AppIconOption {
  final String id;
  final String englishLabel;
  final String chineseLabel;
  final String japaneseLabel;
  final String assetPath;

  const AppIconOption({
    required this.id,
    required this.englishLabel,
    required this.chineseLabel,
    required this.japaneseLabel,
    required this.assetPath,
  });
}

abstract interface class AppIconGateway {
  Future<bool> isSupported();

  Future<String> currentIconId();

  Future<void> setIcon(String iconId);
}

class MethodChannelAppIconGateway implements AppIconGateway {
  static const channel = MethodChannel('lumina/app_icon');

  const MethodChannelAppIconGateway();

  @override
  Future<bool> isSupported() async {
    try {
      return await channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String> currentIconId() async {
    try {
      final id = await channel.invokeMethod<String>('getIcon');
      return appIconOptions.any((option) => option.id == id) ? id! : 'default';
    } on MissingPluginException {
      return 'default';
    }
  }

  @override
  Future<void> setIcon(String iconId) async {
    if (!appIconOptions.any((option) => option.id == iconId)) {
      throw ArgumentError.value(iconId, 'iconId', 'Unknown app icon');
    }
    await channel.invokeMethod<void>('setIcon', {'iconId': iconId});
  }
}
