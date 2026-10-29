#!/usr/bin/env python3
"""Generates every sound effect and the background music for Toffee Twist.

All sounds are synthesised from scratch with math (sine waves, noise and
envelopes), so they are 100% original. They are released under CC0 1.0
(public domain) - see CREDITS.md.

Run:  python3 tool/gen_audio.py      (needs numpy; ffmpeg for the .ogg music)
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
rng = np.random.default_rng(20261028)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.005, release=0.1, sustain=1.0):
    """Attack/decay envelope over n samples."""
    a = max(1, int(SR * attack))
    e = np.ones(n) * sustain
    e[:a] = np.linspace(0, 1, a)
    r = max(1, min(n - a, int(SR * release)))
    e[-r:] *= np.linspace(1, 0, r) ** 1.5
    return e


def exp_decay(n, rate):
    return np.exp(-np.arange(n) / SR * rate)


def tone(freq, sec, harmonics=((1, 1.0),), decay=8.0, attack=0.004):
    x = t(sec)
    if np.isscalar(freq):
        phase = 2 * np.pi * freq * x
    else:
        phase = 2 * np.pi * np.cumsum(freq) / SR
    s = sum(a * np.sin(h * phase) for h, a in harmonics)
    return s * exp_decay(len(x), decay) * env(len(x), attack, 0.02)


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def lowpass(x, cutoff):
    # simple one-pole low-pass
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def delay(x, sec, gain):
    d = int(SR * sec)
    out = np.concatenate([x, np.zeros(d)])
    out[d:] += x * gain
    return out


def seq(*items):
    """items: (start_seconds, samples)."""
    n = max(int(s * SR) + len(p) for s, p in items)
    out = np.zeros(n)
    for s, p in items:
        i = int(s * SR)
        out[i:i + len(p)] += p
    return out


def save(name, x, peak=0.8, sr=SR):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    # tiny fade at both ends to avoid clicks
    f = min(len(x) // 4, 64)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def note(n):
    """MIDI note number to frequency."""
    return 440.0 * 2 ** ((n - 69) / 12)


# ---------------------------------------------------------------------------
# Sound effects
# ---------------------------------------------------------------------------

def sfx():
    os.makedirs(OUT, exist_ok=True)

    # swap: soft airy whoosh
    n = noise(0.14)
    sweep = np.linspace(800, 2400, len(n))
    save('swap.wav', lowpass(n, 2600) * np.sin(np.linspace(0, np.pi, len(n))) * 0.6
         + tone(np.linspace(500, 900, len(n)), 0.14, decay=10) * 0.25, peak=0.45)

    # swap back: "boing" down and up
    f = np.concatenate([np.linspace(520, 330, int(SR * 0.09)), np.linspace(330, 470, int(SR * 0.09))])
    save('swap_back.wav', tone(f, len(f) / SR, ((1, 1), (2, 0.25)), decay=6), peak=0.45)

    # pops: bubbly pop, higher for bigger cascades
    for i, base in enumerate([620, 720, 840, 980], start=1):
        f = base * np.exp(-t(0.12) * 14) + base * 0.6
        p = tone(f, 0.12, ((1, 1), (2, 0.3), (3, 0.1)), decay=24)
        click = highpass(noise(0.01), 3000) * 0.3
        save(f'pop{i}.wav', mix(p, click), peak=0.6)

    # striped: zappy laser sweep
    x = t(0.36)
    f = np.linspace(300, 1700, len(x))
    zap = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.4 + np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR) * 0.5
    zap = lowpass(zap, 3500) * exp_decay(len(x), 6) * (0.7 + 0.3 * np.sin(2 * np.pi * 30 * x))
    save('striped.wav', zap, peak=0.55)

    # box: soft boom
    boom = tone(np.linspace(130, 55, int(SR * 0.5)), 0.5, ((1, 1), (2, 0.3)), decay=7)
    rumble = lowpass(noise(0.5), 600) * exp_decay(int(SR * 0.5), 9) * 0.8
    save('box.wav', mix(boom, rumble), peak=0.8)

    # swirl: sparkly rising arpeggio with echo
    notes = [72, 76, 79, 84, 88, 91, 96]
    parts = [(k * 0.055, tone(note(m), 0.35, ((1, 1), (2, 0.2), (4, 0.08)), decay=9)) for k, m in enumerate(notes)]
    save('swirl.wav', delay(seq(*parts), 0.09, 0.35), peak=0.6)

    # special made: two-note chime
    save('special_made.wav', seq((0, tone(note(79), 0.4, ((1, 1), (3, 0.15)), decay=7)),
                                 (0.09, tone(note(86), 0.45, ((1, 1), (3, 0.15)), decay=6))), peak=0.55)

    # combo: big shimmering chord + sweep
    chord = sum(tone(note(m), 0.9, ((1, 1), (2, 0.25)), decay=3.5) for m in [60, 64, 67, 72, 76])
    sweep = tone(np.linspace(400, 2000, int(SR * 0.5)), 0.5, decay=4) * 0.4
    save("combo.wav", mix(chord, sweep, lowpass(noise(0.4), 500) * exp_decay(int(SR * 0.4), 10)), peak=0.8)

    # crate: wooden knock
    knock = tone(310, 0.16, ((1, 1), (2.7, 0.4), (4.1, 0.2)), decay=28)
    knock = mix(knock, lowpass(noise(0.05), 1800) * 0.6)
    save('crate.wav', seq((0, knock), (0.07, knock * 0.5)), peak=0.7)

    # caramel: soft squish
    sq = lowpass(noise(0.16), 900) * np.sin(np.linspace(0, np.pi, int(SR * 0.16)))
    sq = mix(sq, tone(np.linspace(260, 140, int(SR * 0.16)), 0.16, decay=12) * 0.5)
    save('caramel.wav', sq, peak=0.5)

    # nut collected: bright double ding
    save('nut.wav', seq((0, tone(note(88), 0.35, ((1, 1), (2.4, 0.2)), decay=8)),
                        (0.1, tone(note(93), 0.5, ((1, 1), (2.4, 0.2)), decay=6))), peak=0.6)

    # shuffle: fluttering whoosh
    x = t(0.55)
    fl = lowpass(noise(0.55), 2200) * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * x)) * np.sin(np.linspace(0, np.pi, len(x)))
    save('shuffle.wav', fl, peak=0.45)

    # star: sparkling ding
    save('star.wav', delay(tone(note(91), 0.5, ((1, 1), (2, 0.3), (3, 0.1)), decay=6), 0.07, 0.3), peak=0.55)

    # win jingle
    mel = [(0.00, 72), (0.12, 76), (0.24, 79), (0.36, 84), (0.60, 83), (0.72, 84)]
    parts = [(s, tone(note(m), 0.5, ((1, 1), (2, 0.3), (3, 0.1)), decay=5)) for s, m in mel]
    chord = sum(tone(note(m), 1.0, ((1, 1), (2, 0.2)), decay=2.5) for m in [60, 64, 67, 72]) * 0.5
    save('win.wav', seq(*parts, (0.72, chord)), peak=0.7)

    # lose: gentle descending notes
    mel = [(0.0, 67), (0.22, 65), (0.44, 63), (0.70, 60)]
    parts = [(s, tone(note(m), 0.6 if i == 3 else 0.35, ((1, 1), (2, 0.15)), decay=3.5)) for i, (s, m) in enumerate(mel)]
    save('lose.wav', seq(*parts), peak=0.55)

    # coin
    save('coin.wav', seq((0, tone(note(83), 0.09, ((1, 1), (2, 0.3)), decay=20)),
                         (0.07, tone(note(88), 0.3, ((1, 1), (2, 0.3)), decay=9))), peak=0.5)

    # button click
    save('button.wav', tone(np.linspace(900, 600, int(SR * 0.05)), 0.05, ((1, 1), (2, 0.2)), decay=50), peak=0.4)

    # booster: magic rising sweep with sparkles
    x = t(0.45)
    rise = tone(np.linspace(300, 1400, len(x)), 0.45, ((1, 1), (2, 0.3)), decay=3)
    sparkle = sum(tone(note(m), 0.2, decay=15) for m in [96, 100]) * 0.2
    save('booster.wav', seq((0, rise), (0.3, sparkle)), peak=0.55)

    # spin tick
    save('spin_tick.wav', tone(1800, 0.025, decay=150), peak=0.3)


# ---------------------------------------------------------------------------
# Background music: a cosy 4-chord loop (about 29 seconds, loops seamlessly)
# ---------------------------------------------------------------------------

def music():
    sr = 32000
    bpm = 100
    beat = 60 / bpm
    bars = 12
    total = int(sr * beat * 4 * bars)
    out = np.zeros(total)

    def tn(freq, dur, harm, decay):
        x = np.arange(int(sr * dur)) / sr
        s = sum(a * np.sin(2 * np.pi * freq * h * x) for h, a in harm)
        a = min(len(x), int(sr * 0.01))
        e = np.exp(-x * decay)
        e[:a] *= np.linspace(0, 1, a)
        return s * e

    def put(start_beats, sig, gain):
        i = int(start_beats * beat * sr) % total
        n = len(sig)
        end = i + n
        if end <= total:
            out[i:end] += sig * gain
        else:  # wrap around so the loop is seamless
            k = total - i
            out[i:] += sig[:k] * gain
            out[:n - k] += sig[k:] * gain

    # C - Am - F - G progression (major, cosy), 3 times
    chords = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]
    bass = [36, 33, 29, 31]
    keys = ((1, 1.0), (2, 0.35), (3, 0.12), (4, 0.05))  # soft electric-piano-ish
    melody_scale = [72, 74, 76, 79, 81, 84]
    mrng = np.random.default_rng(7)
    for bar in range(bars):
        ch = chords[bar % 4]
        # bass on beats 1 and 3
        put(bar * 4, tn(note(bass[bar % 4]), beat * 1.8, ((1, 1), (2, 0.4)), 1.6), 0.55)
        put(bar * 4 + 2, tn(note(bass[bar % 4] + 7), beat * 1.6, ((1, 1), (2, 0.4)), 1.8), 0.35)
        # gentle chord stabs on the off-beats
        for b in [0.5, 1.5, 2.5, 3.5]:
            for m in ch:
                put(bar * 4 + b, tn(note(m), beat * 0.9, keys, 3.5), 0.10)
        # soft shaker
        for b in np.arange(0, 4, 0.5):
            hat = rng.uniform(-1, 1, int(sr * 0.05)) * np.exp(-np.arange(int(sr * 0.05)) / sr * 90)
            put(bar * 4 + b, hat, 0.035 if b % 1 else 0.055)
        # simple music-box melody (first 8 bars, then a calmer ending)
        if bar < 8 or bar % 2 == 0:
            pattern = [0, 1, 2, 3] if bar % 2 == 0 else [0, 1.5, 2, 3]
            for b in pattern:
                m = int(mrng.choice(melody_scale))
                if m % 12 not in [x % 12 for x in ch] and mrng.random() < 0.5:
                    m = ch[mrng.integers(0, 3)] + 12
                put(bar * 4 + b, tn(note(m), beat * 1.2, ((1, 1), (2, 0.15), (5, 0.04)), 2.8), 0.18)

    out = out / np.max(np.abs(out)) * 0.85
    wav = os.path.join(OUT, 'music_loop.wav')
    data = (out * 32767).astype(np.int16)
    with wave.open(wav, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())
    ogg = os.path.join(OUT, 'music_loop.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '3', ogg],
                   check=True)
    os.remove(wav)


if __name__ == '__main__':
    sfx()
    music()
    print('Sounds written to', os.path.abspath(OUT))
