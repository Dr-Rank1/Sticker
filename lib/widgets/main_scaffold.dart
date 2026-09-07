import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/community_screen.dart';
import '../screens/create_screen.dart';
import '../screens/library_screen.dart';
import '../state/navigation_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tiktok/tiktok_import_sheet.dart';

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
        body: IndexedStack(
          index: tab.index,
          children: const [
            LibraryScreen(),
            CreateScreen(),
            CommunityScreen(),
          ],
        ),
        bottomNavigationBar: StikkBottomBar(
          current: tab,
          onSelect: (next) {
            ref.read(navigationProvider.notifier).select(next);
            if (next == AppTab.create) {
              showTiktokImportSheet(context);
            }
          },
        ),
      ),
    );
  }
}

class StikkBottomBar extends StatelessWidget {
  const StikkBottomBar({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 84,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 64,
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
                      key: const Key('nav-library'),
                      icon: Icons.grid_view_rounded,
                      label: 'Library',
                      selected: current == AppTab.library,
                      onTap: () => onSelect(AppTab.library),
                    ),
                  ),
                  const SizedBox(width: 72),
                  Expanded(
                    child: _NavItem(
                      key: const Key('nav-community'),
                      icon: Icons.public_rounded,
                      label: 'Community',
                      selected: current == AppTab.community,
                      onTap: () => onSelect(AppTab.community),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -4,
              child: _CreateFab(
                key: const Key('nav-create'),
                selected: current == AppTab.create,
                onTap: () => onSelect(AppTab.create),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateFab extends StatelessWidget {
  const _CreateFab({
    super.key,
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.accent,
                  colors.accentDim,
                ],
              ),
              border: selected
                  ? Border.all(color: colors.accentOn, width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.add_rounded,
              color: colors.accentOn,
              size: 32,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? colors.accent : colors.navInactive,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
          ),
        ],
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
    final color = selected ? colors.accent : colors.navInactive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
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
