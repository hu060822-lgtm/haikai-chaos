#!/usr/bin/env python3
"""HAIKAI: CHAOS music, composed and synthesised here (no samples, no outside sounds).

    python3 tools/music/compose.py [out_dir]     -> lobby.ogg, match.ogg, results.ogg

Every track is rendered as one circular loop: the reverb and delay tails wrap around to the
start, so the file loops with no seam. Deterministic (fixed seeds): same code, same music.

  lobby    灰板待機室  84 BPM, D minor. Warm detuned pads through Dm9 / Bbmaj7 / Gm9 / A7sus,
           a sub bass, a lo-fi kick and rim, a soft bell melody in the second half, and
           far-off metal clanks: a concrete hall waiting for the match.
  match    PATCH WAR   156 BPM, E minor. Industrial drive: four-on-the-floor kick, a
           distorted sixteenth-note bass, a saw arpeggio, a lead that enters in B, a break
           and a full return. ULTRAKILL-speed energy without the noise wall.
  results  結算         96 BPM. Eight bars of the lobby's chords, brighter, for the score screen.
"""
import math
import os
import subprocess
import sys

import numpy as np

SR = 44100


def midi(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7,
        "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def n(name):
    """'E2' -> midi number."""
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE[pitch]


# --- Oscillators and shapes -------------------------------------------------------------

def _blep(phase, dt):
    """PolyBLEP correction for a jump at phase 0 (dt: per-sample phase step)."""
    out = np.zeros_like(phase)
    a = phase < dt
    t = phase[a] / dt[a]
    out[a] = t + t - t * t - 1.0
    b = phase > 1.0 - dt
    t = (phase[b] - 1.0) / dt[b]
    out[b] = t * t + t + t + 1.0
    return out


def saw(freq, length, phase0=0.0):
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (length,))
    dt = np.ascontiguousarray(f / SR)
    phase = (phase0 + np.cumsum(dt)) % 1.0
    return 2.0 * phase - 1.0 - _blep(phase, dt)


def square(freq, length, width=0.5):
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (length,))
    dt = np.ascontiguousarray(f / SR)
    p1 = np.cumsum(dt) % 1.0
    p2 = (p1 + (1.0 - width)) % 1.0
    return (2.0 * p1 - 1.0 - _blep(p1, dt)) - (2.0 * p2 - 1.0 - _blep(p2, dt))


def sine(freq, length, phase0=0.0):
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (length,))
    return np.sin(phase0 + 2.0 * np.pi * np.cumsum(f) / SR)


def adsr(length, a=0.01, d=0.1, s=0.7, r=0.1, hold=None):
    """Attack, decay, sustain level, release (seconds); the note is held for `hold` s."""
    t = np.arange(length) / SR
    hold = length / SR - r if hold is None else hold
    env = np.where(t < a, t / max(a, 1e-6), s + (1.0 - s) * np.exp(-(t - a) / max(d, 1e-6)))
    rel = t > hold
    if rel.any():
        at_release = env[np.argmax(rel)] if rel.any() else s
        env[rel] = at_release * np.exp(-(t[rel] - hold) / max(r / 4.0, 1e-6))
    return env


def onepole_lp(x, cutoff):
    """One-pole low-pass, cutoff in Hz (scalar or per-sample)."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    a = 1.0 - np.exp(-2.0 * np.pi * c / SR)
    y = np.empty_like(x)
    z = 0.0
    for i in range(x.shape[0]):
        z += a[i] * (x[i] - z)
        y[i] = z
    return y


def svf(x, cutoff, q=0.7, mode="lp"):
    """Chamberlin state-variable filter; cutoff scalar or per-sample. Resonant."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    f = 2.0 * np.sin(np.pi * np.minimum(c, SR / 6.0) / SR)
    damp = 1.0 / q
    low = band = 0.0
    out = np.empty_like(x)
    for i in range(x.shape[0]):
        low += f[i] * band
        high = x[i] - low - damp * band
        band += f[i] * high
        out[i] = low if mode == "lp" else (band if mode == "bp" else high)
    return out


def hp_noise(length, rng, smooth=0.6):
    w = rng.uniform(-1, 1, length)
    lp = np.convolve(w, np.ones(3) / 3.0, mode="same")
    return w - smooth * lp


# --- Instruments ------------------------------------------------------------------------

def kick(rng, punch=1.0, length=0.45, low=44.0):
    L = int(length * SR)
    t = np.arange(L) / SR
    f = low + (150.0 * punch) * np.exp(-t * 28.0)
    body = sine(f, L) * np.exp(-t * 7.5)
    click = rng.uniform(-1, 1, L) * np.exp(-t * 400.0) * 0.4
    return np.tanh((body + click) * 1.6) * 0.9


def snare(rng, length=0.28, tone=190.0, crack=1.0):
    L = int(length * SR)
    t = np.arange(L) / SR
    noise = hp_noise(L, rng, 0.8) * np.exp(-t * 16.0) * crack
    body = sine(tone * (1.0 + 0.4 * np.exp(-t * 60)), L) * np.exp(-t * 22.0)
    return np.tanh((noise * 0.8 + body * 0.7) * 1.3) * 0.7


def rim(rng):
    L = int(0.08 * SR)
    t = np.arange(L) / SR
    return (sine(1700.0, L) * 0.5 + hp_noise(L, rng) * 0.5) * np.exp(-t * 70.0) * 0.5


def hat(rng, open_=False):
    L = int((0.32 if open_ else 0.06) * SR)
    t = np.arange(L) / SR
    metal = sum(square(f, L) for f in (3150.0, 4270.0, 5340.0, 6900.0)) / 4.0
    x = (hp_noise(L, rng, 0.95) * 0.6 + metal * 0.4)
    x = x - onepole_lp(x, 6000.0)
    return x * np.exp(-t * (9.0 if open_ else 60.0)) * 0.35


def clank(rng, base=180.0):
    """A far-off hit on a steel beam: inharmonic partials, quick decay."""
    L = int(1.6 * SR)
    t = np.arange(L) / SR
    out = np.zeros(L)
    for ratio, amp, dec in ((1.0, 1.0, 3.0), (2.76, 0.6, 5.0), (5.40, 0.4, 8.0), (8.93, 0.25, 12.0)):
        out += sine(base * ratio * rng.uniform(0.99, 1.01), L) * amp * np.exp(-t * dec)
    return out * 0.18 * np.minimum(t * 300, 1.0)


def crash(rng):
    L = int(2.2 * SR)
    t = np.arange(L) / SR
    x = hp_noise(L, rng, 0.9)
    x = x - onepole_lp(x, 4000.0)
    return x * np.exp(-t * 1.8) * 0.3


def pad_voice(freq, length, detune=0.12, cutoff=1400.0, rng=None):
    """Three detuned saws, gently low-passed: a warm, wide pad."""
    x = np.zeros(length)
    for d in (-detune, 0.0, detune):
        x += saw(freq * 2.0 ** (d / 12.0), length, phase0=rng.uniform() if rng is not None else 0.0)
    return onepole_lp(onepole_lp(x / 3.0, cutoff), cutoff * 1.3)


def bell(freq, length):
    """FM bell: modulator at 3.5x, index falling."""
    t = np.arange(length) / SR
    index = 2.4 * np.exp(-t * 4.0)
    mod = np.sin(2 * np.pi * freq * 3.5 * t) * index
    return np.sin(2 * np.pi * freq * t + mod) * np.exp(-t * 2.2)


def pluck_saw(freq, length, cutoff_from, cutoff_to, q=1.4, decay=10.0):
    t = np.arange(length) / SR
    cut = cutoff_to + (cutoff_from - cutoff_to) * np.exp(-t * decay)
    return svf(saw(freq, length), cut, q)


# --- Mixing -----------------------------------------------------------------------------

class Track:
    def __init__(self, bpm, bars, beats=4):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.length = int(round(bars * beats * self.beat * SR))
        self.bus = {}

    def at(self, bar, beat=0.0):
        return int(round((bar * 4 + beat) * self.beat * SR))

    def add(self, bus, sound, start, gain=1.0, pan=0.0):
        """Mixes a mono `sound` into stereo `bus` at sample `start`, wrapping around the loop."""
        if bus not in self.bus:
            self.bus[bus] = np.zeros((2, self.length))
        l = math.cos((pan + 1) * math.pi / 4) * math.sqrt(2) * gain
        r = math.sin((pan + 1) * math.pi / 4) * math.sqrt(2) * gain
        idx = (start + np.arange(sound.shape[0])) % self.length
        np.add.at(self.bus[bus][0], idx, sound * l)
        np.add.at(self.bus[bus][1], idx, sound * r)

    def add_stereo(self, bus, left, right, start, gain=1.0):
        if bus not in self.bus:
            self.bus[bus] = np.zeros((2, self.length))
        idx = (start + np.arange(left.shape[0])) % self.length
        np.add.at(self.bus[bus][0], idx, left * gain)
        np.add.at(self.bus[bus][1], idx, right * gain)


def circular_reverb(x, seconds=2.4, damp=3000.0, seed=3, predelay=0.02):
    """Convolution with decaying, darkening noise, done circularly (loops with no seam)."""
    rng = np.random.default_rng(seed)
    L = int(seconds * SR)
    t = np.arange(L) / SR
    out = np.zeros_like(x)
    for ch in range(2):
        ir = rng.uniform(-1, 1, L) * np.exp(-t * 6.9 / seconds)
        ir = onepole_lp(ir, damp)
        ir[: int(predelay * SR)] = 0.0
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        n = x.shape[1]
        size = 1 << int(math.ceil(math.log2(n)))
        ir_full = np.zeros(n)
        ir_full[: min(L, n)] = ir[: min(L, n)]
        out[ch] = np.real(np.fft.ifft(np.fft.fft(x[ch]) * np.fft.fft(ir_full)))
    return out


def circular_delay(x, seconds, feedback=0.4, repeats=5, pingpong=True):
    out = np.zeros_like(x)
    d = int(seconds * SR)
    for k in range(1, repeats + 1):
        g = feedback ** k
        if pingpong:
            ch_from = (k % 2)
            out[ch_from] += np.roll((x[0] + x[1]) * 0.5, d * k) * g
        else:
            out += np.roll(x, d * k, axis=1) * g
    return out


def duck(track, kicks, depth=0.5, release=0.18):
    """A gain curve that dips at each kick (sidechain pump)."""
    g = np.ones(track.length)
    L = int(release * 4 * SR)
    t = np.arange(L) / SR
    shape = 1.0 - depth * np.exp(-t / release * 2.2)
    for k in kicks:
        idx = (k + np.arange(L)) % track.length
        g[idx] = np.minimum(g[idx], shape)
    return g


def master(x, drive=1.15, ceiling=0.92):
    x = x / (np.max(np.abs(x)) + 1e-9)
    x = np.tanh(x * drive) / np.tanh(drive)
    # Gentle low cut so the loop isn't muddy.
    for ch in range(2):
        x[ch] = x[ch] - onepole_lp(x[ch], 28.0)
    return x / (np.max(np.abs(x)) + 1e-9) * ceiling


def write_ogg(x, path, quality=5):
    pcm = (np.clip(x, -1, 1).T * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(quality), path], input=pcm, check=True)


# --- Lobby: 灰板待機室 ------------------------------------------------------------------

def lobby():
    rng = np.random.default_rng(11)
    tr = Track(84, 32)
    chords = [  # each two bars
        ["D3", "F3", "A3", "C4", "E4"],     # Dm9
        ["Bb2", "D3", "F3", "A3", "E4"],    # Bbmaj7(#11-ish)
        ["G2", "Bb2", "D3", "F3", "A3"],    # Gm9
        ["A2", "D3", "E3", "G3", "C#4"],    # A7sus -> A7 colour
    ]
    roots = ["D2", "Bb1", "G1", "A1"]
    bar_len = tr.at(2) - tr.at(0)
    for bar in range(0, 32, 2):
        ci = (bar // 2) % 4
        L = bar_len + int(0.6 * SR)
        for i, note in enumerate(chords[ci]):
            f = midi(n(note))
            cutoff = 900.0 + 500.0 * (bar >= 16)
            v = pad_voice(f, L, detune=0.1, cutoff=cutoff, rng=rng) * adsr(L, a=0.6, d=1.2, s=0.8, r=0.7, hold=bar_len / SR)
            tr.add("pad", v, tr.at(bar), 0.16, pan=(i - 2) * 0.28)
        # Sub bass: root on the one, a fifth on bar two's "and of three".
        f = midi(n(roots[ci]))
        L = int(bar_len * 0.95)
        b = (sine(f, L) + 0.3 * sine(f * 2, L)) * adsr(L, a=0.02, d=0.6, s=0.6, r=0.3)
        tr.add("bass", b, tr.at(bar), 0.36)
        L2 = int(tr.beat * 1.5 * SR)
        b2 = sine(f * 1.5, L2) * adsr(L2, a=0.02, d=0.2, s=0.5, r=0.2)
        tr.add("bass", b2, tr.at(bar + 1, 2.5), 0.3)
    kicks = []
    for bar in range(32):
        if bar < 2:
            continue
        for beat in (0.0, 2.5):
            s = tr.at(bar, beat)
            kicks.append(s)
            tr.add("drums", kick(rng, punch=0.7, low=48.0), s, 0.55)
        for beat in (1.0, 3.0):
            tr.add("drums", rim(rng), tr.at(bar, beat), 0.5, pan=0.15)
        for beat in np.arange(0, 4, 0.5):
            if rng.uniform() < 0.8:
                tr.add("drums", hat(rng), tr.at(bar, beat + (0.04 if beat % 1 else 0.0)), 0.14 + 0.08 * (beat % 1 == 0.5),
                       pan=-0.3)
    # Bell melody in the second half: D minor pentatonic, sparse, answering phrases.
    phrase = [("A4", 0.0, 1.5), ("C5", 1.5, 0.5), ("D5", 2.0, 2.0), ("F5", 4.5, 0.5), ("E5", 5.0, 1.0), ("C5", 6.0, 2.0),
              ("D5", 8.0, 1.5), ("A4", 9.5, 0.5), ("G4", 10.0, 2.0), ("A4", 12.5, 0.5), ("C5", 13.0, 1.0), ("A4", 14.0, 2.0)]
    for rep in (16, 24):
        for note, beat, dur in phrase:
            L = int((dur * tr.beat + 1.4) * SR)
            tr.add("lead", bell(midi(n(note)), L), tr.at(rep) + int(beat * tr.beat * SR), 0.2, pan=0.25)
    # Clanks, far away.
    for bar in (3, 7, 12, 19, 23, 28, 31):
        tr.add("fx", clank(rng, base=rng.uniform(140, 260)), tr.at(bar, rng.choice([1.5, 2.75, 3.25])), 0.8,
               pan=rng.uniform(-0.8, 0.8))
    # Room tone: soft filtered noise, slowly breathing.
    t = np.arange(tr.length) / SR
    air = onepole_lp(onepole_lp(rng.uniform(-1, 1, tr.length), 450.0), 450.0) * (0.6 + 0.4 * np.sin(2 * np.pi * t / (tr.length / SR) * 4))
    tr.add("fx", air, 0, 0.08)

    pump = duck(tr, kicks, depth=0.35)
    mix = (tr.bus["pad"] * pump + tr.bus["bass"] * pump + tr.bus["drums"] + tr.bus["lead"] + tr.bus["fx"])
    wet = circular_reverb(tr.bus["pad"] * 0.6 + tr.bus["lead"] + tr.bus["fx"] * 1.2 + tr.bus["drums"] * 0.25, seconds=3.2,
                          damp=2600.0)
    echo = circular_delay(tr.bus["lead"], tr.beat * 0.75, feedback=0.45)
    return master(mix + wet * 0.55 + echo * 0.5, drive=1.05)


# --- Match: PATCH WAR -------------------------------------------------------------------

def match():
    rng = np.random.default_rng(23)
    bars = 40
    tr = Track(156, bars)
    prog = ["E", "C", "D", "B"]                # Em - C - D - B, two bars each
    prog_oct = {"E": "E1", "C": "C2", "D": "D2", "B": "B1"}
    arp = {"E": ["E4", "G4", "B4", "E5", "B4", "G4"], "C": ["C4", "E4", "G4", "C5", "G4", "E4"],
           "D": ["D4", "F#4", "A4", "D5", "A4", "F#4"], "B": ["B3", "D#4", "F#4", "B4", "F#4", "D#4"]}

    def section(bar):
        if bar < 4:
            return "intro"
        if bar < 12:
            return "A"
        if bar < 20:
            return "B"
        if bar < 24:
            return "break"
        if bar < 36:
            return "A2"
        return "outro"

    six = tr.beat / 4.0
    kicks = []
    for bar in range(bars):
        sec = section(bar)
        chord = prog[(bar // 2) % 4]
        # Drums.
        if sec in ("A", "B", "A2") or (sec == "intro" and bar >= 2) or (sec == "outro" and bar < 39):
            for beat in range(4):
                s = tr.at(bar, beat)
                kicks.append(s)
                tr.add("drums", kick(rng, punch=1.1, length=0.35), s, 0.85)
            if sec == "B":
                tr.add("drums", kick(rng, punch=1.0, length=0.3), tr.at(bar, 2.75), 0.5)
        if sec in ("A", "B", "A2", "outro"):
            for beat in (1, 3):
                tr.add("drums", snare(rng), tr.at(bar, beat), 0.75, pan=0.05)
            if bar % 4 == 3:
                for k, beat in enumerate((3.5, 3.75)):
                    tr.add("drums", snare(rng, length=0.15, crack=0.8), tr.at(bar, beat), 0.4 + 0.15 * k, pan=-0.1)
            for s16 in range(16):
                accent = 0.32 if s16 % 4 == 2 else 0.16
                if sec == "B" or s16 % 2 == 0 or rng.uniform() < 0.4:
                    tr.add("drums", hat(rng, open_=(s16 % 8 == 6 and sec != "outro")), tr.at(bar, s16 / 4.0), accent,
                           pan=0.35)
        if sec in ("A", "A2") and bar % 8 == (4 if sec == "A" else 0):
            tr.add("drums", crash(rng), tr.at(bar), 0.6, pan=-0.3)
        if sec == "break" and bar == 20:
            tr.add("drums", crash(rng), tr.at(bar), 0.7, pan=0.3)
        if sec == "break":
            tr.add("drums", kick(rng, punch=0.9, length=0.5), tr.at(bar, 0), 0.7)
            tr.add("drums", snare(rng, length=0.4, crack=1.2), tr.at(bar, 2), 0.55)
        # Bass: sixteenths, octave jumps, distorted, filter opens with the section.
        if sec != "break" and not (sec == "intro" and bar < 2):
            root = midi(n(prog_oct[chord]))
            pattern = [1, 0, 1, 1, 2, 0, 1, 1, 1, 0, 1, 2, 1, 1, 0, 1]   # 0 rest, 1 root, 2 octave
            for s16, p in enumerate(pattern):
                if p == 0:
                    continue
                f = root * (2.0 if p == 2 else 1.0)
                L = int(six * SR * 0.9)
                cut = {"intro": 500.0, "A": 900.0, "B": 1300.0, "A2": 1500.0, "outro": 700.0}[sec]
                v = pluck_saw(f, L, cut * 2.2, cut * 0.5, q=1.8, decay=18.0) + 0.6 * sine(f, L)
                v = np.tanh(v * 2.2) * adsr(L, a=0.002, d=0.08, s=0.7, r=0.03)
                tr.add("bass", v, tr.at(bar, s16 / 4.0), 0.36)
        # Arpeggio: saw plucks, sixteenths (triplet-feel six-note cycle over 16ths).
        if sec != "outro" or bar < 38:
            notes = arp[chord]
            gain = 0.11 if sec == "intro" else (0.085 if sec in ("B", "A2") else 0.1)
            open_ = {"intro": 600 + 700 * (bar / 4.0), "A": 2200, "B": 1800, "break": 1400, "A2": 2600, "outro": 1200}[sec]
            for s16 in range(16):
                note = notes[(bar * 16 + s16) % len(notes)]
                L = int(six * SR * 1.6)
                v = pluck_saw(midi(n(note)), L, open_ * 1.8, open_ * 0.3, q=2.2, decay=14.0)
                tr.add("arp", v * adsr(L, a=0.002, d=0.12, s=0.3, r=0.06), tr.at(bar, s16 / 4.0), gain,
                       pan=0.45 if s16 % 2 else -0.45)
        # Pads in the break and under B.
        if sec in ("break", "B") and bar % 2 == 0:
            chord_notes = {"E": ["E3", "G3", "B3", "D4"], "C": ["C3", "E3", "G3", "B3"], "D": ["D3", "F#3", "A3", "C4"],
                           "B": ["B2", "D#3", "F#3", "A3"]}[chord]
            L = tr.at(2) + int(0.5 * SR)
            for i, note in enumerate(chord_notes):
                v = pad_voice(midi(n(note)), L, 0.14, 1800.0 if sec == "break" else 1100.0, rng)
                v *= adsr(L, a=0.4 if sec == "B" else 1.2, d=1.0, s=0.8, r=0.5, hold=tr.at(2) / SR)
                tr.add("pad", v, tr.at(bar), 0.11 if sec == "B" else 0.17, pan=(i - 1.5) * 0.4)
    # Lead: B section and the second half of A2. Square-ish, with delay.
    lead = [("B4", 0, 1.5), ("D5", 1.5, 0.5), ("E5", 2, 1), ("G5", 3, 1), ("F#5", 4, 1.5), ("E5", 5.5, 0.5), ("D5", 6, 2),
            ("E5", 8, 1.5), ("G5", 9.5, 0.5), ("A5", 10, 1), ("B5", 11, 1), ("A5", 12, 0.75), ("G5", 12.75, 0.75),
            ("F#5", 13.5, 0.5), ("D#5", 14, 2)]
    for start in (12, 16, 28, 32):
        for note, beat, dur in lead:
            L = int((dur * tr.beat * 0.95) * SR)
            f = midi(n(note))
            vib = f * (1.0 + 0.004 * np.sin(2 * np.pi * 5.5 * np.arange(L) / SR) * np.minimum(np.arange(L) / (0.25 * SR), 1))
            v = 0.6 * square(vib, L, 0.35) + 0.5 * saw(vib * 1.003, L)
            v = onepole_lp(v, 3200.0) * adsr(L, a=0.008, d=0.2, s=0.75, r=0.08)
            tr.add("lead", v, tr.at(start) + int(beat * tr.beat * SR), 0.16, pan=0.0)
    # Riser into A2: noise swell over the last break bar.
    L = tr.at(1)
    t = np.arange(L) / SR
    riser = hp_noise(L, rng, 0.9) * (t / t[-1]) ** 2
    riser = svf(riser, 400 + 6000 * (t / t[-1]) ** 2, 2.0, "bp")
    tr.add("fx", riser, tr.at(23), 0.5)

    pump = duck(tr, kicks, depth=0.55, release=0.12)
    dry = tr.bus["drums"] + tr.bus["bass"] * pump + tr.bus["arp"] * pump + tr.bus["pad"] * pump + tr.bus["lead"] + tr.bus["fx"]
    wet = circular_reverb(tr.bus["arp"] * 0.5 + tr.bus["pad"] + tr.bus["lead"] * 0.7 + tr.bus["drums"] * 0.12 + tr.bus["fx"],
                          seconds=1.8, damp=4200.0, seed=5)
    echo = circular_delay(tr.bus["lead"], tr.beat * 0.75, feedback=0.38, repeats=4)
    return master(dry + wet * 0.35 + echo * 0.4, drive=1.3)


# --- Results ----------------------------------------------------------------------------

def results():
    rng = np.random.default_rng(31)
    tr = Track(96, 8)
    chords = [["D3", "F3", "A3", "C4", "E4"], ["Bb2", "D3", "F3", "A3", "C4"], ["F2", "C3", "F3", "A3", "E4"],
              ["A2", "C#3", "E3", "G3", "B3"]]
    bar_len = tr.at(2)
    for i, ch in enumerate(chords):
        L = bar_len + int(0.8 * SR)
        for j, note in enumerate(ch):
            v = pad_voice(midi(n(note)), L, 0.09, 2000.0, rng) * adsr(L, a=0.3, d=1.0, s=0.8, r=0.8, hold=bar_len / SR)
            tr.add("pad", v, tr.at(i * 2), 0.17, pan=(j - 2) * 0.3)
        for k, note in enumerate(ch[1:] + [ch[0][:-1] + str(int(ch[0][-1]) + 2)]):
            L = int(2.0 * SR)
            tr.add("lead", bell(midi(n(note)) * 2, L), tr.at(i * 2, k * 1.0), 0.12, pan=0.3 - k * 0.15)
    wet = circular_reverb(tr.bus["pad"] + tr.bus["lead"], seconds=3.5, damp=3000.0, seed=9)
    return master(tr.bus["pad"] + tr.bus["lead"] + wet * 0.6, drive=1.0)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "audio", "music")
    os.makedirs(out, exist_ok=True)
    for name, fn in (("results", results), ("lobby", lobby), ("match", match)):
        x = fn()
        write_ogg(x, os.path.join(out, name + ".ogg"))
        print("wrote %s.ogg  %.1f s" % (name, x.shape[1] / SR))
