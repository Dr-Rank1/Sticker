import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../permissions/media_permission_dialog.dart';
import '../theme/app_colors.dart';
import 'onboarding_controller.dart';

class OnboardingPageData {
  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const kOnboardingPages = [
  OnboardingPageData(
    icon: Icons.link_rounded,
    title: 'Paste TikTok links',
    body: 'Drop in any video URL. We fetch a clean clip so you can turn a moment into a sticker.',
  ),
  OnboardingPageData(
    icon: Icons.auto_fix_high_rounded,
    title: 'Edit & remove backgrounds',
    body: 'Trim, add text, and cut out the subject on this device. No account. No uploads.',
  ),
  OnboardingPageData(
    icon: Icons.chat_rounded,
    title: 'Export to WhatsApp',
    body: 'Pack your stickers and add them to WhatsApp in a tap. Always free, forever.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  var _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index >= kOnboardingPages.length - 1;

  Future<void> _next() async {
    if (_isLast) {
      await _finish();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (!mounted) return;
    await showMediaPermissionDialog(context);
    if (!mounted) return;
    await ref.read(onboardingCompleteProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final brightness = Theme.of(context).brightness;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('onboarding-skip'),
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    key: const Key('onboarding-pager'),
                    controller: _controller,
                    itemCount: kOnboardingPages.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) {
                      return _OnboardingSlide(page: kOnboardingPages[index]);
                    },
                  ),
                ),
                SmoothPageIndicator(
                  controller: _controller,
                  count: kOnboardingPages.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: colors.accent,
                    dotColor: colors.border,
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3.2,
                    spacing: 8,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: _isLast
                        ? const Key('onboarding-get-started')
                        : const Key('onboarding-next'),
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(_isLast ? 'Get started' : 'Next'),
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

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.page});

  final OnboardingPageData page;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: colors.border),
            ),
            child: Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(page.icon, size: 40, color: colors.accent),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: textTheme.displaySmall?.copyWith(fontSize: 30, height: 1.15),
          ),
          const SizedBox(height: 14),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
