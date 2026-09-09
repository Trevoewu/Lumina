import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Vector data from the HugeIcons Stroke / Rounded family.
typedef AppIconData = List<List<dynamic>>;

/// App-wide icon renderer; inherits size, color and disabled opacity from IconTheme.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final AppIconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? IconTheme.of(context).size ?? 24;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: icon == null
            ? SizedBox.square(dimension: dimension)
            : HugeIcon(icon: icon!, size: dimension, color: color),
      ),
    );
  }
}

/// Semantic aliases keep page code independent of the icon vendor's naming.
/// Every alias resolves to Stroke / Rounded; state never switches icon family.
abstract final class AppIcons {
  static const moreHorizontal = HugeIcons.strokeRoundedMoreHorizontal;
  static const add01 = HugeIcons.strokeRoundedAdd01;
  static const addCircle = HugeIcons.strokeRoundedAddCircle;
  static const aiMagic = HugeIcons.strokeRoundedAiMagic;
  static const aiNetwork = HugeIcons.strokeRoundedAiNetwork;
  static const aiVoice = HugeIcons.strokeRoundedAiVoice;
  static const airplayLine = HugeIcons.strokeRoundedAirplayLine;
  static const album01 = HugeIcons.strokeRoundedAlbum01;
  static const alertCircle = HugeIcons.strokeRoundedAlertCircle;
  static const arrowDataTransferHorizontal =
      HugeIcons.strokeRoundedArrowDataTransferHorizontal;
  static const arrowDown01 = HugeIcons.strokeRoundedArrowDown01;
  static const arrowLeft02 = HugeIcons.strokeRoundedArrowLeft02;
  static const arrowRight01 = HugeIcons.strokeRoundedArrowRight01;
  static const arrowRight02 = HugeIcons.strokeRoundedArrowRight02;
  static const arrowTurnBackward = HugeIcons.strokeRoundedArrowTurnBackward;
  static const arrowUp01 = HugeIcons.strokeRoundedArrowUp01;
  static const arrowUp02 = HugeIcons.strokeRoundedArrowUp02;
  static const arrowUpDown = HugeIcons.strokeRoundedArrowUpDown;
  static const arrowUpRight01 = HugeIcons.strokeRoundedArrowUpRight01;
  static const audioWave01 = HugeIcons.strokeRoundedAudioWave01;
  static const bookOpen01 = HugeIcons.strokeRoundedBookOpen01;
  static const bookOpen02 = HugeIcons.strokeRoundedBookOpen02;
  static const bookPlus = HugeIcons.strokeRoundedBookPlus;
  static const bookSearch = HugeIcons.strokeRoundedBookSearch;
  static const bookmark01 = HugeIcons.strokeRoundedBookmark01;
  static const bookmark02 = HugeIcons.strokeRoundedBookmark02;
  static const bookmarkCheck01 = HugeIcons.strokeRoundedBookmarkCheck01;
  static const bubbleChat = HugeIcons.strokeRoundedBubbleChat;
  static const bulb = HugeIcons.strokeRoundedBulb;
  static const cancel01 = HugeIcons.strokeRoundedCancel01;
  static const cancel02 = HugeIcons.strokeRoundedCancel02;
  static const cancelCircle = HugeIcons.strokeRoundedCancelCircle;
  static const champion = HugeIcons.strokeRoundedChampion;
  static const chartIncrease = HugeIcons.strokeRoundedChartIncrease;
  static const checkmarkCircle02 = HugeIcons.strokeRoundedCheckmarkCircle02;
  static const chemistry01 = HugeIcons.strokeRoundedChemistry01;
  static const circle = HugeIcons.strokeRoundedCircle;
  static const clean = HugeIcons.strokeRoundedClean;
  static const clock01 = HugeIcons.strokeRoundedClock01;
  static const clockArrowDown = HugeIcons.strokeRoundedClockArrowDown;
  static const cloud = HugeIcons.strokeRoundedCloud;
  static const cloudOff = HugeIcons.strokeRoundedCloudOff;
  static const compass = HugeIcons.strokeRoundedCompass;
  static const database02 = HugeIcons.strokeRoundedDatabase02;
  static const delete02 = HugeIcons.strokeRoundedDelete02;
  static const download01 = HugeIcons.strokeRoundedDownload01;
  static const downloadCircle01 = HugeIcons.strokeRoundedDownloadCircle01;
  static const favourite = HugeIcons.strokeRoundedFavourite;
  static const file02 = HugeIcons.strokeRoundedFile02;
  static const fileUpload = HugeIcons.strokeRoundedFileUpload;
  static const fire = HugeIcons.strokeRoundedFire;
  static const globe02 = HugeIcons.strokeRoundedGlobe02;
  static const goBackward10Sec = HugeIcons.strokeRoundedGoBackward10Sec;
  static const goForward10Sec = HugeIcons.strokeRoundedGoForward10Sec;
  static const home01 = HugeIcons.strokeRoundedHome01;
  static const hourglass = HugeIcons.strokeRoundedHourglass;
  static const image01 = HugeIcons.strokeRoundedImage01;
  static const imageNotFound01 = HugeIcons.strokeRoundedImageNotFound01;
  static const informationCircle = HugeIcons.strokeRoundedInformationCircle;
  static const laptop = HugeIcons.strokeRoundedLaptop;
  static const leftToRightListBullet =
      HugeIcons.strokeRoundedLeftToRightListBullet;
  static const link01 = HugeIcons.strokeRoundedLink01;
  static const linkSquare02 = HugeIcons.strokeRoundedLinkSquare02;
  static const magicWand01 = HugeIcons.strokeRoundedMagicWand01;
  static const mic01 = HugeIcons.strokeRoundedMic01;
  static const minusSign = HugeIcons.strokeRoundedMinusSign;
  static const minusSignCircle = HugeIcons.strokeRoundedMinusSignCircle;
  static const moon02 = HugeIcons.strokeRoundedMoon02;
  static const mortarboard01 = HugeIcons.strokeRoundedMortarboard01;
  static const next = HugeIcons.strokeRoundedNext;
  static const note01 = HugeIcons.strokeRoundedNote01;
  static const paintBoard = HugeIcons.strokeRoundedPaintBoard;
  static const pause = HugeIcons.strokeRoundedPause;
  static const pauseCircle = HugeIcons.strokeRoundedPauseCircle;
  static const pencilEdit02 = HugeIcons.strokeRoundedPencilEdit02;
  static const play = HugeIcons.strokeRoundedPlay;
  static const playCircle = HugeIcons.strokeRoundedPlayCircle;
  static const playList = HugeIcons.strokeRoundedPlayList;
  static const podcast = HugeIcons.strokeRoundedPodcast;
  static const quoteDown = HugeIcons.strokeRoundedQuoteDown;
  static const radioButton = HugeIcons.strokeRoundedRadioButton;
  static const refresh = HugeIcons.strokeRoundedRefresh;
  static const reload = HugeIcons.strokeRoundedReload;
  static const rss = HugeIcons.strokeRoundedRss;
  static const search01 = HugeIcons.strokeRoundedSearch01;
  static const searchRemove = HugeIcons.strokeRoundedSearchRemove;
  static const settings02 = HugeIcons.strokeRoundedSettings02;
  static const stop = HugeIcons.strokeRoundedStop;
  static const subtitle = HugeIcons.strokeRoundedSubtitle;
  static const sun01 = HugeIcons.strokeRoundedSun01;
  static const sun03 = HugeIcons.strokeRoundedSun03;
  static const target02 = HugeIcons.strokeRoundedTarget02;
  static const text = HugeIcons.strokeRoundedText;
  static const textFont = HugeIcons.strokeRoundedTextFont;
  static const tick02 = HugeIcons.strokeRoundedTick02;
  static const tickDouble02 = HugeIcons.strokeRoundedTickDouble02;
  static const timer01 = HugeIcons.strokeRoundedTimer01;
  static const translation = HugeIcons.strokeRoundedTranslation;
  static const user = HugeIcons.strokeRoundedUser;
  static const viewOff = HugeIcons.strokeRoundedViewOff;
  static const volumeHigh = HugeIcons.strokeRoundedVolumeHigh;
}
