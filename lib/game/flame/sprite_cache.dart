import 'dart:ui' as ui;

import '../logic/types.dart';
import '../render/sweet_art.dart';

/// Renders each kind of piece once into an image, so the board only has to
/// draw images every frame (keeps the game at 60 fps).
class SpriteCache {
  SpriteCache(this.pixelSize);

  final int pixelSize;
  final Map<int, ui.Image> _images = {};

  static int _key(Piece p) {
    if (p.isNut) return 9999;
    return p.special.index * 100 + (p.color + 1) * 2 + (p.armed ? 1 : 0);
  }

  ui.Image imageFor(Piece p) => _images.putIfAbsent(_key(p), () => _render(p));

  ui.Image _render(Piece p) {
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    final s = pixelSize.toDouble();
    SweetArt.paintPiece(
      canvas,
      ui.Rect.fromLTWH(s * 0.04, s * 0.04, s * 0.92, s * 0.92),
      color: p.color,
      special: p.special,
      nut: p.isNut,
      armed: p.armed,
    );
    final picture = rec.endRecording();
    final image = picture.toImageSync(pixelSize, pixelSize);
    picture.dispose();
    return image;
  }

  void dispose() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
  }
}
