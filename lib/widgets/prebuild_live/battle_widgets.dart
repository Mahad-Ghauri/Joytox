import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../utils/colors.dart';
import '../../ui/container_with_corner.dart';
import '../../ui/text_with_tap.dart';
import 'package:easy_localization/easy_localization.dart';

class BattlePointsWidget extends StatelessWidget {
  final int myPoints;
  final int hisPoints;

  const BattlePointsWidget({
    Key? key,
    required this.myPoints,
    required this.hisPoints,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);
    var pkColors = [kOrangedColor, kPurpleColor];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        2,
        (index) {
          return ContainerCorner(
            width: size.width / 2,
            height: 15,
            color: pkColors[index],
            borderWidth: 0,
            child: TextWithTap(
              "${index == 0 ? myPoints : hisPoints} " +
                  tr("coins_and_points_screen.points_"),
              color: Colors.white,
              alignment:
                  index == 1 ? Alignment.centerRight : Alignment.centerLeft,
              fontSize: 12,
              marginRight: index == 1 ? 10 : 0,
              marginLeft: index == 0 ? 10 : 0,
              fontWeight: FontWeight.w900,
            ),
          );
        },
      ),
    );
  }
}

class BattleVictoryWidget extends StatelessWidget {
  final int myVictories;
  final int hisVictories;

  const BattleVictoryWidget({
    Key? key,
    required this.myVictories,
    required this.hisVictories,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);

    return SizedBox(
      width: size.width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          2,
          (index) {
            return ContainerCorner(
              color: Colors.black38,
              borderWidth: 0,
              borderRadius: 4,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextWithTap(
                      "WIN",
                      color: kOrangeColor100,
                      fontWeight: FontWeight.w900,
                      marginRight: 1,
                      fontSize: 12,
                    ),
                    TextWithTap(
                      "x ${index == 0 ? myVictories : hisVictories}",
                      color: Colors.white,
                      alignment: index == 1
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BattleWinnerWidget extends StatelessWidget {
  final int myPoints;
  final int hisPoints;
  final bool showWinner;

  const BattleWinnerWidget({
    Key? key,
    required this.myPoints,
    required this.hisPoints,
    required this.showWinner,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!showWinner) return const SizedBox();

    Size size = MediaQuery.sizeOf(context);

    if (myPoints > hisPoints) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Lottie.asset(
            "assets/lotties/battle_winner.json",
            height: size.width / 2.3,
            width: size.width / 2.3,
          ),
          Lottie.asset(
            "assets/lotties/battle_lost.json",
            height: size.width / 3,
            width: size.width / 3,
          ),
        ],
      );
    } else if (hisPoints > myPoints) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Lottie.asset(
            "assets/lotties/battle_lost.json",
            height: size.width / 3,
            width: size.width / 3,
          ),
          Lottie.asset(
            "assets/lotties/battle_winner.json",
            height: size.width / 2.3,
            width: size.width / 2.3,
          ),
        ],
      );
    } else {
      return Lottie.asset(
        "assets/lotties/no_winner.json",
        height: size.width / 2.3,
        width: size.width / 2.3,
      );
    }
  }
}
