import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musio/features/music/data/models/song_model.dart';
import 'package:musio/features/player/presentation/providers/audio_player_provider.dart';
import 'package:musio/shared/widgets/album_art_image.dart';

class SongCard extends ConsumerWidget {
  final SongModel song;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? subtitleWidget;

  const SongCard({
    required this.song,
    required this.onTap,
    super.key,
    this.subtitle,
    this.subtitleWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final playerState = ref.watch(audioPlayerProvider);
    final isCurrentSong = playerState.currentSong?.id == song.id;
    final isPlaying = isCurrentSong && playerState.isPlaying;

    return GestureDetector(
      onTap: () {
        if (isCurrentSong) {
          if (isPlaying) {
            ref.read(audioPlayerProvider.notifier).pause();
          } else {
            ref.read(audioPlayerProvider.notifier).resume();
          }
        } else {
          onTap();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    boxShadow: isCurrentSong
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.15),
                              blurRadius: 15,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: AlbumArtImage(
                      albumArtPath: song.albumArtPath,
                      songId: song.id,
                      size: double.infinity,
                      borderRadius: BorderRadius.zero,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (isCurrentSong)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: isPlaying
                              ? _EqualizerBars(color: scheme.primaryContainer)
                              : Icon(
                                  Icons.play_arrow_rounded,
                                  color: scheme.primaryContainer,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isCurrentSong ? scheme.primaryContainer : scheme.onSurface,
                ),
          ),
          const SizedBox(height: 2),
          if (subtitleWidget != null)
            subtitleWidget!
          else
            Text(
              subtitle ?? song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}

/// Petites barres animées façon égaliseur (piste en cours de lecture).
class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars({required this.color});

  final Color color;

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        Widget bar(double phase, double minH, double maxH) {
          final h = minH +
              (maxH - minH) * (0.5 + 0.5 * (1 - ((t + phase) % 1.0 - 0.5).abs() * 2));
          return Container(
            width: 3,
            height: h,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            bar(0.0, 4, 14),
            const SizedBox(width: 3),
            bar(0.3, 4, 16),
            const SizedBox(width: 3),
            bar(0.6, 4, 12),
          ],
        );
      },
    );
  }
}
