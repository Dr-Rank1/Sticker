import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class TrimTimeline extends StatelessWidget {
  const TrimTimeline({
    super.key,
    required this.duration,
    required this.start,
    required this.end,
    required this.playhead,
    this.maxSelectionDuration = 3,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  final double duration;
  final double start;
  final double end;
  final double playhead;
  final double maxSelectionDuration;
  final void Function(double start, double end) onChanged;
  final VoidCallback onChangeStart;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                _format(start),
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const Spacer(),
              Text(
                '${_format(end - start)} / '
                '${_format(maxSelectionDuration)} max',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _format(end),
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final total = duration <= 0 ? 1.0 : duration;
              return Semantics(
                button: true,
                label: 'Clip trim range',
                hint:
                    'Drag the handles to set a clip up to '
                    '${_format(maxSelectionDuration)}',
                value: '${_format(start)} to ${_format(end)}',
                child: GestureDetector(
                  onHorizontalDragStart: (details) {
                    onChangeStart();
                    _drag(details.localPosition.dx, width, total);
                  },
                  onHorizontalDragUpdate: (details) =>
                      _drag(details.localPosition.dx, width, total),
                  onHorizontalDragEnd: (_) => onChangeEnd(),
                  child: CustomPaint(
                    size: Size(width, 56),
                    painter: _TimelinePainter(
                      start: start / total,
                      end: end / total,
                      playhead: (playhead / total).clamp(0.0, 1.0),
                      accent: colors.accent,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _drag(double dx, double width, double total) {
    final t = (dx / width).clamp(0.0, 1.0) * total;
    final limit = maxSelectionDuration.clamp(0.2, total).toDouble();
    final startDist = (t - start).abs();
    final endDist = (t - end).abs();
    if (startDist < endDist) {
      var nextStart = t.clamp(0, end - 0.2).toDouble();
      if (end - nextStart > limit) {
        nextStart = end - limit;
      }
      onChanged(nextStart, end);
    } else {
      final nextEnd = t.clamp(start + 0.2, start + limit).clamp(0, total);
      onChanged(start, nextEnd.toDouble());
    }
  }

  String _format(double seconds) {
    final safe = seconds.isNaN ? 0.0 : seconds.clamp(0, 999);
    final whole = safe.floor();
    final ms = ((safe - whole) * 10).floor();
    final m = whole ~/ 60;
    final s = whole % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}.$ms';
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.start,
    required this.end,
    required this.playhead,
    required this.accent,
  });

  final double start;
  final double end;
  final double playhead;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 10, size.width, 36),
      const Radius.circular(10),
    );
    canvas.drawRRect(track, Paint()..color = const Color(0xFF2A2F36));

    const stripe = 10.0;
    for (var x = 0.0; x < size.width; x += stripe) {
      canvas.drawRect(
        Rect.fromLTWH(x, 14, 5, 28),
        Paint()..color = const Color(0xFF3A414B),
      );
    }

    final left = start * size.width;
    final right = end * size.width;
    final selected = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, 10, right, 46),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      selected,
      Paint()
        ..color = accent.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      selected,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    void handle(double x) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, 28), width: 14, height: 40),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = Colors.white);
      canvas.drawLine(
        Offset(x, 16),
        Offset(x, 40),
        Paint()
          ..color = const Color(0xFF111318)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    handle(left);
    handle(right);

    final playX = playhead * size.width;
    canvas.drawLine(
      Offset(playX, 8),
      Offset(playX, 48),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.playhead != playhead ||
        oldDelegate.accent != accent;
  }
}
