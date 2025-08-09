import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'video_recorder_screen.dart';
import 'video_editor_screen.dart';

class VideoCreationPage extends StatelessWidget {
  const VideoCreationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return VideoRecorderScreen();
  }
}

// Adicione as rotas no seu arquivo de rotas ou no GetMaterialApp
final videoRoutes = [
  GetPage(
    name: '/video-creation',
    page: () => const VideoCreationPage(),
  ),
  GetPage(
    name: '/video-editor',
    page: () => VideoEditorScreen(
      videoPath: Get.arguments as String,
    ),
  ),
];
