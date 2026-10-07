"""Synthesize an original 110 BPM instrumental and two original interface sounds.

No samples, recordings, melodies, or presets from the skill's media library.
Run with: uv run --with numpy python brag-output/make-soundtrack.py
"""
from pathlib import Path
import json
import wave
import numpy as np

out = Path(__file__).resolve().parent/'composition/assets'
rate, seconds, bpm = 48000, 21, 110
beat = 60/bpm
rng = np.random.default_rng(22716)
mix = np.zeros((rate*seconds, 2), dtype=np.float64)

def hz(note): return 440*2**((note-69)/12)

def add(sound, at, gain=1, pan=0):
    start = round(at*rate)
    length = min(len(sound), len(mix)-start)
    if length <= 0: return
    gains = np.sqrt([(1-pan)/2, (1+pan)/2])
    mix[start:start+length] += gain*sound[:length, None]*gains

def time(duration): return np.arange(round(duration*rate))/rate

# Warm sustained harmony and a restrained electric-piano figure.
chords = [(52,55,59,66), (48,52,55,59), (43,50,55,64), (50,54,57,64)]
roots = [40,36,31,38]
for bar in range(10):
    start = bar*4*beat
    chord = chords[(bar//2)%4]
    t = time(4*beat+0.7)
    env = np.minimum(t/.28, 1)*np.exp(-t/4)*np.clip((t[-1]-t)/.7, 0, 1)
    for index, note in enumerate(chord):
        f = hz(note)
        pad = (np.sin(2*np.pi*f*t)+.25*np.sin(2*np.pi*f*1.0017*t)+.12*np.sin(4*np.pi*f*t))*env
        add(pad, start, .055, (index-1.5)*.35)
    for step, index in enumerate([0,2,1,3,2,1,0,2]):
        t = time(.85)
        f = hz(chord[index]+12)
        envelope = np.minimum(t/.009,1)*np.exp(-t/0.20)
        key = np.sin(2*np.pi*f*t+0.45*np.sin(4*np.pi*f*t)*np.exp(-t/.08))*envelope
        pan = (-.28 if step%2 else .28)
        add(key,start+step*beat/2,.11,pan)
        add(key,start+step*beat/2+beat*.75,.022,-pan)
    for step in [0,2,3.5]:
        t=time(.5)
        bass = np.sin(2*np.pi*hz(roots[(bar//2)%4])*t)*np.minimum(t/.01,1)*np.exp(-t/.2)
        add(bass,start+step*beat,.19)

for pulse in range(int(seconds/beat)+1):
    # Soft kick, brushed backbeat, and quiet eighth-note hats.
    if pulse%4 in (0,2):
        t=time(.24)
        freq=44+88*np.exp(-t/.017)
        kick=np.sin(2*np.pi*np.cumsum(freq)/rate)*np.exp(-t/.068)*np.minimum(t/.003,1)
        add(kick,pulse*beat,.26)
    if pulse%4 in (1,3):
        t=time(.15)
        noise=rng.normal(size=len(t))
        brush=np.convolve(noise,np.ones(5)/5,mode='same')*np.exp(-t/.025)
        add(brush,pulse*beat,.09,.05)
    for half in [0,.5]:
        t=time(.055)
        noise=rng.normal(size=len(t))
        hat=np.diff(noise,prepend=0)*np.exp(-t/.009)*np.minimum(t/.002,1)
        add(hat,(pulse+half)*beat,.010 if half else .008,.2)

fade=np.minimum(np.arange(len(mix))/rate/.15,1)*np.clip((seconds-np.arange(len(mix))/rate)/1.2,0,1)
mix=np.tanh(mix*1.2)*fade[:,None]
mix*=.88/np.max(np.abs(mix))

def write(file,samples):
    file.parent.mkdir(parents=True,exist_ok=True)
    if samples.ndim==1: samples=np.repeat(samples[:,None],2,axis=1)
    with wave.open(str(file),'wb') as writer:
        writer.setnchannels(2);writer.setsampwidth(2);writer.setframerate(rate)
        writer.writeframes((np.clip(samples,-1,1)*32767).astype('<i2').tobytes())

write(out/'music/bed.wav',mix)
t=time(.18)
reveal=(np.sin(2*np.pi*(420*t+600*t*t))*.18+rng.normal(size=len(t))*.08)*np.sin(np.pi*t/.18)**2*np.exp(-t/0.08)
write(out/'sfx/reveal.wav',reveal)
t=time(.02)
click=np.sin(2*np.pi*1250*t)*np.exp(-t/.003)*.16
write(out/'sfx/click.wav',click)
(out/'music/cues.json').write_text(json.dumps({'bpm':bpm,'duration':seconds,'beats':[round(i*beat,5) for i in range(int(seconds/beat)+1)]},indent=2)+'\n')
print('Original instrumental bed and interface sounds generated, 21 seconds at 110 BPM.')
