import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import 'progress_service.dart';

/// Sound effects (files in assets/audio/, made by tool/gen_audio.py).
enum Sfx {
  swap('swap.wav'),
  swapBack('swap_back.wav'),
  pop1('pop1.wav'),
  pop2('pop2.wav'),
  pop3('pop3.wav'),
  pop4('pop4.wav'),
  striped('striped.wav'),
  box('box.wav'),
  swirl('swirl.wav'),
  special('special_made.wav'),
  combo('combo.wav'),
  crate('crate.wav'),
  caramel('caramel.wav'),
  nut('nut.wav'),
  shuffle('shuffle.wav'),
  star('star.wav'),
  win('win.wav'),
  lose('lose.wav'),
  coin('coin.wav'),
  button('button.wav'),
  booster('booster.wav'),
  spin('spin_tick.wav');

  const Sfx(this.file);
  final String file;
}

/// Plays sound effects and the background music, following the settings.
class AudioService {
  AudioService(this._progress);

  final ProgressService _progress;
  bool _ready = false;
  bool _musicPlaying = false;
  static const musicFile = 'music_loop.ogg';

  Future<void> init() async {
    try {
      FlameAudio.audioCache.prefix = 'assets/audio/';
      await FlameAudio.audioCache.loadAll([for (final s in Sfx.values) s.file]);
      FlameAudio.bgm.initialize();
      _ready = true;
    } catch (e) {
      debugPrint('Audio not available: $e');
    }
  }

  void play(Sfx sfx, {double volume = 0.7}) {
    if (!_ready || !_progress.sound) return;
    FlameAudio.play(sfx.file, volume: volume).then<void>(
      (_) {},
      onError: (Object e) => debugPrint('Sound failed: $e'),
    );
  }

  /// Pop sound that gets higher with each cascade.
  void pop(int cascade) => play(switch (cascade) {
        <= 1 => Sfx.pop1,
        2 => Sfx.pop2,
        3 => Sfx.pop3,
        _ => Sfx.pop4,
      });

  Future<void> startMusic() async {
    if (!_ready || !_progress.music || _musicPlaying) return;
    try {
      await FlameAudio.bgm.play(musicFile, volume: 0.35);
      _musicPlaying = true;
    } catch (e) {
      debugPrint('Music failed: $e');
    }
  }

  Future<void> stopMusic() async {
    if (!_musicPlaying) return;
    _musicPlaying = false;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
  }

  /// Call after the music setting changes.
  Future<void> applySettings() => _progress.music ? startMusic() : stopMusic();

  void pauseForBackground() {
    if (_musicPlaying) FlameAudio.bgm.pause();
  }

  void resumeFromBackground() {
    if (_musicPlaying && _progress.music) FlameAudio.bgm.resume();
  }
}
