import sys, importlib
from preview import filmstrip
names = sys.argv[3:]
ms = []
for mod in sys.argv[2].split(','):
    m = importlib.import_module(mod)
    ms += [(k, v) for k, v in m.M.items() if not names or k in names]
filmstrip(ms, sys.argv[1])
print(len(ms))
