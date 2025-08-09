import 'package:parse_server_sdk/parse_server_sdk.dart';

/// Extensão para adicionar funcionalidades extras aos arquivos ParseFile
extension ParseFileExtensions on ParseFileBase {
  /// Obtém a duração do vídeo a partir de metadados armazenados
  Duration? get duration {
    // Verificar se existem metadados associados ao arquivo
    final Map<String, dynamic>? metadata =
        this.get<Map<String, dynamic>>('metadata');
    if (metadata != null && metadata.containsKey('duration')) {
      final seconds = metadata['duration'] ?? 0;
      return Duration(
          seconds:
              seconds is int ? seconds : int.tryParse(seconds.toString()) ?? 0);
    }
    return null;
  }

  /// Obtém a URL da miniatura do vídeo
  String? get thumbnailUrl {
    // Verificar se existem metadados associados ao arquivo
    final Map<String, dynamic>? metadata =
        this.get<Map<String, dynamic>>('metadata');
    if (metadata != null && metadata.containsKey('thumbnailUrl')) {
      return metadata['thumbnailUrl'];
    }

    // Alternativa: se não houver metadata, tentar usar a URL do vídeo com um timestmap
    if (url != null) {
      return '$url?thumbnail=true';
    }

    return null;
  }
}
