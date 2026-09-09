import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/error/app_error_fallback.dart';
import 'package:stickr/l10n/l10n.dart';

void main() {
  testWidgets('fallback UI shows a generic recovery message', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppErrorFallback()));

    expect(find.byType(AppErrorFallback), findsOneWidget);
    expect(
      find.text(fallbackLocalizations.unexpectedErrorTitle),
      findsOneWidget,
    );
    expect(
      find.text(fallbackLocalizations.unexpectedErrorMessage),
      findsOneWidget,
    );
    expect(find.textContaining('EXCEPTION CAUGHT'), findsNothing);
  });
}
