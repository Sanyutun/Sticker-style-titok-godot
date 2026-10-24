#!/usr/bin/env python3
"""Original 48 kHz audio bed, SFX and a scratch synthesized narration guide.

The music and sound effects are synthesized from scratch for this repository
(project-owned, CC0). The narration is a synthetic guide track generated with
espeak-ng; it is NOT a final human voice-over and must be replaced before
publication (see credits).
"""
from pathlib import Path
import subprocess, wave, json
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "projects" / "salt_hypertension" / "audio"
OUT = ROOT / "tools_audio" / "_work"
AUDIO.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
SR = 48000
DUR = 10.2

rng = np.random.default_rng(20261024)

def write_wav(path, data, sr=SR):
    data = np.asarray(data)
    if data.ndim == 1:
        data = np.stack([data, data], axis=1)
    data = np.clip(data, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())

def t_axis(d):
    return np.arange(int(SR * d)) / SR

def env_ad(n, attack, decay, curve=2.0):
    a = np.clip(np.arange(n) / max(1, int(SR * attack)), 0, 1)
    d = np.exp(-np.arange(n) / max(1, SR * decay / 4))
    return (a ** 0.7) * d

def sine(freq, d, phase=0.0):
    return np.sin(2 * np.pi * freq * t_axis(d) + phase)

def soft_saw(freq, d, harmonics=7):
    t = t_axis(d)
    out = np.zeros_like(t)
    for k in range(1, harmonics + 1):
        out += np.sin(2 * np.pi * freq * k * t) / (k * k)
    return out

def pluck(freq, d=1.4, amp=1.0):
    t = t_axis(d)
    e = np.exp(-t * 5.2)
    w = (np.sin(2*np.pi*freq*t) + 0.35*np.sin(2*np.pi*freq*2.01*t) + 0.12*np.sin(2*np.pi*freq*3.99*t))
    return w * e * amp

def add(buf, sig, start):
    i = int(start * SR)
    n = min(len(sig), len(buf) - i)
    if n > 0:
        buf[i:i+n] += sig[:n]

# ---------------------------------------------------------------- music bed
n = int(SR * DUR)
music = np.zeros((n, 2))
t = np.arange(n) / SR

# Warm minimal pad. Chord blocks: Am, Fmaj7, Cmaj9, Am(add9).
chords = [
    (0.0, 4.4, [110.00, 164.81, 220.00, 261.63]),
    (4.2, 6.9, [87.31, 130.81, 174.61, 220.00]),
    (6.7, 8.9, [130.81, 196.00, 261.63, 329.63]),
    (8.7, 10.2, [110.00, 164.81, 220.00, 277.18]),
]
for start, end, freqs in chords:
    i0, i1 = int(start*SR), int(end*SR)
    seg_t = np.arange(i1-i0)/SR
    # slow swell in and out
    env = np.minimum(1, seg_t/0.5) * np.minimum(1, np.maximum(0, (end-start-seg_t))/0.8)
    env = env ** 1.4
    for k, f in enumerate(freqs):
        for det, pan in [(-0.18, 0.35), (0.18, 0.65)]:
            sig = np.sin(2*np.pi*(f+det)*seg_t + 0.1*k) * (0.035 / (1 + k*0.3))
            sig += 0.25*np.sin(2*np.pi*(f+det)*2*seg_t) * 0.035 / (1 + k*0.3)
            music[i0:i1, 0] += sig * pan * env
            music[i0:i1, 1] += sig * (1-pan) * env

# Sub pulse / heartbeat (soft, intentional)
for bt, amp in [(0.0, .12), (4.55, .16), (5.02, .10), (8.78, .18), (9.30, .10)]:
    d = 0.9
    tt = t_axis(d)
    kick = np.sin(2*np.pi*(52 - 18*tt/d)*tt) * np.exp(-tt*7) * amp
    add(music[:,0], kick, bt); add(music[:,1], kick, bt)

# Plucked motif, sparse and deliberate
notes = [
    (0.35, 659.25, .12), (0.85, 880.00, .08), (1.55, 523.25, .10),
    (2.35, 659.25, .11), (2.95, 587.33, .07), (3.60, 523.25, .08),
    (4.50, 349.23, .10), (5.00, 440.00, .08), (5.55, 523.25, .10),
    (6.05, 587.33, .06), (6.70, 392.00, .09), (7.20, 523.25, .10),
    (7.75, 659.25, .09), (8.30, 783.99, .08), (8.80, 880.00, .12),
    (9.35, 659.25, .06),
]
for st, f, amp in notes:
    p = pluck(f, 1.6, amp)
    add(music[:,0], p, st)
    add(music[:,1], np.roll(p, 24), st)

# Shaker ticks - quiet, textured, every eighth at 96bpm
for i in range(34):
    st = i * 0.3125 + 0.08
    if st >= DUR - 0.2:
        break
    nsh = int(0.035*SR)
    noise = rng.normal(0, 1, nsh)
    noise = np.diff(noise, prepend=0)  # high-pass
    e = np.exp(-np.arange(nsh)/(SR*0.006))
    accent = 0.045 if i % 4 == 0 else (0.028 if i % 2 == 0 else 0.018)
    add(music[:,0], noise*e*accent, st)
    add(music[:,1], noise*e*accent*0.8, st + 0.004)

# Gentle stereo width and final fade
music[:,1] = 0.5*music[:,1] + 0.5*np.roll(music[:,0], 90)
fade = np.ones(n)
tail = int(0.6*SR)
fade[-tail:] = np.linspace(1, 0, tail)
music *= fade[:,None]
write_wav(AUDIO / "music_bed.wav", music * 0.8)

# ---------------------------------------------------------------- SFX
def make_noise_sweep(d, f0, f1, amp=0.5, curve=1.0):
    n = int(SR*d)
    x = np.arange(n)/n
    noise = rng.normal(0, 1, n)
    # cheap resonant-ish filtering with one-pole lowpass whose cutoff rises
    out = np.zeros(n)
    y = 0.0
    fc = (f0 + (f1-f0)*(x**curve)) / SR
    alpha = np.clip(2*np.pi*fc, 0, 1)
    for i in range(n):
        y += alpha[i] * (noise[i] - y)
        out[i] = y
    env = np.sin(np.pi*np.clip(x,0,1))**1.6
    return out*env*amp

# salt pour: granular noise, small crystal ticks
d = 0.95
nz = make_noise_sweep(d, 4500, 12000, 0.35)
for _ in range(46):
    st = rng.uniform(0, d-0.06)
    nsh = int(0.018*SR)
    click = rng.normal(0,1,nsh)*np.exp(-np.arange(nsh)/(SR*0.003))*rng.uniform(.05,.16)
    add(nz, click, st)
write_wav(AUDIO / "sfx_salt_pour.wav", np.stack([nz, np.roll(nz, 33)], axis=1))

# whoosh: both directions
for name, f0, f1, d in [("sfx_whoosh_in.wav", 220, 3200, 0.9), ("sfx_whoosh_out.wav", 2400, 180, 0.8)]:
    w = make_noise_sweep(d, f0, f1, 0.42, 0.7)
    st = np.stack([w, np.roll(w, 47)], axis=1)
    write_wav(AUDIO / name, st)

# tick
d = 0.12
tt = t_axis(d)
tick = (np.sin(2*np.pi*1900*tt) + .5*np.sin(2*np.pi*2900*tt))*np.exp(-tt*55)*0.22
write_wav(AUDIO / "sfx_tick.wav", np.stack([tick, tick], axis=1))

# riser into hero
d = 1.5
r = make_noise_sweep(d, 300, 9000, 0.25, 2.0)
tt = t_axis(d)
tone = (np.sin(2*np.pi*(180 + 520*(tt/d)**2)*tt) * nn if False else 0)
env = (tt/d)**2.2 * np.minimum(1, (d-tt)/0.08)
r = r + np.sin(2*np.pi*(160 + 480*(tt/d)**2)*tt)*env*0.05
write_wav(AUDIO / "sfx_riser.wav", np.stack([r, np.roll(r, 61)], axis=1))

# accent chime + low impact
d = 1.8
tt = t_axis(d)
boom = np.sin(2*np.pi*(70 - 26*tt/d)*tt)*np.exp(-tt*5)*0.55
chime = (np.sin(2*np.pi*880*tt) + .55*np.sin(2*np.pi*1320*tt) + .3*np.sin(2*np.pi*1760*tt))*np.exp(-tt*2.6)*0.18
accent = boom + chime
write_wav(AUDIO / "sfx_accent.wav", np.stack([accent, np.roll(accent, 18)], axis=1))

# stamp / thud
d = 0.7
tt = t_axis(d)
thud = np.sin(2*np.pi*90*tt)*np.exp(-tt*10)*0.5 + rng.normal(0, .12, len(tt))*np.exp(-tt*40)
write_wav(AUDIO / "sfx_stamp.wav", np.stack([thud, thud*0.95], axis=1))

# water drip
d = 0.8
tt = t_axis(d)
f = 950 - 420*tt/d
drip = np.sin(2*np.pi*f*tt)*np.exp(-tt*9)*0.25
write_wav(AUDIO / "sfx_drip.wav", np.stack([drip, drip], axis=1))

# ---------------------------------------------------------------- narration guide
lines = [
    ("narration_01.wav", "Too much sodium can make your body hold water.", 0.35, 2.55),
    ("narration_02.wav", "That can raise blood pressure.", 2.95, 2.25),
    ("narration_03.wav", "Over time, it can contribute to hypertension.", 4.70, 2.75),
    ("narration_04.wav", "Cutting back helps.", 7.45, 1.35),
]
manifest = []
for fn, text, start, slot in lines:
    raw = OUT / (fn.replace(".wav", "_raw.wav"))
    subprocess.run(["espeak-ng", "-v", "en-us", "-s", "168", "-p", "42", "-a", "180", "-w", str(raw), text], check=True)
    with wave.open(str(raw)) as w:
        raw_dur = w.getnframes()/w.getframerate()
    tempo = max(1.0, raw_dur / slot)
    # convert to 48k stereo, gentle EQ / compression via ffmpeg
    af = f"atempo={tempo:.4f},aresample=48000,highpass=f=90,lowpass=f=12000,acompressor=threshold=-18dB:ratio=2.5:attack=8:release=120,pan=stereo|c0=c0|c1=c0"
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(raw), "-af", af,
                    "-ar", "48000", "-ac", "2", str(AUDIO / fn)], check=True)
    with wave.open(str(AUDIO / fn)) as w:
        dur = w.getnframes()/w.getframerate()
    manifest.append({"file": fn, "text": text, "start": start, "duration": dur, "tempo": tempo})
    print(fn, f"raw={raw_dur:.3f}s -> {dur:.3f}s (atempo {tempo:.2f})")

(ROOT / "projects" / "salt_hypertension" / "audio" / "narration_timing.json").write_text(json.dumps(manifest, indent=2))
print("done")
