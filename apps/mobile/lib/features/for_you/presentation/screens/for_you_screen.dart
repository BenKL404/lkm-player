import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:musio/core/routing/app_router.dart';
import 'package:musio/features/music/data/models/song_model.dart';
import 'package:musio/features/music/data/repositories/music_repository.dart';
import 'package:musio/features/music/presentation/providers/music_provider.dart';
import 'package:musio/features/player/presentation/providers/audio_player_provider.dart';
import 'package:musio/shared/widgets/album_art_image.dart';
import 'package:musio/shared/widgets/mini_player.dart';
import 'package:musio/shared/widgets/song_card.dart';

/// Onglet Accueil — reproduit fidèlement la maquette "Sonic Noir"
/// (en-tête, salutation, raccourcis en ligne, Écoutés récemment, Tendances).
class ForYouScreen extends ConsumerWidget {
  const ForYouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicState = ref.watch(musicProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Menu',
          onPressed: () => context.push(AppRouter.settings),
        ),
        title: Text(
          'LKM Player',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => context.push(AppRouter.settings),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.person,
                    color: scheme.onPrimaryContainer, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: musicState.when(
        data: (state) {
          if (state.songs.isEmpty) {
            return const Center(
                child: Text('Aucune musique dans la bibliothèque.'));
          }

          final recentlyPlayed = state.songs
              .where((s) => s.lastPlayed != null)
              .toList()
            ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));

          final recentlyAdded = List<SongModel>.from(state.songs)
            ..sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));

          final mostPlayed = state.songs.where((s) => s.playCount > 0).toList()
            ..sort((a, b) => b.playCount.compareTo(a.playCount));

          final recentRail =
              recentlyPlayed.isNotEmpty ? recentlyPlayed : recentlyAdded;
          final trending = mostPlayed.isNotEmpty ? mostPlayed : recentlyAdded;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              const _HomeHeader(),
              const SizedBox(height: 24),
              _SourceShortcutsRow(
                  onTapSource: () => context.push(AppRouter.online)),
              const SizedBox(height: 32),
              Text('Écoutés récemment',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recentRail.take(8).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final song = recentRail[index];
                    return SizedBox(
                      width: 140,
                      child: SongCard(
                        song: song,
                        onTap: () => ref
                            .read(audioPlayerProvider.notifier)
                            .play(recentRail, index),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              Text('Tendances streaming',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...trending.take(6).map(
                    (song) => _TrendingRow(
                      song: song,
                      onTap: () => ref
                          .read(audioPlayerProvider.notifier)
                          .play(trending, trending.indexOf(song)),
                    ),
                  ),
              const SizedBox(height: 90),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

/// Salutation contextuelle en haut de l'onglet Accueil.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Bonne nuit';
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          "Prêt pour une session d'écoute ?",
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Raccourcis vers les sources en ligne (mènent à l'onglet Découvrir).
class _SourceShortcutsRow extends StatelessWidget {
  final VoidCallback onTapSource;

  const _SourceShortcutsRow({required this.onTapSource});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SourceShortcutCard(
            icon: Icons.headphones_rounded,
            label: 'Deezer',
            caption: 'Rechercher',
            onTap: onTapSource,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SourceShortcutCard(
            icon: Icons.cloud_outlined,
            label: 'SoundCloud',
            caption: 'Découvrir',
            onTap: onTapSource,
          ),
        ),
      ],
    );
  }
}

class _SourceShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  const _SourceShortcutCard({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 108,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: scheme.onSurface, size: 26),
                  Icon(Icons.north_east_rounded,
                      color: scheme.onSurfaceVariant, size: 16),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    caption,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne "Tendances streaming" — pochette 56px, titre, icône casque + artiste,
/// menu contextuel (pas de bouton play dédié : toute la ligne est cliquable).
class _TrendingRow extends ConsumerWidget {
  final SongModel song;
  final VoidCallback onTap;

  const _TrendingRow({required this.song, required this.onTap});

  void _showOptionsMenu(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isFavorite = ref
            .read(musicProvider)
            .asData
            ?.value
            .songs
            .firstWhere((s) => s.id == song.id, orElse: () => song)
            .isFavorite ??
        song.isFavorite;
    final albumKey = MusicRepository.effectiveAlbumKey(song);
    final artistKey = MusicRepository.effectiveArtistKey(song);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.35)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AlbumArtImage(
                          albumArtPath: song.albumArtPath,
                          songId: song.id,
                          size: 44,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.35)),
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: const Text('Lire'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onTap();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: const Text('Lire ensuite'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref.read(audioPlayerProvider.notifier).addNext(song);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: const Text('Ajouter à la file'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref.read(audioPlayerProvider.notifier).addToQueue(song);
                  },
                ),
                ListTile(
                  leading: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite ? scheme.primary : null,
                  ),
                  title: Text(isFavorite
                      ? 'Retirer des favoris'
                      : 'Ajouter aux favoris'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref.read(musicProvider.notifier).toggleFavoriteStatus(song);
                  },
                ),
                if (albumKey != null)
                  ListTile(
                    leading: const Icon(Icons.album_rounded),
                    title: const Text('Aller à l\'album'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push('/album/$albumKey');
                    },
                  ),
                if (artistKey != null)
                  ListTile(
                    leading: const Icon(Icons.person_rounded),
                    title: const Text('Aller à l\'artiste'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push('/artist/$artistKey');
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AlbumArtImage(
                  albumArtPath: song.albumArtPath,
                  songId: song.id,
                  size: 56,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.headphones_rounded,
                            size: 14, color: scheme.primaryContainer),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                onPressed: () => _showOptionsMenu(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
