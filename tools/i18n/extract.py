"""Collect every localizable key used in the Swift sources: L("..."), LText("..."), Lp(n, one:, other:), Loc.text("...")."""
import os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
SKIP = ('LocalizationData.swift', 'ExerciseTranslations.swift', 'MotionData.swift')

STR = r'"((?:[^"\\]|\\.)*)"'
PATTERNS = [
    re.compile(r'\b(?:L|LText)\(\s*' + STR),
    re.compile(r'\bLoc\.text\(\s*' + STR),
    re.compile(r'\btext\(\s*' + STR + r'\s*,\s*\['),          # inside Loc itself
    re.compile(r'\bLp\([^"]*?one:\s*' + STR + r'\s*,\s*other:\s*' + STR, re.S),
]


def unescape(s):
    return (s.replace('\\"', '"').replace("\\'", "'").replace('\\n', '\n').replace('\\\\', '\\'))


def keys(root=ROOT):
    found = {}
    for base, _, files in os.walk(os.path.join(root, 'Momentum')):
        for f in files:
            if not f.endswith('.swift') or f in SKIP:
                continue
            path = os.path.join(base, f)
            src = open(path).read()
            for pat in PATTERNS:
                for m in pat.finditer(src):
                    for g in m.groups():
                        k = unescape(g)
                        if '\\(' in k:
                            print(f'!! interpolation in key ({f}): {k}', file=sys.stderr)
                        found.setdefault(k, set()).add(f)
    return found


if __name__ == '__main__':
    ks = keys()
    for k in sorted(ks):
        print(k)
    print(len(ks), 'keys', file=sys.stderr)
