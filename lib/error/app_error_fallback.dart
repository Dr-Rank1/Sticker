import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Generic recovery UI used instead of Flutter's red error screen.
class AppErrorFallback extends StatelessWidget {
  const AppErrorFallback({super.key, this.details, this.onRetry});

  final FlutterErrorDetails? details;
  final VoidCallback? onRetry;

  static const title = 'Something went wrong';
  static const message =
      'Stickr hit an unexpected problem. You can keep using the rest of the app.';

  @override
  Widget build(BuildContext context) {
    final dark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final colors = dark ? AppColors.dark : AppColors.light;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: colors.background,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sentiment_dissatisfied_rounded,
                    size: 48,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, fontSize: 15),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
