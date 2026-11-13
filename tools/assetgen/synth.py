"""Minimal chiptune synthesizer used by sfx.py and music.py (mono, 16-bit, 22050 Hz)."""

import math
import os
import wave

import numpy as np

SR = 22050
NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def note_freq(name):
    """'A4' -> 440.0 ; 'C#5' -> ... ; supports sharps and flats."""
    name = name.strip()
    pitch, octave = name[:-1], int(name[-1])
    n = NOTE_INDEX[pitch] + (octave + 1) * 12
    return 440.0 * 2 ** ((n - 69) / 12)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def phase_from_freq(freq):
    """freq: scalar or array per sample -> phase in cycles."""
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), freq.shape if hasattr(freq, "shape") else ())
    return np.cumsum(f) / SR if np.ndim(freq) else None


def osc(kind, freq, dur, duty=0.5):
    n = int(dur * SR)
    if np.ndim(freq) == 0:
        ph = (np.arange(n) * float(freq) / SR) % 1.0
    else:
        f = np.asarray(freq, dtype=np.float64)[:n]
        ph = np.cumsum(f) / SR % 1.0
    if kind == "square":
        return np.where(ph < duty, 1.0, -1.0)
    if kind == "tri":
        return 4.0 * np.abs(ph - 0.5) - 1.0
    if kind == "saw":
        return 2.0 * ph - 1.0
    if kind == "sine":
        return np.sin(2 * math.pi * ph)
    raise ValueError(kind)


def noise(dur, seed=0, period=1):
    rnd = np.random.default_rng(seed)
    n = int(dur * SR)
    base = rnd.uniform(-1, 1, n // period + 1)
    return np.repeat(base, period)[:n]


def sweep(f0, f1, dur, curve=1.0):
    n = int(dur * SR)
    x = np.linspace(0, 1, n) ** curve
    return f0 + (f1 - f0) * x


def env(n_or_dur, a=0.005, d=0.05, s=0.6, r=0.1, sustain_time=None):
    """ADSR envelope; length in seconds or samples."""
    n = n_or_dur if isinstance(n_or_dur, int) else int(n_or_dur * SR)
    out = np.zeros(n)
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    si = max(0, n - ai - di - ri) if sustain_time is None else int(sustain_time * SR)
    seg = []
    seg.append(np.linspace(0, 1, max(ai, 1)))
    seg.append(np.linspace(1, s, max(di, 1)))
    seg.append(np.full(si, s))
    seg.append(np.linspace(s, 0, max(ri, 1)))
    e = np.concatenate(seg)[:n]
    out[: len(e)] = e
    return out


def decay(dur, k=8.0):
    t = t_axis(dur)
    return np.exp(-k * t)


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff in Hz (scalar)."""
    a = 1.0 - math.exp(-2 * math.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def lowpass_fast(x, cutoff):
    """Vectorised approximation: moving average sized to the cutoff."""
    k = max(1, int(SR / (cutoff * 2.2)))
    if k == 1:
        return x
    kernel = np.ones(k) / k
    return np.convolve(x, kernel, mode="same")


def highpass_fast(x, cutoff):
    return x - lowpass_fast(x, cutoff)


def echo(x, delay, feedback=0.35, repeats=4, wrap=False):
    d = int(delay * SR)
    out = np.copy(x) if wrap else np.concatenate([x, np.zeros(d * repeats)])
    for k in range(1, repeats + 1):
        g = feedback ** k
        if wrap:
            out += g * np.roll(x, d * k)
        else:
            out[d * k: d * k + len(x)] += g * x
    return out


def bitcrush(x, levels=16):
    return np.round(x * levels) / levels


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def place(buf, sig, start):
    s = int(start)
    if s >= len(buf):
        return
    e = min(len(buf), s + len(sig))
    buf[s:e] += sig[: e - s]


def normalize(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x * (peak / m)


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = np.clip(x, -1, 1)
    pcm = (data * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
