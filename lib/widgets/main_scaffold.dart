import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discover/discover_screen.dart';
import '../screens/community_screen.dart';
import '../screens/create_screen.dart';
import '../screens/library_screen.dart';
import '../state/navigation_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tiktok/comment_sticker_sheet.dart';
import '../tiktok/tiktok_import_sheet.dart';

final _tiktokClipboardUrlPattern = RegExp(
  r'https?://(?:(?:www|m|vm|vt)\.)?tiktok\.com/[^\s]+',
  caseSensitive: false,
);

String? extractTikTokClipboardUrl(String? text) {
  if (text == null) return null;
  final match = _tiktokClipboardUrlPattern.firstMatch(text.trim())?.group(0);
  return match?.replaceFirst(RegExp(r'''[.,!?;:'")\]}]+$'''), '');
}

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with WidgetsBindingObserver {
  bool _checkingClipboard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    if (_checkingClipboard || !mounted) return;
    _checkingClipboard = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final url = extractTikTokClipboardUrl(data?.text);
      if (url == null || !mounted) return;

      // Consume the link before opening the sheet so another lifecycle event
      // cannot trigger the same scan.
      await Clipboard.setData(const ClipboardData(text: ''));
      if (!mounted) return;
      await showCommentStickerSheet(context, videoUrl: url);
    } on PlatformException {
      // Clipboard access may be denied by the OS or device privacy settings.
    } finally {
      _checkingClipboard = false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            DiscoverScreen(),
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
      child: Container(
        height: 70,
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
            Expanded(
              child: _NavItem(
                key: const Key('nav-create'),
                icon: Icons.add_circle_rounded,
                label: 'Create',
                selected: current == AppTab.create,
                onTap: () => onSelect(AppTab.create),
              ),
            ),
            Expanded(
              child: _NavItem(
                key: const Key('nav-discover'),
                icon: Icons.auto_awesome_rounded,
                label: 'Discover',
                selected: current == AppTab.discover,
                onTap: () => onSelect(AppTab.discover),
              ),
            ),
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
