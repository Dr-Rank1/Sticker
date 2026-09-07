import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_models.dart';

class EditorState {
  const EditorState({
    required this.document,
    this.undoStack = const [],
    this.redoStack = const [],
    this.saving = false,
    this.saveProgress = 0,
    this.errorMessage,
  });

  final EditorDocument document;
  final List<EditorDocument> undoStack;
  final List<EditorDocument> redoStack;
  final bool saving;
  final double saveProgress;
  final String? errorMessage;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  EditorState copyWith({
    EditorDocument? document,
    List<EditorDocument>? undoStack,
    List<EditorDocument>? redoStack,
    bool? saving,
    double? saveProgress,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EditorState(
      document: document ?? this.document,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      saving: saving ?? this.saving,
      saveProgress: saveProgress ?? this.saveProgress,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final editorProvider =
    NotifierProvider<EditorController, EditorState>(
  EditorController.new,
  isAutoDispose: true,
);

class EditorController extends Notifier<EditorState> {
  EditorDocument? _gestureBase;

  @override
  EditorState build() => const EditorState(document: EditorDocument());

  void reset() {
    _gestureBase = null;
    state = const EditorState(document: EditorDocument());
  }

  void hydrateDuration(double seconds) {
    final duration = seconds < 0.2 ? 0.2 : seconds;
    final end = duration < 3 ? duration : 3;
    final clampedEnd = end > WhatsAppStickerSpec.maxDurationSeconds
        ? WhatsAppStickerSpec.maxDurationSeconds
        : end;
    state = state.copyWith(
      document: state.document.copyWith(
        videoDuration: duration,
        trimStart: 0,
        trimEnd: clampedEnd.toDouble(),
      ),
    );
  }

  void undo() {
    if (!state.canUndo) return;
    final previous = state.undoStack.last;
    state = state.copyWith(
      document: previous,
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      redoStack: [...state.redoStack, state.document],
    );
  }

  void redo() {
    if (!state.canRedo) return;
    final next = state.redoStack.last;
    state = state.copyWith(
      document: next,
      redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
      undoStack: [...state.undoStack, state.document],
    );
  }

  void addText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final id = _newId();
    _commit(
      state.document.copyWith(
        overlays: [
          ...state.document.overlays,
          StickerOverlay(
            id: id,
            kind: OverlayKind.text,
            content: trimmed,
          ),
        ],
        selectedId: id,
      ),
    );
  }

  void addEmoji(String emoji) {
    final id = _newId();
    _commit(
      state.document.copyWith(
        overlays: [
          ...state.document.overlays,
          StickerOverlay(
            id: id,
            kind: OverlayKind.emoji,
            content: emoji,
            ny: 0.62,
          ),
        ],
        selectedId: id,
      ),
    );
  }

  void select(String? id) {
    state = state.copyWith(
      document: state.document.copyWith(
        selectedId: id,
        clearSelection: id == null,
      ),
    );
  }

  void deleteSelected() {
    final id = state.document.selectedId;
    if (id == null) return;
    _commit(
      state.document.copyWith(
        overlays: [
          for (final overlay in state.document.overlays)
            if (overlay.id != id) overlay,
        ],
        clearSelection: true,
      ),
    );
  }

  void setSpeed(double speed) {
    if (speed == state.document.speed) return;
    _commit(state.document.copyWith(speed: speed));
  }

  void setTrim(double start, double end) {
    final duration = state.document.videoDuration;
    var nextStart = start.clamp(0, duration);
    var nextEnd = end.clamp(0, duration);
    if (nextEnd - nextStart < 0.2) {
      nextEnd = (nextStart + 0.2).clamp(0, duration);
    }
    if (nextEnd - nextStart > WhatsAppStickerSpec.maxDurationSeconds) {
      nextEnd = nextStart + WhatsAppStickerSpec.maxDurationSeconds;
    }
    state = state.copyWith(
      document: state.document.copyWith(
        trimStart: nextStart.toDouble(),
        trimEnd: nextEnd.toDouble(),
      ),
    );
  }

  void beginGesture() {
    _gestureBase = state.document;
  }

  void updateOverlayLive(StickerOverlay overlay) {
    state = state.copyWith(
      document: state.document.copyWith(
        overlays: [
          for (final item in state.document.overlays)
            if (item.id == overlay.id) overlay else item,
        ],
        selectedId: overlay.id,
      ),
    );
  }

  void endGesture() {
    final base = _gestureBase;
    _gestureBase = null;
    if (base == null) return;
    if (_sameDocument(base, state.document)) return;
    state = state.copyWith(
      undoStack: [...state.undoStack, base],
      redoStack: const [],
    );
  }

  void setSaving({required bool saving, double progress = 0, String? error}) {
    state = state.copyWith(
      saving: saving,
      saveProgress: progress,
      errorMessage: error,
      clearError: error == null,
    );
  }

  void _commit(EditorDocument next) {
    if (_sameDocument(state.document, next)) return;
    state = state.copyWith(
      document: next,
      undoStack: [...state.undoStack, state.document],
      redoStack: const [],
    );
  }

  bool _sameDocument(EditorDocument a, EditorDocument b) {
    return a.trimStart == b.trimStart &&
        a.trimEnd == b.trimEnd &&
        a.speed == b.speed &&
        a.selectedId == b.selectedId &&
        a.overlays.length == b.overlays.length &&
        _overlaySignature(a.overlays) == _overlaySignature(b.overlays);
  }

  String _overlaySignature(List<StickerOverlay> overlays) {
    return overlays
        .map(
          (o) =>
              '${o.id}:${o.content}:${o.nx.toStringAsFixed(3)}:${o.ny.toStringAsFixed(3)}:${o.scale.toStringAsFixed(3)}:${o.rotation.toStringAsFixed(3)}',
        )
        .join('|');
  }

  int _seq = 0;

  String _newId() {
    _seq += 1;
    return 'ov_$_seq';
  }
}
