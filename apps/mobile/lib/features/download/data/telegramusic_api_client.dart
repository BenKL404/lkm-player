import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'download_cancel_token.dart';
import 'models/deezer_search_result.dart';

/// Résultats d'une recherche unifiée multi-sources.
class UnifiedSearchResults {
  const UnifiedSearchResults({
    this.deezerTracks = const [],
    this.deezerAlbums = const [],
    this.youtube = const [],
    this.soundcloud = const [],
  });

  final List<DeezerSearchResult> deezerTracks;
  final List<DeezerSearchResult> deezerAlbums;
  final List<DeezerSearchResult> youtube;
  final List<DeezerSearchResult> soundcloud;

  /// Tous les résultats "piste" toutes sources confondues (hors albums Deezer).
  List<DeezerSearchResult> get allTracks => [
        ...deezerTracks,
        ...youtube,
        ...soundcloud,
      ];

  bool get isEmpty =>
      deezerTracks.isEmpty &&
      deezerAlbums.isEmpty &&
      youtube.isEmpty &&
      soundcloud.isEmpty;
}

/// Client HTTP pour l'API LKM Player (recherche unifiée, streaming, téléchargement).
class TelegramusicApiClient {
  TelegramusicApiClient({required String baseUrl, this.apiKey = ''})
      : baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;

  /// Clé API (X-API-Key), optionnelle — vide si le serveur n'en exige pas.
  final String apiKey;

  static const Duration _timeout = Duration(seconds: 30);

  bool get isConfigured => baseUrl.isNotEmpty;

  Map<String, String> get _authHeaders =>
      apiKey.isEmpty ? const {} : {'X-API-Key': apiKey};

  Uri _uri(String path, [Map<String, String>? queryParams]) {
    final u = '$baseUrl$path';
    final params = <String, String>{...?queryParams};
    if (apiKey.isNotEmpty) params['api_key'] = apiKey;
    if (params.isEmpty) return Uri.parse(u);
    return Uri.parse(u).replace(queryParameters: params);
  }

  /// GET /api/v1/search — recherche unifiée Deezer / YouTube / SoundCloud.
  Future<UnifiedSearchResults> unifiedSearch(
    String query, {
    String provider = 'all',
    int limit = 20,
  }) async {
    if (!isConfigured) throw Exception('API non configurée');
    try {
      final response = await http
          .get(
            _uri('/api/v1/search', {
              'q': query,
              'provider': provider,
              'limit': '$limit',
            }),
            headers: {'Accept': 'application/json', ..._authHeaders},
          )
          .timeout(_timeout);
      if (response.statusCode == 403) {
        throw Exception('Clé API invalide ou manquante');
      }
      if (response.statusCode != 200) {
        throw Exception('Recherche échouée: ${response.statusCode}');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      final deezer = json['deezer'] as Map<String, dynamic>?;
      List<DeezerSearchResult> parse(dynamic raw) => (raw as List<dynamic>? ?? [])
          .map((e) => DeezerSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
      return UnifiedSearchResults(
        deezerTracks: parse(deezer?['tracks']),
        deezerAlbums: parse(deezer?['albums']),
        youtube: parse(json['youtube']),
        soundcloud: parse(json['soundcloud']),
      );
    } on SocketException {
      // Ne jamais inclure l'URL configurée dans un message affiché à l'écran.
      throw Exception('Serveur injoignable. Vérifiez la configuration dans Paramètres et la connexion internet du téléphone.');
    } on TimeoutException {
      throw Exception('Délai dépassé. Le serveur ne répond pas.');
    }
  }

  /// Liste des résultats de recherche Deezer seuls (tracks ou albums) —
  /// conservé pour compat, utilise désormais la route v1.
  Future<List<DeezerSearchResult>> searchResults(String query, {String type = 'track'}) async {
    final results = await unifiedSearch(query, provider: 'deezer');
    return type == 'album' ? results.deezerAlbums : results.deezerTracks;
  }

  /// URL de streaming direct (lecture sans téléchargement), pour AudioSource.uri.
  /// La clé API est passée en query param (`?api_key=`), plus fiable que les
  /// en-têtes HTTP personnalisés selon les lecteurs audio de la plateforme.
  String streamUrl(DeezerSearchResult result, {String format = 'MP3_128'}) {
    switch (result.source) {
      case ResultSource.deezer:
        return _uri('/api/v1/deezer/track/${result.id}/stream', {'format': format}).toString();
      case ResultSource.youtube:
        return _uri('/api/v1/youtube/${result.id}/stream').toString();
      case ResultSource.soundcloud:
        return _uri('/api/v1/soundcloud/stream', {'url': result.sourceUrl ?? ''}).toString();
    }
  }

  /// GET /api/v1/deezer/track/{id}/download → bytes du fichier audio.
  /// [onProgress] appelé avec (bytes reçus, total ou null si inconnu).
  Future<List<int>> downloadTrack(
    String trackId, {
    void Function(int received, int? total)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    return _downloadBytes(
      _uri('/api/v1/deezer/track/$trackId/download'),
      timeout: const Duration(minutes: 2),
      onProgress: onProgress,
      cancelToken: cancelToken,
      failureLabel: 'Téléchargement échoué',
    );
  }

  /// GET /api/v1/youtube/{id}/download → bytes du fichier audio.
  Future<List<int>> downloadYoutube(
    String videoId, {
    void Function(int received, int? total)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    return _downloadBytes(
      _uri('/api/v1/youtube/$videoId/download'),
      timeout: const Duration(minutes: 3),
      onProgress: onProgress,
      cancelToken: cancelToken,
      failureLabel: 'Téléchargement YouTube échoué',
    );
  }

  /// GET /api/v1/soundcloud/download?url=... → bytes du fichier audio.
  Future<List<int>> downloadSoundcloud(
    String trackUrl, {
    void Function(int received, int? total)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    return _downloadBytes(
      _uri('/api/v1/soundcloud/download', {'url': trackUrl}),
      timeout: const Duration(minutes: 3),
      onProgress: onProgress,
      cancelToken: cancelToken,
      failureLabel: 'Téléchargement SoundCloud échoué',
    );
  }

  Future<List<int>> _downloadBytes(
    Uri uri, {
    required Duration timeout,
    required String failureLabel,
    void Function(int received, int? total)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    if (!isConfigured) throw Exception('API non configurée');
    final request = http.Request('GET', uri)..headers.addAll(_authHeaders);
    final client = http.Client();
    try {
      final streamed = await client.send(request).timeout(timeout);
      if (streamed.statusCode != 200) {
        throw Exception('$failureLabel: ${streamed.statusCode}');
      }
      final total = streamed.contentLength;
      int received = 0;
      final chunks = <int>[];
      await for (final chunk in streamed.stream) {
        if (cancelToken?.isCancelled == true) {
          throw DownloadCancelledException(cancelToken!.reason ?? DownloadCancelReason.cancel);
        }
        chunks.addAll(chunk);
        received += chunk.length;
        onProgress?.call(received, total != null && total > 0 ? total : null);
      }
      return chunks;
    } finally {
      client.close();
    }
  }

  /// URL de la pochette Deezer (pour Image.network).
  String trackCoverUrl(String trackId) => _uri('/api/v1/deezer/track/$trackId/cover').toString();

  /// GET /api/v1/deezer/album/{id}/download → bytes du ZIP.
  Future<List<int>> downloadAlbum(
    String albumId, {
    void Function(int received, int? total)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    return _downloadBytes(
      _uri('/api/v1/deezer/album/$albumId/download'),
      timeout: const Duration(minutes: 10),
      onProgress: onProgress,
      cancelToken: cancelToken,
      failureLabel: 'Téléchargement album échoué',
    );
  }

  /// URL pochette album (pour affichage).
  String albumCoverUrl(String albumId) => _uri('/api/v1/deezer/album/$albumId/cover').toString();

  /// GET /api/v1/deezer/album/{id}/tracks
  Future<List<DeezerSearchResult>> albumTracks(String albumId) async {
    if (!isConfigured) throw Exception('API non configurée');
    try {
      final response = await http
          .get(
            _uri('/api/v1/deezer/album/$albumId/tracks'),
            headers: {'Accept': 'application/json', ..._authHeaders},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception('Pistes album: ${response.statusCode}');
      }
      final map = jsonDecode(response.body) as Map<String, dynamic>?;
      final raw = map?['tracks'] as List<dynamic>? ?? [];
      return raw
          .map((e) => DeezerSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } on SocketException {
      throw Exception('Serveur injoignable.');
    } on TimeoutException {
      throw Exception('Délai dépassé.');
    }
  }
}
