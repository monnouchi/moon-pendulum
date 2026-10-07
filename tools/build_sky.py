#!/usr/bin/env python3
"""Freeze catalog / observer data. Only this offline tool uses IAU SOFA.

Inputs are CDS V/50 TSV and the two Horizons JSON observer responses described
in SKY_SCENES.md. The game and normal asset build need no network or SOFA.
"""
import argparse
import csv
import ctypes as C
import hashlib
import json
import math
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OBSERVER = {"latitude": 35.0, "longitude": 135.0, "height_m": 100.0,
            "timezone": "Asia/Tokyo", "dut1_seconds": 0.0, "pressure_hpa": 0.0}
NIGHTS = [
    ("ORI", "2026-02-01T21:00:00+09:00", "winter", [2061,1790,1948,1903,1852,2004,1713]),
    ("LYR", "2026-07-15T22:00:00+09:00", "summer", [7001,7051,7056,7139,7178,7106]),
    ("CAS", "2026-11-01T21:00:00+09:00", "autumn", [542,403,264,168,21]),
    ("CYG", "2026-06-15T21:15:00+09:00", "summer", [7924,7796,7417,7528,7949,8115]),
    ("SCO", "2026-06-01T00:00:00+09:00", "summer", [5984,5953,5944,6084,6134,6165,6241,6247,6271,6380,6553,6615,6580,6527,6508]),
]
D = math.pi / 180.0
AS = D / 3600.0

def dot(a,b): return sum(x*y for x,y in zip(a,b))
def unit(v):
    n = math.sqrt(dot(v,v))
    return [x/n for x in v]
def enu(az,alt):
    a,h = az*D,alt*D
    return [math.sin(a)*math.cos(h),math.cos(a)*math.cos(h),math.sin(h)]
def sexagesimal(s):
    v = [float(x) for x in s.lstrip('+-').split()]
    return (-1 if s.startswith('-') else 1)*(v[0]+v[1]/60+v[2]/3600)
def catalog(path):
    result = {}
    for line in path.read_text().splitlines():
        if line.startswith('#'): continue
        c = line.split('\t')
        if len(c)!=7 or not c[0].strip().isdigit() or len(c[2].split())!=3: continue
        hr = int(c[0])
        result[hr] = dict(hr=hr,name=c[1].strip(),ra=sexagesimal(c[2])*15*D,
                          dec=sexagesimal(c[3])*D,mag=float(c[4]),
                          pmra=float(c[5] or 0)*AS,pmdec=float(c[6] or 0)*AS)
    assert len(result)==9096, "Unexpected or truncated BSC5 response"
    return result
def ephemeris(path):
    result = json.loads(path.read_text())['result']
    rows = csv.reader(result.split('$$SOE')[1].split('$$EOE')[0].strip().splitlines())
    return {datetime.strptime(r[0].strip(),'%Y-%b-%d %H:%M:%S.%f').replace(tzinfo=timezone.utc):
            [float(v) for v in r[3:] if v.strip()] for r in rows}
def sofa(path):
    lib = C.CDLL(str(path.resolve()))
    dp = C.POINTER(C.c_double)
    lib.iauDtf2d.argtypes = [C.c_char_p]+[C.c_int]*5+[C.c_double,dp,dp]
    lib.iauFk52h.argtypes = [C.c_double]*6+[dp]*6
    lib.iauAtco13.argtypes = [C.c_double]*18+[dp]*6
    return lib
def observed(lib,star,date):
    utc1,utc2 = C.c_double(),C.c_double()
    status = lib.iauDtf2d(b'UTC',date.year,date.month,date.day,date.hour,date.minute,
                         float(date.second),C.byref(utc1),C.byref(utc2))
    assert status>=0, "Invalid UTC date"
    # BSC pmRA is cos(dec) * dRA/dt in arcsec/year, not an RA time value.
    icrs = [C.c_double() for _ in range(6)]
    lib.iauFk52h(star['ra'],star['dec'],star['pmra']/math.cos(star['dec']),
                star['pmdec'],0.0,0.0,*[C.byref(v) for v in icrs])
    out = [C.c_double() for _ in range(6)]
    status = lib.iauAtco13(*[v.value for v in icrs],utc1.value,utc2.value,0.0,
                          OBSERVER['longitude']*D,OBSERVER['latitude']*D,100.0,
                          0.0,0.0,0.0,10.0,0.0,0.55,*[C.byref(v) for v in out])
    assert status>=0, "SOFA rejected observation"
    az,alt = out[0].value/D,90-out[1].value/D
    return az,alt,enu(az,alt)
def rounded(value):
    if isinstance(value,float):return round(value,9)
    if isinstance(value,list):return [rounded(v) for v in value]
    if isinstance(value,dict):return {k:rounded(v) for k,v in value.items()}
    return value
def generate(cat,lib,moons,suns):
    scenes = []
    for code,local,season,ids in NIGHTS:
        date = datetime.fromisoformat(local).astimezone(timezone.utc)
        targets = [observed(lib,cat[hr],date) for hr in ids]
        assert min(t[1] for t in targets)>5.0, "A target lies too close to or below the horizon"
        center = unit([sum(t[2][i] for t in targets) for i in range(3)])
        az,alt = math.atan2(center[0],center[1])%math.tau,math.asin(center[2])
        right = [math.cos(az),-math.sin(az),0.0]
        up = [-math.sin(alt)*math.sin(az),-math.sin(alt)*math.cos(az),math.cos(alt)]
        def project(v):
            front = dot(v,center)
            return [dot(v,right)/front,-dot(v,up)/front]
        main = [[hr,*project(t[2]),cat[hr]['mag'],t[0],t[1]] for hr,t in zip(ids,targets)]
        neighbors = []
        # Bright stars only, same tangent plane; unresolved companions of targets
        # are omitted rather than appearing as extra game goals.
        for hr,s in sorted(cat.items(),key=lambda item:(item[1]['mag'],item[0])):
            if s['mag']>5.0 or hr in ids: continue
            a,h,v = observed(lib,s,date)
            if h<=0 or dot(v,center)<0.5:continue
            if any(dot(v,t[2])>math.cos(0.1*D) for t in targets):continue
            p = project(v)
            if any(math.hypot(p[0]-n[1],p[1]-n[2])<0.001 for n in neighbors):continue
            neighbors.append([hr,*p,s['mag'],a,h])
        ma,mh,illum,diam,phase = moons[date]
        sa,sh = suns[date]
        assert sh<-18, "The chosen scene is not an astronomical night"
        mv,sv = enu(ma,mh),enu(sa,sh)
        mf = dot(mv,center)
        moon_xy = project(mv) if mf>0.05 else [0.0,0.0]
        if mf>0.05:
            light = unit([(dot(sv,right)*mf-dot(mv,right)*dot(sv,center))/mf**2,
                          -(dot(sv,up)*mf-dot(mv,up)*dot(sv,center))/mf**2])
        else:light = [1.0,0.0]
        separation = min(math.acos(max(-1,min(1,dot(mv,t[2]))))/D for t in targets)
        assert mh<=0 or separation>diam/7200+0.5, "The Moon obscures a target"
        scenes.append(dict(code=code,local=local,utc=date.isoformat(),season=season,
                           center_az=az/D,center_alt=alt/D,horizon=math.tan(alt),
                           sun_alt=sh,targets=main,neighbors=neighbors,
                           moon=dict(az=ma,alt=mh,illum=illum/100,radius=diam*AS/2,
                                     phase_angle=phase,front=mf,xy=moon_xy,light=light,
                                     nearest_target_degrees=separation)))
    return rounded(scenes)
def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--catalog',type=Path,required=True)
    p.add_argument('--sofa-library',type=Path,required=True)
    p.add_argument('--moon',type=Path,required=True)
    p.add_argument('--sun',type=Path,required=True)
    args = p.parse_args()
    scenes = generate(catalog(args.catalog),sofa(args.sofa_library),
                      ephemeris(args.moon),ephemeris(args.sun))
    header = ('extends RefCounted\n## Generated by tools/build_sky.py; see SKY_SCENES.md.\n'
              '## CDS BSC5 (Hoffleit & Warren 1991), IAU SOFA 2023-10-11, JPL Horizons.\n')
    hashes = {name:hashlib.sha256(path.read_bytes()).hexdigest()
              for name,path in [('catalog',args.catalog),('moon',args.moon),('sun',args.sun)]}
    out = header+'const OBSERVER = '+json.dumps(OBSERVER)+'\n'
    out += 'const INPUT_SHA256 = '+json.dumps(hashes)+'\nconst SCENES = [\n'
    for s in scenes:
        out += '\t{\n'
        for k,v in s.items():
            if k in ['targets','neighbors']:
                out += '\t\t"'+k+'": [\n'+''.join('\t\t\t'+json.dumps(a)+',\n' for a in v)+'\t\t],\n'
            else:out += '\t\t'+json.dumps(k)+': '+json.dumps(v)+',\n'
        out += '\t},\n'
    out += ']\n'
    (ROOT/'game/scripts/sky_data.gd').write_text(out)
    for s in scenes:
        print(s['code'],s['local'],'center',round(s['center_az'],2),round(s['center_alt'],2),
              'target altitude',round(min(t[5] for t in s['targets']),2),round(max(t[5] for t in s['targets']),2),
              'moon',round(s['moon']['az'],2),round(s['moon']['alt'],2),
              'neighbors',len(s['neighbors']))
if __name__=='__main__':main()
