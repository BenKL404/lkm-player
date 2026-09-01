import 'dart:io';

import 'package:flutter/material.dart';

/// Widget réutilisable pour afficher les images d'albums
/// Utilise le chemin du fichier ou l'URI MediaStore ; sinon placeholder.
class AlbumArtImage extends StatelessWidget {
  final String? albumArtPath;
  final String songId;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Widget? placeholderIcon;

  const AlbumArtImage({
    required this.songId,
    super.key,
    this.albumArtPath,
    this.size = 48,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(8);

    // URI content:// MediaStore, ou pochette distante (résultats de recherche en ligne).
    if (albumArtPath != null &&
        (albumArtPath!.startsWith('content://') ||
            albumArtPath!.startsWith('http://') ||
            albumArtPath!.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          albumArtPath!,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildPlaceholder(context),
        ),
      );
    }

    // Fichier local (téléchargements Deezer)
    if (albumArtPath != null && File(albumArtPath!).existsSync()) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(albumArtPath!),
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildPlaceholder(context),
        ),
      );
    }

    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: placeholderIcon ??
          Icon(
            Icons.music_note,
            color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.7),
            size: size.isFinite ? size * 0.5 : 48,
          ),
    );
  }
}

/// Widget pour les grandes images (Now Playing, Album Details)
class AlbumArtImageLarge extends StatelessWidget {
  final String? albumArtPath;
  final String songId;
  final double size;
  final String? heroTag;

  const AlbumArtImageLarge({
    required this.songId,
    super.key,
    this.albumArtPath,
    this.size = 300,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    Widget child;

    // Décoder à une résolution proche de l'affichage (pas la résolution native
    // de la pochette, potentiellement bien plus grande) : évite les à-coups
    // pendant les transitions de page (Hero, SliverAppBar).
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (size.isFinite ? size * dpr : 600).round();

    // Utiliser directement la pochette si disponible
    if (albumArtPath != null &&
        (albumArtPath!.startsWith('content://') ||
            albumArtPath!.startsWith('http://') ||
            albumArtPath!.startsWith('https://'))) {
      child = ClipRRect(
        borderRadius: radius,
        child: Image.network(
          albumArtPath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cachePx,
          cacheHeight: cachePx,
        ),
      );
    } else if (albumArtPath != null && File(albumArtPath!).existsSync()) {
      child = ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(albumArtPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cachePx,
          cacheHeight: cachePx,
        ),
      );
    } else {
      // Aucun cover : dégradé "aura" (teal -> secondaire) au lieu d'un fond plat.
      final scheme = Theme.of(context).colorScheme;
      child = ClipRRect(
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerHigh,
                scheme.primaryContainer.withValues(alpha: 0.55),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.music_note,
              size: size * 0.45,
              color: scheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ),
      );
    }

    if (heroTag != null) {
      child = Hero(
        tag: heroTag!,
        child: child,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: child,
    );
  }
}

/// Widget pour les vignettes circulaires (artistes, etc.)
class AlbumArtCircle extends StatelessWidget {
  final String? albumArtPath;
  final String songId;
  final double size;

  const AlbumArtCircle({
    required this.songId,
    super.key,
    this.albumArtPath,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: AlbumArtImage(
        albumArtPath: albumArtPath,
        songId: songId,
        size: size,
        borderRadius: BorderRadius.zero,
        fit: BoxFit.cover,
      ),
    );
  }
}
