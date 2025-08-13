// ignore_for_file: unused_element

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math';

/// Classe para armazenar informações de cache de vídeo
class VideoMetadata {
  final String videoId;
  final String videoUrl;
  final String localPath;
  final DateTime cachedAt;
  final int fileSize;
  final Map<String, dynamic> metadata;

  VideoMetadata({
    required this.videoId,
    required this.videoUrl,
    required this.localPath,
    required this.cachedAt,
    required this.fileSize,
    required this.metadata,
  });
}

/// Gerenciador de cache de vídeos otimizado para reprodução suave
/// Implementa sistema de LRU cache, download paralelo e gerenciamento de armazenamento
class VideoCacheManager {
  static final VideoCacheManager _instance = VideoCacheManager._internal();
  factory VideoCacheManager() => _instance;

  VideoCacheManager._internal();

  // Diretório de cache
  late Directory _cacheDir;

  // Tamanho máximo do cache (200MB) - REDUCED from 500MB - saves 300MB
  static const int _maxCacheSize = 200 * 1024 * 1024;

  // Estado de inicialização
  bool _initialized = false;
  bool get isCacheInitialized => _initialized;

  // Cache de caminhos de arquivos (para evitar operações de I/O desnecessárias)
  final Map<String, String> _pathCache = {};

  // Lista de vídeos em cache ordenada por último acesso (LRU)
  final List<String> _lruList = [];

  // Map para controlar downloads ativos e evitar duplicações
  final Map<String, Completer<String>> _activeDownloads = {};

  // Estatísticas de cache
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _totalDownloaded = 0;

  /// Inicializa o gerenciador de cache
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Obter diretório para cache
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/video_cache');

      // Criar diretório se não existir
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }

      // Carregar informações dos arquivos em cache
      await _loadCacheInfo();

      // Limpar cache antigo se necessário
      await _cleanupOldCache();

      _initialized = true;
      print('VideoCacheManager: Cache inicializado em ${_cacheDir.path}');
      print(
          'VideoCacheManager: ${_lruList.length} vídeos em cache (${await _getCacheSize() ~/ 1024 ~/ 1024}MB)');
    } catch (e) {
      print('VideoCacheManager: Erro ao inicializar cache: $e');
    }
  }

  /// Carrega informações sobre os arquivos em cache
  Future<void> _loadCacheInfo() async {
    try {
      final files = await _cacheDir.list().toList();

      for (var file in files) {
        if (file is File) {
          // Extrair ID do vídeo do nome do arquivo
          final fileName = file.path.split('/').last;
          final videoId = fileName.split('.').first;

          // Adicionar ao cache de caminhos
          _pathCache[videoId] = file.path;

          // Adicionar à lista LRU
          if (!_lruList.contains(videoId)) {
            _lruList.add(videoId);
          }
        }
      }
    } catch (e) {
      print('VideoCacheManager: Erro ao carregar informações de cache: $e');
    }
  }

  /// Limpa cache antigo para manter tamanho sob controle
  Future<void> _cleanupOldCache() async {
    try {
      final currentSize = await _getCacheSize();

      // Se o tamanho atual for menor que o limite, não fazer nada
      if (currentSize < _maxCacheSize) {
        return;
      }

      print(
          'VideoCacheManager: Cache excede o limite (${currentSize ~/ 1024 ~/ 1024}MB), limpando...');

      // Ordenar pela ordem LRU (os mais antigos primeiro)
      final List<String> videosToRemove = List.from(_lruList.reversed);

      // Remover arquivos até ficar abaixo do limite ou até sobrar apenas 10% dos vídeos
      int removed = 0;
      int bytesFreed = 0;
      final minVideosToKeep = (_lruList.length * 0.1).ceil();

      for (var videoId in videosToRemove) {
        // Não remover se já estamos abaixo do limite e temos poucos vídeos
        if (currentSize - bytesFreed < _maxCacheSize * 0.8 &&
            _lruList.length - removed <= minVideosToKeep) {
          break;
        }

        // Obter caminho do arquivo
        final path = _pathCache[videoId];
        if (path != null) {
          final file = File(path);

          // Verificar se o arquivo existe
          if (await file.exists()) {
            // Obter tamanho do arquivo
            final fileSize = await file.length();

            // Remover arquivo
            await file.delete();
            bytesFreed += fileSize;
            removed++;

            // Remover do cache
            _pathCache.remove(videoId);
            _lruList.remove(videoId);
          }
        }
      }

      print(
          'VideoCacheManager: Removidos $removed vídeos (${bytesFreed ~/ 1024 ~/ 1024}MB)');
    } catch (e) {
      print('VideoCacheManager: Erro ao limpar cache antigo: $e');
    }
  }

  /// Calcula o tamanho total do cache
  Future<int> _getCacheSize() async {
    int totalSize = 0;

    try {
      final files = await _cacheDir.list().toList();

      for (var file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
    } catch (e) {
      print('VideoCacheManager: Erro ao calcular tamanho do cache: $e');
    }

    return totalSize;
  }

  /// Gera ID único para URL do vídeo
  String _generateIdForUrl(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Retorna o caminho do vídeo em cache, baixando-o se necessário
  Future<String?> getCachedVideoPath(String videoId, String videoUrl,
      {bool forceDownload = false, bool priority = false}) async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (e) {
        print('VideoCacheManager: Falha ao inicializar cache: $e');
        return null;
      }
    }

    // Gerar ID baseado na URL se o ID fornecido for muito curto (provavelmente não é um hash)
    final String effectiveVideoId =
        videoId.length < 10 ? _generateIdForUrl(videoUrl) : videoId;

    // Verificar se já existe no cache
    if (!forceDownload && _pathCache.containsKey(effectiveVideoId)) {
      final path = _pathCache[effectiveVideoId]!;
      final file = File(path);

      // Verificar se o arquivo existe
      if (await file.exists()) {
        // Atualizar posição na lista LRU
        _lruList.remove(effectiveVideoId);
        _lruList.add(effectiveVideoId);

        _cacheHits++;
        print(
            'VideoCacheManager: Cache hit para $effectiveVideoId (acertos: $_cacheHits, falhas: $_cacheMisses)');
        return path;
      } else {
        // Arquivo não existe mais, remover do cache
        _pathCache.remove(effectiveVideoId);
        _lruList.remove(effectiveVideoId);
      }
    }

    _cacheMisses++;

    // Verificar se já existe um download ativo para este vídeo
    if (_activeDownloads.containsKey(effectiveVideoId)) {
      print(
          'VideoCacheManager: Download já em andamento para $effectiveVideoId, aguardando...');
      try {
        // Esperar download finalizar
        return await _activeDownloads[effectiveVideoId]!
            .future
            .timeout(Duration(seconds: 30), onTimeout: () {
          _activeDownloads.remove(effectiveVideoId);
          throw TimeoutException('Timeout ao aguardar download do vídeo');
        });
      } catch (e) {
        print('VideoCacheManager: Erro ao aguardar download: $e');
        return null;
      }
    }

    // Iniciar novo download
    return await _downloadVideo(effectiveVideoId, videoUrl, priority: priority);
  }

  /// Baixa o vídeo e armazena em cache
  Future<String?> _downloadVideo(String videoId, String videoUrl,
      {bool priority = false}) async {
    if (_activeDownloads.containsKey(videoId)) {
      return await _activeDownloads[videoId]!.future;
    }

    final completer = Completer<String>();
    _activeDownloads[videoId] = completer;

    try {
      print('VideoCacheManager: Iniciando download de $videoId');

      // Caminho para o arquivo no cache
      final filePath = '${_cacheDir.path}/$videoId.mp4';
      final file = File(filePath);

      // Verificar espaço antes de baixar
      await _ensureSpaceAvailable();

      // Baixar o vídeo
      final httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(videoUrl));
      final response = await httpClient.send(request);

      // Verificar se a requisição foi bem sucedida
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final fileStream = file.openWrite();
        int bytesDownloaded = 0;

        // Mostrar progresso a cada 5% ou a cada 500KB
        final reportInterval = (response.contentLength ?? 1000000) ~/ 20;
        final minReportBytes = 500 * 1024;
        int lastReportedBytes = 0;

        await response.stream.listen((List<int> chunk) {
          fileStream.add(chunk);
          bytesDownloaded += chunk.length;

          // Reportar progresso periodicamente
          if (bytesDownloaded - lastReportedBytes > reportInterval ||
              bytesDownloaded - lastReportedBytes > minReportBytes) {
            final progress = response.contentLength != null
                ? (bytesDownloaded / response.contentLength! * 100)
                    .toStringAsFixed(1)
                : 'desconhecido';
            print(
                'VideoCacheManager: Download de $videoId - $progress% (${bytesDownloaded ~/ 1024}KB)');
            lastReportedBytes = bytesDownloaded;
          }
        }).asFuture<void>();

        await fileStream.flush();
        await fileStream.close();
        httpClient.close();

        // Adicionar ao cache
        _pathCache[videoId] = filePath;
        _lruList.remove(videoId);
        _lruList.add(videoId);

        // Atualizar estatísticas
        _totalDownloaded += bytesDownloaded;

        print(
            'VideoCacheManager: Download concluído para $videoId (${bytesDownloaded ~/ 1024}KB)');

        completer.complete(filePath);
        _activeDownloads.remove(videoId);
        return filePath;
      } else {
        print(
            'VideoCacheManager: Falha ao baixar vídeo $videoId - HTTP ${response.statusCode}');

        completer.completeError('HTTP Error: ${response.statusCode}');
        _activeDownloads.remove(videoId);
        return null;
      }
    } catch (e) {
      print('VideoCacheManager: Erro ao baixar vídeo $videoId: $e');

      if (!completer.isCompleted) {
        completer.completeError(e);
      }

      _activeDownloads.remove(videoId);
      return null;
    }
  }

  /// Garante que há espaço disponível no cache
  Future<void> _ensureSpaceAvailable() async {
    try {
      final currentSize = await _getCacheSize();

      // Se já estamos perto do limite, limpar cache antigo
      if (currentSize > _maxCacheSize * 0.9) {
        await _cleanupOldCache();
      }
    } catch (e) {
      print('VideoCacheManager: Erro ao verificar espaço disponível: $e');
    }
  }

  /// Limpa todo o cache
  Future<void> clearCache() async {
    try {
      // Cancela downloads ativos
      _activeDownloads.forEach((id, completer) {
        if (!completer.isCompleted) {
          completer.completeError('Cache limpo durante download');
        }
      });
      _activeDownloads.clear();

      // Exclui arquivos
      final files = await _cacheDir.list().toList();
      for (var file in files) {
        if (file is File) {
          await file.delete();
        }
      }

      // Limpa cache em memória
      _pathCache.clear();
      _lruList.clear();

      print('VideoCacheManager: Cache limpo completamente');
    } catch (e) {
      print('VideoCacheManager: Erro ao limpar cache: $e');
    }
  }

  /// Verifica se um vídeo está em cache
  Future<bool> isVideoCached(String videoUrl) async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (e) {
        return false;
      }
    }

    final String videoId = _generateIdForUrl(videoUrl);

    // Verificar se está no cache de caminhos
    if (_pathCache.containsKey(videoId)) {
      final path = _pathCache[videoId]!;
      final file = File(path);

      // Verificar se o arquivo realmente existe
      return await file.exists();
    }

    return false;
  }

  /// Cancela download de um vídeo específico
  Future<void> cancelDownload(String videoId) async {
    if (_activeDownloads.containsKey(videoId)) {
      if (!_activeDownloads[videoId]!.isCompleted) {
        _activeDownloads[videoId]!.completeError('Download cancelado');
      }
      _activeDownloads.remove(videoId);
      print('VideoCacheManager: Download cancelado para $videoId');
    }
  }

  /// Pré-carrega múltiplos vídeos em segundo plano para melhorar a experiência
  Future<void> preloadVideos(
    List<Map<String, String>> videosList, {
    int maxConcurrent = 2,
    bool priority = false,
  }) async {
    // Evitar downloads duplicados e múltiplas chamadas simultâneas
    if (videosList.isEmpty) return;

    // Número máximo de downloads concorrentes (default: 2)
    int activeDownloads = 0;
    int completedDownloads = 0;
    final Set<String> queued = {}; // Usar um Set para evitar duplicações

    try {
      print('VideoCacheManager: Pré-carregando ${videosList.length} vídeos');

      // Filtrar vídeos já em cache ou já em download
      final List<Map<String, String>> filteredVideos = [];
      for (var video in videosList) {
        final String videoId =
            video['id'] ?? _generateIdForUrl(video['url'] ?? '');
        final String videoUrl = video['url'] ?? '';

        // Pular se ID ou URL estiverem vazios
        if (videoId.isEmpty || videoUrl.isEmpty) continue;

        // Pular se já está em cache
        if (_pathCache.containsKey(videoId)) {
          final path = _pathCache[videoId]!;
          final file = File(path);
          if (await file.exists()) {
            print('VideoCacheManager: Vídeo $videoId já em cache, pulando');
            continue;
          }
        }

        // Pular se já está em download ativo (evita duplicações)
        if (_activeDownloads.containsKey(videoId)) {
          print(
              'VideoCacheManager: Vídeo $videoId já está sendo baixado, pulando');
          continue;
        }

        // Pular se já está na lista de vídeos a baixar
        if (queued.contains(videoId)) {
          print('VideoCacheManager: Vídeo $videoId já está na fila, pulando');
          continue;
        }

        // Adicionar à lista filtrada e marcar como enfileirado
        filteredVideos.add(video);
        queued.add(videoId);
      }

      // Se todos os vídeos já estão em cache ou download, não fazer nada
      if (filteredVideos.isEmpty) {
        print(
            'VideoCacheManager: Todos os vídeos já estão em cache ou download, nada a fazer');
        return;
      }

      // Iniciar downloads limitados pela capacidade de concorrência
      for (var i = 0; i < min(maxConcurrent, filteredVideos.length); i++) {
        _startPreloadDownload(
          filteredVideos[i]['id'] ??
              _generateIdForUrl(filteredVideos[i]['url'] ?? ''),
          filteredVideos[i]['url'] ?? '',
          priority,
        );
        activeDownloads++;
      }

      // Iniciar novos downloads à medida que os anteriores são concluídos
      while (completedDownloads < filteredVideos.length) {
        await Future.delayed(Duration(milliseconds: 500));

        // Verificar quantos downloads ativos ainda existem
        final remainingActive = min(activeDownloads, maxConcurrent);

        // Quantos novos downloads podemos iniciar
        final slotsAvailable = maxConcurrent - remainingActive;

        // Verificar quantos downloads já foram concluídos
        for (var i = 0; i < filteredVideos.length; i++) {
          final videoId = filteredVideos[i]['id'] ??
              _generateIdForUrl(filteredVideos[i]['url'] ?? '');

          // Verificar se o download já foi concluído
          if (!_activeDownloads.containsKey(videoId) &&
              queued.contains(videoId)) {
            completedDownloads++;
            queued.remove(videoId);
          }
        }

        // Iniciar novos downloads se houver slots disponíveis
        for (var i = 0; i < slotsAvailable; i++) {
          final nextIndex = completedDownloads + activeDownloads;
          if (nextIndex < filteredVideos.length) {
            _startPreloadDownload(
              filteredVideos[nextIndex]['id'] ??
                  _generateIdForUrl(filteredVideos[nextIndex]['url'] ?? ''),
              filteredVideos[nextIndex]['url'] ?? '',
              priority,
            );
            activeDownloads++;
          }
        }

        // Se todos os downloads foram iniciados, sair do loop
        if (completedDownloads + activeDownloads >= filteredVideos.length) {
          break;
        }
      }
    } catch (e) {
      print('VideoCacheManager: Erro ao pré-carregar vídeos: $e');
    }
  }

  /// Inicia download individual para pré-carregamento
  Future<void> _startPreloadDownload(
    String videoId,
    String videoUrl,
    bool priority,
  ) async {
    if (videoId.isEmpty || videoUrl.isEmpty) return;

    // Verificar se já está em download
    if (_activeDownloads.containsKey(videoId)) {
      print('VideoCacheManager: Download já em andamento para $videoId');
      return;
    }

    // Verificar se já está em cache
    if (_pathCache.containsKey(videoId)) {
      final path = _pathCache[videoId]!;
      final file = File(path);
      if (await file.exists()) {
        print('VideoCacheManager: Vídeo $videoId já em cache');
        return;
      }
    }

    try {
      print('VideoCacheManager: Iniciando pré-carregamento de $videoId');
      _downloadVideo(videoId, videoUrl, priority: priority);
    } catch (e) {
      print(
          'VideoCacheManager: Erro ao iniciar pré-carregamento de $videoId: $e');
    }
  }

  /// Obter estatísticas do cache
  

  /// Baixa um vídeo em segundo plano e retorna imediatamente
  /// Útil para pré-carregar vídeos sem bloquear a UI
  Future<void> downloadVideo(String videoUrl, {int priority = 5}) async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (e) {
        print('VideoCacheManager: Falha ao inicializar cache: $e');
        return;
      }
    }

    final String videoId = _generateIdForUrl(videoUrl);

    // Verificações preliminares para evitar duplicação
    // 1. Verificar se já está em cache
    if (_pathCache.containsKey(videoId)) {
      try {
        final path = _pathCache[videoId]!;
        final file = File(path);

        // Verificar se o arquivo realmente existe
        if (await file.exists()) {
          // Já em cache, apenas atualizar LRU e sair
          _lruList.remove(videoId);
          _lruList.add(videoId);
          print('VideoCacheManager: Vídeo $videoId já em cache');
          return;
        }
      } catch (e) {
        print('VideoCacheManager: Erro verificando arquivo em cache: $e');
        // Continuar com o download como fallback
      }
    }

    // 2. Verificar se já existe um download ativo para este vídeo
    if (_activeDownloads.containsKey(videoId)) {
      print('VideoCacheManager: Download já em andamento para $videoId');
      return;
    }

    // Agora é seguro iniciar um novo download
    print('VideoCacheManager: Iniciando download em segundo plano de $videoId');

    // Criamos um Completer para controlar o download
    final completer = Completer<String>();
    _activeDownloads[videoId] = completer;

    // Executar o download em isolamento para evitar loop de recursão
    () async {
      try {
        print('VideoCacheManager: Processando download de $videoId');

        // Caminho para o arquivo no cache
        final filePath = '${_cacheDir.path}/$videoId.mp4';
        final file = File(filePath);

        // Verificar espaço disponível
        await _ensureSpaceAvailable();

        // Iniciar download HTTP
        final httpClient = http.Client();
        final request = http.Request('GET', Uri.parse(videoUrl));
        final response = await httpClient.send(request);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Erro HTTP: ${response.statusCode}');
        }

        // Salvar o arquivo
        final fileStream = file.openWrite();
        int bytesDownloaded = 0;

        await response.stream.listen((chunk) {
          fileStream.add(chunk);
          bytesDownloaded += chunk.length;
        }).asFuture<void>();

        await fileStream.flush();
        await fileStream.close();
        httpClient.close();

        // Registrar no cache
        _pathCache[videoId] = filePath;
        _lruList.remove(videoId);
        _lruList.add(videoId);

        print(
            'VideoCacheManager: Download concluído: $videoId (${bytesDownloaded ~/ 1024}KB)');

        if (!completer.isCompleted) {
          completer.complete(filePath);
        }
      } catch (e) {
        print('VideoCacheManager: Erro no download de $videoId: $e');
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      } finally {
        // Sempre remover da lista de downloads ativos quando terminar
        // Isso é crucial para evitar bloqueios
        _activeDownloads.remove(videoId);
      }
    }();
  }

  /// FIX: Add comprehensive cleanup methods to prevent ImageReader buffer issues
  /// Dispose all active downloads and clear cache
  Future<void> dispose() async {
    try {
      print('VideoCacheManager: Starting disposal process');

      // Cancel all active downloads
      final activeDownloadIds = _activeDownloads.keys.toList();
      for (final videoId in activeDownloadIds) {
        await cancelDownload(videoId);
      }

      // Clear all caches
      _pathCache.clear();
      _lruList.clear();
      _activeDownloads.clear();

      // Reset statistics
      _cacheHits = 0;
      _cacheMisses = 0;
      _totalDownloaded = 0;

      // Mark as uninitialized
      _initialized = false;

      print('VideoCacheManager: Disposal completed successfully');
    } catch (e) {
      print('VideoCacheManager: Error during disposal: $e');
    }
  }

  /// Force clear all cache files and reset
  Future<void> clearAllCache() async {
    try {
      print('VideoCacheManager: Clearing all cache files');

      // Cancel active downloads first
      await dispose();

      // Delete all cache files
      if (await _cacheDir.exists()) {
        final files = await _cacheDir.list().toList();
        for (final file in files) {
          if (file is File) {
            try {
              await file.delete();
            } catch (e) {
              print('VideoCacheManager: Error deleting file ${file.path}: $e');
            }
          }
        }
      }

      print('VideoCacheManager: All cache files cleared');
    } catch (e) {
      print('VideoCacheManager: Error clearing cache: $e');
    }
  }

  /// Get cache statistics for monitoring
  Map<String, dynamic> getCacheStats() {
    return {
      'initialized': _initialized,
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'totalDownloaded': _totalDownloaded,
      'cachedVideosCount': _pathCache.length,
      'activeDownloads': _activeDownloads.length,
    };
  }
}

class _DownloadRequest {
  final String videoId;
  final String videoUrl;
  final Completer<String?> completer;

  _DownloadRequest({
    required this.videoId,
    required this.videoUrl,
    required this.completer,
  });
}

// Adicionar classe Semaphore para controlar downloads paralelos
class Semaphore {
  final int _maxConcurrent;
  int _current = 0;
  final List<Completer<void>> _waiters = [];

  Semaphore(this._maxConcurrent);

  Future<void> acquire() async {
    if (_current < _maxConcurrent) {
      _current++;
      return;
    }

    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void release() {
    _current--;

    if (_waiters.isNotEmpty) {
      final completer = _waiters.removeAt(0);
      _current++;
      completer.complete();
    }
  }
}
