"""Synthesizes Purrmodoro's UI sounds into App/Sounds. Run: python3 Tools/make_sounds.py"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Sounds")


def silence(seconds):
    return [0.0] * int(SR * seconds)


def mallet(freq, seconds, decay):
    """A soft marimba-ish note: warm fundamental plus a quick, bright overtone."""
    out = []
    for i in range(int(SR * seconds)):
        t = i / SR
        env = (t / 0.004) if t < 0.004 else math.exp(-(t - 0.004) / decay)
        s = (math.sin(2 * math.pi * freq * t)
             + 0.10 * math.sin(2 * math.pi * freq * 2 * t) * math.exp(-t / 0.12)
             + 0.22 * math.sin(2 * math.pi * freq * 3.98 * t) * math.exp(-t / 0.04))
        out.append(s * env)
    return out


def mix(base, other, at_seconds, gain=1.0):
    start = int(SR * at_seconds)
    needed = start + len(other)
    if needed > len(base):
        base = base + [0.0] * (needed - len(base))
    for i, s in enumerate(other):
        base[start + i] += s * gain
    return base


def room(samples):
    """A touch of space so it doesn't sound dry."""
    out = samples + [0.0] * int(SR * 0.3)
    for delay, gain in ((0.045, 0.18), (0.09, 0.09), (0.16, 0.04)):
        d = int(SR * delay)
        for i in range(len(samples)):
            out[i + d] += samples[i] * gain
    return out


def write(name, samples, peak):
    top = max(abs(s) for s in samples) or 1
    fade = int(SR * 0.01)
    for i in range(fade):
        samples[-1 - i] *= i / fade
    frames = b"".join(struct.pack("<h", int(max(-1, min(1, s / top * peak)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


def pop():
    """A bubbly pop: quick downward pitch sweep."""
    out = []
    phase = 0.0
    for i in range(int(SR * 0.12)):
        t = i / SR
        freq = 520 + 700 * math.exp(-t / 0.018)
        phase += 2 * math.pi * freq / SR
        env = (t / 0.002) if t < 0.002 else math.exp(-t / 0.028)
        out.append(math.sin(phase) * env)
    return room(out)


def tick():
    random.seed(7)
    out = []
    for i in range(int(SR * 0.04)):
        t = i / SR
        env = math.exp(-t / 0.005)
        out.append((0.8 * math.sin(2 * math.pi * 2600 * t) + 0.2 * random.uniform(-1, 1)) * env)
    return out


def chime():
    """Two rising notes (C6 -> G6): 'ding-ding!'"""
    s = mallet(1046.5, 0.9, 0.28)
    s = mix(s, mallet(1568.0, 1.1, 0.35), 0.12)
    return room(s)


def chime_low():
    """Two gentle falling notes (G5 -> C5): 'break's over'."""
    s = mallet(784.0, 0.9, 0.3)
    s = mix(s, mallet(523.25, 1.2, 0.4), 0.16)
    return room(s)


def boop():
    """A tiny upward blip for booping her nose."""
    out = []
    phase = 0.0
    for i in range(int(SR * 0.14)):
        t = i / SR
        freq = 700 + 600 * (1 - math.exp(-t / 0.03))
        phase += 2 * math.pi * freq / SR
        env = (t / 0.003) if t < 0.003 else math.exp(-t / 0.045)
        out.append(math.sin(phase) * env)
    return room(out)


def purr():
    """A soft, rumbly purr: filtered noise pulsing about 24 times a second."""
    random.seed(3)
    out = []
    low = 0.0
    dur = 1.6
    for i in range(int(SR * dur)):
        t = i / SR
        low += 0.06 * (random.uniform(-1, 1) - low)
        pulse = (0.5 + 0.5 * math.sin(2 * math.pi * 24 * t)) ** 2
        env = min(1, t / 0.15) * min(1, (dur - t) / 0.4)
        tone = 0.35 * math.sin(2 * math.pi * 120 * t) + 0.2 * math.sin(2 * math.pi * 240 * t)
        out.append((low * 2.2 + tone) * pulse * env)
    return out


def phrase(notes, voice, gap, repeat_at, decay, tail):
    """Play a little run of notes, then once more a touch quieter, like a gentle wake-up."""
    s = silence(0.01)
    for rep, gain in ((0, 1.0), (repeat_at, 0.8)):
        for n, f in enumerate(notes):
            s = mix(s, voice(f, tail, decay), rep + n * gap, gain)
    return room(s)


def music_box_note(freq, seconds, decay):
    """A plucked comb tooth: bright, quick attack, a slight shimmer from two detuned tines."""
    out = []
    for i in range(int(SR * seconds)):
        t = i / SR
        env = (t / 0.002) if t < 0.002 else math.exp(-(t - 0.002) / decay)
        shimmer = 1 + 0.04 * math.sin(2 * math.pi * 5.5 * t)
        s = (0.5 * math.sin(2 * math.pi * freq * t)
             + 0.5 * math.sin(2 * math.pi * freq * 1.0025 * t)
             + 0.25 * math.sin(2 * math.pi * freq * 3 * t) * math.exp(-t / 0.05))
        out.append(s * env * shimmer)
    return out


def singing_bowl(freq, seconds):
    """One soft strike of a bowl: slow bloom, long ring, gentle wobble from beating partials."""
    out = []
    for i in range(int(SR * seconds)):
        t = i / SR
        env = min(1, t / 0.03) * math.exp(-t / 1.8)
        s = (math.sin(2 * math.pi * freq * t)
             + 0.9 * math.sin(2 * math.pi * (freq + 1.3) * t)
             + 0.35 * math.sin(2 * math.pi * freq * 2.71 * t) * math.exp(-t / 1.1)
             + 0.15 * math.sin(2 * math.pi * freq * 5.12 * t) * math.exp(-t / 0.5))
        out.append(s * env)
    return out


def alarm_marimba(low=False):
    """Warm wooden knocks, rising (or falling, when a break ends)."""
    notes = [783.99, 659.25, 523.25, 392.0] if low else [523.25, 659.25, 783.99, 1046.5]
    return phrase(notes, mallet, 0.15, 1.7, 0.35, 1.2)


def alarm_music_box(low=False):
    """A tiny tinkly tune."""
    tune = [1318.51, 1567.98, 2093.0, 1975.53, 1567.98]
    if low:
        tune = [f / 2 for f in tune]
    return phrase(tune, music_box_note, 0.2, 1.6, 0.55, 1.4)


def alarm_bowl(low=False):
    """A single deep, calm hum, struck twice."""
    f = 196.0 if low else 262.0
    return room(mix(singing_bowl(f, 4.0), singing_bowl(f, 4.0), 2.6, 0.7))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("pop.wav", pop(), 0.55)
    write("tick.wav", tick(), 0.25)
    write("chime.wav", chime(), 0.6)
    write("chime-low.wav", chime_low(), 0.5)
    write("boop.wav", boop(), 0.45)
    write("purr.wav", purr(), 0.5)
    write("alarm-marimba.wav", alarm_marimba(), 0.42)
    write("alarm-marimba-low.wav", alarm_marimba(low=True), 0.38)
    write("alarm-musicbox.wav", alarm_music_box(), 0.34)
    write("alarm-musicbox-low.wav", alarm_music_box(low=True), 0.34)
    write("alarm-bowl.wav", alarm_bowl(), 0.45)
    write("alarm-bowl-low.wav", alarm_bowl(low=True), 0.45)
    print("Sounds written to", os.path.abspath(OUT))
