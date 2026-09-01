import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:musio/core/routing/app_router.dart';
import 'package:musio/core/theme/app_theme.dart';
import 'package:musio/features/download/presentation/providers/download_provider.dart';
import 'package:musio/features/music/presentation/providers/music_provider.dart';
import 'package:musio/features/settings/presentation/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  /// false quand l'écran est affiché comme onglet de [MainScreen] (la barre
  /// de navigation reste alors visible en dessous, pas de flèche retour) ;
  /// true (défaut) quand poussé depuis ailleurs (raccourci avatar/menu).
  final bool showBackButton;

  const SettingsScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minDuration = ref.watch(minSongDurationProvider);
    final isOnlineEnabled = ref.watch(onlineFeatureEnabledProvider);
    final themeMode = ref.watch(themeModeSettingProvider);
    final accentColor = ref.watch(accentColorSettingProvider);
    final sleepTimerDefault = ref.watch(sleepTimerDefaultMinutesProvider);

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBackButton,
        leading: showBackButton ? const BackButton() : null,
        title: const Text('Paramètres'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SettingsSection(
              icon: Icons.palette_outlined,
              title: 'Apparence',
              children: [
                themeMode.when(
                  data: (modeIndex) => ListTile(
                    title: const Text('Thème'),
                    subtitle: Text(_themeModeLabel(modeIndex)),
                    leading: const Icon(Icons.brightness_6_outlined),
                    onTap: () => _showThemeModeDialog(context, ref),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                accentColor.when(
                  data: (colorIndex) {
                    final idx =
                        colorIndex.clamp(0, AppTheme.accentColors.length - 1);
                    return ListTile(
                      title: const Text('Couleur principale'),
                      subtitle: Text(AppTheme.accentColorNames[idx]),
                      leading: const Icon(Icons.color_lens_outlined),
                      trailing: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColors[idx],
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.outlineVariant, width: 2),
                        ),
                      ),
                      onTap: () => _showAccentColorDialog(context, ref, colorIndex),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                sleepTimerDefault.when(
                  data: (minutes) => ListTile(
                    title: const Text('Minuteur de sommeil (défaut)'),
                    subtitle: Text(minutes == 0 ? 'Désactivé' : '$minutes min'),
                    leading: const Icon(Icons.timer_outlined),
                    onTap: () => _showSleepTimerDefaultDialog(context, ref),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),

            _SettingsSection(
              icon: Icons.cast_connected_rounded,
              title: 'Serveur & Sources',
              children: [
                isOnlineEnabled.when(
                  data: (enabled) => SwitchListTile(
                    title: const Text('Fonctionnalités en ligne'),
                    subtitle: const Text(
                        'Afficher le bouton pour découvrir de la musique en ligne'),
                    value: enabled,
                    onChanged: (value) {
                      ref
                          .read(onlineFeatureEnabledProvider.notifier)
                          .setEnabled(value);
                    },
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                ),
                ref.watch(downloadApiBaseUrlProvider).when(
                  data: (baseUrl) => ListTile(
                    leading: const Icon(Icons.cloud_download_outlined),
                    title: const Text('Serveur de téléchargement'),
                    // Toujours masqué : jamais affiché en clair, même une fois configuré.
                    subtitle: Text(
                      baseUrl.isEmpty
                          ? 'Non configuré (défaut : serveur LKM Player)'
                          : '•' * 16,
                    ),
                    trailing: const Icon(Icons.lock_outline, size: 18),
                    onTap: () => _showDownloadApiUrlDialog(context, ref, baseUrl),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                ref.watch(downloadApiKeyProvider).when(
                  data: (apiKey) => ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Clé API'),
                    subtitle: Text(
                      apiKey.isEmpty ? 'Non configurée (facultatif)' : '•' * 12,
                    ),
                    trailing: apiKey.isEmpty ? null : const Icon(Icons.lock_outline, size: 18),
                    onTap: () => _showDownloadApiKeyDialog(context, ref, apiKey),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                ref.watch(downloadDirectoryPathProvider).when(
                  data: (dirPath) => ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Dossier des téléchargements'),
                    subtitle: Text(
                      dirPath,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: dirPath));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Chemin copié. Collez-le dans votre gestionnaire de fichiers pour ouvrir le dossier.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  loading: () => const ListTile(
                    leading: Icon(Icons.folder_outlined),
                    title: Text('Dossier des téléchargements'),
                    subtitle: Text('Chargement…'),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),

            _SettingsSection(
              icon: Icons.library_music_outlined,
              title: 'Bibliothèque',
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Rescanner la bibliothèque'),
                  subtitle: const Text('Chercher les nouveaux fichiers musicaux'),
                  onTap: () {
                    ref.read(musicProvider.notifier).rescanLibrary();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Scan de la bibliothèque démarré...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                minDuration.when(
                  data: (duration) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          'Durée minimale des chansons',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Ignorer les fichiers audio de moins de ${duration}s',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Slider(
                        value: duration.toDouble(),
                        min: 0,
                        max: 60,
                        divisions: 12,
                        label: '${duration.round()}s',
                        onChanged: (value) {
                          ref
                              .read(minSongDurationProvider.notifier)
                              .setDuration(value.round());
                        },
                      ),
                    ],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                ),
                ref.watch(excludeMessagingAppsProvider).when(
                      data: (excluded) => SwitchListTile(
                        title: const Text('Filtrer les apps de messagerie'),
                        subtitle: const Text(
                          'Active le filtrage des fichiers audio provenant des apps de chat',
                        ),
                        secondary: const Icon(Icons.chat_bubble_outline),
                        value: excluded,
                        onChanged: (value) async {
                          await ref
                              .read(excludeMessagingAppsProvider.notifier)
                              .setEnabled(value);
                          ref.read(musicProvider.notifier).rescanLibrary();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value
                                  ? 'Filtrage activé. Scan en cours…'
                                  : 'Filtrage désactivé. Scan en cours…'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                ref.watch(excludeMessagingAppsProvider).maybeWhen(
                      data: (excluded) => excluded
                          ? Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Configurer par application',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ),
                                _buildAppToggle(
                                  context,
                                  ref,
                                  icon: Icons.message,
                                  label: 'WhatsApp',
                                  subtitle: 'Exclure les audios WhatsApp',
                                  value: ref.watch(excludeWhatsAppProvider),
                                  onChanged: (v) => ref
                                      .read(excludeWhatsAppProvider.notifier)
                                      .setEnabled(v),
                                ),
                                _buildAppToggle(
                                  context,
                                  ref,
                                  icon: Icons.send,
                                  label: 'Telegram',
                                  subtitle:
                                      'Exclure les audios Telegram (bots inclus)',
                                  value: ref.watch(excludeTelegramProvider),
                                  onChanged: (v) => ref
                                      .read(excludeTelegramProvider.notifier)
                                      .setEnabled(v),
                                ),
                                _buildAppToggle(
                                  context,
                                  ref,
                                  icon: Icons.lock_outline,
                                  label: 'Signal',
                                  subtitle: 'Exclure les audios Signal',
                                  value: ref.watch(excludeSignalProvider),
                                  onChanged: (v) => ref
                                      .read(excludeSignalProvider.notifier)
                                      .setEnabled(v),
                                ),
                                _buildAppToggle(
                                  context,
                                  ref,
                                  icon: Icons.phone_in_talk_outlined,
                                  label: 'Viber',
                                  subtitle: 'Exclure les audios Viber',
                                  value: ref.watch(excludeViberProvider),
                                  onChanged: (v) => ref
                                      .read(excludeViberProvider.notifier)
                                      .setEnabled(v),
                                ),
                                _buildAppToggle(
                                  context,
                                  ref,
                                  icon: Icons.headset_mic_outlined,
                                  label: 'Discord',
                                  subtitle: 'Exclure les audios Discord',
                                  value: ref.watch(excludeDiscordProvider),
                                  onChanged: (v) => ref
                                      .read(excludeDiscordProvider.notifier)
                                      .setEnabled(v),
                                ),
                                _buildAppToggle(
                                  context,
                                  ref,
                                  icon: Icons.more_horiz,
                                  label: 'Autres',
                                  subtitle: 'Skype, Line, WeChat, Snapchat, Slack…',
                                  value: ref.watch(excludeOtherMessagingProvider),
                                  onChanged: (v) => ref
                                      .read(excludeOtherMessagingProvider.notifier)
                                      .setEnabled(v),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
              ],
            ),

            _SettingsSection(
              icon: Icons.storage_rounded,
              title: 'Stockage & Cache',
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('Vider le cache des pochettes'),
                  subtitle:
                      const Text('Supprime les images des albums téléchargées'),
                  onTap: () async {
                    await ref.read(musicProvider.notifier).clearArtworkCache();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cache des pochettes vidé.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),

            _SettingsSection(
              icon: Icons.bar_chart_rounded,
              title: 'Statistiques',
              children: [
                ListTile(
                  leading: const Icon(Icons.insights_rounded),
                  title: const Text('Statistiques d\'écoute'),
                  subtitle: const Text('Titres, durée, top écoutes'),
                  onTap: () => context.push(AppRouter.stats),
                ),
              ],
            ),

            _SettingsSection(
              icon: Icons.info_outline_rounded,
              title: 'À propos',
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('À propos de LKM Player'),
                  onTap: () => context.push(AppRouter.about),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _themeModeLabel(int index) {
    switch (index) {
      case 0:
        return 'Clair';
      case 1:
        return 'Sombre';
      default:
        return 'Système';
    }
  }

  void _showThemeModeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(themeModeSettingProvider).valueOrNull ?? 1;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thème'),
        content: RadioGroup<int>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) {
              ref.read(themeModeSettingProvider.notifier).setMode(v);
            }
            Navigator.pop(context);
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                title: Text('Clair'),
                value: 0,
              ),
              RadioListTile<int>(
                title: Text('Sombre'),
                value: 1,
              ),
              RadioListTile<int>(
                title: Text('Système'),
                value: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccentColorDialog(BuildContext context, WidgetRef ref, int current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Couleur principale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            AppTheme.accentColors.length,
            (index) {
              final color = AppTheme.accentColors[index];
              final name = AppTheme.accentColorNames[index];
              final isSelected = index == current.clamp(0, AppTheme.accentColors.length - 1);
              return InkWell(
                onTap: () {
                  ref.read(accentColorSettingProvider.notifier).setColorIndex(index);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                      if (isSelected) ...[
                        const Spacer(),
                        Icon(Icons.check_rounded,
                            color: Theme.of(context).colorScheme.primary),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDownloadApiUrlDialog(BuildContext context, WidgetRef ref, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Serveur de téléchargement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              // Masquée en permanence : ni l'ancienne ni la nouvelle valeur
              // ne doivent jamais s'afficher en clair.
              obscureText: true,
              obscuringCharacter: '•',
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'https://…',
                labelText: 'URL de l\'API',
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Valeur masquée par sécurité. Laisser vide pour revenir au serveur par défaut.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(downloadApiBaseUrlProvider.notifier).setBaseUrl(controller.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showDownloadApiKeyDialog(BuildContext context, WidgetRef ref, String currentKey) {
    final controller = TextEditingController(text: currentKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clé API'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              // Masquée en permanence, jamais affichée en clair.
              obscureText: true,
              obscuringCharacter: '•',
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'Laisser vide si non requis',
                labelText: 'X-API-Key',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Valeur masquée par sécurité.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(downloadApiKeyProvider.notifier).setApiKey(controller.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerDefaultDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(sleepTimerDefaultMinutesProvider).valueOrNull ?? 0;
    const options = [0, 15, 30, 45, 60];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Minuteur de sommeil (défaut)'),
        content: SingleChildScrollView(
          child: RadioGroup<int>(
            groupValue: current,
            onChanged: (v) {
              if (v != null) {
                ref
                    .read(sleepTimerDefaultMinutesProvider.notifier)
                    .setDefaultMinutes(v);
              }
              Navigator.pop(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map(
                    (m) => RadioListTile<int>(
                      title: Text(m == 0 ? 'Désactivé' : '$m min'),
                      value: m,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildAppToggle(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required String subtitle,
    required AsyncValue<bool> value,
    required Future<void> Function(bool) onChanged,
  }) {
    return value.maybeWhen(
      data: (excluded) => SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 32),
        secondary: Icon(icon, size: 20),
        title: Text(label),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        value: excluded,
        onChanged: (val) async {
          await onChanged(val);
          ref.read(musicProvider.notifier).rescanLibrary();
        },
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Regroupe des réglages liés dans une carte arrondie avec un en-tête
/// icône + titre, comme dans la maquette Paramètres.
class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: scheme.primaryContainer, size: 22),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
