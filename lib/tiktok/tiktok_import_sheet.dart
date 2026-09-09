import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../editor/editor_screen.dart';
import 'tiktok_import_controller.dart';

Future<void> showTiktokImportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const TiktokImportSheet(),
      );
    },
  );
}

class TiktokImportSheet extends ConsumerStatefulWidget {
  const TiktokImportSheet({super.key});

  @override
  ConsumerState<TiktokImportSheet> createState() => _TiktokImportSheetState();
}

class _TiktokImportSheetState extends ConsumerState<TiktokImportSheet> {
  final _linkController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tiktokImportProvider.notifier).reset();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _linkController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.clipboardEmpty)));
      return;
    }
    _linkController.text = text;
    _linkController.selection = TextSelection.collapsed(offset: text.length);
    setState(() {});
  }

  Future<void> _submit() async {
    await ref
        .read(tiktokImportProvider.notifier)
        .importFromLink(_linkController.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final importState = ref.watch(tiktokImportProvider);

    ref.listen(tiktokImportProvider, (previous, next) {
      if (!mounted) return;
      if (next.phase == TiktokImportPhase.error &&
          next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.phase == TiktokImportPhase.completed &&
          previous?.phase != TiktokImportPhase.completed &&
          next.savedFilePath != null) {
        final navigator = Navigator.of(context, rootNavigator: true);
        final path = next.savedFilePath!;
        final caption = next.caption;
        navigator.pop();
        Future.microtask(() {
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => EditorScreen(videoPath: path, caption: caption),
            ),
          );
        });
      }
    });

    return PopScope(
      canPop: !importState.isBusy,
      child: Material(
        color: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXl),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(context.l10n.fromTikTok, style: textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                context.l10n.tiktokImportDescription,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('tiktok-link-field'),
                controller: _linkController,
                focusNode: _focusNode,
                enabled: !importState.isBusy,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: context.l10n.tiktokUrlHint,
                  prefixIcon: Icon(
                    Icons.link_rounded,
                    color: colors.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    tooltip: context.l10n.paste,
                    onPressed: importState.isBusy ? null : _pasteFromClipboard,
                    icon: Icon(
                      Icons.content_paste_rounded,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ImportProgress(state: importState),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('tiktok-import-button'),
                  onPressed:
                      importState.isBusy || _linkController.text.trim().isEmpty
                      ? null
                      : _submit,
                  child: Text(
                    importState.phase == TiktokImportPhase.resolving
                        ? context.l10n.findingVideo
                        : importState.phase == TiktokImportPhase.downloading
                        ? context.l10n.downloading
                        : context.l10n.importVideo,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportProgress extends StatelessWidget {
  const _ImportProgress({required this.state});

  final TiktokImportState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final visible =
        state.phase == TiktokImportPhase.resolving ||
        state.phase == TiktokImportPhase.downloading;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: visible
          ? Column(
              key: const ValueKey('progress'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.phase == TiktokImportPhase.resolving
                            ? context.l10n.lookingUpTikTok
                            : context.l10n.downloadingVideo,
                        style: textTheme.titleSmall,
                      ),
                    ),
                    if (state.phase == TiktokImportPhase.downloading &&
                        state.progress != null)
                      Text(
                        '${(state.progress! * 100).clamp(0, 100).round()}%',
                        style: textTheme.titleSmall?.copyWith(
                          color: colors.accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    key: const Key('tiktok-download-progress'),
                    minHeight: 8,
                    value: state.phase == TiktokImportPhase.downloading
                        ? state.progress
                        : null,
                    backgroundColor: colors.surfaceMuted,
                    color: colors.accent,
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
