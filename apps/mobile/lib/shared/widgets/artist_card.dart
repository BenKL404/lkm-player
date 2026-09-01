import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musio/features/music/data/models/artist_model.dart';

class ArtistCard extends StatelessWidget {
  final ArtistModel artist;
  final VoidCallback? onTap;

  const ArtistCard({
    required this.artist,
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Pas de fond de carte : seul le cercle (pochette ou lettre) doit être visible,
    // aussi large que la carte elle-même.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ?? () => context.push('/artist/${artist.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) =>
                    _ArtistAvatar(artist: artist, size: constraints.maxWidth),
              ),
              const SizedBox(height: 10),
              // Artist name
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              // Artist info
              Text(
                '${artist.albumCount} album${artist.albumCount > 1 ? 's' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pochette d'un album/titre de l'artiste si disponible, sinon la première
/// lettre du nom dans un cercle teinté.
class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({required this.artist, required this.size});

  final ArtistModel artist;
  final double size;

  Widget _letterFallback(ColorScheme scheme) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.33,
          fontWeight: FontWeight.bold,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = artist.imagePath;

    if (path == null || path.isEmpty) {
      return _letterFallback(scheme);
    }

    Widget image;
    if (path.startsWith('content://') || path.startsWith('http')) {
      image = Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _letterFallback(scheme),
      );
    } else {
      final file = File(path);
      if (!file.existsSync()) return _letterFallback(scheme);
      image = Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _letterFallback(scheme),
      );
    }

    return ClipOval(
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}
