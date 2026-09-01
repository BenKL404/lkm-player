import 'package:flutter/material.dart';
import 'package:musio/features/for_you/presentation/screens/for_you_screen.dart';
import 'package:musio/features/home/presentation/screens/home_screen.dart';
import 'package:musio/features/online/presentation/screens/online_screen.dart';
import 'package:musio/features/settings/presentation/screens/settings_screen.dart';

/// Coquille principale de l'app : navigation persistante à 4 destinations
/// (Accueil / Découvrir / Bibliothèque / Réglages). Chaque onglet garde son
/// propre mini-player (voir [ForYouScreen], [OnlineScreen], [OfflineHomeScreen],
/// [SettingsScreen]) ; cet écran ne fournit que la barre de navigation
/// partagée, visible sur les 4 onglets — y compris Réglages.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tabIndex = 0;
  late final PageController _pageController = PageController(initialPage: _tabIndex);

  // Chaque onglet est enveloppé dans [_KeepAlivePage] : le PageView ne doit
  // jamais réinitialiser leur état (recherche en cours, sous-onglet actif,
  // position de scroll) quand ils sortent de l'écran pendant une transition.
  static const List<Widget> _tabs = [
    _KeepAlivePage(child: ForYouScreen()),
    _KeepAlivePage(child: OnlineScreen(showBackButton: false)),
    _KeepAlivePage(child: OfflineHomeScreen()),
    _KeepAlivePage(child: SettingsScreen(showBackButton: false)),
  ];

  // Libellés en anglais, comme dans la maquette Stitch (Home / Search /
  // Library / Settings), même si le reste de l'app est en français.
  static const _destinations = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    (icon: Icons.search_outlined, selectedIcon: Icons.search, label: 'Search'),
    (icon: Icons.library_music_outlined, selectedIcon: Icons.library_music, label: 'Library'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Depuis un tap sur la barre de navigation : glisse jusqu'à l'onglet visé
  /// (vers la gauche si plus loin dans la liste, vers la droite si avant).
  void _onTap(int index) {
    if (index == _tabIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _tabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // PageView natif : balayage au doigt ET tap sur la nav bar animent la
      // même transition glissée (gauche <-> droite selon la direction).
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _tabs,
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: _NavPill(
                      icon: _destinations[i].icon,
                      selectedIcon: _destinations[i].selectedIcon,
                      label: _destinations[i].label,
                      selected: i == _tabIndex,
                      onTap: () => _onTap(i),
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

/// Puce de navigation : icône + libellé, pastille teal pleine quand
/// sélectionné (fond + icône + texte dans la même teinte token).
class _NavPill extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Semantics(
          label: label,
          selected: selected,
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? selectedIcon : icon, color: fg, size: 22),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

/// Empêche le [PageView] de détruire l'état d'un onglet quand il glisse hors
/// de l'écran pendant une transition (texte de recherche, sous-onglet actif,
/// position de scroll…) : sans ça, chaque swipe repartirait de zéro.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
