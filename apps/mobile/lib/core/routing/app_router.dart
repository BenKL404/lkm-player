import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musio/features/album/presentation/screens/album_details_screen.dart';
import 'package:musio/features/artist/presentation/screens/artist_details_screen.dart';
import 'package:musio/features/download/presentation/screens/downloads_screen.dart';
import 'package:musio/features/home/presentation/screens/main_screen.dart';
import 'package:musio/features/home/presentation/screens/splash_screen.dart';
import 'package:musio/features/music/data/models/song_model.dart';
import 'package:musio/features/online/presentation/screens/online_screen.dart';
import 'package:musio/features/player/presentation/screens/lyrics_full_screen.dart';
import 'package:musio/features/player/presentation/screens/now_playing_screen.dart';
import 'package:musio/features/player/presentation/screens/queue_full_screen.dart';
import 'package:musio/features/playlist/presentation/screens/playlist_details_screen.dart';
import 'package:musio/features/search/presentation/screens/search_screen.dart';
import 'package:musio/features/settings/presentation/screens/about_screen.dart';
import 'package:musio/features/settings/presentation/screens/settings_screen.dart';
import 'package:musio/features/settings/presentation/screens/stats_screen.dart';
import 'package:musio/shared/screens/song_list_screen.dart';

/// Transition glissée gauche/droite pour toutes les pages « secondaires »
/// (tout sauf le splash et l'accueil) : la nouvelle page arrive de la
/// droite, l'ancienne glisse légèrement vers la gauche en profondeur — au
/// pop c'est l'inverse. Même logique et même durée que le swipe entre
/// onglets de [MainScreen], pour une sensation cohérente dans toute l'app.
CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurveTween(curve: Curves.easeInOutCubic);
      final incoming =
          Tween(begin: const Offset(1, 0), end: Offset.zero).chain(curve);
      final outgoing =
          Tween(begin: Offset.zero, end: const Offset(-0.25, 0)).chain(curve);
      return SlideTransition(
        position: animation.drive(incoming),
        child: SlideTransition(
          position: secondaryAnimation.drive(outgoing),
          child: child,
        ),
      );
    },
  );
}

/// Transition glissée du bas vers le haut, façon feuille plein écran (Lecture
/// en cours, Paroles, File d'attente) : ces pages « couvrent » l'écran plutôt
/// que de s'enchaîner latéralement dans la pile de navigation.
CustomTransitionPage<void> _bottomSheetPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.easeOutQuart; // Courbe douce façon Apple
      final tween = Tween(begin: begin, end: end).chain(
        CurveTween(curve: curve),
      );
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}

class AppRouter {
  static const String splash = '/';
  static const String home = '/home';
  static const String online = '/online';
  static const String downloads = '/downloads';
  static const String nowPlaying = '/now-playing';
  static const String albumDetails = '/album/:id';
  static const String artistDetails = '/artist/:id';
  static const String playlistDetails = '/playlist/:id';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String about = '/settings/about';
  static const String stats = '/settings/stats';
  static const String songList = '/song-list';
  static const String lyrics = '/lyrics';
  static const String queue = '/queue';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      // Splash Screen (Initial Route)
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Coquille principale (Accueil / Découvrir / Bibliothèque / Réglages)
      GoRoute(
        path: home,
        name: 'home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Online
      GoRoute(
        path: online,
        name: 'online',
        pageBuilder: (context, state) =>
            _slidePage(state, const OnlineScreen()),
      ),

      // Téléchargements (file + historique)
      GoRoute(
        path: downloads,
        name: 'downloads',
        pageBuilder: (context, state) =>
            _slidePage(state, const DownloadsScreen()),
      ),

      // Settings
      GoRoute(
        path: settings,
        name: 'settings',
        pageBuilder: (context, state) =>
            _slidePage(state, const SettingsScreen()),
        routes: [
          GoRoute(
            path: 'stats',
            name: 'stats',
            pageBuilder: (context, state) =>
                _slidePage(state, const StatsScreen()),
          ),
          GoRoute(
            path: 'about',
            name: 'about',
            pageBuilder: (context, state) =>
                _slidePage(state, const AboutScreen()),
          ),
        ],
      ),

      // Song List (Generic)
      GoRoute(
        path: songList,
        name: 'song-list',
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is! Map<String, dynamic> ||
              extra['title'] is! String ||
              extra['songs'] is! List) {
            return _slidePage(
              state,
              Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Paramètres invalides',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go(home),
                        child: const Text('Retour à l\'accueil'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return _slidePage(
            state,
            SongListScreen(
              title: extra['title'] as String,
              songs: List<SongModel>.from(extra['songs'] as List),
            ),
          );
        },
      ),

      // Now Playing
      GoRoute(
        path: nowPlaying,
        name: 'now-playing',
        pageBuilder: (context, state) =>
            _bottomSheetPage(state, const NowPlayingScreen()),
      ),

      // Paroles plein écran (style Spotify)
      GoRoute(
        path: lyrics,
        name: 'lyrics',
        pageBuilder: (context, state) =>
            _bottomSheetPage(state, const LyricsFullScreen()),
      ),

      // File d'attente plein écran (style Spotify)
      GoRoute(
        path: queue,
        name: 'queue',
        pageBuilder: (context, state) =>
            _bottomSheetPage(state, const QueueFullScreen()),
      ),

      // Album Details
      GoRoute(
        path: albumDetails,
        name: 'album-details',
        pageBuilder: (context, state) {
          final albumId = state.pathParameters['id']!;
          return _slidePage(state, AlbumDetailsScreen(albumId: albumId));
        },
      ),

      // Artist Details
      GoRoute(
        path: artistDetails,
        name: 'artist-details',
        pageBuilder: (context, state) {
          final artistId = state.pathParameters['id']!;
          return _slidePage(state, ArtistDetailsScreen(artistId: artistId));
        },
      ),

      // Playlist Details
      GoRoute(
        path: playlistDetails,
        name: 'playlist-details',
        pageBuilder: (context, state) {
          final playlistId = state.pathParameters['id']!;
          return _slidePage(
              state, PlaylistDetailsScreen(playlistId: playlistId));
        },
      ),

      // Search
      GoRoute(
        path: search,
        name: 'search',
        pageBuilder: (context, state) =>
            _slidePage(state, const SearchScreen()),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page non trouvée',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(home),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    ),
  );
}
