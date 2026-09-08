import 'package:flutter/material.dart';

import '../../accessibility/accessible_tap.dart';
import '../../haptics/haptic_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../editor_models.dart';

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
                          onSelected: (_) {
                            hapticService.buttonTap();
                            onSpeedPicked(value);
                          },
                          showCheckmark: false,
                          selectedColor: colors.accent,
                          labelStyle: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: speed == value
                                    ? colors.accentOn
                                    : Colors.white,
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
              hint: 'Adds a text sticker to the canvas',
              onTap: onText,
            ),
            _ToolButton(
              icon: Icons.emoji_emotions_outlined,
              label: 'Emojis',
              hint: 'Adds an emoji sticker to the canvas',
              onTap: onEmojis,
            ),
            if (showSpeed)
              _ToolButton(
                icon: Icons.speed_rounded,
                label: 'Speed',
                hint: 'Opens playback speed options',
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
    required this.hint,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: AccessibleTap(
        label: label,
        hint: hint,
        selected: selected,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const kStickerEmojis = [
  '🔥',
  '😂',
  '❤️',
  '✨',
  '💀',
  '😎',
  '😭',
  '🙏',
  '💯',
  '🎉',
  '🐶',
  '🐱',
  '💪',
  '🌸',
  '😍',
  '🤯',
];
