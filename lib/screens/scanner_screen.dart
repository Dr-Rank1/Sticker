import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tiktok/apify_service.dart';
import '../tiktok/comment_sticker_sheet.dart';
import '../tiktok/tiktok_comment_service.dart';
import '../tiktok/tiktok_url.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  static const _scannerLoadingSize = 220.0;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _checkingClipboard = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    if (_checkingClipboard || _isLoading || !mounted) return;
    _checkingClipboard = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final url = extractTikTokClipboardUrl(data?.text);
      if (url == null || !mounted) return;

      _controller.text = url;
      _controller.selection = TextSelection.collapsed(offset: url.length);

      // Consume the link before scanning so another lifecycle event cannot
      // trigger the same scan.
      await Clipboard.setData(const ClipboardData(text: ''));
      if (!mounted) return;
      await _scan(url);
    } on PlatformException {
      // Clipboard access may be denied by the OS or device privacy settings.
    } finally {
      _checkingClipboard = false;
    }
  }

  Future<void> _onScanPressed() async {
    final url = extractTikTokUrl(_controller.text);
    if (url == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.invalidTikTokLink),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    await _scan(url);
  }

  Future<void> _scan(String videoUrl) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    List<CommentSticker> stickers = const [];
    String? errorMessage;
    try {
      stickers = await ref
          .read(apifyServiceProvider)
          .fetchCommentStickers(videoUrl);
    } on ApifyException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = context.l10n.couldNotScanComments;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (errorMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    await showCommentStickerSheet(context, stickers: stickers);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.scanner, style: textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              l10n.scannerSubtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: _scannerLoadingSize,
                        height: _scannerLoadingSize,
                        child: Lottie.asset(
                          // Place your downloaded quirky animation file at
                          // assets/animations/scanner_loading.json
                          'assets/animations/scanner_loading.json',
                          key: const Key('scanner-loading-lottie'),
                          repeat: true,
                          fit: BoxFit.contain,
                          width: _scannerLoadingSize,
                          height: _scannerLoadingSize,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 2),
                        TextField(
                          key: const Key('scanner-tiktok-field'),
                          controller: _controller,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          minLines: 3,
                          maxLines: 5,
                          onSubmitted: (_) => _onScanPressed(),
                          style: textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.pasteTikTokVideoLink,
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: colors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 22,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLg,
                              ),
                              borderSide: BorderSide(
                                color: colors.border,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLg,
                              ),
                              borderSide: BorderSide(
                                color: colors.border,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLg,
                              ),
                              borderSide: BorderSide(
                                color: colors.accent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 58,
                          child: FilledButton(
                            key: const Key('scanner-scan-button'),
                            onPressed: _onScanPressed,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.textPrimary,
                              foregroundColor: colors.background,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLg,
                                ),
                              ),
                              textStyle: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            child: Text(l10n.scanCommentsForStickers),
                          ),
                        ),
                        const Spacer(flex: 3),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
