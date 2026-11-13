"""Chiptune soundtrack, composed note by note and rendered with synth.py.

Every track is an exact number of bars and wraps its reverb / release tails back to the start,
so it loops seamlessly in the game (audio.gd sets the loop points).
"""

import os

import numpy as np

from synth import (SR, decay, echo, env, highpass_fast, lowpass_fast, noise, normalize, note_freq, osc, place,
                   sweep, write_wav)

CHORD_SHAPES = {"": (0, 4, 7), "m": (0, 3, 7), "dim": (0, 3, 6), "sus": (0, 5, 7)}
NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
FLATS = {"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#"}


def chord_notes(ch, octave):
    root = ch[:2] if len(ch) > 1 and ch[1] in "#b" else ch[:1]
    qual = ch[len(root):]
    root = FLATS.get(root, root)
    ri = NAMES.index(root)
    out = []
    for iv in CHORD_SHAPES[qual]:
        k = ri + iv
        out.append(f"{NAMES[k % 12]}{octave + k // 12}")
    return out


def parse(seq):
    out = []
    for tok in seq.split():
        n, d = tok.split(":")
        out.append((n, int(d)))
    return out


# ---- instruments ---------------------------------------------------------
def inst_pulse(duty=0.25, vol=0.3, a=0.005, d=0.08, s=0.55, r=0.06, vib=0.0):
    def play(f, dur):
        n = int(dur * SR)
        freq = np.full(n, f)
        if vib and dur > 0.25:
            t = np.arange(n) / SR
            freq = f * (1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) * 4, 0, 1))
        return osc("square", freq, dur, duty) * env(n, a, d, s, r) * vol
    return play


def inst_tri(vol=0.4, a=0.004, d=0.06, s=0.7, r=0.05):
    def play(f, dur):
        n = int(dur * SR)
        return osc("tri", f, dur) * env(n, a, d, s, r) * vol
    return play


def inst_bell(vol=0.3, k=4.0):
    def play(f, dur):
        dd = max(dur, 0.9)
        return (osc("sine", f, dd) * 0.8 + osc("sine", f * 2.01, dd) * 0.25 + osc("sine", f * 3.0, dd) * 0.08) \
            * decay(dd, k) * vol
    return play


def inst_pad(vol=0.18):
    def play(f, dur):
        n = int(dur * SR)
        s = osc("saw", f * 0.997, dur) + osc("saw", f * 1.004, dur) + osc("tri", f * 0.5, dur) * 0.6
        s = lowpass_fast(s, 1100)
        return s * env(n, min(0.35, dur * 0.3), 0.2, 0.8, min(0.4, dur * 0.3)) * vol
    return play


def kick(vol=0.9):
    d = 0.18
    return osc("sine", sweep(140, 42, d, 0.4), d) * decay(d, 16) * vol


def snare(vol=0.45):
    d = 0.16
    return (highpass_fast(noise(d, 31), 1200) * decay(d, 18) + osc("tri", 190, d) * decay(d, 30) * 0.5) * vol


def hat(vol=0.12, open_=False):
    d = 0.12 if open_ else 0.04
    return highpass_fast(noise(d, 32), 5000) * decay(d, 25 if open_ else 80) * vol


# ---- track renderer ---------------------------------------------------------
class Track:
    def __init__(self, bpm, bars):
        self.step = 60.0 / bpm / 4.0     # one 16th note
        self.bars = bars
        self.length = int(round(bars * 16 * self.step * SR))
        self.buf = np.zeros(self.length + SR * 4)

    def seq(self, notes, inst, start_bar=0, transpose=1.0):
        pos = start_bar * 16
        for name, d in notes:
            if name != "-":
                sig = inst(note_freq(name) * transpose, d * self.step)
                place(self.buf, sig, pos * self.step * SR)
            pos += d
        return pos

    def chords(self, prog, inst, octave, pattern, beats_per_chord=16):
        """pattern: list of (step_in_bar, chord_tone_index, length_in_steps). tone index may exceed 2 -> octave up."""
        for bi, ch in enumerate(prog):
            tones = chord_notes(ch, octave)
            for st, ti, ln in pattern:
                note = tones[ti % 3]
                f = note_freq(note) * (2 ** (ti // 3))
                place(self.buf, inst(f, ln * self.step), (bi * beats_per_chord + st) * self.step * SR)

    def bass(self, prog, inst, octave, pattern):
        """pattern: list of (step, 'r'|'5'|'8', length)."""
        for bi, ch in enumerate(prog):
            root = chord_notes(ch, octave)
            for st, kind, ln in pattern:
                if kind == "r":
                    f = note_freq(root[0])
                elif kind == "5":
                    f = note_freq(root[2])
                else:
                    f = note_freq(root[0]) * 2
                place(self.buf, inst(f, ln * self.step), (bi * 16 + st) * self.step * SR)

    def drums(self, pattern, bars=None, vol=1.0):
        """pattern: dict name->16-char string per bar, x = hit, o = open hat / accent."""
        bars = bars or self.bars
        for b in range(bars):
            for name, pat in pattern.items():
                for i, ch in enumerate(pat):
                    if ch == ".":
                        continue
                    if name == "k":
                        s = kick(0.9 * vol)
                    elif name == "s":
                        s = snare((0.45 if ch == "x" else 0.25) * vol)
                    else:
                        s = hat((0.12 if ch == "x" else 0.09) * vol, open_=(ch == "o"))
                    place(self.buf, s, (b * 16 + i) * self.step * SR)

    def render(self, reverb=0.0, delay_steps=3, peak=0.8):
        out = self.buf[: self.length].copy()
        tail = self.buf[self.length:]
        out[: len(tail)] += tail[: self.length]
        if reverb:
            out = echo(out, delay_steps * self.step, reverb, 4, wrap=True)
        return normalize(out, peak)


def bars_of(prog_bars):
    return [c for c in prog_bars.split()]


# ---- compositions -------------------------------------------------------------
def camp():
    t = Track(84, 16)
    prog = bars_of("D Bm G A D Bm Em A G A F#m Bm G A D D")
    arp = [(i * 2, [0, 1, 2, 3, 2, 1, 0, 1][i], 2) for i in range(8)]
    t.chords(prog, inst_tri(0.22, s=0.5, r=0.08), 4, arp)
    t.bass(prog, inst_tri(0.42), 2, [(0, "r", 6), (6, "5", 2), (8, "8", 6), (14, "5", 2)])
    mel = parse(
        "F#5:4 E5:2 D5:2 A4:8  B4:4 C#5:2 D5:2 F#5:8  G5:4 F#5:2 E5:2 D5:4 B4:4  C#5:6 D5:2 E5:8 "
        "F#5:4 A5:4 G5:2 F#5:2 E5:4  D5:4 F#5:4 B4:8  E5:4 G5:4 F#5:2 E5:2 D5:4  C#5:8 -:8 "
        "B4:4 D5:4 G5:8  A4:4 C#5:4 E5:8  F#5:4 E5:2 C#5:2 A4:8  B4:4 D5:4 F#5:4 E5:4 "
        "D5:4 B4:4 G4:4 B4:4  C#5:4 E5:4 A5:4 G5:4  F#5:8 E5:4 D5:4  D5:12 -:4")
    t.seq(mel, inst_pulse(0.25, 0.16, a=0.02, s=0.6, r=0.12, vib=0.006))
    t.drums({"h": "....x.......x..."}, vol=0.7)
    return t.render(reverb=0.3, delay_steps=3)


def moss():
    t = Track(96, 16)
    prog = bars_of("Am Am F G Am Am Dm E F G Am Am Dm E Am Am")
    t.bass(prog, inst_tri(0.5, s=0.6), 2,
           [(0, "r", 2), (2, "r", 2), (4, "8", 2), (6, "r", 2), (8, "5", 2), (10, "r", 2), (12, "8", 2), (14, "5", 2)])
    t.chords(prog, inst_pad(0.1), 3, [(0, 0, 16), (0, 1, 16), (0, 2, 16)])
    lead = parse(
        "A4:4 -:2 C5:2 E5:4 D5:2 C5:2  B4:8 -:8  A4:4 -:2 C5:2 F5:4 E5:2 D5:2  D5:8 B4:8 "
        "A4:4 -:2 C5:2 E5:4 A5:4  G5:4 E5:4 C5:8  D5:4 F5:4 A5:4 F5:4  G#5:8 E5:8 "
        "F5:4 E5:4 C5:4 A4:4  G4:4 B4:4 D5:4 G5:4  E5:6 D5:2 C5:4 B4:4  A4:16 "
        "D5:4 C5:2 D5:2 F5:4 A5:4  G#5:4 F5:2 E5:2 D5:4 B4:4  C5:4 E5:4 A5:8  -:16")
    t.seq(lead, inst_pulse(0.125, 0.14, a=0.01, s=0.5, r=0.1, vib=0.005))
    t.drums({"k": "x.......x.......", "s": "....x.......x...", "h": "..x...x...x...x."}, vol=0.75)
    return t.render(reverb=0.32, delay_steps=3)


def ash():
    t = Track(104, 16)
    prog = bars_of("Dm C Bb C Dm C Bb A Gm Am Bb C Dm Bb A A")
    t.bass(prog, inst_pulse(0.5, 0.22, s=0.7, r=0.03), 2,
           [(0, "r", 3), (3, "r", 1), (4, "8", 2), (6, "r", 2), (8, "5", 3), (11, "r", 1), (12, "8", 2), (14, "5", 2)])
    t.chords(prog, inst_tri(0.12, s=0.4), 4, [(i * 2, [0, 2, 1, 2][i % 4], 2) for i in range(8)])
    lead = parse(
        "D5:3 F5:3 A5:2 G5:4 F5:4  E5:8 C5:8  D5:3 F5:3 A#5:2 A5:4 G5:4  G5:8 E5:8 "
        "D5:3 F5:3 A5:2 D6:4 C6:4  A#5:4 A5:4 G5:8  F5:4 G5:4 A5:4 A#5:4  A5:8 C#5:8 "
        "G5:4 A#5:4 D6:8  C6:4 A5:4 E5:8  F5:4 D5:4 A#4:8  C5:4 E5:4 G5:8 "
        "A5:6 G5:2 F5:4 E5:4  D5:6 E5:2 F5:4 D5:4  E5:4 C#5:4 A4:8  -:16")
    t.seq(lead, inst_pulse(0.5, 0.11, a=0.01, s=0.55, r=0.08, vib=0.004))
    t.drums({"k": "x.....x...x.....", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.xo"}, vol=0.7)
    return t.render(reverb=0.25, delay_steps=3)


def sanctum():
    t = Track(72, 16)
    prog = bars_of("Em C Am B Em C F B Em C Am B Em F B B")
    t.chords(prog, inst_pad(0.16), 3, [(0, 0, 16), (0, 1, 16), (0, 2, 16)])
    drone = inst_tri(0.3, a=0.3, s=0.9, r=0.3)
    for b in range(16):
        place(t.buf, drone(note_freq("E2"), 16 * t.step), b * 16 * t.step * SR)
    bells = parse(
        "E6:4 -:4 B5:4 G5:4  C6:8 G5:8  A5:4 C6:4 E6:8  D#6:8 F#5:8 "
        "G5:4 B5:4 E6:8  E6:4 D6:4 C6:8  F5:4 A5:4 C6:8  B5:16 "
        "E5:4 -:4 B4:4 G5:4  C6:8 E5:8  A5:4 E5:4 C6:8  D#5:8 B5:8 "
        "G5:4 E5:4 B5:8  F5:4 A5:4 C6:8  B5:8 F#5:8  -:16")
    t.seq(bells, inst_bell(0.22, 3.0))
    t.drums({"k": "x.........x....."}, vol=0.5)
    return t.render(reverb=0.45, delay_steps=4)


def boss():
    t = Track(150, 16)
    prog = bars_of("Em Em C D Em Em C B Am C D B Em C D B")
    t.bass(prog, inst_pulse(0.5, 0.2, s=0.8, r=0.02), 2,
           [(i, ["r", "r", "8", "r"][i % 4], 1) for i in range(16)])
    t.chords(prog, inst_pulse(0.125, 0.06, s=0.5), 4, [(i * 2, [0, 1, 2, 1][i % 4], 2) for i in range(8)])
    lead = parse(
        "E5:2 E5:2 G5:2 E5:2 B5:4 A5:4  G5:2 F#5:2 E5:2 D5:2 E5:8  E5:2 E5:2 G5:2 E5:2 C6:4 B5:4 "
        "A5:2 G5:2 F#5:2 G5:2 A5:8  B5:4 G5:4 E5:4 G5:4  B5:2 C6:2 B5:2 A5:2 G5:8 "
        "C6:4 G5:4 E5:4 G5:4  F#5:4 D#5:4 B4:8  A5:4 C6:4 E6:4 C6:4  G5:4 C6:4 E6:8 "
        "F#5:4 A5:4 D6:4 A5:4  D#6:8 B5:8  E6:4 B5:4 G5:4 E5:4  C6:4 G5:4 E5:4 C5:4 "
        "D6:4 A5:4 F#5:4 D5:4  B5:4 D#6:4 F#6:8")
    t.seq(lead, inst_pulse(0.25, 0.17, a=0.005, s=0.7, r=0.04, vib=0.008))
    t.drums({"k": "x...x...x...x.x.", "s": "....x.......x..x", "h": "xxxxxxxxxxxxxxxx"}, vol=0.8)
    return t.render(reverb=0.2, delay_steps=3)


def jingle(kind):
    if kind == "victory":
        t = Track(132, 4)
        mel = parse("C5:2 E5:2 G5:2 C6:4 -:2 G5:2 C6:2  E6:16  -:16 -:16")
        t.seq(mel, inst_pulse(0.25, 0.25, s=0.7, r=0.3))
        t.chords(["C", "C", "F", "C"], inst_tri(0.25), 4, [(0, 0, 16), (0, 1, 16), (0, 2, 16)])
        out = t.buf[: int(4 * 16 * t.step * SR + SR)]
    else:
        t = Track(90, 3)
        mel = parse("E5:4 D5:4 B4:4 G4:4  F#4:6 D#4:2 E4:16  -:12")
        t.seq(mel, inst_pulse(0.5, 0.22, s=0.6, r=0.4, vib=0.01))
        t.chords(["Em", "B", "Em"], inst_pad(0.2), 3, [(0, 0, 16), (0, 1, 16), (0, 2, 16)])
        out = t.buf[: int(3 * 16 * t.step * SR + SR)]
    out = echo(out, 0.18, 0.3, 3)
    n = int(0.3 * SR)
    out[-n:] *= np.linspace(1, 0, n)
    return normalize(out, 0.8)


TRACKS = {"camp": camp, "moss": moss, "ash": ash, "sanctum": sanctum, "boss": boss,
          "victory": lambda: jingle("victory"), "death": lambda: jingle("death")}


def build_all(out_dir):
    for name, fn in TRACKS.items():
        write_wav(os.path.join(out_dir, f"{name}.wav"), fn())
    return len(TRACKS)
