import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pull request workflow formats, analyzes, and tests the project', () {
    final workflow = File(
      '${Directory.current.path}/.github/workflows/pr_validation.yml',
    ).readAsStringSync();

    expect(workflow, contains('pull_request:'));
    expect(workflow, contains('uses: actions/checkout@v4'));
    expect(workflow, contains('uses: subosito/flutter-action@v2'));
    expect(workflow, contains('run: dart format --set-exit-if-changed .'));
    expect(workflow, contains('run: flutter analyze'));
    expect(workflow, contains('run: flutter test'));
  });
}
