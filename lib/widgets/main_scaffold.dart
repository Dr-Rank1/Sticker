import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accessibility/accessible_tap.dart';
import '../l10n/l10n.dart';
import '../screens/community_screen.dart';
import '../screens/library_screen.dart';
import '../screens/scanner_screen.dart';
import '../state/navigation_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

export '../tiktok/tiktok_url.dart' show extractTikTokClipboardUrl;

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(navigationProvider);
    final colors = context.colors;
    final brightness = Theme.of(context).brightness;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: colors.background,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: colors.background,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: Scaffold(
        extendBody: true,
        floatingActionButton:
            tab == AppTab.library ? const LibraryCreateFab() : null,
        body: IndexedStack(
          index: tab.index,
          children: const [
            ScannerScreen(),
            LibraryScreen(),
            CommunityScreen(),
          ],
        ),
        bottomNavigationBar: StickrBottomBar(
          current: tab,
          onSelect: (next) => ref.read(navigationProvider.notifier).select(next),
        ),
      ),
    );
  }
}

class StickrBottomBar extends StatelessWidget {
  const StickrBottomBar({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        constraints: BoxConstraints(
          minHeight: 70,
          maxHeight: AppTheme.scaled(context, 78).clamp(70.0, 96.0),
        ),
        decoration: BoxDecoration(
          color: colors.navBar,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                key: const Key('nav-scanner'),
                icon: Icons.document_scanner_outlined,
                label: l10n.scanner,
                selected: current == AppTab.scanner,
                onTap: () => onSelect(AppTab.scanner),
              ),
            ),
            Expanded(
              child: _NavItem(
                key: const Key('nav-library'),
                icon: Icons.grid_view_rounded,
                label: l10n.myPacks,
                selected: current == AppTab.library,
                onTap: () => onSelect(AppTab.library),
              ),
            ),
            Expanded(
              child: _NavItem(
                key: const Key('nav-community'),
                icon: Icons.local_fire_department_outlined,
                label: l10n.trending,
                selected: current == AppTab.community,
                onTap: () => onSelect(AppTab.community),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
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
    final l10n = context.l10n;
    final color = selected ? colors.accent : colors.navInactive;

    return AccessibleTap(
      label: label,
      hint: selected ? l10n.currentTab : l10n.switchesToTab(label),
      selected: selected,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
