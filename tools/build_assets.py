"""Build original stereo bell timbres, bundled font and public build identity.
Python standard library only. No remote samples, runtime synthesizer or audio effects.
"""
from pathlib import Path
import base64, math, os, re, struct, subprocess, wave
from build_music import build as build_music
ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / 'game/assets/audio'
AUDIO.mkdir(parents=True, exist_ok=True)
NOTES = [50, 57, 62, 64, 66, 71, 74]  # Fixed reference recordings; night_harmony.gd selects each night's playback pitches.
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

for prefix, attack, partials in BANKS:
    for index, midi in enumerate(NOTES):
        make_sample(AUDIO/f'{prefix}_{index}.wav', midi, (index-3)/3*.65, attack, partials)
    for name,midi,pan in [('left_low',62,-.38),('right_low',71,.38),('left_high',66,-.38),('right_high',74,.38)]:
        make_sample(AUDIO/f'{prefix}_echo_{name}.wav',midi,pan,attack,partials)
build_music(AUDIO)
font_dir = ROOT / 'game/assets/fonts'
(font_dir/'MoonSans.ttf').write_bytes(base64.b64decode((font_dir/'MoonSans.ttf.b64').read_text()))
revision = os.environ.get('GITHUB_SHA', '')
if not revision:
    try:
        revision = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True,stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError): revision = 'local'
if not re.fullmatch('[0-9a-f]{40}', revision): revision = 'local'
(ROOT/'game/build_info.gd').write_text('extends RefCounted\nconst COMMIT = "'+revision+'"\n')
print('Built original bell timbres, five night instruments, sustained bass, bundled font and build identity.')
