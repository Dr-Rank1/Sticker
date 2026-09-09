import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FFmpeg GPL notice provides license and source information', () {
    final notice = File('LICENSES/FFMPEG_GPL_NOTICE.md').readAsStringSync();
    final screen = File('lib/settings/about_licenses_screen.dart')
        .readAsStringSync();

    expect(notice, contains('GNU General Public License'));
    expect(notice, contains('https://ffmpeg.org/download.html'));
    expect(notice, contains('https://github.com/Dr-Rank1/Sticker'));
    expect(notice, matches(RegExp(r'written source\s+offer')));
    expect(screen, contains('AboutLicensesScreen'));
    expect(screen, contains('open-third-party-licenses'));
  });

  test('README describes the current product integrations', () {
    final readme = File('README.md').readAsStringSync();

    expect(readme, contains('Sticker packs use Isar, not Hive'));
    expect(readme, contains('Giphy powers trending Community content'));
    expect(readme, contains('run-sync-get-dataset-items'));
    expect(readme, contains('A `.stickr` file is a ZIP archive'));
    expect(readme, isNot(contains('Tenor')));
    expect(readme, isNot(contains('debug signing for release builds')));
  });
}
