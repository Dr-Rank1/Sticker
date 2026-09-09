import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../haptics/haptic_service.dart';
import '../l10n/l10n.dart';
import '../packs/save_to_pack_sheet.dart';
import '../state/navigation_controller.dart';
import '../storage/storage_utility.dart';
import '../theme/app_colors.dart';
import 'canvas_exporter.dart';
import 'editor_controller.dart';
import 'editor_models.dart';
import 'ffmpeg_sticker_service.dart';
import 'overlay_composer.dart';
import 'widgets/editor_toolbar.dart';
import 'widgets/overlay_canvas.dart';
import 'widgets/text_font_picker.dart';
import 'widgets/trim_timeline.dart';
import '../photos/photo_import_controller.dart';

final ffmpegStickerServiceProvider = Provider<FfmpegStickerService>((ref) {
  return FfmpegStickerService();
});

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.videoPath, this.imagePath, this.caption})
    : assert(
        (videoPath == null) != (imagePath == null),
        'Provide either a videoPath or an imagePath',
      );

  final String? videoPath;
  final String? imagePath;
  final String? caption;

  bool get isStatic => imagePath != null;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  VideoPlayerController? _player;
  bool _showSpeeds = false;
  final _textController = TextEditingController();
  final _overlayCaptureKey = GlobalKey();

  EditorController get _editor => ref.read(editorProvider.notifier);

  @override
  void initState() {
    super.initState();
    if (!widget.isStatic) {
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    final player = VideoPlayerController.file(File(widget.videoPath!));
    _player = player;
    await player.initialize();
    if (!mounted) return;
    final seconds = player.value.duration.inMilliseconds / 1000.0;
    _editor.hydrateDuration(seconds);
    await player.setLooping(true);
    await player.setVolume(0);
    await player.play();
    player.addListener(_onTick);
    setState(() {});
  }

  void _onTick() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    final doc = ref.read(editorProvider).document;
    final position = player.value.position.inMilliseconds / 1000.0;
    if (position >= doc.trimEnd - 0.03 || position < doc.trimStart - 0.05) {
      player.seekTo(Duration(milliseconds: (doc.trimStart * 1000).round()));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _cancelSave() {
    ref.read(ffmpegStickerServiceProvider).cancel();
    ref.read(imageStickerServiceProvider).cancel();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!widget.isStatic) {
      final player = _player;
      if (player == null || !player.value.isInitialized) return;
      await player.pause();
    }

    _editor.setSaving(saving: true, progress: 0);

    try {
      final document = ref.read(editorProvider).document;
      File? overlay;
      if (document.overlays.isNotEmpty) {
        final temp = await getStickrTemporaryDirectory();
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        overlay = await CanvasExporter.captureToFile(
          key: _overlayCaptureKey,
          directory: temp,
        );
        overlay ??= await OverlayComposer.compose(
          overlays: document.overlays,
          directory: temp,
        );
      }

      final StickerExportResult result;
      if (widget.isStatic) {
        result = await ref
            .read(imageStickerServiceProvider)
            .exportStaticSticker(
              imagePath: widget.imagePath!,
              overlayPngPath: overlay?.path,
              onProgress: (value) {
                if (!mounted) return;
                _editor.setSaving(saving: true, progress: value);
              },
            );
      } else {
        result = await ref
            .read(ffmpegStickerServiceProvider)
            .exportSticker(
              inputPath: widget.videoPath!,
              document: document,
              overlayPngPath: overlay?.path,
              onProgress: (value) {
                if (!mounted) return;
                _editor.setSaving(saving: true, progress: value);
              },
            );
      }

      final docs = await getApplicationDocumentsDirectory();
      final folder = Directory('${docs.path}${Platform.pathSeparator}stickers');
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }
      final saved = await result.file.copy(
        '${folder.path}${Platform.pathSeparator}stickr_${DateTime.now().millisecondsSinceEpoch}.webp',
      );
      await ref.read(storageUtilityProvider).cleanupAfterStickerSaved([
        widget.videoPath,
        widget.imagePath,
        overlay?.path,
        result.file.path,
      ]);

      if (!mounted) return;
      _editor.setSaving(saving: false, progress: 1);
      final pack = await showSaveToPackSheet(
        context,
        stickerPath: saved.path,
        animated: !widget.isStatic,
      );
      if (!mounted) return;

      if (pack != null) {
        hapticService.success();
        ref.read(navigationProvider.notifier).select(AppTab.library);
        Navigator.of(context).pop(saved.path);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.addedToPack(pack.name, pack.countLabel),
              ),
            ),
          );
      } else {
        hapticService.success();
        Navigator.of(context).pop(saved.path);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.stickerSaved((result.bytes / 1024).round()),
              ),
            ),
          );
      }
    } catch (error) {
      if (!mounted) return;
      final cancelled = error is StickerExportCancelled;
      final message = cancelled
          ? error.message
          : error is StickerExportException
          ? error.message
          : context.l10n.couldNotSaveSticker;
      _editor.setSaving(saving: false, error: cancelled ? null : message);
      if (!cancelled) hapticService.error();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      if (!widget.isStatic) {
        await _player?.play();
      }
    }
  }

  Future<void> _promptText() async {
    _textController.clear();
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.addText),
          content: TextField(
            controller: _textController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: context.l10n.textHint),
            onSubmitted: Navigator.of(context).pop,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _textController.text),
              child: Text(context.l10n.add),
            ),
          ],
        );
      },
    );
    if (text != null) _editor.addText(text);
  }

  Future<void> _pickEmoji() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.emojiTool,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 8,
                  children: [
                    for (final item in kStickerEmojis)
                      InkWell(
                        onTap: () => Navigator.pop(context, item),
                        child: Center(
                          child: Text(
                            item,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (emoji != null) _editor.addEmoji(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final document = editorState.document;
    final player = _player;
    final videoReady = player != null && player.value.isInitialized;
    final ready = widget.isStatic || videoReady;
    final playhead = videoReady
        ? player.value.position.inMilliseconds / 1000.0
        : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E12),
        body: SafeArea(
          child: Column(
            children: [
              _EditorAppBar(
                canUndo: editorState.canUndo,
                canRedo: editorState.canRedo,
                saving: editorState.saving,
                onClose: () => Navigator.pop(context),
                onUndo: _editor.undo,
                onRedo: _editor.redo,
                onSave: ready && !editorState.saving ? _save : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 8,
                  ),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Colors.transparent),
                            if (widget.isStatic)
                              _StaticPhoto(path: widget.imagePath!)
                            else if (videoReady && player.value.size.width > 0)
                              FittedBox(
                                key: const Key('editor-video-preview'),
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: player.value.size.width,
                                  height: player.value.size.height,
                                  child: VideoPlayer(player),
                                ),
                              )
                            else
                              const Center(child: CircularProgressIndicator()),
                            OverlayCanvas(
                              captureKey: _overlayCaptureKey,
                              layers: document.overlays,
                              selectedId: document.selectedId,
                              showSelection: !editorState.saving,
                              onSelect: _editor.select,
                              onChanged: _editor.updateOverlayLive,
                              onGestureStart: _editor.beginGesture,
                              onGestureEnd: _editor.endGesture,
                              onDelete: (_) => _editor.deleteSelected(),
                            ),
                            if (editorState.saving)
                              _EditorSavingOverlay(
                                progress: editorState.saveProgress,
                                onCancel: _cancelSave,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: document.selected?.kind == OverlayKind.text
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextFontPicker(
                                selectedFont: document.selected!.fontName,
                                onSelected: _editor.setSelectedTextFont,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    EditorToolbar(
                      speed: document.speed,
                      showSpeeds: _showSpeeds,
                      showSpeed: !widget.isStatic,
                      onText: _promptText,
                      onEmojis: _pickEmoji,
                      onToggleSpeed: () =>
                          setState(() => _showSpeeds = !_showSpeeds),
                      onSpeedPicked: (value) {
                        _editor.setSpeed(value);
                        _player?.setPlaybackSpeed(value);
                      },
                    ),
                    if (!widget.isStatic) ...[
                      const SizedBox(height: 8),
                      TrimTimeline(
                        duration: document.videoDuration <= 0
                            ? 1
                            : document.videoDuration,
                        start: document.trimStart,
                        end: document.trimEnd,
                        playhead: playhead,
                        maxSelectionDuration:
                            WhatsAppStickerSpec.maxSourceDurationForSpeed(
                              document.speed,
                            ),
                        onChanged: _editor.setTrim,
                        onChangeStart: _editor.beginGesture,
                        onChangeEnd: () {
                          _editor.endGesture();
                          final doc = ref.read(editorProvider).document;
                          _player?.seekTo(
                            Duration(
                              milliseconds: (doc.trimStart * 1000).round(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorSavingOverlay extends StatelessWidget {
  const _EditorSavingOverlay({required this.progress, required this.onCancel});

  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                value: progress == 0 ? null : progress,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.makingSticker,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextButton(
              key: const Key('editor-cancel-export'),
              onPressed: onCancel,
              child: Text(context.l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorAppBar extends StatelessWidget {
  const _EditorAppBar({
    required this.canUndo,
    required this.canRedo,
    required this.saving,
    required this.onClose,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
  });

  final bool canUndo;
  final bool canRedo;
  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: context.l10n.closeEditor,
            onPressed: () {
              hapticService.buttonTap();
              onClose();
            },
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: context.l10n.undo,
            onPressed: canUndo
                ? () {
                    hapticService.buttonTap();
                    onUndo();
                  }
                : null,
            icon: Icon(
              Icons.undo_rounded,
              color: canUndo ? Colors.white : Colors.white24,
            ),
          ),
          IconButton(
            tooltip: context.l10n.redo,
            onPressed: canRedo
                ? () {
                    hapticService.buttonTap();
                    onRedo();
                  }
                : null,
            icon: Icon(
              Icons.redo_rounded,
              color: canRedo ? Colors.white : Colors.white24,
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onSave == null
                ? null
                : () {
                    hapticService.buttonTap();
                    onSave!();
                  },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    context.l10n.save,
                    style: TextStyle(
                      color: onSave == null
                          ? colors.textTertiary
                          : colors.accentOn,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StaticPhoto extends StatefulWidget {
  const _StaticPhoto({required this.path});

  final String path;

  @override
  State<_StaticPhoto> createState() => _StaticPhotoState();
}

class _StaticPhotoState extends State<_StaticPhoto> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _StaticPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _load();
    }
  }

  Future<void> _load() async {
    final file = File(widget.path);
    if (!file.existsSync()) {
      if (mounted) setState(() => _bytes = null);
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _Checkerboard(),
        if (_bytes != null)
          Image.memory(
            _bytes!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.expand(),
          ),
      ],
    );
  }
}

class _Checkerboard extends StatelessWidget {
  const _Checkerboard();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _CheckerboardPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 16.0;
    final dark = Paint()..color = const Color(0xFF151A21);
    final light = Paint()..color = const Color(0xFF1C222B);
    canvas.drawRect(Offset.zero & size, dark);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final odd = ((x / cell).floor() + (y / cell).floor()).isOdd;
        if (odd) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), light);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
