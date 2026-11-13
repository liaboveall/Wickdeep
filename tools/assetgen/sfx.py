"""Sound effects, all synthesised. Names match the keys used by src/autoload/audio.gd."""

import os

import numpy as np

from synth import (SR, bitcrush, decay, echo, env, highpass_fast, lowpass_fast, mix, noise, normalize, osc,
                   place, sweep, t_axis, write_wav)


def shoot():
    d = 0.12
    f = sweep(980, 360, d, 0.6)
    s = osc("square", f, d, 0.25) * decay(d, 22) * 0.55
    s += highpass_fast(noise(d, 1), 2000) * decay(d, 60) * 0.35
    return s


def shoot_heavy():
    d = 0.2
    f = sweep(520, 140, d, 0.5)
    s = osc("square", f, d, 0.5) * decay(d, 14) * 0.6
    s += noise(d, 2, 2) * decay(d, 25) * 0.4
    return s


def hit():
    d = 0.09
    s = noise(d, 3, 2) * decay(d, 40) * 0.8
    s += osc("square", sweep(300, 90, d), d) * decay(d, 30) * 0.5
    return s


def crit():
    d = 0.18
    s = hit()
    s = mix(s, osc("square", sweep(1400, 1800, d), d, 0.25) * decay(d, 18) * 0.35)
    return s


def enemy_die():
    d = 0.35
    s = noise(d, 4, 3) * decay(d, 9) * 0.6
    s += osc("square", sweep(420, 60, d, 0.7), d, 0.5) * decay(d, 8) * 0.45
    return bitcrush(s, 10)


def enemy_shoot():
    d = 0.14
    return osc("tri", sweep(700, 300, d), d) * decay(d, 18) * 0.7 + noise(d, 5) * decay(d, 50) * 0.15


def arrow():
    d = 0.22
    tw = osc("tri", sweep(240, 180, d), d) * decay(d, 12) * 0.6
    wh = highpass_fast(noise(d, 6), 3000) * env(d, 0.02, 0.05, 0.3, 0.12) * 0.35
    return mix(tw, wh)


def player_hurt():
    d = 0.4
    s = osc("square", sweep(620, 110, d, 0.8), d, 0.5) * decay(d, 6) * 0.6
    s += noise(d, 7, 4) * decay(d, 16) * 0.5
    return bitcrush(s, 8)


def player_die():
    d = 1.4
    s = osc("square", sweep(400, 40, d, 0.6), d, 0.5) * decay(d, 2.2) * 0.55
    s += osc("tri", sweep(200, 30, d, 0.5), d) * decay(d, 1.8) * 0.5
    s += noise(d, 8, 6) * decay(d, 4) * 0.3
    return bitcrush(s, 8)


def dash():
    d = 0.22
    n = lowpass_fast(noise(d, 9), 2400)
    return n * env(d, 0.02, 0.04, 0.7, 0.14) * 1.2 + osc("sine", sweep(200, 500, d), d) * decay(d, 14) * 0.2


def flare():
    d = 0.9
    rise = osc("square", sweep(180, 900, 0.25), 0.25, 0.5) * env(0.25, 0.01, 0.1, 0.6, 0.1) * 0.35
    boom = noise(d, 10, 3) * decay(d, 5) * 0.7 + osc("sine", sweep(110, 35, d), d) * decay(d, 4) * 0.8
    out = np.zeros(int((d + 0.25) * SR))
    place(out, rise, 0)
    place(out, boom, 0.2 * SR)
    return out


def pickup():
    d = 0.09
    a = osc("tri", 1318.5, d * 0.5) * decay(d * 0.5, 30)
    b = osc("tri", 1760, d * 0.5) * decay(d * 0.5, 25)
    return np.concatenate([a, b]) * 0.55


def heal():
    out = np.zeros(int(0.5 * SR))
    for i, f in enumerate((523.3, 659.3, 784, 1046.5)):
        place(out, osc("tri", f, 0.18) * decay(0.18, 10) * 0.5, i * 0.07 * SR)
    return out


def relic():
    out = np.zeros(int(1.1 * SR))
    for i, f in enumerate((392, 523.3, 659.3, 784, 1046.5, 1318.5)):
        place(out, osc("square", f, 0.3, 0.25) * decay(0.3, 7) * 0.3, i * 0.06 * SR)
        place(out, osc("sine", f * 2, 0.4) * decay(0.4, 6) * 0.15, i * 0.06 * SR)
    return echo(out, 0.12, 0.3, 3)[: int(1.3 * SR)]


def door_close():
    d = 0.35
    s = osc("square", sweep(160, 70, d), d, 0.5) * decay(d, 9) * 0.6
    s += noise(d, 11, 5) * decay(d, 14) * 0.6
    return bitcrush(s, 6)


def door_open():
    out = np.zeros(int(0.45 * SR))
    for i in range(4):
        place(out, noise(0.06, 12 + i, 3) * decay(0.06, 30) * 0.45, i * 0.07 * SR)
    place(out, osc("tri", sweep(200, 420, 0.3), 0.3) * env(0.3, 0.02, 0.1, 0.5, 0.15) * 0.4, 0.05 * SR)
    return out


def ui_move():
    d = 0.04
    return osc("square", 880, d, 0.25) * decay(d, 50) * 0.35


def ui_select():
    out = np.zeros(int(0.14 * SR))
    place(out, osc("square", 659.3, 0.06, 0.25) * decay(0.06, 30) * 0.4, 0)
    place(out, osc("square", 987.8, 0.08, 0.25) * decay(0.08, 25) * 0.4, 0.05 * SR)
    return out


def ui_back():
    out = np.zeros(int(0.14 * SR))
    place(out, osc("square", 659.3, 0.06, 0.25) * decay(0.06, 30) * 0.4, 0)
    place(out, osc("square", 440, 0.08, 0.25) * decay(0.08, 25) * 0.4, 0.05 * SR)
    return out


def slime_hop():
    d = 0.2
    return osc("sine", sweep(160, 420, d, 0.5), d) * decay(d, 10) * 0.7 + noise(d, 13, 8) * decay(d, 30) * 0.2


def knight_charge():
    d = 0.6
    s = osc("saw", sweep(90, 160, d), d) * env(d, 0.05, 0.1, 0.8, 0.2) * 0.45
    s += lowpass_fast(noise(d, 14), 900) * env(d, 0.05, 0.1, 0.8, 0.2) * 0.8
    return bitcrush(s, 10)


def stun():
    out = np.zeros(int(0.5 * SR))
    for i, f in enumerate((1200, 1500, 1200, 1500)):
        place(out, osc("tri", f, 0.08) * decay(0.08, 20) * 0.35, i * 0.1 * SR)
    return out


def spawn():
    d = 0.5
    return osc("sine", sweep(200, 700, d), d) * env(d, 0.2, 0.1, 0.5, 0.2) * 0.4 + \
        highpass_fast(noise(d, 15), 3000) * env(d, 0.3, 0.05, 0.3, 0.15) * 0.25


def explode():
    d = 0.6
    s = noise(d, 16, 4) * decay(d, 6) * 0.8
    s += osc("sine", sweep(120, 30, d), d) * decay(d, 5) * 0.9
    return bitcrush(s, 10)


def boss_roar():
    d = 1.4
    s = osc("saw", sweep(70, 45, d), d) * env(d, 0.1, 0.2, 0.8, 0.5) * 0.4
    s += osc("square", sweep(140, 90, d), d, 0.3) * env(d, 0.1, 0.2, 0.6, 0.5) * 0.25
    s += lowpass_fast(noise(d, 17, 2), 1200) * env(d, 0.05, 0.3, 0.6, 0.6) * 0.7
    return bitcrush(s, 8)


def boss_slam():
    d = 0.8
    s = osc("sine", sweep(90, 28, d, 0.6), d) * decay(d, 4.5) * 1.0
    s += noise(d, 18, 6) * decay(d, 8) * 0.6
    return s


def coin():
    out = np.zeros(int(0.35 * SR))
    place(out, osc("square", 987.8, 0.08, 0.5) * decay(0.08, 20) * 0.35, 0)
    place(out, osc("square", 1318.5, 0.25, 0.5) * decay(0.25, 10) * 0.35, 0.07 * SR)
    return out


def deny():
    d = 0.22
    return osc("square", 180, d, 0.5) * env(d, 0.005, 0.05, 0.7, 0.05) * 0.4 + \
        osc("square", 190, d, 0.5) * env(d, 0.005, 0.05, 0.7, 0.05) * 0.3


def talk(base):
    d = 0.045
    return osc("square", base, d, 0.5) * decay(d, 40) * 0.25


def stairs():
    out = np.zeros(int(1.2 * SR))
    for i, f in enumerate((659.3, 523.3, 440, 329.6, 261.6)):
        place(out, osc("tri", f, 0.25) * decay(0.25, 8) * 0.45, i * 0.11 * SR)
    place(out, lowpass_fast(noise(1.0, 19), 1500) * env(1.0, 0.3, 0.2, 0.5, 0.4) * 0.4, 0)
    return out


def shield_break():
    d = 0.4
    s = highpass_fast(noise(d, 20, 1), 4000) * decay(d, 10) * 0.6
    for f in (2093, 2637, 3136):
        s += osc("sine", f, d) * decay(d, 12) * 0.15
    return s


def altar():
    out = np.zeros(int(0.9 * SR))
    for i, f in enumerate((523.3, 784, 1046.5)):
        place(out, osc("sine", f, 0.6) * decay(0.6, 4) * 0.35, i * 0.1 * SR)
    return echo(out, 0.15, 0.35, 3)[: int(1.2 * SR)]


def burn():
    d = 0.18
    return lowpass_fast(noise(d, 21), 1800) * env(d, 0.02, 0.05, 0.4, 0.1) * 0.5


def footstep():
    d = 0.05
    return lowpass_fast(noise(d, 22, 2), 900) * decay(d, 60) * 0.35


SOUNDS = {
    "shoot": shoot, "shoot_heavy": shoot_heavy, "hit": hit, "crit": crit, "enemy_die": enemy_die,
    "enemy_shoot": enemy_shoot, "arrow": arrow, "player_hurt": player_hurt, "player_die": player_die,
    "dash": dash, "flare": flare, "pickup": pickup, "heal": heal, "relic": relic,
    "door_close": door_close, "door_open": door_open, "ui_move": ui_move, "ui_select": ui_select,
    "ui_back": ui_back, "slime_hop": slime_hop, "knight_charge": knight_charge, "stun": stun,
    "spawn": spawn, "explode": explode, "boss_roar": boss_roar, "boss_slam": boss_slam, "coin": coin,
    "deny": deny, "talk_wick": lambda: talk(880), "talk_granny": lambda: talk(330),
    "stairs": stairs, "shield_break": shield_break, "altar": altar, "burn": burn, "footstep": footstep,
}


def build_all(out_dir):
    for name, fn in SOUNDS.items():
        s = fn()
        # tiny fade-out to avoid clicks
        n = min(len(s), int(0.01 * SR))
        s[-n:] *= np.linspace(1, 0, n)
        write_wav(os.path.join(out_dir, f"{name}.wav"), normalize(s, 0.85))
    _ = t_axis
    return len(SOUNDS)
