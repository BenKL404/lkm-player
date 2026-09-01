/// Fournisseur d'origine d'un résultat de recherche en ligne.
enum ResultSource { deezer, youtube, soundcloud }

/// Résultat de recherche unifié (Deezer / YouTube / SoundCloud) depuis
/// l'API LKM Player (`GET /api/v1/search`). Le nom de la classe est
/// conservé pour limiter l'impact sur le code existant, mais elle couvre
/// maintenant les 3 sources.
class DeezerSearchResult {
  const DeezerSearchResult({
    required this.id,
    required this.idType,
    required this.title,
    required this.artist,
    this.album,
    /// ID album Deezer (quand connu) — pour regrouper les pistes téléchargées à la pièce.
    this.deezerAlbumId,
    this.imgUrl,
    this.previewUrl,
    this.sourceUrl,
    this.durationSeconds,
  });

  final String id;
  final String idType; // 'track' | 'album' | 'youtube' | 'soundcloud'
  final String title;
  final String artist;
  final String? album;
  final String? deezerAlbumId;
  final String? imgUrl;
  final String? previewUrl;

  /// URL d'origine (YouTube/SoundCloud) — requise pour streamer/télécharger
  /// ces deux sources, l'API n'utilisant pas de simple ID numérique pour elles.
  final String? sourceUrl;

  /// Durée en secondes, quand connue (YouTube/SoundCloud ; absente pour Deezer).
  final int? durationSeconds;

  factory DeezerSearchResult.fromJson(Map<String, dynamic> json) {
    final idType = json['id_type'] as String? ?? 'track';
    // Pour les albums, l'API Deezer met le nom dans "album", pas "title".
    final titleValue = idType == 'album'
        ? (json['album'] as String? ?? json['title'] as String? ?? '')
        : (json['title'] as String? ?? json['album'] as String? ?? '');
    final rawAlbumId = json['album_id'];
    final parsedAlbumId = rawAlbumId == null
        ? null
        : (rawAlbumId is int ? rawAlbumId.toString() : rawAlbumId as String?);
    final normalizedAlbumId =
        (parsedAlbumId != null && parsedAlbumId.isNotEmpty) ? parsedAlbumId : null;
    return DeezerSearchResult(
      id: json['id']?.toString() ?? '',
      idType: idType,
      title: titleValue,
      artist: json['artist'] as String? ?? 'Artiste inconnu',
      album: json['album'] as String?,
      deezerAlbumId: normalizedAlbumId,
      imgUrl: (json['img_url'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['img_url'] as String?,
      previewUrl: json['preview_url'] as String?,
      sourceUrl: json['url'] as String?,
      durationSeconds: (json['duration'] as num?)?.toInt(),
    );
  }

  ResultSource get source => switch (idType) {
        'youtube' => ResultSource.youtube,
        'soundcloud' => ResultSource.soundcloud,
        _ => ResultSource.deezer,
      };

  bool get isTrack => idType == 'track';
  bool get isAlbum => idType == 'album';
  bool get isDeezer => source == ResultSource.deezer;

  /// Titre affiché : pour un album c'est le nom de l'album, pour un track c'est le titre du morceau.
  String get displayTitle => title.trim().isEmpty ? (album ?? 'Sans titre') : title;

  String get sourceLabel => switch (source) {
        ResultSource.deezer => 'Deezer',
        ResultSource.youtube => 'YouTube',
        ResultSource.soundcloud => 'SoundCloud',
      };
}
