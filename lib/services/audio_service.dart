import 'dart:async';

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
///
/// Each sound effect has a few players that are loaded once and reused.
/// (Creating a new player for every sound - what `FlameAudio.play` does -
/// leaks players on Android, where short sounds never report that they
/// finished, and each leaked player keeps polling its position every frame,
/// so the game got slower the longer it was played.)
class AudioService {
  AudioService(this._progress);

  final ProgressService _progress;
  bool _ready = false;
  bool _musicPlaying = false;
  static const musicFile = 'music_loop.ogg';

  /// How many copies of one sound can play at the same time.
  static const voices = 3;
  final Map<Sfx, List<Future<AudioPlayer>?>> _players = {};
  final Map<Sfx, int> _next = {};
  static final AudioContext _context =
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  Future<void> init() async {
    try {
      FlameAudio.audioCache.prefix = 'assets/audio/';
      await FlameAudio.audioCache.loadAll([for (final s in Sfx.values) s.file]);
      FlameAudio.bgm.initialize();
      // The music player does not need its position either.
      FlameAudio.bgm.audioPlayer.positionUpdater = null;
      _ready = true;
      // Load one player per sound in the background (the first play of each
      // sound is then instant).
      for (final s in Sfx.values) {
        unawaited(_player(s, 0).then<void>((_) {}, onError: (Object _) {}));
      }
    } catch (e) {
      debugPrint('Audio not available: $e');
    }
  }

  Future<AudioPlayer> _player(Sfx sfx, int slot) {
    final slots = _players.putIfAbsent(sfx, () => List.filled(voices, null));
    return slots[slot] ??= _createPlayer(sfx.file);
  }

  static Future<AudioPlayer> _createPlayer(String file) async {
    final p = AudioPlayer()
      ..audioCache = FlameAudio.audioCache
      ..positionUpdater = null;
    await p.setAudioContext(_context);
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setPlayerMode(PlayerMode.lowLatency);
    await p.setSource(AssetSource(file));
    return p;
  }

  void play(Sfx sfx, {double volume = 0.7}) {
    if (!_ready || !_progress.sound) return;
    final slot = (_next[sfx] ?? 0) % voices;
    _next[sfx] = slot + 1;
    _start(sfx, slot, volume).then<void>(
      (_) {},
      onError: (Object e) => debugPrint('Sound failed: $e'),
    );
  }

  Future<void> _start(Sfx sfx, int slot, double volume) async {
    final p = await _player(sfx, slot);
    // stop() rewinds, so the same player can play the sound again.
    await p.stop();
    await p.setVolume(volume);
    await p.resume();
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
