import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:musio/core/routing/app_router.dart';
import 'package:musio/features/player/presentation/providers/audio_player_provider.dart';
import 'package:musio/shared/widgets/album_art_image.dart';

/// Barre de lecture compacte, fidèle à la maquette : pochette, titre (avec
/// icône égaliseur), artiste, lecture/pause + suivant, fine barre de
/// progression en bas de la carte.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final currentSong = playerState.currentSong;
    final scheme = Theme.of(context).colorScheme;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final radius = BorderRadius.circular(18);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Material(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
            borderRadius: radius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AlbumArtImage(
                        albumArtPath: currentSong.albumArtPath,
                        songId: currentSong.id,
                        size: 48,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.push(AppRouter.nowPlaying),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.graphic_eq_rounded,
                                        size: 14, color: scheme.primaryContainer),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        currentSong.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentSong.artist.isEmpty
                                      ? 'Artiste inconnu'
                                      : currentSong.artist,
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
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: scheme.primaryContainer,
                      ),
                      onPressed: () {
                        if (playerState.isPlaying) {
                          ref.read(audioPlayerProvider.notifier).pause();
                        } else {
                          ref.read(audioPlayerProvider.notifier).resume();
                        }
                      },
                      tooltip: playerState.isPlaying ? 'Pause' : 'Lecture',
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next_rounded, color: scheme.onSurface),
                      onPressed: () => ref.read(audioPlayerProvider.notifier).next(),
                      tooltip: 'Suivant',
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: playerState.duration.inMilliseconds > 0
                    ? playerState.position.inMilliseconds /
                        playerState.duration.inMilliseconds
                    : 0,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primaryContainer),
                minHeight: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
