import 'gift_manager/defines.dart';

final List<ZegoGiftItem> giftItemList = [
  ZegoGiftItem(
    name: 'Music Box1',
    icon: 'assets/gift/musicBox.png',
    sourceURL:
        'https://storage.zego.im/sdk-doc/Pics/zegocloud/gift/music_box.mp4',
    source: ZegoGiftSource.url,
    type: ZegoGiftType.mp4,
    weight: 1,
  ),
  ZegoGiftItem(
    name: 'Music Box2',
    icon: 'assets/gift/musicBox.png',
    sourceURL:
        'https://storage.zego.im/sdk-doc/Pics/zegocloud/gift/music_box.mp4',
    source: ZegoGiftSource.url,
    type: ZegoGiftType.mp4,
    weight: 10,
  ),
  ZegoGiftItem(
    name: 'Music Box3',
    icon: 'assets/gift/musicBox.png',
    sourceURL:
        'https://storage.zego.im/sdk-doc/Pics/zegocloud/gift/music_box.mp4',
    source: ZegoGiftSource.url,
    type: ZegoGiftType.mp4,
    weight: 100,
  ),
  ZegoGiftItem(
    name: 'rocket',
    icon: 'assets/gift/rocket.png',
    sourceURL: 'assets/gift/rocket.svga',
    source: ZegoGiftSource.asset,
    type: ZegoGiftType.svga,
    weight: 1,
  ),
  ZegoGiftItem(
    name: 'crown',
    icon: 'assets/gift/crown.png',
    sourceURL: 'assets/gift/crown.svga',
    source: ZegoGiftSource.asset,
    type: ZegoGiftType.svga,
    weight: 100,
  ),
];

ZegoGiftItem? queryGiftInItemList(String name) {
  // Exact match first
  final exactIndex = giftItemList.indexWhere((item) => item.name == name);
  if (-1 != exactIndex) return giftItemList.elementAt(exactIndex);

  // Flexible match: normalize and map aliases
  final normalized = _normalizeName(name);
  final aliasTarget = _aliasMap[normalized];
  if (aliasTarget != null) {
    final aliasIndex = giftItemList.indexWhere(
        (item) => _normalizeName(item.name) == _normalizeName(aliasTarget));
    if (-1 != aliasIndex) return giftItemList.elementAt(aliasIndex);
  }

  // Fallback: match by normalized name
  final flexIndex = giftItemList
      .indexWhere((item) => _normalizeName(item.name) == normalized);
  return -1 != flexIndex ? giftItemList.elementAt(flexIndex) : null;
}

String _normalizeName(String input) {
  return input.toLowerCase().replaceAll(RegExp(r"[\s_\-]+"), '').trim();
}

// Common alias mappings between backend names and UI gift asset names
const Map<String, String> _aliasMap = {
  // e.g. 'music_box' or 'musicbox' -> 'Music Box1'
  'musicbox': 'Music Box1',
  'music_box': 'Music Box1',
  'musicbox1': 'Music Box1',
  // Add other known mappings if backend names differ from UI asset names
};
