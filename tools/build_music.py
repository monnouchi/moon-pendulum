"""Original, soft musical voices for the five night scores (standard library).

Notes are rendered before export because Web Sample playback has no effect bus.
The score itself lives in night_music.gd; these are its instruments, not mixes.
"""
import math
import struct
import wave

RATE = 22050
BASS_LOOP_BEGIN = 30000
BASS_LOOP_END = 90000
PROFILES = [
    # high attack/decay/length, foundation attack/decay/length, overtone weights
    (.055, .95, 2.8, .22, 2.5, 4.0, (.86, .10, .025)),
    (.045, .62, 2.3, .10, 1.4, 3.2, (.80, .12, .030)),
    (.130, 1.55, 3.4, .45, 3.4, 5.0, (.93, .04, .015)),
    (.036, .50, 1.8, .06, 1.0, 2.8, (.86, .08, .040)),
    (.065, 1.20, 3.2, .30, 3.0, 5.0, (.85, .09, .030)),
]

def smooth(value):
    t = min(1.0, max(0.0, value))
    return t*t*(3.0-2.0*t)

def write_wave(path, frames):
    peak = max(max(abs(left),abs(right)) for left,right in frames)
    scale = min(1.0,.42/max(peak,1e-9))
    data = bytearray()
    for left,right in frames:
        data.extend(struct.pack('<hh',round(left*scale*32767),round(right*scale*32767)))
    with wave.open(str(path),'wb') as output:
        output.setnchannels(2);output.setsampwidth(2);output.setframerate(RATE);output.writeframes(data)

def note(path, midi, attack, decay, duration, weights, pan, breath=False):
    frequency = 440*2**((midi-69)/12)
    angle = (pan+1)*math.pi/4
    left,right = math.cos(angle),math.sin(angle)
    def tone(t):
        if t<0:return 0.0
        phase = 2*math.pi*frequency*t
        if breath:phase += .0025*frequency/3.4*math.sin(2*math.pi*3.4*t)
        envelope = smooth(t/attack)*math.exp(-t/decay)*smooth((duration-t)/.25)
        return .38*envelope*sum(weight*math.sin((index+1)*phase) for index,weight in enumerate(weights))
    frames=[]
    for index in range(round(RATE*duration)):
        t=index/RATE
        direct= tone(t)
        reflection=.10*tone(t-.27)+.045*tone(t-.53)
        frames.append((direct*left+reflection*right,direct*right+reflection*left))
    write_wave(path,frames)

def bass(path):
    # Quantize only this low fundamental by <2 cents so the steady loop closes
    # on an exact period. The small settling glide is finished before the loop.
    frequency=RATE/300
    phase=0.0
    frames=[]
    for index in range(BASS_LOOP_END):
        t=index/RATE
        glide=.053*math.exp(-t/.38)*smooth((1.25-t)/.30) if t<1.25 else 0.0
        phase += 2*math.pi*frequency*(1+glide)/RATE
        envelope=smooth(t/.8)
        settling=1+.075*math.sin(2*math.pi*6*t)*math.exp(-t/.4)
        value=.32*envelope*settling*(.43*math.sin(phase)+.26*math.sin(phase*2)+.20*math.sin(phase*3)+.11*math.sin(phase*4))
        frames.append((value/math.sqrt(2),value/math.sqrt(2)))
    write_wave(path,frames)

def build(audio):
    for index,profile in enumerate(PROFILES):
        attack,decay,duration,base_attack,base_decay,base_duration,weights=profile
        note(audio/f'music_{index}_base.wav',50,base_attack,base_decay,base_duration,weights,0.0,index==2)
        for side,pan in [('left',-.24),('right',.24)]:
            note(audio/f'music_{index}_{side}.wav',74,attack,decay,duration,weights,pan,index==2)
    bass(audio/'music_bass.wav')
