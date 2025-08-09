// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../controllers/video_editor_controller.dart';

class VideoEditorScreen extends StatefulWidget {
  final String videoPath;

  const VideoEditorScreen({Key? key, required this.videoPath})
      : super(key: key);

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen>
    with WidgetsBindingObserver {
  final VideoEditorController controller = Get.find<VideoEditorController>();
  late TextEditingController textController;
  late FocusNode textFocusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    textController = TextEditingController();
    textFocusNode = FocusNode();
    _initializeEditor();
  }

  Future<void> _initializeEditor() async {
    try {
      await controller.initializeEditor(widget.videoPath);
    } catch (e) {
      print('Error initializing editor: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    textController.dispose();
    textFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      controller.video?.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (controller.isPlaying.value) {
        controller.video?.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildVideoPreview(),

            // Video Controls Overlay
            Positioned(
              bottom: 150,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Progress Bar
                    Obx(() {
                      final position = controller.videoPosition.value;
                      final duration = controller.videoDuration.value;
                      return SliderTheme(
                        data: SliderThemeData(
                          thumbColor: Colors.white,
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white.withOpacity(0.3),
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          trackHeight: 2,
                        ),
                        child: Slider(
                          value: position.clamp(0, duration),
                          max: duration,
                          onChanged: (value) => controller.seekTo(value),
                        ),
                      );
                    }),

                    // Time and Play/Pause
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Time
                          Obx(() => Text(
                                '${controller.formattedPosition} / ${controller.formattedDuration}',
                                style: const TextStyle(color: Colors.white),
                              )),

                          // Play/Pause Button
                          Obx(() => Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => controller.togglePlayPause(),
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(
                                      controller.isPlaying.value
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Controls
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
                    // Filter Options
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterOption('Normal'),
                          _buildFilterOption('Vintage'),
                          _buildFilterOption('B&W'),
                          _buildFilterOption('Sepia'),
                          _buildFilterOption('Vivid'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.music_note,
                          label: 'Música',
                          onTap: () => controller.addMusic(),
                        ),
                        _buildActionButton(
                          icon: Icons.text_fields,
                          label: 'Texto',
                          onTap: () {
                            _showTextInputDialog();
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.save,
                          label: 'Salvar',
                          onTap: () async {
                            final String? outputPath =
                                await controller.exportVideo();
                            if (outputPath != null) {
                              Get.back(result: outputPath);
                            }
                          },
                        ),
                      ],
                    ),
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
                    Obx(() => Text(
                          controller.exportText.value,
                          style: const TextStyle(color: Colors.white),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Obx(() {
      if (controller.errorMessage.value.isNotEmpty) {
        return Center(
          child: Text(
            controller.errorMessage.value,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        );
      }

      if (controller.video == null || !controller.video!.value.isInitialized) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }

      return Center(
        child: AspectRatio(
          aspectRatio: controller.video!.value.aspectRatio,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(
                _getFilterMatrix(controller.currentFilter.value)),
            child: VideoPlayer(controller.video!),
          ),
        ),
      );
    });
  }

  Widget _buildFilterOption(String name) {
    return Obx(() {
      final bool isSelected =
          controller.currentFilter.value == name.toLowerCase();
      final bool isVideoReady =
          controller.video != null && controller.video!.value.isInitialized;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GestureDetector(
          onTap: isVideoReady
              ? () => controller.setFilter(name.toLowerCase())
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isVideoReady
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: ColorFiltered(
                          colorFilter:
                              ColorFilter.matrix(_getFilterMatrix(name)),
                          child: VideoPlayer(controller.video!),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showTextInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Adicionar Texto',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: textController,
          focusNode: textFocusNode,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Digite seu texto...',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              // Implement text overlay
              Get.back();
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  List<double> _getFilterMatrix(String filterName) {
    switch (filterName.toLowerCase()) {
      case 'vintage':
        return [
          0.9,
          0.5,
          0.1,
          0,
          0,
          0.3,
          0.8,
          0.1,
          0,
          0,
          0.2,
          0.3,
          0.5,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
      case 'b&w':
        return [
          0.33,
          0.33,
          0.33,
          0,
          0,
          0.33,
          0.33,
          0.33,
          0,
          0,
          0.33,
          0.33,
          0.33,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
      case 'sepia':
        return [
          0.393,
          0.769,
          0.189,
          0,
          0,
          0.349,
          0.686,
          0.168,
          0,
          0,
          0.272,
          0.534,
          0.131,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
      case 'vivid':
        return [
          1.3,
          0,
          0,
          0,
          0,
          0,
          1.3,
          0,
          0,
          0,
          0,
          0,
          1.3,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
      default:
        return [
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
    }
  }
}
