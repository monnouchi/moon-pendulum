"""Build original stereo bell timbres, bundled font and public build identity.
Python standard library only. No remote samples, runtime synthesizer or audio effects.
"""
from pathlib import Path
import base64, math, os, re, struct, subprocess, wave
ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / 'game/assets/audio'
AUDIO.mkdir(parents=True, exist_ok=True)
NOTES = [50, 57, 62, 64, 66, 71, 74]  # D, A, D, E, F-sharp, B, D: D-major pentatonic.
BANKS = [
    ('bell', .009, [(1,.62,.72),(2,.20,.48),(3,.10,.31),(4,.04,.17)]),
    ('warm', .017, [(1,.82,1.05),(2,.14,.74),(3,.035,.42),(4,.01,.20)]),
    ('air', .012, [(1,.52,1.13),(2,.24,.83),(3,.12,.46),(5,.055,.23)]),
]

def make_sample(path, midi, pan, attack_time, partials):
    rate, duration = 22050, 2.4
    freq = 440 * 2 ** ((midi - 69) / 12)
    theta = (pan + 1) * math.pi / 4
    left, right = math.cos(theta), math.sin(theta)
    def tone(x):
        if x < 0: return 0
        attack = min(1, x / attack_time)
        return attack * sum(a * math.sin(2*math.pi*freq*p*x) * math.exp(-x/d) for p,a,d in partials)
    data = bytearray()
    for i in range(int(rate * duration)):
        t = i / rate
        direct = .52 * tone(t)
        reflected = .52 * (.21*tone(t-.21) + .10*tone(t-.43))
        fade = min(1, (duration-t)/.30)**2
        channels = ((direct*left + reflected*right)*fade, (direct*right + reflected*left)*fade)
        data.extend(struct.pack('<hh', *(int(max(-.98,min(.98,v))*32767) for v in channels)))
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(rate); w.writeframes(data)

def make_coda(path, attack_time, partials):
    """A quiet D-major bloom, changing note lengths, then an open tonic."""
    rate, duration = 22050, 4.8
    frames = int(rate * duration)
    left, right = [0.0]*frames, [0.0]*frames
    events = [
        (0.00,62,.22,-.18),(0.04,66,.16,.04),(0.09,69,.13,.20),
        (0.38,74,.24,.22),(0.66,71,.20,.12),(1.10,69,.22,-.08),
        (1.68,66,.18,-.18),(2.10,64,.17,.10),
        (2.60,62,.25,0.0),(2.60,50,.19,-.14),(2.64,69,.11,.18),
    ]
    for at,midi,level,pan in events:
        start = int(at*rate)
        freq = 440 * 2**((midi-69)/12)
        angle = (pan+1)*math.pi/4
        l,r = math.cos(angle),math.sin(angle)
        for j in range(min(int(2.4*rate),frames-start)):
            t = j/rate
            fade = min(1,(2.4-t)/.30)**2
            tone = min(1,t/attack_time)*sum(a*math.sin(2*math.pi*freq*p*t)*math.exp(-t/d) for p,a,d in partials)
            v = level*tone*fade
            left[start+j] += v*l
            right[start+j] += v*r
            for delay,reflection in [(int(.21*rate),.17),(int(.43*rate),.08)]:
                if start+j+delay<frames:
                    left[start+j+delay] += v*r*reflection
                    right[start+j+delay] += v*l*reflection
    peak = max(max(map(abs,left)),max(map(abs,right)))
    scale = min(1,.48/max(peak,.0001))
    data = bytearray()
    for i,(l,r) in enumerate(zip(left,right)):
        fade = min(1,(duration-i/rate)/.30)**2
        data.extend(struct.pack('<hh',int(l*scale*fade*32767),int(r*scale*fade*32767)))
    with wave.open(str(path),'wb') as w:
        w.setnchannels(2);w.setsampwidth(2);w.setframerate(rate);w.writeframes(data)

for prefix, attack, partials in BANKS:
    for index, midi in enumerate(NOTES):
        make_sample(AUDIO/f'{prefix}_{index}.wav', midi, (index-3)/3*.65, attack, partials)
    for name,midi,pan in [('left_low',62,-.38),('right_low',71,.38),('left_high',66,-.38),('right_high',74,.38)]:
        make_sample(AUDIO/f'{prefix}_echo_{name}.wav',midi,pan,attack,partials)
    make_coda(AUDIO/f'{prefix}_coda.wav',attack,partials)
font_dir = ROOT / 'game/assets/fonts'
(font_dir/'MoonSans.ttf').write_bytes(base64.b64decode((font_dir/'MoonSans.ttf.b64').read_text()))
revision = os.environ.get('GITHUB_SHA', '')
if not revision:
    try:
        revision = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True,stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError): revision = 'local'
if not re.fullmatch('[0-9a-f]{40}', revision): revision = 'local'
(ROOT/'game/build_info.gd').write_text('extends RefCounted\nconst COMMIT = "'+revision+'"\n')
print('Built three original stereo timbres, spatial echoes, three harmonic codas, bundled font and build identity.')
