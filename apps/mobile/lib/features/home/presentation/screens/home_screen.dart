import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:musio/core/routing/app_router.dart';
import 'package:musio/features/music/data/models/album_model.dart';
import 'package:musio/features/music/data/models/artist_model.dart';
import 'package:musio/features/music/data/models/playlist_model.dart';
import 'package:musio/features/music/data/models/song_model.dart';
import 'package:musio/features/music/presentation/providers/music_provider.dart';
import 'package:musio/features/playlist/data/system_playlist.dart';
import 'package:musio/features/settings/presentation/providers/settings_provider.dart';
import 'package:musio/shared/widgets/album_art_image.dart';
import 'package:musio/shared/widgets/album_card.dart';
import 'package:musio/shared/widgets/artist_card.dart';
import 'package:musio/shared/widgets/mini_player.dart';
import 'package:musio/shared/widgets/song_card.dart';
import 'package:musio/shared/widgets/song_tile.dart';

import '../../../player/presentation/providers/audio_player_provider.dart';

// Provider pour le nombre de colonnes dans la grille d'albums
final albumGridColumnsProvider = StateProvider<double>((ref) => 2.0);
// Provider pour le mode d'affichage des chansons (true = liste, false = grille)
final songDisplayModeProvider = StateProvider<bool>((ref) => true);

/// Regroupement de l'onglet Titres — indépendant du tri : on peut grouper
/// par artiste ET choisir l'ordre d'arrivée à l'intérieur, par exemple.
enum SongGroupBy { none, album, artist }

/// Ordre des morceaux (à plat, ou à l'intérieur/entre les groupes).
enum SongSortBy { alphabetical, dateAdded }

final songGroupByProvider =
    StateProvider<SongGroupBy>((ref) => SongGroupBy.none);
final songSortByProvider =
    StateProvider<SongSortBy>((ref) => SongSortBy.dateAdded);

/// Genre sélectionné dans l'onglet Titres (null = tous les genres).
final songGenreFilterProvider = StateProvider<String?>((ref) => null);

/// Mode de sélection multiple : null = inactif, 'songs' = pistes, 'albums' = albums.
final selectionModeProvider = StateProvider<String?>((ref) => null);
final selectedSongIdsProvider = StateProvider<Set<String>>((ref) => {});
final selectedAlbumIdsProvider = StateProvider<Set<String>>((ref) => {});

class OfflineHomeScreen extends ConsumerStatefulWidget {
  const OfflineHomeScreen({super.key});

  @override
  ConsumerState<OfflineHomeScreen> createState() => _OfflineHomeScreenState();
}

class _OfflineHomeScreenState extends ConsumerState<OfflineHomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    // Demander les permissions au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(musicRepositoryProvider).requestPermissions();
    });
  }

  void _clearSelection() {
    ref.read(selectionModeProvider.notifier).state = null;
    ref.read(selectedSongIdsProvider.notifier).state = {};
    ref.read(selectedAlbumIdsProvider.notifier).state = {};
  }

  void _confirmDeleteSelectedSongs(
      BuildContext context, Set<String> ids) async {
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer les morceaux ?'),
        content: Text(
          '${ids.length} morceau(x) seront supprimés de la bibliothèque. Les fichiers seront supprimés du téléphone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final notifier = ref.read(musicProvider.notifier);
      for (final id in ids) {
        await notifier.removeSong(id);
      }
      _clearSelection();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ids.length} morceau(x) supprimé(s)')),
        );
      }
    }
  }

  void _confirmDeleteSelectedAlbums(
      BuildContext context, Set<String> ids) async {
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer les albums ?'),
        content: Text(
          'Les ${ids.length} album(s) et toutes leurs pistes seront supprimés de la bibliothèque. Les fichiers seront supprimés du téléphone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final notifier = ref.read(musicProvider.notifier);
      final playerNotifier = ref.read(audioPlayerProvider.notifier);
      final currentQueueIds =
          ref.read(audioPlayerProvider).queue.map((s) => s.id).toSet();
      for (final albumId in ids) {
        final songIds =
            ref.read(albumSongsProvider(albumId)).map((s) => s.id).toSet();
        if (songIds.any((id) => currentQueueIds.contains(id))) {
          await playerNotifier.stop();
          break;
        }
      }
      for (final albumId in ids) {
        await notifier.removeAlbum(albumId);
      }
      _clearSelection();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ids.length} album(s) supprimé(s)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicState = ref.watch(musicProvider);
    final selectionMode = ref.watch(selectionModeProvider);
    final selectedSongIds = ref.watch(selectedSongIdsProvider);
    final selectedAlbumIds = ref.watch(selectedAlbumIdsProvider);

    final isSelectionActive = selectionMode != null;
    final selectionCount = selectionMode == 'songs'
        ? selectedSongIds.length
        : selectionMode == 'albums'
            ? selectedAlbumIds.length
            : 0;

    const categories = <String>['Playlists', 'Artistes', 'Albums', 'Titres'];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: isSelectionActive
          ? AppBar(
              title: Text('$selectionCount sélectionné(s)'),
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
                tooltip: 'Annuler',
              ),
              actions: [
                if (selectionCount > 0)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error),
                    tooltip: 'Supprimer',
                    onPressed: () {
                      if (selectionMode == 'songs') {
                        _confirmDeleteSelectedSongs(context, selectedSongIds);
                      } else {
                        _confirmDeleteSelectedAlbums(context, selectedAlbumIds);
                      }
                    },
                  ),
              ],
            )
          : AppBar(
              automaticallyImplyLeading: false,
              leading: _buildMenuButton(context, ref),
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
          if (state.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scan de la bibliothèque en cours...'),
                ],
              ),
            );
          }

          if (state.songs.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              _LibraryChipRow(
                categories: categories,
                selectedIndex: _currentIndex,
                onSelected: (index) {
                  if (ref.read(selectionModeProvider) != null) {
                    _clearSelection();
                  }
                  setState(() => _currentIndex = index);
                },
              ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    _buildPlaylistsTab(state.playlists, state.songs),
                    _buildArtistsTab(state.artists),
                    _buildAlbumsTab(state.albums),
                    _buildSongsTab(state.songs),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(musicProvider.notifier).rescanLibrary(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showCreatePlaylistDialog(context, ref),
              label: const Text('Créer une playlist'),
              icon: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _buildMenuButton(BuildContext context, WidgetRef ref) {
    final isOnlineEnabled =
        ref.watch(onlineFeatureEnabledProvider).valueOrNull ?? false;
    final isSongList = ref.watch(songDisplayModeProvider);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Menu',
      onSelected: _handleMenuAction,
      itemBuilder: (context) {
        final menuItems = <PopupMenuEntry<String>>[];

        if (isOnlineEnabled) {
          menuItems.add(
            const PopupMenuItem(
              value: 'online',
              child: Row(
                children: [
                  Icon(Icons.public),
                  SizedBox(width: 12),
                  Text('Découvrir en ligne'),
                ],
              ),
            ),
          );
        }
        menuItems.addAll([
          const PopupMenuItem(
            value: 'search',
            child: Row(
              children: [
                Icon(Icons.search),
                SizedBox(width: 12),
                Text('Rechercher'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'settings',
            child: Row(
              children: [
                Icon(Icons.settings_outlined),
                SizedBox(width: 12),
                Text('Paramètres'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'scan',
            child: Row(
              children: [
                Icon(Icons.refresh),
                SizedBox(width: 12),
                Text('Rescanner la bibliothèque'),
              ],
            ),
          ),
        ]);

        if (_currentIndex == 2) {
          menuItems.addAll([
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'album_grid_size',
              child: Row(
                children: [
                  Icon(Icons.grid_view),
                  SizedBox(width: 12),
                  Text('Taille de la grille'),
                ],
              ),
            ),
          ]);
        }
        if (_currentIndex == 3) {
          menuItems.addAll([
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'toggle_song_view',
              child: Row(
                children: [
                  Icon(isSongList ? Icons.grid_view : Icons.list),
                  const SizedBox(width: 12),
                  Text(isSongList ? 'Vue grille' : 'Vue liste'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'song_sort',
              child: Row(
                children: [
                  Icon(Icons.sort_rounded),
                  SizedBox(width: 12),
                  Text('Trier / grouper'),
                ],
              ),
            ),
          ]);
        }
        return menuItems;
      },
    );
  }

  void _toggleSongSelection(String songId) {
    final next = Set<String>.from(ref.read(selectedSongIdsProvider));
    if (!next.remove(songId)) next.add(songId);
    ref.read(selectedSongIdsProvider.notifier).state = next;
  }

  void _enterSongSelection(String songId) {
    ref.read(selectionModeProvider.notifier).state = 'songs';
    ref.read(selectedAlbumIdsProvider.notifier).state = {};
    ref.read(selectedSongIdsProvider.notifier).state = {songId};
  }

  /// Genres distincts présents dans la bibliothèque (tag `genre`), triés.
  List<String> _distinctGenres(List<SongModel> songs) {
    final set = <String>{};
    for (final s in songs) {
      final g = (s.genre ?? '').trim();
      if (g.isNotEmpty) set.add(g);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  int _compareBySort(SongModel a, SongModel b, SongSortBy sortBy) {
    return switch (sortBy) {
      SongSortBy.alphabetical =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      SongSortBy.dateAdded => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0),
    };
  }

  String _groupKey(SongModel s, SongGroupBy groupBy) {
    return switch (groupBy) {
      SongGroupBy.album => s.album.isEmpty ? 'Album inconnu' : s.album,
      SongGroupBy.artist => s.artist.isEmpty ? 'Artiste inconnu' : s.artist,
      SongGroupBy.none => '',
    };
  }

  /// Tri à plat (pas de regroupement) — utilisé quand [SongGroupBy.none].
  List<SongModel> _sortSongs(List<SongModel> songs, SongSortBy sortBy) {
    final sorted = List<SongModel>.from(songs);
    sorted.sort((a, b) => _compareBySort(a, b, sortBy));
    return sorted;
  }

  /// Groupe [songs] par [groupBy], puis ordonne indépendamment les groupes
  /// et les morceaux à l'intérieur selon [sortBy] (alphabétique : nom de
  /// groupe puis titre, A → Z ; ordre d'arrivée : groupe dont l'ajout le
  /// plus récent est le plus récent d'abord, puis piste la plus récente
  /// d'abord) — groupement et tri sont deux choix combinables.
  List<SongModel> _groupedFlatOrder(
    List<SongModel> songs,
    SongGroupBy groupBy,
    SongSortBy sortBy,
  ) {
    final groups = <String, List<SongModel>>{};
    for (final s in songs) {
      groups.putIfAbsent(_groupKey(s, groupBy), () => []).add(s);
    }
    for (final list in groups.values) {
      list.sort((a, b) => _compareBySort(a, b, sortBy));
    }

    final groupKeys = groups.keys.toList();
    if (sortBy == SongSortBy.alphabetical) {
      groupKeys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      int mostRecent(String key) => groups[key]!.fold<int>(
          0, (acc, s) => (s.dateAdded ?? 0) > acc ? s.dateAdded! : acc);
      groupKeys.sort((a, b) => mostRecent(b).compareTo(mostRecent(a)));
    }

    return [for (final key in groupKeys) ...groups[key]!];
  }

  /// Aplati une liste déjà ordonnée par groupe (voir [_groupedFlatOrder]) en
  /// lignes d'en-tête + morceau, en gardant l'index (nécessaire pour la
  /// file de lecture, qui doit correspondre à l'ordre affiché).
  List<({String? header, SongModel? song, int? index})> _buildGroupedItems(
    List<SongModel> flatOrder,
    SongGroupBy groupBy,
  ) {
    final items = <({String? header, SongModel? song, int? index})>[];
    String? lastKey;
    for (var i = 0; i < flatOrder.length; i++) {
      final s = flatOrder[i];
      final key = _groupKey(s, groupBy);
      if (key != lastKey) {
        items.add((header: key, song: null, index: null));
        lastKey = key;
      }
      items.add((header: null, song: s, index: i));
    }
    return items;
  }

  Widget _buildSongsTab(List<SongModel> songs) {
    final isList = ref.watch(songDisplayModeProvider);
    final selectionMode = ref.watch(selectionModeProvider);
    final selectedIds = ref.watch(selectedSongIdsProvider);
    final isSongSelection = selectionMode == 'songs';
    final groupBy = ref.watch(songGroupByProvider);
    final sortBy = ref.watch(songSortByProvider);
    final genreFilter = ref.watch(songGenreFilterProvider);

    if (songs.isEmpty) {
      return _buildEmptyState();
    }

    final genres = _distinctGenres(songs);
    final genreFiltered = genreFilter == null
        ? songs
        : songs.where((s) => (s.genre ?? '').trim() == genreFilter).toList();
    final isGrouped = isList && groupBy != SongGroupBy.none;
    final displayedSongs = isGrouped
        ? _groupedFlatOrder(genreFiltered, groupBy, sortBy)
        : _sortSongs(genreFiltered, sortBy);

    Widget content;
    if (displayedSongs.isEmpty) {
      content = Center(
        child: Text(
          'Aucun titre pour ce genre.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    } else if (isGrouped) {
      final items = _buildGroupedItems(displayedSongs, groupBy);
      content = ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          if (item.header != null) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              child: Text(
                item.header!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            );
          }
          final song = item.song!;
          final index = item.index!;
          final isSelected = selectedIds.contains(song.id);
          if (isSongSelection) {
            return InkWell(
              onTap: () => _toggleSongSelection(song.id),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSongSelection(song.id),
                  ),
                  Expanded(
                    child: SongTile(
                      song: song,
                      playlist: displayedSongs,
                      songIndex: index,
                      showTrailingMenu: false,
                    ),
                  ),
                ],
              ),
            );
          }
          return SongTile(
            song: song,
            playlist: displayedSongs,
            songIndex: index,
            onLongPress: () => _enterSongSelection(song.id),
          );
        },
      );
    } else if (isList) {
      content = ListView.separated(
        itemCount: displayedSongs.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final song = displayedSongs[index];
          final isSelected = selectedIds.contains(song.id);
          if (isSongSelection) {
            return InkWell(
              onTap: () => _toggleSongSelection(song.id),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSongSelection(song.id),
                  ),
                  Expanded(
                    child: SongTile(
                      song: song,
                      playlist: displayedSongs,
                      songIndex: index,
                      showTrailingMenu: false,
                    ),
                  ),
                ],
              ),
            );
          }
          return SongTile(
            song: song,
            playlist: displayedSongs,
            songIndex: index,
            onLongPress: () => _enterSongSelection(song.id),
          );
        },
      );
    } else {
      content = GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: displayedSongs.length,
        itemBuilder: (context, index) {
          final song = displayedSongs[index];
          final isSelected = selectedIds.contains(song.id);
          if (isSongSelection) {
            return InkWell(
              onTap: () => _toggleSongSelection(song.id),
              child: Stack(
                children: [
                  AlbumCard(
                    album: song.toAlbumModel(),
                    onTap: () {},
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSongSelection(song.id),
                    ),
                  ),
                ],
              ),
            );
          }
          return GestureDetector(
            onLongPress: () => _enterSongSelection(song.id),
            child: AlbumCard(
              album: song.toAlbumModel(),
              onTap: () => ref
                  .read(audioPlayerProvider.notifier)
                  .play(displayedSongs, index),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        if (genres.isNotEmpty)
          _GenreFilterChips(
            genres: genres,
            selected: genreFilter,
            onSelected: (g) =>
                ref.read(songGenreFilterProvider.notifier).state = g,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(musicProvider.notifier).rescanLibrary();
            },
            child: content,
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumsTab(List<AlbumModel> albums) {
    final columns = ref.watch(albumGridColumnsProvider);
    final selectionMode = ref.watch(selectionModeProvider);
    final selectedIds = ref.watch(selectedAlbumIdsProvider);
    final isAlbumSelection = selectionMode == 'albums';

    if (albums.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(musicProvider.notifier).rescanLibrary();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns.round(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          final isSelected = selectedIds.contains(album.id);
          if (isAlbumSelection) {
            return InkWell(
              onTap: () {
                final next = Set<String>.from(selectedIds);
                if (isSelected) {
                  next.remove(album.id);
                } else {
                  next.add(album.id);
                }
                ref.read(selectedAlbumIdsProvider.notifier).state = next;
              },
              child: Stack(
                children: [
                  AlbumCard(album: album, onTap: () {}),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) {
                        final next = Set<String>.from(selectedIds);
                        if (isSelected) {
                          next.remove(album.id);
                        } else {
                          next.add(album.id);
                        }
                        ref.read(selectedAlbumIdsProvider.notifier).state =
                            next;
                      },
                    ),
                  ),
                ],
              ),
            );
          }
          return GestureDetector(
            onLongPress: () {
              ref.read(selectionModeProvider.notifier).state = 'albums';
              ref.read(selectedSongIdsProvider.notifier).state = {};
              ref.read(selectedAlbumIdsProvider.notifier).state = {album.id};
            },
            child: AlbumCard(album: album),
          );
        },
      ),
    );
  }

  Widget _buildArtistsTab(List<ArtistModel> artists) {
    if (artists.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(musicProvider.notifier).rescanLibrary();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.7,
        ),
        itemCount: artists.length,
        itemBuilder: (context, index) => ArtistCard(artist: artists[index]),
      ),
    );
  }

  Widget _buildPlaylistsTab(
      List<PlaylistModel> playlists, List<SongModel> songs) {
    final favoritesCount = songs.where((s) => s.isFavorite).length;
    final recentCount = songs.where((s) => s.lastPlayed != null).length;
    final mostPlayedCount = songs.where((s) => s.playCount > 0).length;
    final favoriteSongs = songs.where((s) => s.isFavorite).toList();
    final recentlyAdded = List<SongModel>.from(songs)
      ..sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));

    return ListView(
      padding: const EdgeInsets.only(bottom: 140),
      children: [
        if (favoriteSongs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.favorite_rounded,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    size: 20),
                const SizedBox(width: 8),
                Text('Favoris Locaux',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: favoriteSongs.take(6).length,
              itemBuilder: (context, index) {
                final song = favoriteSongs[index];
                return SongCard(
                  song: song,
                  onTap: () => ref
                      .read(audioPlayerProvider.notifier)
                      .play(favoriteSongs, index),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (recentlyAdded.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ajouts Récents',
                    style: Theme.of(context).textTheme.titleLarge),
                InkWell(
                  onTap: () => context.push(
                    AppRouter.songList,
                    extra: {'title': 'Ajouts récents', 'songs': recentlyAdded},
                  ),
                  child: Text(
                    'Voir tout',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                  ),
                ),
              ],
            ),
          ),
          ...recentlyAdded.take(4).map(
                (song) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AlbumArtImage(
                      albumArtPath: song.albumArtPath,
                      songId: song.id,
                      size: 48,
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  onTap: () => ref
                      .read(audioPlayerProvider.notifier)
                      .play(recentlyAdded, recentlyAdded.indexOf(song)),
                ),
              ),
          const Divider(height: 32, indent: 16, endIndent: 16),
        ],
        // Playlists système
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'PLAYLISTS SYSTÈME',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.favorite,
                color: Theme.of(context).colorScheme.primary),
          ),
          title: const Text('Favoris'),
          subtitle:
              Text('$favoritesCount chanson${favoritesCount != 1 ? 's' : ''}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/playlist/${SystemPlaylist.favorites}'),
        ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.history,
                color: Theme.of(context).colorScheme.primary),
          ),
          title: const Text('Récemment jouées'),
          subtitle: Text('$recentCount chanson${recentCount != 1 ? 's' : ''}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/playlist/${SystemPlaylist.recent}'),
        ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.trending_up,
                color: Theme.of(context).colorScheme.primary),
          ),
          title: const Text('Les plus jouées'),
          subtitle: Text(
              '$mostPlayedCount chanson${mostPlayedCount != 1 ? 's' : ''}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/playlist/${SystemPlaylist.mostPlayed}'),
        ),
        const Divider(height: 24),
        // Playlists utilisateur
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'MES PLAYLISTS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Créez une playlist avec le bouton +',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          ...playlists.map((playlist) => ListTile(
                leading: const Icon(Icons.playlist_play),
                title: Text(playlist.name),
                subtitle: Text(
                    '${playlist.songIds.length} chanson${playlist.songIds.length != 1 ? 's' : ''}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/playlist/${playlist.id}'),
              )),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouvelle playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom de la playlist',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  ref
                      .read(musicProvider.notifier)
                      .createPlaylist(controller.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
  }

  void _showAlbumGridSizeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Taille de la grille'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      '${ref.watch(albumGridColumnsProvider).round()} colonnes'),
                  Slider(
                    value: ref.watch(albumGridColumnsProvider),
                    min: 2,
                    max: 5,
                    divisions: 3,
                    label:
                        '${ref.watch(albumGridColumnsProvider).round()} colonnes',
                    onChanged: (value) {
                      setState(() {
                        ref.read(albumGridColumnsProvider.notifier).state =
                            value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  void _showSongSortDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final groupBy = ref.watch(songGroupByProvider);
          final sortBy = ref.watch(songSortByProvider);
          final scheme = Theme.of(context).colorScheme;

          Widget sectionLabel(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              );

          Widget groupOption(String label, IconData icon, SongGroupBy value) {
            return RadioListTile<SongGroupBy>(
              value: value,
              title: Text(label),
              secondary: Icon(icon),
            );
          }

          Widget sortOption(String label, IconData icon, SongSortBy value) {
            return RadioListTile<SongSortBy>(
              value: value,
              title: Text(label),
              secondary: Icon(icon),
            );
          }

          return AlertDialog(
            title: const Text('Trier / grouper les titres'),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Regroupement et tri sont deux choix indépendants,
                  // combinables (ex. groupé par artiste + ordre d'arrivée).
                  sectionLabel('Regrouper par'),
                  RadioGroup<SongGroupBy>(
                    groupValue: groupBy,
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(songGroupByProvider.notifier).state = v;
                      }
                    },
                    child: Column(
                      children: [
                        groupOption(
                            'Aucun', Icons.list_rounded, SongGroupBy.none),
                        groupOption(
                            'Album', Icons.album_rounded, SongGroupBy.album),
                        groupOption('Artiste', Icons.person_rounded,
                            SongGroupBy.artist),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  sectionLabel('Trier par'),
                  RadioGroup<SongSortBy>(
                    groupValue: sortBy,
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(songSortByProvider.notifier).state = v;
                      }
                    },
                    child: Column(
                      children: [
                        sortOption('Ordre d\'arrivée', Icons.schedule_rounded,
                            SongSortBy.dateAdded),
                        sortOption(
                            'Alphabétique (A → Z)',
                            Icons.sort_by_alpha_rounded,
                            SongSortBy.alphabetical),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.library_music, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Aucune musique trouvée',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Scannez votre bibliothèque pour commencer'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(musicProvider.notifier).rescanLibrary(),
            icon: const Icon(Icons.refresh),
            label: const Text('Scanner la bibliothèque'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'online':
        context.push(AppRouter.online);
        break;
      case 'search':
        context.push(AppRouter.search);
        break;
      case 'scan':
        ref.read(musicProvider.notifier).rescanLibrary();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan de la bibliothèque démarré')),
        );
        break;
      case 'settings':
        context.push(AppRouter.settings);
        break;
      case 'toggle_song_view':
        final notifier = ref.read(songDisplayModeProvider.notifier);
        notifier.state = !notifier.state;
        break;
      case 'album_grid_size':
        _showAlbumGridSizeDialog(context, ref);
        break;
      case 'song_sort':
        _showSongSortDialog(context, ref);
        break;
    }
  }
}

extension on SongModel {
  AlbumModel toAlbumModel() {
    return AlbumModel(
      id: id,
      name: title,
      artist: artist,
      albumArtPath: albumArtPath,
      year: year,
      songIds: [id],
      trackCount: 1,
    );
  }
}

/// Rangée de puces pour choisir la catégorie affichée (Albums / Titres /
/// Playlists), remplace l'ancienne barre de navigation interne — la
/// sélection de catégorie n'a plus besoin de sa propre bottom bar
/// maintenant que la Bibliothèque est un onglet parmi d'autres.
class _LibraryChipRow extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _LibraryChipRow({
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(categories[index]),
            selected: selected,
            onSelected: (_) => onSelected(index),
            showCheckmark: false,
            labelStyle: textTheme.labelLarge?.copyWith(
              color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            backgroundColor: scheme.surfaceContainerHigh,
            selectedColor: scheme.primaryContainer,
            side: BorderSide(
              color: selected ? Colors.transparent : scheme.outlineVariant,
            ),
            shape: const StadiumBorder(),
          );
        },
      ),
    );
  }
}

/// Rangée de puces de filtre par genre (Rap, Soul…) pour l'onglet Titres —
/// "Tous" (null) + un genre par valeur distincte trouvée dans la bibliothèque.
class _GenreFilterChips extends StatelessWidget {
  final List<String> genres;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _GenreFilterChips({
    required this.genres,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Volontairement différent de _LibraryChipRow (puces pleines en stadium,
    // pour la navigation principale) : ici un filtre plus fin/secondaire,
    // donc des puces plus petites, contour fin, coins peu arrondis.
    Widget chip(String label, String? value) {
      final isSelected = selected == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onSelected(value),
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelStyle: textTheme.labelMedium?.copyWith(
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
          backgroundColor: Colors.transparent,
          selectedColor: scheme.primary.withValues(alpha: 0.12),
          side: BorderSide(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          chip('Tous', null),
          ...genres.map((g) => chip(_titleCaseGenre(g), g)),
        ],
      ),
    );
  }
}

/// Capitalise chaque mot ("rap" -> "Rap", "HIP HOP" -> "Hip Hop") — les tags
/// de genre des fichiers audio ont une casse très inconsistante.
String _titleCaseGenre(String s) {
  return s
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}
