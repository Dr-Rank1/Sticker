import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:stikk/tiktok/comment_sticker_isolate.dart';
import 'package:stikk/tiktok/tiktok_comment_service.dart';

void main() {
  test('progress maps match the UI contract', () {
    const progress = CommentStickerProgress(downloaded: 45, total: 120);
    expect(progress.toMap(), {'downloaded': 45, 'total': 120, 'done': false});

    final parsed = CommentStickerProgress.fromMap(const {
      'downloaded': 45,
      'total': 120,
    });
    expect(parsed.downloaded, 45);
    expect(parsed.total, 120);
    expect(parsed.done, isFalse);
    expect(parsed.sticker, isNull);
  });

  test('immediate pipeline streams stickers one at a time', () async {
    const stickers = [
      CommentSticker(
        id: '1_0',
        commentId: '1',
        imageUrl: 'https://example.com/a.webp',
        author: 'Ian',
      ),
      CommentSticker(
        id: '2_0',
        commentId: '2',
        imageUrl: 'https://example.com/b.webp',
        author: 'Ada',
      ),
    ];

    final events = await ImmediateCommentStickerPipeline()
        .download(stickers: stickers, directory: '/tmp')
        .toList();

    expect(events.first.downloaded, 0);
    expect(events.first.total, 2);
    expect(events[1].downloaded, 1);
    expect(events[1].sticker?.id, '1_0');
    expect(events[2].downloaded, 2);
    expect(events[2].sticker?.id, '2_0');
    expect(events.last.done, isTrue);
  });

  test('worker isolate streams downloaded/total over a SendPort', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
    });
    server.listen((request) async {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.binary
        ..add(List<int>.filled(16, 7));
      await request.response.close();
    });

    final base = 'http://${server.address.host}:${server.port}';
    final directory = await Directory.systemTemp.createTemp('stikk_iso_');
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });

    final stickers = [
      for (var i = 0; i < 3; i++)
        CommentSticker(
          id: 'id_$i',
          commentId: '$i',
          imageUrl: '$base/$i.webp',
          author: 'Ian',
        ),
    ];

    final events = await IsolateCommentStickerPipeline()
        .download(stickers: stickers, directory: directory.path)
        .toList();

    expect(events.first.toMap(), {'downloaded': 0, 'total': 3, 'done': false});
    final withFiles = events.where((event) => event.sticker != null).toList();
    expect(withFiles, hasLength(3));
    expect(withFiles.map((event) => event.toMap()['downloaded']).toList(), [
      1,
      2,
      3,
    ]);
    expect(events.last.done, isTrue);
    expect(File(withFiles.first.sticker!.localPath!).existsSync(), isTrue);
  });

  test(
    'isolate entrypoint sends progress through the provided SendPort',
    () async {
      final port = ReceivePort();
      addTearDown(port.close);

      await Isolate.spawn(commentStickerIsolateMain, <String, dynamic>{
        'sendPort': port.sendPort,
        'directory': Directory.systemTemp.path,
        'stickers': const <Map<String, String>>[],
      });

      final first = await port.first;
      expect(first, isA<Map>());
      final progress = CommentStickerProgress.fromMap(
        Map<String, dynamic>.from(first as Map),
      );
      expect(progress.downloaded, 0);
      expect(progress.total, 0);
    },
  );
}
