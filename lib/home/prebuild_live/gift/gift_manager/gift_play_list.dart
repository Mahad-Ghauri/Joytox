part of 'gift_manager.dart';

mixin GiftPlayList {
  final _playListImpl = PlayListImpl();

  PlayListImpl get playList => _playListImpl;
}

class PlayListImpl {
  final playingDataNotifier = ValueNotifier<GiftsModel?>(null);
  List<GiftsModel> pendingPlaylist = [];

  void next() {
    if (pendingPlaylist.isEmpty) {
      playingDataNotifier.value = null;
    } else {
      playingDataNotifier.value = pendingPlaylist.removeAt(0);
    }
  }

  void add(
      GiftsModel data,
  ) {
    if (playingDataNotifier.value != null) {
      pendingPlaylist.add(data);
      return;
    }
    playingDataNotifier.value = data;
  }

  bool clear() {
    playingDataNotifier.value = null;
    pendingPlaylist.clear();

    return true;
  }
}
