import 'package:flutter/material.dart';

import '../editor_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.speed,
    required this.showSpeeds,
    required this.onText,
    required this.onEmojis,
    required this.onToggleSpeed,
    required this.onSpeedPicked,
    this.showSpeed = true,
  });

  final double speed;
  final bool showSpeeds;
  final bool showSpeed;
  final VoidCallback onText;
  final VoidCallback onEmojis;
  final VoidCallback onToggleSpeed;
  final ValueChanged<double> onSpeedPicked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: showSpeed && showSpeeds
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final value in WhatsAppStickerSpec.speeds)
                        ChoiceChip(
                          label: Text('${value}x'),
                          selected: speed == value,
                          onSelected: (_) => onSpeedPicked(value),
                          showCheckmark: false,
                          selectedColor: colors.accent,
                          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: speed == value ? colors.accentOn : Colors.white,
                              ),
                          backgroundColor: const Color(0xFF2A2F36),
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Row(
          children: [
            _ToolButton(
              icon: Icons.title_rounded,
              label: 'Text',
              onTap: onText,
            ),
            _ToolButton(
              icon: Icons.emoji_emotions_outlined,
              label: 'Emojis',
              onTap: onEmojis,
            ),
            if (showSpeed)
              _ToolButton(
                icon: Icons.speed_rounded,
                label: 'Speed',
                selected: showSpeeds,
                onTap: onToggleSpeed,
              ),
          ],
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? colors.accentSoft : const Color(0xFF2A2F36),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: selected ? colors.accent : Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const kStickerEmojis = [
  '🔥', '😂', '❤️', '✨', '💀', '😎', '😭', '🙏',
  '💯', '🎉', '🐶', '🐱', '💪', '🌸', '😍', '🤯',
];
