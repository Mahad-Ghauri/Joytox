// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import '../controllers/video_editor_controller.dart';

class VideoRecorderScreen extends StatelessWidget {
  final VideoEditorController controller = Get.put(VideoEditorController());

  VideoRecorderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview
            Obx(() {
              if (!controller.isCameraPermissionGranted.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        controller.errorMessage.value,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => controller.initializeCamera(),
                        child: const Text('Conceder Permissão'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (!controller.isCameraInitialized.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (controller.errorMessage.value.isNotEmpty) {
                return Center(
                  child: Text(
                    controller.errorMessage.value,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Center(
                child: CameraPreview(controller.cameraController.value!),
              );
            }),

            // Controls Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Timer Display
                    Obx(() {
                      if (controller.isRecording.value) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            controller.formattedRemainingTime,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),

                    // Duration Selection
                    Obx(() => Visibility(
                          visible: !controller.isRecording.value,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: controller.availableDurations
                                  .map((duration) => Obx(() {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: ChoiceChip(
                                            label: Text('${duration}s'),
                                            selected: controller
                                                    .selectedDuration.value ==
                                                duration,
                                            onSelected: (selected) {
                                              if (selected) {
                                                controller.setRecordingDuration(
                                                    duration);
                                              }
                                            },
                                            selectedColor: Colors.white,
                                            backgroundColor: Colors.grey[800],
                                            labelStyle: TextStyle(
                                              color: controller.selectedDuration
                                                          .value ==
                                                      duration
                                                  ? Colors.black
                                                  : Colors.white,
                                            ),
                                          ),
                                        );
                                      }))
                                  .toList(),
                            ),
                          ),
                        )),
                    const SizedBox(height: 20),
                    // Record Button
                    Obx(() {
                      return GestureDetector(
                        onTap: controller.isCameraInitialized.value
                            ? () {
                                if (controller.isRecording.value) {
                                  controller.stopRecording().then((videoPath) {
                                    if (videoPath != null) {
                                      Get.toNamed('/video-editor',
                                          arguments: videoPath);
                                    }
                                  });
                                } else {
                                  controller.startRecording();
                                }
                              }
                            : null,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: controller.isCameraInitialized.value
                                  ? Colors.white
                                  : Colors.grey,
                              width: 4,
                            ),
                            color: controller.isRecording.value
                                ? Colors.red
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: controller.isRecording.value
                                    ? Colors.red
                                    : (controller.isCameraInitialized.value
                                        ? Colors.white
                                        : Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios,
                          color: Colors.white),
                      onPressed: controller.isCameraInitialized.value
                          ? () => controller.flipCamera()
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
