import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musio/features/artist/presentation/providers/artist_wikipedia_provider.dart';
import 'package:musio/features/music/presentation/providers/music_provider.dart';
import 'package:musio/features/player/presentation/providers/audio_player_provider.dart';
import 'package:musio/shared/widgets/album_art_image.dart';
import 'package:musio/shared/widgets/album_card.dart';
import 'package:musio/shared/widgets/mini_player.dart';
import 'package:musio/shared/widgets/song_tile.dart';
import 'package:palette_generator/palette_generator.dart';

class ArtistDetailsScreen extends ConsumerStatefulWidget {
  final String artistId;

  const ArtistDetailsScreen({
    required this.artistId,
    super.key,
  });

  @override
  ConsumerState<ArtistDetailsScreen> createState() =>
      _ArtistDetailsScreenState();
}

class _ArtistDetailsScreenState extends ConsumerState<ArtistDetailsScreen> {
  Color? dominantColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDominantColor();
    });
  }

  Future<void> _loadDominantColor() async {
    final artists = ref.read(allArtistsProvider);
    try {
      final artist = artists.firstWhere((a) => a.id == widget.artistId);
      if (artist.imagePath != null) {
        // Here we ideally want to load the image from file, but artist image logic in MusicService
        // uses album art path of its first song.
        // The UI uses AlbumArtImageLarge to resolve this.
        // Redimensionnée : évite de décoder la pochette en pleine résolution
        // juste pour en extraire une couleur, ce qui saccadait la transition.
        final path = artist.imagePath!;
        final ImageProvider imageProvider = path.startsWith('content://')
            ? ResizeImage(NetworkImage(path), width: 80, height: 80)
            : ResizeImage(FileImage(File(path)), width: 80, height: 80);
        final palette = await PaletteGenerator.fromImageProvider(
          imageProvider,
          maximumColorCount: 10,
        );
        if (mounted) {
          setState(() {
            dominantColor = palette.dominantColor?.color ??
                palette.vibrantColor?.color ??
                palette.mutedColor?.color;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final artists = ref.watch(allArtistsProvider);
    final songs = ref.watch(artistSongsProvider(widget.artistId));
    final albums = ref.watch(allAlbumsProvider);

    if (artists.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final artist = artists.firstWhere((a) => a.id == widget.artistId);

    // Gestion intelligente du chargement pour éviter le clignotement
    // On utilise directement la liste retournée par le provider synchrone
    if (songs.isEmpty) {
      // Si la liste est vide, on peut afficher un message ou un loader si on sait que ça charge
      // Mais comme le provider est synchrone, s'il est vide c'est qu'il n'y a pas de chansons
    }

    final artistAlbums =
        albums.where((album) => album.artist == artist.name).toList();

    // Apply the diluted solid color background
    final backgroundColor = dominantColor != null
        ? Color.lerp(
            Theme.of(context).scaffoldBackgroundColor, dominantColor!, 0.15)
        : Theme.of(context).scaffoldBackgroundColor;

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar avec photo artiste
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: backgroundColor,
            iconTheme: IconThemeData(color: scheme.onSurface),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                artist.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: backgroundColor),
                  AlbumArtImageLarge(
                    songId:
                        artist.songIds.isNotEmpty ? artist.songIds.first : '0',
                    albumArtPath: artist.imagePath,
                    heroTag: 'artist-art-${artist.id}',
                    // placeholderIcon: const Icon(Icons.person, size: 100),
                  ),
                  // Slight gradient to make text readable
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Statistiques
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(context, artist.albumCount.toString(), 'Albums'),
                  _buildStat(context, artist.trackCount.toString(), 'Chansons'),
                ],
              ),
            ),
          ),

          // Divider
          SliverToBoxAdapter(
            child: Divider(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
              thickness: 1,
            ),
          ),

          // Biographie Wikipedia (cache + API)
          SliverToBoxAdapter(
            child: _WikipediaSection(artistName: artist.name),
          ),

          // Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        ref.read(audioPlayerProvider.notifier).play(songs, 0);
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Lire tout'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(audioPlayerProvider.notifier).play(songs, 0);
                        ref.read(audioPlayerProvider.notifier).toggleShuffle();
                      },
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Mélanger'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top chansons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Top chansons', style: Theme.of(context).textTheme.titleLarge),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = songs[index];
                return SongTile(
                  song: song,
                  playlist: songs,
                  songIndex: index,
                  showIndex: true, // Afficher le numéro de piste
                );
              },
              childCount: songs.length,
            ),
          ),

          // Albums
          if (artistAlbums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Albums', style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => AlbumCard(album: artistAlbums[index]),
                  childCount: artistAlbums.length,
                ),
              ),
            ),
          ],

          // Espace pour le mini player
          const SliverToBoxAdapter(
            child: SizedBox(height: 72),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _buildStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

/// Section affichant la biographie de l'artiste depuis Wikipedia (cache puis API).
class _WikipediaSection extends ConsumerWidget {
  const _WikipediaSection({required this.artistName});

  final String artistName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInfo = ref.watch(artistWikipediaInfoProvider(artistName));
    return asyncInfo.when(
      data: (info) {
        if (info == null || info.extract.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('À propos', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                info.extract,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
