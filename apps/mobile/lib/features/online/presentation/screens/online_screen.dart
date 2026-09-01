import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:musio/core/routing/app_router.dart';
import 'package:musio/features/download/data/models/deezer_search_result.dart';
import 'package:musio/features/download/data/telegramusic_api_client.dart';
import 'package:musio/features/download/presentation/providers/download_provider.dart';
import 'package:musio/features/download/presentation/providers/download_session_provider.dart';
import 'package:musio/features/download/presentation/widgets/active_downloads_section.dart';
import 'package:musio/features/player/presentation/providers/audio_player_provider.dart';
import 'package:musio/shared/widgets/mini_player.dart';
import 'package:musio/shared/widgets/song_tile.dart';

/// Écran « Découvrir » — recherche Deezer + téléchargement (design LKM unifié).
class OnlineScreen extends ConsumerStatefulWidget {
  const OnlineScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  ConsumerState<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends ConsumerState<OnlineScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const double _albumArt = 124;
  static const double _albumStripHeight = 196;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    listenDownloadSessionBanner(context, ref);

    final searchState = ref.watch(onlineSearchStateProvider);
    final apiClient = ref.watch(downloadApiClientProvider);
    final downloadingTrackId = ref.watch(downloadingTrackIdProvider);
    final downloadingAlbumId = ref.watch(downloadingAlbumIdProvider);
    final downloadProgress = ref.watch(downloadProgressProvider);

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : Consumer(
                builder: (context, ref, _) {
                  final n =
                      ref.watch(downloadSessionProvider).activeTasks.length;
                  final label = n > 99 ? '99+' : '$n';
                  return IconButton(
                    tooltip: 'Téléchargements${n > 0 ? ' ($n)' : ''}',
                    onPressed: () => context.push(AppRouter.downloads),
                    icon: Badge(
                      isLabelVisible: n > 0,
                      label: Text(
                        label,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1),
                      ),
                      padding: n > 9
                          ? const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2)
                          : const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                      child: const Icon(Icons.downloading_rounded),
                    ),
                  );
                },
              ),
        title: Text(
          widget.showBackButton ? 'Découvrir' : 'LKM Player',
          style: widget.showBackButton
              ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  )
              : Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
        ),
        centerTitle: !widget.showBackButton,
        actions: widget.showBackButton
            ? null
            : [
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                _SearchBar(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onChanged: () => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    ref.read(onlineSearchStateProvider.notifier).clear();
                    setState(() {});
                  },
                  onSubmit: (value) {
                    if (value.trim().isNotEmpty) {
                      ref
                          .read(onlineSearchStateProvider.notifier)
                          .search(value.trim());
                    }
                  },
                ),
                const SizedBox(height: 10),
                _SourceFilterChips(selected: searchState.sourceFilter),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(
        context,
        ref,
        apiClient,
        searchState,
        downloadingTrackId,
        downloadingAlbumId,
        downloadProgress,
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    TelegramusicApiClient? apiClient,
    OnlineSearchState searchState,
    String? downloadingTrackId,
    String? downloadingAlbumId,
    double? downloadProgress,
  ) {
    // Filtre "Local" : indépendant du serveur de téléchargement, on cherche
    // uniquement dans la bibliothèque déjà présente sur l'appareil.
    if (searchState.sourceFilter == SearchSourceFilter.local) {
      return _buildLocalResults(searchState);
    }

    // Pas de connexion internet : la recherche en ligne a échoué et
    // basculé automatiquement sur la bibliothèque locale, affichée tout de
    // suite (avec un bandeau expliquant pourquoi) plutôt qu'un écran d'erreur.
    if (searchState.isOfflineFallback) {
      return _buildLocalResults(searchState, offline: true);
    }

    if (apiClient == null || !apiClient.isConfigured) {
      return const _StatePage(
        icon: Icons.cloud_off_rounded,
        iconGradient: true,
        title: 'Connexion au serveur',
        subtitle:
            'Dans Paramètres, renseignez l’URL du serveur de téléchargement (ex. l’API Telegramusic).',
      );
    }

    if (searchState.isLoading) {
      return const _StatePage(
        leading: _RotatingSearchIcon(),
        title: 'Recherche…',
        showProgress: true,
      );
    }

    if (searchState.error != null) {
      return _StatePage(
        icon: Icons.wifi_tethering_error_rounded,
        title: 'Impossible de chercher',
        subtitle: searchState.error!,
        isError: true,
      );
    }

    if (searchState.results.isEmpty && searchState.albumResults.isEmpty) {
      final session = ref.watch(downloadSessionProvider);
      if (session.hasActiveWork) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.downloading_rounded,
                      size: 56,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.65),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Téléchargements en cours',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ouvre la file pour mettre en pause, annuler ou voir l’historique.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push(AppRouter.downloads),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Voir les téléchargements'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ou lance une recherche pour ajouter d’autres titres.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      return const _StatePage(
        icon: Icons.explore_rounded,
        iconGradient: true,
        title: 'Trouve ta musique',
        subtitle:
            'Tape un titre, un artiste ou un album puis valide avec Entrée.',
      );
    }

    // `results` contient déjà uniquement des pistes (Deezer + YouTube + SoundCloud) :
    // les albums Deezer sont dans une liste séparée.
    final tracks = searchState.results;
    final albums = searchState.albumResults.where((r) => r.isAlbum).toList();

    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        if (albums.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionTitle(
              label: 'Albums',
              count: albums.length,
              icon: Icons.album_rounded,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: _albumStripHeight,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                scrollDirection: Axis.horizontal,
                itemCount: albums.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final album = albums[index];
                  final isDl = downloadingAlbumId == album.id;
                  return _AlbumCard(
                    album: album,
                    artSize: _albumArt,
                    isDownloading: isDl,
                    progress: isDl ? downloadProgress : null,
                    onOpenDetails: () =>
                        _openAlbumTracksSheet(context, ref, apiClient, album),
                  );
                },
              ),
            ),
          ),
        ],
        if (tracks.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: albums.isNotEmpty ? 8 : 16),
              child: _SectionTitle(
                label: 'Morceaux',
                count: tracks.length,
                icon: Icons.music_note_rounded,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            sliver: SliverList.separated(
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final track = tracks[index];
                final isDl = downloadingTrackId == track.id;
                return _TrackCard(
                  track: track,
                  isDownloading: isDl,
                  progress: isDl ? downloadProgress : null,
                  onDownload: () => _downloadTrack(context, track),
                  onStream: () => _streamTrack(context, track),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Résultats du filtre "Local", ou repli automatique hors-ligne ([offline])
  /// : morceaux déjà dans la bibliothèque de l'appareil, réutilise
  /// [SongTile] (lecture, favoris, menu… déjà en place).
  Widget _buildLocalResults(OnlineSearchState searchState,
      {bool offline = false}) {
    final songs = searchState.localResults;
    if (songs.isEmpty) {
      return _StatePage(
        icon: offline ? Icons.wifi_off_rounded : Icons.folder_rounded,
        iconGradient: true,
        title: offline ? 'Pas de connexion internet' : 'Bibliothèque locale',
        subtitle: offline
            ? 'Aucun résultat dans ta bibliothèque pour cette recherche. Reconnecte-toi pour chercher en ligne.'
            : 'Tape un titre, un artiste ou un album de ta bibliothèque puis valide avec Entrée.',
      );
    }
    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        if (offline)
          const SliverToBoxAdapter(
            child: _OfflineBanner(),
          ),
        SliverToBoxAdapter(
          child: _SectionTitle(
            label: 'Bibliothèque locale',
            count: songs.length,
            icon: Icons.folder_rounded,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 4, bottom: 100),
          sliver: SliverList.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) => SongTile(
              song: songs[index],
              playlist: songs,
              songIndex: index,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadTrack(
      BuildContext context, DeezerSearchResult track) async {
    await ref.read(downloadSessionProvider.notifier).enqueue(track);
  }

  Future<void> _streamTrack(
      BuildContext context, DeezerSearchResult track) async {
    try {
      await playStream(ref, track);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _downloadAlbum(
      BuildContext context, DeezerSearchResult album) async {
    await ref.read(downloadSessionProvider.notifier).enqueue(album);
  }

  void _openAlbumTracksSheet(
    BuildContext context,
    WidgetRef ref,
    TelegramusicApiClient client,
    DeezerSearchResult album,
  ) {
    final tracksFuture = client.albumTracks(album.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.35,
          maxChildSize: 0.94,
          expand: false,
          builder: (ctx, scrollController) {
            final scheme = Theme.of(ctx).colorScheme;
            final textTheme = Theme.of(ctx).textTheme;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 76,
                            height: 76,
                            child:
                                album.imgUrl != null && album.imgUrl!.isNotEmpty
                                    ? Image.network(
                                        album.imgUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _AlbumPlaceholder(scheme: scheme),
                                      )
                                    : _AlbumPlaceholder(scheme: scheme),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                album.displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                album.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  _downloadAlbum(context, album);
                                },
                                icon: const Icon(
                                    Icons.download_for_offline_rounded,
                                    size: 25),
                                label: const Text('Télécharger l’album'),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Text(
                      'Pistes',
                      style: textTheme.labelLarge?.copyWith(
                        letterSpacing: 0.6,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<DeezerSearchResult>>(
                      future: tracksFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: scheme.error),
                              ),
                            ),
                          );
                        }
                        final tracks = snapshot.data ?? [];
                        if (tracks.isEmpty) {
                          return Center(
                            child: Text(
                              'Aucune piste',
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return Consumer(
                          builder: (context, ref, _) {
                            final downloadingTrackId =
                                ref.watch(downloadingTrackIdProvider);
                            final dlProgress =
                                ref.watch(downloadProgressProvider);
                            return ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 28),
                              itemCount: tracks.length,
                              itemBuilder: (context, i) {
                                final track = tracks[i];
                                final isDl = downloadingTrackId == track.id;
                                return _AlbumTrackSheetRow(
                                  track: track,
                                  isDownloading: isDl,
                                  progress: isDl ? dlProgress : null,
                                  onDownload: () {
                                    ref
                                        .read(downloadSessionProvider.notifier)
                                        .enqueue(
                                          track,
                                          trackParentAlbum: album,
                                        );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Ligne piste dans la bottom sheet album.
class _AlbumTrackSheetRow extends StatelessWidget {
  const _AlbumTrackSheetRow({
    required this.track,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
  });

  final DeezerSearchResult track;
  final bool isDownloading;
  final double? progress;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final p = progress?.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        // Ligne plate, sans carte colorée — cohérent avec la liste principale.
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isDownloading ? null : onDownload,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: track.imgUrl != null && track.imgUrl!.isNotEmpty
                        ? Image.network(
                            track.imgUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _TrackThumbMini(scheme: scheme),
                          )
                        : _TrackThumbMini(scheme: scheme),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      if (isDownloading) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: p != null && p > 0 ? p : null,
                            minHeight: 4,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isDownloading)
                  IconButton(
                    tooltip: 'Télécharger',
                    onPressed: onDownload,
                    icon: Icon(Icons.download_rounded,
                        color: scheme.onSurfaceVariant, size: 22),
                  )
                else
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: p != null && p > 0
                          ? Text(
                              '${(p * 100).round()}%',
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            )
                          : const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackThumbMini extends StatelessWidget {
  const _TrackThumbMini({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.music_note_rounded,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
    );
  }
}

// ——— Barre de recherche ———

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Artiste, morceau ou album…',
            hintStyle: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.65)),
            prefixIcon:
                Icon(Icons.search_rounded, color: scheme.primary, size: 26),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: scheme.onSurfaceVariant),
                    onPressed: onClear,
                  )
                : null,
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.35)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: scheme.primary, width: 2),
            ),
          ),
          onChanged: (_) => onChanged(),
          onSubmitted: onSubmit,
        );
      },
    );
  }
}

/// Puces de filtre par source (Tout / Deezer / YouTube / SoundCloud / Local).
class _SourceFilterChips extends ConsumerWidget {
  const _SourceFilterChips({required this.selected});

  final SearchSourceFilter selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget chip(String label, SearchSourceFilter filter,
        {Color? dot, IconData? icon}) {
      final isSelected = selected == filter;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                Icon(icon,
                    size: 14,
                    color: isSelected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant),
                const SizedBox(width: 6),
              ],
              Text(label),
            ],
          ),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) => ref
              .read(onlineSearchStateProvider.notifier)
              .setSourceFilter(filter),
          labelStyle: textTheme.labelLarge?.copyWith(
            color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
          backgroundColor: scheme.surfaceContainerHigh,
          selectedColor: scheme.primaryContainer,
          side: BorderSide.none,
          shape: const StadiumBorder(),
        ),
      );
    }

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('Tout', SearchSourceFilter.all),
          chip('Deezer', SearchSourceFilter.deezer,
              dot: const Color(0xFFB266FF)),
          chip('YouTube', SearchSourceFilter.youtube,
              dot: const Color(0xFFFF5A5A)),
          chip('SoundCloud', SearchSourceFilter.soundcloud,
              dot: const Color(0xFFFF9142)),
          chip('Local', SearchSourceFilter.local, icon: Icons.folder_rounded),
        ],
      ),
    );
  }
}

/// Bandeau affiché quand la recherche en ligne a échoué faute de réseau et
/// qu'on est basculé automatiquement sur la bibliothèque locale.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pas de connexion internet : résultats de ta bibliothèque locale.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ——— Section ———

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          // Icône seule, sans pastille colorée derrière.
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Text(
              '$count',
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ——— Album ———

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.artSize,
    required this.isDownloading,
    required this.progress,
    required this.onOpenDetails,
  });

  final DeezerSearchResult album;
  final double artSize;
  final bool isDownloading;
  final double? progress;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final p = progress?.clamp(0.0, 1.0);

    return SizedBox(
      width: artSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            // Plate, sans carte colorée derrière : la pochette seule, comme
            // partout ailleurs dans l'app (AlbumCard, SongCard, ArtistCard…).
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isDownloading ? null : onOpenDetails,
              child: SizedBox(
                width: artSize,
                height: artSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    album.imgUrl != null && album.imgUrl!.isNotEmpty
                        ? Image.network(
                            album.imgUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _AlbumPlaceholder(scheme: scheme),
                          )
                        : _AlbumPlaceholder(scheme: scheme),
                    if (isDownloading)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Center(
                          child: Text(
                            p != null && p > 0 ? '${(p * 100).round()}%' : '…',
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    if (isDownloading)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 14,
                        child:
                            _LinearDownloadBar(progress: p, brightTrack: true),
                      ),
                    if (!isDownloading)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: FilledButton(
                          onPressed: onOpenDetails,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 40),
                          ),
                          child:
                              const Icon(Icons.queue_music_rounded, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            album.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumPlaceholder extends StatelessWidget {
  const _AlbumPlaceholder({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.album_rounded,
            size: 44, color: scheme.onSurfaceVariant.withValues(alpha: 0.45)),
      ),
    );
  }
}

// ——— Morceau ———

/// Libellé court par source, réutilisé par la carte de résultat et la
/// feuille de détail d'un morceau.
String sourceBadgeLabel(ResultSource source) => switch (source) {
      ResultSource.deezer => 'DZ',
      ResultSource.youtube => 'YT',
      ResultSource.soundcloud => 'SC',
    };

/// Couleur associée à chaque source, idem.
Color sourceBadgeColor(ResultSource source) => switch (source) {
      ResultSource.deezer => const Color(0xFFB266FF),
      ResultSource.youtube => const Color(0xFFFF5A5A),
      ResultSource.soundcloud => const Color(0xFFFF9142),
    };

class _TrackCard extends ConsumerWidget {
  const _TrackCard({
    required this.track,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
    required this.onStream,
  });

  final DeezerSearchResult track;
  final bool isDownloading;
  final double? progress;
  final VoidCallback onDownload;
  final VoidCallback onStream;

  String get _badgeLabel => sourceBadgeLabel(track.source);

  Color get _badgeColor => sourceBadgeColor(track.source);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final p = progress?.clamp(0.0, 1.0);

    final playerState = ref.watch(audioPlayerProvider);
    final streamId = 'stream_${track.source.name}_${track.id}';
    final isActive = playerState.currentSong?.id == streamId;
    final isPlayingThis = isActive && playerState.isPlaying;

    return Material(
      // Ligne plate sur le fond de la page par défaut (comme les autres
      // listes de l'app) ; seule la piste en cours de lecture ressort avec
      // une légère teinte, pas de carte colorée systématique.
      color: isActive
          ? scheme.primaryContainer.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDownloading ? null : onStream,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    track.imgUrl != null && track.imgUrl!.isNotEmpty
                        ? Image.network(
                            track.imgUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _TrackThumbFallback(scheme: scheme),
                          )
                        : _TrackThumbFallback(scheme: scheme),
                    if (isActive)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.4),
                        child: Icon(Icons.equalizer_rounded,
                            color: scheme.primary, size: 20),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color:
                                  isActive ? scheme.primary : scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _badgeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _badgeLabel,
                            style: TextStyle(
                              color: _badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (isDownloading) ...[
                      const SizedBox(height: 8),
                      _LinearDownloadBar(progress: p, brightTrack: false),
                      if (p != null && p > 0)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(p * 100).round()}%',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              if (!isDownloading) ...[
                IconButton(
                  tooltip: 'Télécharger',
                  onPressed: onDownload,
                  icon: Icon(Icons.download_rounded,
                      color: scheme.onSurfaceVariant, size: 22),
                ),
                IconButton(
                  tooltip: isPlayingThis ? 'Pause' : 'Écouter',
                  onPressed: onStream,
                  icon: Icon(
                    isPlayingThis
                        ? Icons.pause_circle_rounded
                        : Icons.play_circle_rounded,
                    color: isActive ? scheme.primary : scheme.onSurface,
                    size: 30,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackThumbFallback extends StatelessWidget {
  const _TrackThumbFallback({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.music_note_rounded,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
    );
  }
}

// ——— Progress ———

class _LinearDownloadBar extends StatelessWidget {
  const _LinearDownloadBar({required this.progress, required this.brightTrack});

  final double? progress;
  final bool brightTrack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = progress;
    final bg = brightTrack ? Colors.white24 : scheme.surfaceContainerHighest;
    final fg = brightTrack ? scheme.primaryContainer : scheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 5,
        child: p == null || p <= 0
            ? LinearProgressIndicator(
                minHeight: 5, backgroundColor: bg, color: fg)
            : LinearProgressIndicator(
                value: p,
                minHeight: 5,
                backgroundColor: bg,
                color: fg,
              ),
      ),
    );
  }
}

// ——— États vides / erreur ———

/// Sablier animé pour l’état « recherche en cours » (Flutter natif, sans dépendance).
class _RotatingSearchIcon extends StatefulWidget {
  const _RotatingSearchIcon();

  @override
  State<_RotatingSearchIcon> createState() => _RotatingSearchIconState();
}

class _RotatingSearchIconState extends State<_RotatingSearchIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RotationTransition(
      turns: _controller,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.25),
              scheme.tertiary.withValues(alpha: 0.2),
            ],
          ),
        ),
        child: Icon(
          Icons.hourglass_top_rounded,
          size: 40,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _StatePage extends StatelessWidget {
  const _StatePage({
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.iconGradient = false,
    this.isError = false,
    this.showProgress = false,
  }) : assert(
          leading != null || icon != null,
          'Fournir icon ou leading',
        );

  final IconData? icon;

  /// Si non null, remplace l’affichage basé sur [icon] (ex. icône animée).
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool iconGradient;
  final bool isError;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null)
              leading!
            else if (iconGradient)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.25),
                      scheme.tertiary.withValues(alpha: 0.2),
                    ],
                  ),
                ),
                child: Icon(icon!, size: 52, color: scheme.primary),
              )
            else
              Icon(
                icon!,
                size: 56,
                color: isError
                    ? scheme.error
                    : scheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle ?? '',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            if (showProgress) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: scheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
