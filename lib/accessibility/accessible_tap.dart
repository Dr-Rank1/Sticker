import 'package:flutter/material.dart';

import '../haptics/haptic_service.dart';

/// Custom tap target with TalkBack metadata and a medium haptic on press.
class AccessibleTap extends StatelessWidget {
  const AccessibleTap({
    super.key,
    required this.label,
    required this.hint,
    required this.onTap,
    required this.child,
    this.selected = false,
    this.borderRadius,
  });

  final String label;
  final String hint;
  final VoidCallback onTap;
  final Widget child;
  final bool selected;
  final BorderRadius? borderRadius;

  void _handleTap() {
    hapticService.buttonTap();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      hint: hint,
      onTap: _handleTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: _handleTap,
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }
}
