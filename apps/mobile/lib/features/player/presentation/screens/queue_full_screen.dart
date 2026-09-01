import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musio/features/music/data/models/song_model.dart';
import 'package:musio/features/player/presentation/providers/audio_player_provider.dart';
import 'package:musio/features/player/presentation/providers/sleep_timer_provider.dart';
import 'package:musio/features/settings/presentation/providers/settings_provider.dart';
import 'package:musio/shared/widgets/album_art_image.dart';

/// Page plein écran de la file d'attente : bloc "Lecture en cours",
/// liste "Lecture aléatoire à partir de :", prochaine piste en surbrillance,
/// Shuffle + Minuteur en bas. Thème Sonic Noir (tokens, pas de couleurs figées).
class QueueFullScreen extends ConsumerWidget {
  const QueueFullScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final sleepRemaining = ref.watch(sleepTimerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: playerState.queue.isEmpty
                  ? _buildEmpty(context)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Lecture en cours',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _NowPlayingCard(
                          song: playerState.queue[playerState.currentIndex],
                          isPlaying: playerState.isPlaying,
                          onPlayPause: () {
                            if (playerState.isPlaying) {
                              ref.read(audioPlayerProvider.notifier).pause();
                            } else {
                              ref.read(audioPlayerProvider.notifier).resume();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            playerState.isShuffled
                                ? 'Lecture aléatoire à partir de :'
                                : 'À suivre :',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _UpcomingList(
                            queue: playerState.queue,
                            currentIndex: playerState.currentIndex,
                            onSkipTo: (index) => ref
                                .read(audioPlayerProvider.notifier)
                                .skipToIndex(index),
                            onReorder: (oldIndex, newIndex) => ref
                                .read(audioPlayerProvider.notifier)
                                .reorderQueue(oldIndex, newIndex),
                          ),
                        ),
                      ],
                    ),
            ),
            _buildBottomBar(
                context, ref, playerState.isShuffled, sleepRemaining),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: scheme.onSurface,
            iconSize: 32,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'File d\'attente',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 72,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 24),
          Text(
            'La file d\'attente est vide',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    bool isShuffled,
    int? sleepRemaining,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () =>
                  ref.read(audioPlayerProvider.notifier).toggleShuffle(),
              icon: Icon(
                isShuffled ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
                color: scheme.primary,
                size: 24,
              ),
              label: Text(
                'Lecture aléatoire',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.primary,
                side: BorderSide(color: scheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showSleepTimerSheet(context, ref),
              icon: Icon(
                Icons.timer_outlined,
                color: scheme.onSurfaceVariant,
                size: 24,
              ),
              label: Text(
                sleepRemaining != null && sleepRemaining > 0
                    ? '${(sleepRemaining / 60).ceil()} min'
                    : 'Minuteur',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                side: BorderSide(color: scheme.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final remaining = ref.watch(sleepTimerProvider);
          final defaultMinutes =
              ref.watch(sleepTimerDefaultMinutesProvider).valueOrNull ?? 0;
          final scheme = Theme.of(context).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.35)),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color:
                              scheme.onSurfaceVariant.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Minuteur de sommeil',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (remaining != null && remaining > 0) ...[
                      Text(
                        'Arrêt dans ${(remaining / 60).ceil()} min',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: scheme.primary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(sleepTimerProvider.notifier).cancel();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Minuteur annulé'),
                                behavior: SnackBarBehavior.floating),
                          );
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Annuler le minuteur'),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [15, 30, 45, 60].map((m) {
                          return ActionChip(
                            label: Text('$m min'),
                            onPressed: () {
                              ref.read(sleepTimerProvider.notifier).start(m);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Arrêt dans $m min'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                      if (defaultMinutes > 0) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            ref
                                .read(sleepTimerProvider.notifier)
                                .start(defaultMinutes);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Arrêt dans $defaultMinutes min (défaut)'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.timer),
                          label: Text('$defaultMinutes min (défaut)'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  final SongModel song;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const _NowPlayingCard({
    required this.song,
    required this.isPlaying,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlayPause,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AlbumArtImage(
                  songId: song.id,
                  albumArtPath: song.albumArtPath,
                  size: 56,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onPlayPause,
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: scheme.primaryContainer,
                  size: 48,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  final List<SongModel> queue;
  final int currentIndex;
  final void Function(int index) onSkipTo;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _UpcomingList({
    required this.queue,
    required this.currentIndex,
    required this.onSkipTo,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final upcomingCount = queue.length - (currentIndex + 1);
    if (upcomingCount <= 0) {
      return Center(
        child: Text(
          'Aucune piste suivante',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      itemCount: upcomingCount,
      itemBuilder: (context, index) {
        final queueIndex = currentIndex + 1 + index;
        final song = queue[queueIndex];
        final isNext = index == 0;
        return _QueueTile(
          key: ValueKey(song.id),
          song: song,
          isNext: isNext,
          onTap: () => onSkipTo(queueIndex),
          dragHandle: ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle_rounded,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
              size: 24,
            ),
          ),
        );
      },
      onReorder: (oldIndex, newIndex) {
        final oldFull = currentIndex + 1 + oldIndex;
        final newFull = currentIndex + 1 + newIndex;
        onReorder(oldFull, newFull);
      },
    );
  }
}

class _QueueTile extends StatelessWidget {
  final SongModel song;
  final bool isNext;
  final VoidCallback onTap;
  final Widget dragHandle;

  const _QueueTile({
    required this.song,
    required this.isNext,
    required this.onTap,
    required this.dragHandle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AlbumArtImage(
            songId: song.id,
            albumArtPath: song.albumArtPath,
            size: 48,
          ),
        ),
        title: Row(
          children: [
            if (isNext) ...[
              Icon(Icons.play_arrow_rounded, color: accent, size: 20),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isNext ? accent : scheme.onSurface,
                      fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isNext
                    ? accent.withValues(alpha: 0.85)
                    : scheme.onSurfaceVariant,
              ),
        ),
        trailing: dragHandle,
      ),
    );
  }
}
