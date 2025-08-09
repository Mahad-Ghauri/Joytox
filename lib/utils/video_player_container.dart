// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';

/// Widget otimizado para reprodução de vídeo com gerenciamento de recursos e detecção de travamentos
class OptimizedVideoPlayerContainer extends StatefulWidget {
  final CachedVideoPlayerPlusController controller;
  final int index;
  final bool isCurrentPage;
  final VoidCallback? onStall;

  const OptimizedVideoPlayerContainer({
    Key? key,
    required this.controller,
    required this.index,
    required this.isCurrentPage,
    this.onStall,
  }) : super(key: key);

  @override
  _OptimizedVideoPlayerContainerState createState() =>
      _OptimizedVideoPlayerContainerState();
}

class _OptimizedVideoPlayerContainerState
    extends State<OptimizedVideoPlayerContainer> {
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isBuffering = false;
  bool _hasError = false;
  double _aspectRatio = 16 / 9; // Proporção padrão
  DateTime? _lastBufferingTime;
  int _bufferingCount = 0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(OptimizedVideoPlayerContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Se a página atual mudou
    if (widget.isCurrentPage != oldWidget.isCurrentPage) {
      if (widget.isCurrentPage) {
        _playVideo();
      } else {
        _pauseVideo();
      }
    }

    // Se o controlador mudou
    if (widget.controller != oldWidget.controller) {
      _unregisterListeners(oldWidget.controller);
      _initializePlayer();
    }
  }

  void _initializePlayer() {
    // Verificar se o controlador já está inicializado
    final isInitialized = widget.controller.value.isInitialized;
    _isInitialized = isInitialized;
    _hasError = widget.controller.value.hasError;

    if (isInitialized) {
      // Atualizar proporção do vídeo
      _updateAspectRatio();

      // Configurar reprodução inicial
      if (widget.isCurrentPage) {
        _playVideo();
      }
    }

    // Registrar listener para atualizações
    widget.controller.addListener(_onVideoStateChanged);
  }

  void _unregisterListeners(CachedVideoPlayerPlusController controller) {
    try {
      controller.removeListener(_onVideoStateChanged);
    } catch (e) {
      // Ignorar erros de listener
    }
  }

  void _onVideoStateChanged() {
    if (!mounted) return;

    final value = widget.controller.value;
    final wasBuffering = _isBuffering;

    setState(() {
      _isInitialized = value.isInitialized;
      _isPlaying = value.isPlaying;
      _isBuffering = value.isBuffering;
      _hasError = value.hasError;

      // Atualizar proporção se o tamanho do vídeo estiver disponível
      if (value.isInitialized &&
          value.size.width > 0 &&
          value.size.height > 0) {
        _aspectRatio = value.aspectRatio;
      }
    });

    // Detecção de travamentos
    if (!wasBuffering && _isBuffering) {
      _lastBufferingTime = DateTime.now();
    } else if (wasBuffering && !_isBuffering) {
      if (_lastBufferingTime != null) {
        final bufferingDuration =
            DateTime.now().difference(_lastBufferingTime!);

        // Se o buffer demorou mais de 300ms, considerar como travamento
        if (bufferingDuration.inMilliseconds > 300) {
          _bufferingCount++;

          // Reportar travamento após 3 ocorrências
          if (_bufferingCount >= 3 && widget.onStall != null) {
            widget.onStall!();
            _bufferingCount = 0;
          }
        }
      }
    }
  }

  void _updateAspectRatio() {
    if (widget.controller.value.isInitialized) {
      final size = widget.controller.value.size;
      if (size.width > 0 && size.height > 0) {
        setState(() {
          _aspectRatio = size.width / size.height;
        });
      }
    }
  }

  Future<void> _playVideo() async {
    if (!widget.controller.value.isPlaying) {
      try {
        await widget.controller.play();
      } catch (e) {
        print('Erro ao reproduzir vídeo: $e');
      }
    }
  }

  Future<void> _pauseVideo() async {
    if (widget.controller.value.isPlaying) {
      try {
        await widget.controller.pause();
      } catch (e) {
        print('Erro ao pausar vídeo: $e');
      }
    }
  }

  void _togglePlayPause() async {
    if (widget.controller.value.isPlaying) {
      await _pauseVideo();
    } else {
      await _playVideo();
    }
  }

  @override
  void dispose() {
    _unregisterListeners(widget.controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildLoadingPlaceholder();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Vídeo
            AspectRatio(
              aspectRatio: _aspectRatio,
              child: CachedVideoPlayerPlus(widget.controller),
            ),

            // Indicador de buffer
            if (_isBuffering)
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),

            // Botão de play/pause quando pausado
            if (!_isPlaying && !_isBuffering)
              Icon(
                Icons.play_circle_outline,
                color: Colors.white.withOpacity(0.7),
                size: 80,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Erro ao carregar vídeo',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
