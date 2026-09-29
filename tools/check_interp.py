import json, re, sys
from preview import filmstrip
from skeleton import *

src = open('../Momentum/Design/MotionData.swift').read()
data = json.loads(src[src.index('{\n"'):src.rindex('}\n"""#') + 1])

def blend(a, b, t):
    out = list(a)
    for k in range(len(a)):
        if k < 2: out[k] = a[k] + (b[k] - a[k]) * t
        else:
            dlt = (b[k] - a[k]) % 360
            if dlt > 180: dlt -= 360
            out[k] = a[k] + dlt * t
    return out

names = sys.argv[2:]
ms = []
for k in names:
    m = data[k]
    fr = m['frames']; n = len(fr); seq = []
    for i in range(n):
        seq.append(fr[i]); seq.append(blend(fr[i], fr[(i + 1) % n], 0.5))
    ms.append((k, dict(frames=seq[:8], view=m['view'], props=[], held=m['held'])))
filmstrip(ms, sys.argv[1], maxf=8) if False else None
import preview
preview.filmstrip(ms, sys.argv[1], cell=110, maxf=8)
