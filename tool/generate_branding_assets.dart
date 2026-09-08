import 'dart:io';

import 'package:image/image.dart' as img;

const _size = 1024;
final _mint = img.ColorRgba8(0, 196, 140, 255);
final _white = img.ColorRgba8(255, 255, 255, 255);
final _ink = img.ColorRgba8(17, 19, 24, 255);
final _transparent = img.ColorRgba8(0, 0, 0, 0);

void main() {
  final output = Directory('assets/branding')..createSync(recursive: true);

  final icon = img.Image(width: _size, height: _size, numChannels: 4);
  img.fill(icon, color: _mint);
  _drawSticker(icon, peeledCornerColor: _mint);

  final foreground = img.Image(width: _size, height: _size, numChannels: 4);
  img.fill(foreground, color: _transparent);
  _drawSticker(foreground);

  File('${output.path}/app_icon.png').writeAsBytesSync(img.encodePng(icon));
  File('${output.path}/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(foreground));
}

void _drawSticker(img.Image image, {img.Color? peeledCornerColor}) {
  img.fillRect(
    image,
    x1: 205,
    y1: 185,
    x2: 819,
    y2: 839,
    radius: 130,
    color: _white,
  );

  if (peeledCornerColor != null) {
    img.fillPolygon(
      image,
      vertices: [img.Point(650, 839), img.Point(819, 670), img.Point(819, 839)],
      color: peeledCornerColor,
    );
    img.fillPolygon(
      image,
      vertices: [img.Point(680, 810), img.Point(790, 700), img.Point(790, 810)],
      color: _white,
    );
  }

  img.fillCircle(image, x: 405, y: 420, radius: 36, color: _ink);
  img.fillCircle(image, x: 620, y: 420, radius: 36, color: _ink);

  // A rounded smile made from overlapping circles.
  img.fillCircle(image, x: 512, y: 620, radius: 125, color: _ink);
  img.fillCircle(image, x: 512, y: 570, radius: 112, color: _white);
}
