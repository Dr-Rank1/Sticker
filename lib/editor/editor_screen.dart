import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../packs/save_to_pack_sheet.dart';
import '../state/navigation_controller.dart';
import '../theme/app_colors.dart';
import 'editor_controller.dart';
import 'ffmpeg_sticker_service.dart';
import 'overlay_composer.dart';
import 'widgets/editor_toolbar.dart';
import 'widgets/overlay_canvas.dart';
import 'widgets/trim_timeline.dart';

final ffmpegStickerServiceProvider = Provider<FfmpegStickerService>((ref) {
  return FfmpegStickerService();
});

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    required this.videoPath,
    this.caption,
  });

  final String videoPath;
  final String? caption;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  VideoPlayerController? _player;
  bool _showSpeeds = false;
  final _textController = TextEditingController();

  EditorController get _editor => ref.read(editorProvider.notifier);

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final player = VideoPlayerController.file(File(widget.videoPath));
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

  Future<void> _save() async {
    final player = _player;
    final messenger = ScaffoldMessenger.of(context);
    if (player == null || !player.value.isInitialized) return;

    await player.pause();
    _editor.setSaving(saving: true, progress: 0);

    try {
      final document = ref.read(editorProvider).document;
      final temp = await getTemporaryDirectory();
      final overlay = await OverlayComposer.compose(
        overlays: document.overlays,
        directory: temp,
      );
      final result = await ref.read(ffmpegStickerServiceProvider).exportSticker(
            inputPath: widget.videoPath,
            document: document,
            overlayPngPath: overlay?.path,
            onProgress: (value) {
              if (!mounted) return;
              _editor.setSaving(saving: true, progress: value);
            },
          );

      final docs = await getApplicationDocumentsDirectory();
      final folder = Directory('${docs.path}${Platform.pathSeparator}stickers');
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }
      final saved = await result.file.copy(
        '${folder.path}${Platform.pathSeparator}stikk_${DateTime.now().millisecondsSinceEpoch}.webp',
      );

      if (!mounted) return;
      _editor.setSaving(saving: false, progress: 1);
      final pack = await showSaveToPackSheet(context, stickerPath: saved.path);
      if (!mounted) return;

      if (pack != null) {
        ref.read(navigationProvider.notifier).select(AppTab.library);
        Navigator.of(context).pop(saved.path);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Added to ${pack.name} (${pack.countLabel}).')),
          );
      } else {
        Navigator.of(context).pop(saved.path);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Sticker saved (${(result.bytes / 1024).round()}KB). Add it to a pack from Library.',
              ),
            ),
          );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is StickerExportException
          ? error.message
          : 'Could not save that sticker. Please try again.';
      _editor.setSaving(saving: false, error: message);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      await _player?.play();
    }
  }

  Future<void> _promptText() async {
    _textController.clear();
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add text'),
          content: TextField(
            controller: _textController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Say something'),
            onSubmitted: Navigator.of(context).pop,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _textController.text),
              child: const Text('Add'),
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
                Text('Emojis', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 8,
                  children: [
                    for (final item in kStickerEmojis)
                      InkWell(
                        onTap: () => Navigator.pop(context, item),
                        child: Center(
                          child: Text(item, style: const TextStyle(fontSize: 28)),
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
    final ready = player != null && player.value.isInitialized;
    final playhead = ready ? player.value.position.inMilliseconds / 1000.0 : 0.0;

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
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFF151A21)),
                            if (ready && player.value.size.width > 0)
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: player.value.size.width,
                                  height: player.value.size.height,
                                  child: VideoPlayer(player),
                                ),
                              )
                            else
                              const Center(child: CircularProgressIndicator()),
                            OverlayCanvas(
                              overlays: document.overlays,
                              selectedId: document.selectedId,
                              onSelect: _editor.select,
                              onChanged: _editor.updateOverlayLive,
                              onGestureStart: _editor.beginGesture,
                              onGestureEnd: _editor.endGesture,
                            ),
                            if (document.selectedId != null)
                              Positioned(
                                right: 12,
                                top: 12,
                                child: IconButton.filled(
                                  onPressed: _editor.deleteSelected,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                ),
                              ),
                            if (editorState.saving)
                              ColoredBox(
                                color: Colors.black54,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 160,
                                        child: LinearProgressIndicator(
                                          value: editorState.saveProgress == 0
                                              ? null
                                              : editorState.saveProgress,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Making your sticker…',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
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
                    EditorToolbar(
                      speed: document.speed,
                      showSpeeds: _showSpeeds,
                      onText: _promptText,
                      onEmojis: _pickEmoji,
                      onToggleSpeed: () => setState(() => _showSpeeds = !_showSpeeds),
                      onSpeedPicked: (value) {
                        _editor.setSpeed(value);
                        _player?.setPlaybackSpeed(value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TrimTimeline(
                      duration: document.videoDuration <= 0
                          ? 1
                          : document.videoDuration,
                      start: document.trimStart,
                      end: document.trimEnd,
                      playhead: playhead,
                      onChanged: _editor.setTrim,
                      onChangeStart: _editor.beginGesture,
                      onChangeEnd: () {
                        _editor.endGesture();
                        final doc = ref.read(editorProvider).document;
                        _player?.seekTo(
                          Duration(milliseconds: (doc.trimStart * 1000).round()),
                        );
                      },
                    ),
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
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          IconButton(
            onPressed: canUndo ? onUndo : null,
            icon: Icon(
              Icons.undo_rounded,
              color: canUndo ? Colors.white : Colors.white24,
            ),
          ),
          IconButton(
            onPressed: canRedo ? onRedo : null,
            icon: Icon(
              Icons.redo_rounded,
              color: canRedo ? Colors.white : Colors.white24,
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onSave,
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
                    'Save',
                    style: TextStyle(
                      color: onSave == null ? colors.textTertiary : colors.accentOn,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
