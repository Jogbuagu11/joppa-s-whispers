#!/usr/bin/env python3
"""Makes the game's small sound effects, from nothing but arithmetic.

    python3 tool/make_sounds.py

Writes short, soft .wav files into assets/audio/. Each is a few plucked
notes (a sine wave with gentle overtones and a quick fade), so they are ours
outright: no samples, no licences. Change the notes below and run it again
to retune them.
"""
import math
import os
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'audio')
RATE = 22050

# Note names -> frequencies (Hz), a pentatonic set that always sounds kind.
NOTE = {'C4': 261.63, 'D4': 293.66, 'E4': 329.63, 'G4': 392.00, 'A4': 440.00,
        'C5': 523.25, 'D5': 587.33, 'E5': 659.25, 'G5': 783.99, 'A3': 220.00,
        'E3': 164.81}

# name -> (notes as (note, start seconds, length seconds), loudness 0..1)
SOUNDS = {
    'spawn': ([('E4', 0.00, 0.14)], 0.35),
    'merge': ([('G4', 0.00, 0.16), ('C5', 0.07, 0.24)], 0.45),
    'deliver': ([('C5', 0.00, 0.18), ('E5', 0.09, 0.18), ('G5', 0.18, 0.36)], 0.45),
    'task': ([('C4', 0.00, 0.70), ('E4', 0.05, 0.65), ('G4', 0.10, 0.60), ('C5', 0.18, 0.60)], 0.40),
    'empty': ([('A3', 0.00, 0.16), ('E3', 0.10, 0.22)], 0.35),
    'reward': ([('D5', 0.00, 0.14), ('G5', 0.08, 0.14), ('A4', 0.16, 0.12), ('D5', 0.22, 0.40)], 0.40),
}


def pluck(freq, length):
    """One plucked note: quick start, long soft fade, two quiet overtones."""
    count = int(RATE * length)
    out = []
    for i in range(count):
        t = i / RATE
        attack = min(1.0, t / 0.008)
        fade = math.exp(-4.5 * t / length)
        wave_value = (math.sin(2 * math.pi * freq * t)
                      + 0.30 * math.sin(2 * math.pi * freq * 2 * t)
                      + 0.10 * math.sin(2 * math.pi * freq * 3 * t))
        out.append(attack * fade * wave_value / 1.4)
    return out


def render(notes, loudness):
    total = max(start + length for _, start, length in notes) + 0.02
    samples = [0.0] * int(RATE * total)
    for name, start, length in notes:
        offset = int(RATE * start)
        for i, value in enumerate(pluck(NOTE[name], length)):
            samples[offset + i] += value
    peak = max(abs(s) for s in samples) or 1.0
    return [s / peak * loudness for s in samples]


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (notes, loudness) in SOUNDS.items():
        samples = render(notes, loudness)
        path = os.path.join(OUT, f'{name}.wav')
        with wave.open(path, 'wb') as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(RATE)
            f.writeframes(b''.join(
                struct.pack('<h', int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
        print(f'{name}.wav  {len(samples) / RATE:.2f}s  {os.path.getsize(path) // 1024} KB')


if __name__ == '__main__':
    main()
