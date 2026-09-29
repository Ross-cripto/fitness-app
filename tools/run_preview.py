import sys, importlib
from preview import sheet
mods = sys.argv[2:]
ms = []
for name in mods:
    mod = importlib.import_module(name)
    ms += list(mod.M.items())
sheet(ms, sys.argv[1])
print(len(ms), 'motions')
