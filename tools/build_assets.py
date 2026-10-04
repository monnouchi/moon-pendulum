"""Build the original bell samples and bundled font. Python standard library only."""
from pathlib import Path
import base64, math, random, struct, wave
ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / 'game/assets/audio'
AUDIO.mkdir(parents=True, exist_ok=True)
# The seven bells form a D-major pentatonic voicing, never an arbitrary scale.
NOTES = [50, 57, 62, 64, 66, 69, 74]
for index, midi in enumerate(NOTES):
    rate, duration = 22050, 2.4
    freq = 440 * 2 ** ((midi - 69) / 12)
    data = bytearray()
    for i in range(int(rate * duration)):
        t = i / rate
        # A soft felt attack, tuned harmonic partials and baked-in echoes.
        def tone(x):
            if x < 0: return 0
            attack = min(1, x / .009)
            return attack * sum(a * math.sin(2*math.pi*freq*p*x) * math.exp(-x/d) for p,a,d in [(1,.62,.72),(2,.20,.48),(3,.10,.31),(4,.04,.17)])
        v = .52 * (tone(t) + .21*tone(t-.21) + .10*tone(t-.43))
        data.extend(struct.pack('<h', int(max(-.98,min(.98,v))*32767)))
    with wave.open(str(AUDIO / f'bell_{index}.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(data)
font_dir = ROOT / 'game/assets/fonts'
(font_dir/'MoonSans.ttf').write_bytes(base64.b64decode((font_dir/'MoonSans.ttf.b64').read_text()))
print('Built seven original D-major bell samples and bundled Japanese font.')
