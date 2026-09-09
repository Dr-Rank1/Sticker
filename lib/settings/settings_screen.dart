import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/theme_controller.dart';
import '../storage/storage_utility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  var _clearing = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final usage = ref.watch(storageUsageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: RefreshIndicator(
        onRefresh: _refreshUsage,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              l10n.storage,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.storageDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                side: BorderSide(color: colors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: usage.when(
                  loading: () => const SizedBox(
                    height: 116,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => _StorageError(onRetry: _refreshUsage),
                  data: (value) => Column(
                    children: [
                      _UsageRow(
                        icon: Icons.folder_rounded,
                        title: l10n.appDocuments,
                        subtitle: l10n.savedPacksAndStickers,
                        value: formatStorageBytes(value.documentsBytes),
                      ),
                      const SizedBox(height: 18),
                      _UsageRow(
                        icon: Icons.cached_rounded,
                        title: l10n.temporaryCache,
                        subtitle: l10n.rawVideosAndWorkingFiles,
                        value: formatStorageBytes(value.cacheBytes),
                      ),
                      const SizedBox(height: 18),
                      Divider(color: colors.border),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.totalAppStorage,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            formatStorageBytes(value.totalBytes),
                            key: const Key('total-storage-usage'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('clear-cache-button'),
                          onPressed: _clearing ? null : _clearCache,
                          icon: _clearing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cleaning_services_rounded),
                          label: Text(
                            _clearing ? l10n.clearing : l10n.clearCache,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.savedPacksNotDeleted,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.appearance,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                side: BorderSide(color: colors.border),
              ),
              child: Column(
                children: [
                  _ThemeOption(
                    icon: Icons.brightness_auto_rounded,
                    label: l10n.systemTheme,
                    selected: themeMode == ThemeMode.system,
                    onTap: () => _setTheme(ThemeMode.system),
                  ),
                  Divider(height: 1, indent: 56, color: colors.border),
                  _ThemeOption(
                    icon: Icons.light_mode_rounded,
                    label: l10n.lightTheme,
                    selected: themeMode == ThemeMode.light,
                    onTap: () => _setTheme(ThemeMode.light),
                  ),
                  Divider(height: 1, indent: 56, color: colors.border),
                  _ThemeOption(
                    icon: Icons.dark_mode_rounded,
                    label: l10n.darkTheme,
                    selected: themeMode == ThemeMode.dark,
                    onTap: () => _setTheme(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setTheme(ThemeMode mode) {
    ref.read(themeModeProvider.notifier).setMode(mode);
  }

  Future<void> _refreshUsage() async {
    ref.invalidate(storageUsageProvider);
    await ref.read(storageUsageProvider.future);
  }

  Future<void> _clearCache() async {
    setState(() => _clearing = true);
    try {
      final result = await ref.read(storageUtilityProvider).clearCache();
      ref.invalidate(storageUsageProvider);
      await ref.read(storageUsageProvider.future);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.bytesFreed == 0
                  ? context.l10n.cacheAlreadyClear
                  : context.l10n.freedStorage(
                      formatStorageBytes(result.bytesFreed),
                    ),
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.couldNotClearCache)));
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, color: colors.accentDim),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: selected ? colors.accent : colors.textSecondary,
      ),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colors.accent)
          : null,
    );
  }
}

class _StorageError extends StatelessWidget {
  const _StorageError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(context.l10n.couldNotReadStorage),
        ),
      ),
    );
  }
}
