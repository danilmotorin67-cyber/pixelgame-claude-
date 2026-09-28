#!/usr/bin/env python3
"""Readies the audio made in ElevenLabs (docs/audio/ELEVENLABS_BRIEF.md) for the game.

Put the downloads, named by id, in assets_src/audio/music/, assets_src/audio/ambience/ and
assets_src/audio/sfx/ (mp3, wav, ogg or flac). Then:

    python3 tools/audio_loop.py            # everything new or changed
    python3 tools/audio_loop.py cape_spring --loop-from 12.5 --xfade 3

Music and ambience are trimmed of silence, brought to one loudness (music about -16 LUFS, ambience quieter)
and made to loop without a seam: the last `xfade` seconds are blended with the seconds before the loop start,
so when the player jumps from the end back to `loop_start` nothing clicks; the start is nudged (--search
seconds) to where the rhythm before it matches the ending, so the beats of the crossfade fall together. loop_start is written to
data/music.json. By default the loop goes back to the very start (--loop-from 0); a track with an intro gets
--loop-from at the first bar after it. Sounds are trimmed, given short fades and peak at -6 dBFS.
Output: assets/audio/<kind>/<id>.ogg. Needs numpy and soundfile (pip install numpy soundfile).
"""
import argparse
import json
import os
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets_src", "audio")
OUT = os.path.join(ROOT, "assets", "audio")
TABLE = os.path.join(ROOT, "data", "music.json")
KINDS = ("music", "ambience", "sfx")
EXTS = (".mp3", ".wav", ".ogg", ".flac")
# Loudness targets as RMS (dBFS), a simple stand-in for LUFS: music ≈ -16 LUFS, ambience under it.
TARGET_RMS = {"music": -19.0, "ambience": -26.0}
SFX_PEAK = -6.0


def db(x):
    return 20 * np.log10(max(float(x), 1e-9))


def trim(audio, sr, threshold_db=-50.0):
    level = np.abs(audio).max(axis=1)
    loud = np.where(level > 10 ** (threshold_db / 20))[0]
    if loud.size == 0:
        return audio
    pad = int(0.02 * sr)
    return audio[max(loud[0] - pad, 0): min(loud[-1] + pad, len(audio))]


def envelope(audio, sr, hop=0.01):
    """The loudness contour in 10 ms steps, with its onsets stressed (rises only), for matching rhythm."""
    h = int(hop * sr)
    mono = np.abs(audio).mean(axis=1)
    frames = mono[: len(mono) // h * h].reshape(-1, h).mean(axis=1)
    rise = np.maximum(np.diff(frames, prepend=frames[0]), 0.0)
    return frames / (frames.max() + 1e-9) + 4.0 * rise / (rise.max() + 1e-9)


def aligned_start(audio, sr, earliest, xfade, search):
    """The loop start within `search` seconds after `earliest` whose lead-in matches the ending best, so the
    beats of the crossfade fall together instead of doubling."""
    hop = 0.01
    env = envelope(audio, sr, hop)
    n = int(xfade / hop)
    tail = env[-n:] - env[-n:].mean()
    best, best_i = -np.inf, int(earliest / hop)
    for i in range(int(earliest / hop), min(int((earliest + search) / hop), len(env) - 2 * n)):
        head = env[i - n:i] - env[i - n:i].mean()
        score = float((tail * head).sum() / (np.linalg.norm(tail) * np.linalg.norm(head) + 1e-9))
        if score > best:
            best, best_i = score, i
    return best_i * hop, best


def make_loop(audio, sr, loop_from, xfade, search=0.0):
    """The file plays 0..end and then jumps to loop_start; the tail is blended into what precedes it."""
    n = int(xfade * sr)
    earliest = max(loop_from, xfade)
    if search > 0:
        earliest, _ = aligned_start(audio, sr, earliest, xfade, search)
    start = max(int(earliest * sr), n)
    if len(audio) < start + 2 * n:
        raise ValueError("too short to loop with this crossfade")
    out = audio.copy()
    w = np.linspace(0.0, 1.0, n)[:, None]
    out[-n:] = audio[-n:] * np.cos(w * np.pi / 2) + audio[start - n:start] * np.sin(w * np.pi / 2)
    return out, start / sr


def level_to(audio, target_rms):
    rms = np.sqrt(np.mean(audio ** 2))
    gain = 10 ** ((target_rms - db(rms)) / 20)
    audio = audio * gain
    peak = np.abs(audio).max()
    if peak > 0.97:
        audio = audio * (0.97 / peak)
    return audio


def fades(audio, sr, fade_in=0.005, fade_out=0.03):
    a, b = int(fade_in * sr), int(fade_out * sr)
    if a:
        audio[:a] *= np.linspace(0, 1, a)[:, None]
    if b:
        audio[-b:] *= np.linspace(1, 0, b)[:, None]
    return audio


# libsndfile's Vorbis encoder can crash on a long buffer written at once, so it gets one second at a time.
def write_ogg(dest, audio, sr):
    with sf.SoundFile(dest, "w", samplerate=sr, channels=audio.shape[1], format="OGG", subtype="VORBIS") as f:
        data = audio.astype(np.float32)
        for start in range(0, len(data), sr):
            f.write(data[start:start + sr])


def read(path):
    audio, sr = sf.read(path, always_2d=True, dtype="float64")
    if audio.shape[1] == 1:
        audio = np.repeat(audio, 2, axis=1)
    return audio[:, :2], sr


def process(kind, path, loop_from=None, xfade=2.0, search=4.0):
    ident = os.path.splitext(os.path.basename(path))[0]
    audio, sr = read(path)
    audio = trim(audio, sr)
    info = {}
    if kind == "sfx":
        audio = audio / max(np.abs(audio).max(), 1e-9) * 10 ** (SFX_PEAK / 20)
        audio = fades(audio, sr)
    else:
        audio = level_to(audio, TARGET_RMS[kind])
        audio, loop_start = make_loop(audio, sr, loop_from or 0.0, xfade, search)
        info = {"loop_start": round(loop_start, 3), "length": round(len(audio) / sr, 2)}
    os.makedirs(os.path.join(OUT, kind), exist_ok=True)
    dest = os.path.join(OUT, kind, ident + ".ogg")
    write_ogg(dest, audio, sr)
    return ident, dest, info


def save_loop(kind, ident, info):
    table = json.load(open(TABLE, encoding="utf-8"))
    section = "ambience" if kind == "ambience" else ("layers" if ident in table["layers"] else "tracks")
    entry = table[section].setdefault(ident, {"title": ident, "where": "", "loop_start": 0.0})
    entry["loop_start"] = info["loop_start"]
    with open(TABLE, "w", encoding="utf-8") as f:
        json.dump(table, f, ensure_ascii=False, indent=2)
        f.write("\n")


def sources():
    for kind in KINDS:
        folder = os.path.join(SRC, kind)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            if name.lower().endswith(EXTS):
                yield kind, os.path.join(folder, name)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*", help="only these ids (default: all new or changed files)")
    ap.add_argument("--loop-from", type=float, default=None, help="seconds where the loop starts again")
    ap.add_argument("--xfade", type=float, default=2.0, help="seconds of the seam crossfade")
    ap.add_argument("--search", type=float, default=4.0,
                    help="seconds after the loop start to look for the spot whose rhythm matches the ending (0: off)")
    args = ap.parse_args()
    done = 0
    for kind, path in sources():
        ident = os.path.splitext(os.path.basename(path))[0]
        dest = os.path.join(OUT, kind, ident + ".ogg")
        if args.ids and ident not in args.ids:
            continue
        if not args.ids and os.path.exists(dest) and os.path.getmtime(dest) >= os.path.getmtime(path):
            continue
        try:
            ident, dest, info = process(kind, path, args.loop_from, args.xfade, args.search)
        except ValueError as e:
            print(f"{ident}: {e}", file=sys.stderr)
            continue
        if info:
            save_loop(kind, ident, info)
        print(kind, ident, info or "", "->", os.path.relpath(dest, ROOT))
        done += 1
    print(f"{done} file(s)")


if __name__ == "__main__":
    main()
