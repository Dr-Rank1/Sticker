import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/error/app_error_fallback.dart';

void main() {
  testWidgets('fallback UI shows a generic recovery message', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppErrorFallback()));

    expect(find.byType(AppErrorFallback), findsOneWidget);
    expect(find.text(AppErrorFallback.title), findsOneWidget);
    expect(find.text(AppErrorFallback.message), findsOneWidget);
    expect(find.textContaining('EXCEPTION CAUGHT'), findsNothing);
  });
}
