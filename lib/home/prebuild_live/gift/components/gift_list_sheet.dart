// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../../../../helpers/quick_actions.dart';
import '../../../../models/GiftsModel.dart';
import '../../../../models/UserModel.dart';
import '../../../../ui/container_with_corner.dart';
import '../../../../ui/text_with_tap.dart';
import '../../../../utils/colors.dart';
import '../gift_manager/gift_manager.dart';

class OpenGiftsSheet {
  OpenGifts(
      {required BuildContext context,
      required UserModel currentUser,
      Function(GiftsModel giftsModel)? onGiftSelected,
      bool isDismissible = true,
      bool enableDrag = true,
      bool isScrollControlled = false,
      Color backgroundColor = Colors.transparent}) {
    showModalBottomSheet(
        context: (context),
        isScrollControlled: isScrollControlled,
        backgroundColor: backgroundColor,
        enableDrag: enableDrag,
        isDismissible: isDismissible,
        builder: (context) {
          return ZegoGiftSheet(
            currentUser: currentUser,
            onGiftSelected: onGiftSelected,
          );
        });
  }
}

class ZegoGiftSheet extends StatefulWidget {
  final Function? onGiftSelected;
  UserModel currentUser;

  ZegoGiftSheet({
    required this.currentUser,
    this.onGiftSelected,
    Key? key,
  }) : super(key: key);

  @override
  State<ZegoGiftSheet> createState() => _ZegoGiftSheetState();
}

class _ZegoGiftSheetState extends State<ZegoGiftSheet>
    with TickerProviderStateMixin {
  final selectedGiftItemNotifier = ValueNotifier<GiftsModel?>(null);
  final countNotifier = ValueNotifier<String>('1');
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController.unbounded(vsync: this);

    /*widget.itemDataList.sort((l, r) {
      return l.weight.compareTo(r.weight);
    });*/
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: getGifts(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            countDropList(),
            SizedBox(
              height: 30,
              child: sendButton(),
            ),
          ],
        ),
      ],
    );
  }

  Widget getGifts() {
    QueryBuilder<GiftsModel> giftQuery = QueryBuilder<GiftsModel>(GiftsModel());
    giftQuery.whereValueExists(GiftsModel.keyGiftCategories, true);
    giftQuery.whereEqualTo(GiftsModel.keyGiftCategories, GiftsModel.gifStatus);

    return ContainerCorner(
      color: kTransparentColor,
      child: ParseLiveGridWidget<GiftsModel>(
        query: giftQuery,
        crossAxisCount: 4,
        reverse: false,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        lazyLoading: false,
        //childAspectRatio: 1.0,
        shrinkWrap: true,
        listenOnAllSubItems: true,
        duration: Duration(seconds: 0),
        animationController: _animationController,
        childBuilder: (BuildContext context,
            ParseLiveListElementSnapshot<GiftsModel> snapshot) {
          GiftsModel gift = snapshot.loadedData!;
          return GestureDetector(
            //onTap: () => _checkCredits(gift, setState),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => selectedGiftItemNotifier.value = gift,
                    child: Column(
                      children: [
                        ValueListenableBuilder<GiftsModel?>(
                          valueListenable: selectedGiftItemNotifier,
                          builder: (context, selectedGiftItem, _) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(2)),
                                border: Border.all(
                                  color:
                                      selectedGiftItem?.getName == gift.getName
                                          ? Colors.red
                                          : Colors.white.withOpacity(0.2),
                                ),
                              ),
                              width: 50,
                              height: 50,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: QuickActions.photosWidget(
                                    gift.getPreview!.url),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  ContainerCorner(
                    color: kTransparentColor,
                    marginTop: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          "assets/svg/ic_coin_with_star.svg",
                          width: 16,
                          height: 16,
                        ),
                        TextWithTap(
                          gift.getCoins.toString(),
                          color: Colors.white,
                          fontSize: 14,
                          marginLeft: 5,
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        queryEmptyElement: Container(
          margin: EdgeInsets.only(top: 50),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "🎁 [DEBUG] No gifts found in database",
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        gridLoadingElement: Container(
          margin: EdgeInsets.only(top: 50),
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "🎁 [DEBUG] Loading gifts from database...",
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget sendButton() {
    return ElevatedButton(
      onPressed: () {
        debugPrint("gift_selecionado: ${selectedGiftItemNotifier.value}");
        if (selectedGiftItemNotifier.value == null) {
          debugPrint(
              "gift_selecionado: deu null ${selectedGiftItemNotifier.value == null}");
          return;
        }

        final giftItem = selectedGiftItemNotifier.value!;
        final giftCount = int.tryParse(countNotifier.value) ?? 1;
        Navigator.of(context).pop();

        debugPrint("gift_selecionado: tocar antes");

        /// local play
        ZegoGiftManager().playList.add(giftItem);
        debugPrint("gift_selecionado: tocar depois");

        /// notify remote host
        ZegoGiftManager()
            .service
            .sendGift(name: giftItem.getName!, count: giftCount);
      },
      child: Text('comment_post.send_'.tr().toUpperCase()),
    );
  }

  Widget countDropList() {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 15,
    );

    return ValueListenableBuilder<String>(
        valueListenable: countNotifier,
        builder: (context, count, _) {
          return DropdownButton<String>(
            value: count,
            onChanged: (selectedValue) {
              countNotifier.value = selectedValue!;
            },
            alignment: AlignmentDirectional.centerEnd,
            style: textStyle,
            dropdownColor: Colors.black.withOpacity(0.5),
            items: <String>['1', '5', '10', '100'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              );
            }).toList(),
          );
        });
  }
}