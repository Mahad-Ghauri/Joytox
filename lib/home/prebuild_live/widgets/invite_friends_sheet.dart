import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:trace/helpers/quick_actions.dart';
import 'package:trace/models/UserModel.dart';

import '../../../ui/container_with_corner.dart';
import '../../../ui/text_with_tap.dart';
import '../../../utils/colors.dart';

class InviteFriendsSheet extends StatefulWidget {
  final UserModel currentUser;
  final int seatIndex;
  final Function(UserModel user, int seatIndex) onUserSelected;

  const InviteFriendsSheet({
    Key? key,
    required this.currentUser,
    required this.seatIndex,
    required this.onUserSelected,
  }) : super(key: key);

  @override
  State<InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<InviteFriendsSheet>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: ContainerCorner(
        radiusTopRight: 20.0,
        radiusTopLeft: 20.0,
        color: kContentColorLightTheme,
        width: size.width,
        borderWidth: 0,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWithTap(
                    "Invite to Seat ${widget.seatIndex + 1}",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: kPrimaryColor,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: "Followers"),
                Tab(text: "Following"),
              ],
            ),

            // Tab Bar View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUsersList(isFollowers: true),
                  _buildUsersList(isFollowers: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList({required bool isFollowers}) {
    // Get followers or following list
    List<String> userIds = (isFollowers
            ? widget.currentUser.getFollowers ?? []
            : widget.currentUser.getFollowing ?? [])
        .cast<String>();

    if (userIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            TextWithTap(
              isFollowers ? "No followers found" : "No following found",
              color: Colors.grey,
              fontSize: 16,
            ),
          ],
        ),
      );
    }

    QueryBuilder<UserModel> queryUsers =
        QueryBuilder<UserModel>(UserModel.forQuery());
    queryUsers.whereContainedIn(UserModel.keyObjectId, userIds);
    queryUsers.whereNotEqualTo(
        UserModel.keyObjectId, widget.currentUser.objectId);
    queryUsers.setLimit(50);

    return ParseLiveListWidget<UserModel>(
      query: queryUsers,
      reverse: false,
      lazyLoading: true,
      shrinkWrap: true,
      duration: const Duration(milliseconds: 200),
      childBuilder: (BuildContext context,
          ParseLiveListElementSnapshot<UserModel> snapshot) {
        if (snapshot.hasData) {
          UserModel user = snapshot.loadedData!;

          return ContainerCorner(
            marginLeft: 15,
            marginRight: 15,
            marginBottom: 10,
            borderRadius: 12,
            color: Colors.white.withValues(alpha: 0.1),
            onTap: () {
              Navigator.of(context).pop();
              widget.onUserSelected(user, widget.seatIndex);
            },
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Row(
                children: [
                  QuickActions.avatarWidget(
                    user,
                    width: 50,
                    height: 50,
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWithTap(
                          user.getFullName ?? "Unknown User",
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        SizedBox(height: 3),
                        TextWithTap(
                          "@${user.getUsername ?? user.objectId}",
                          fontSize: 12,
                          color: Colors.grey[400]!,
                        ),
                      ],
                    ),
                  ),
                  ContainerCorner(
                    color: kPrimaryColor,
                    borderRadius: 20,
                    width: 80,
                    height: 32,
                    child: TextWithTap(
                      "Invite",
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      alignment: Alignment.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
      listLoadingElement: Center(
        child: CircularProgressIndicator(color: kPrimaryColor),
      ),
      queryEmptyElement: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            TextWithTap(
              isFollowers ? "No followers found" : "No following found",
              color: Colors.grey,
              fontSize: 16,
            ),
          ],
        ),
      ),
    );
  }
}

void showInviteFriendsSheet({
  required BuildContext context,
  required UserModel currentUser,
  required int seatIndex,
  required Function(UserModel user, int seatIndex) onUserSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    isDismissible: true,
    isScrollControlled: true,
    builder: (context) {
      return InviteFriendsSheet(
        currentUser: currentUser,
        seatIndex: seatIndex,
        onUserSelected: onUserSelected,
      );
    },
  );
}
