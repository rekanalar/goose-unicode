#!/usr/bin/env python3
"""Compare the locale aware case mapping with the oracles.

Runs the package and one oracle over a set of texts for the locales tr, az
and lt and the cases upper, lower and title. Reports the first differences.
Usage: diff_locale.py <set> [oracle]
  set     battery: every text of one to four characters over 16 characters
          points: every scalar value as a text of one character
  oracle  ice (default, ICU 79.1), go (golang.org/x/text), rust (icu_casemap)
"""
import itertools
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CHARS = [0x49, 0x69, 0x4A, 0x6A, 0x12E, 0x130, 0x131, 0xCC, 0x249, 0x307, 0x300,
         0x316, 0x327, 0x61, 0x20, 0x3A3]
LOCALES = [("tr", 1), ("az", 2), ("lt", 3)]
KINDS = ["upper", "lower", "title"]


def texts(kind):
    if kind == "points":
        return ["%X" % c for c in range(0x110000) if not 0xD800 <= c <= 0xDFFF]
    out = []
    for n in range(1, 5):
        for t in itertools.product(CHARS, repeat=n):
            out.append(" ".join("%X" % c for c in t))
    return out


def oracle(name, tag, kind, lines):
    data = "\n".join(lines) + "\n"
    odir = os.path.join(HERE, "oracle")
    if name == "rust":
        cmd = [os.path.join(odir, "target", "release", "casemap"), tag, kind]
    else:
        cmd = [os.path.join(odir, "oracle"), "icelocale" if name == "ice" else "golocale", tag, kind]
    return subprocess.run(cmd, input=data, capture_output=True, text=True).stdout.split("\n")


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else "battery"
    name = sys.argv[2] if len(sys.argv) > 2 else "ice"
    lines = texts(which)
    path = os.path.join(os.environ.get("TMPDIR", "/tmp"), "locale_diff_in.txt")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    total = 0
    for tag, num in LOCALES:
        for kind in KINDS:
            proc = subprocess.run(["goose", "run", "test/locale_diff.goose", "--", str(num), kind, path],
                                  cwd=ROOT, capture_output=True, text=True)
            if proc.returncode != 0:
                print(proc.stdout[-2000:], proc.stderr[-2000:])
                return 1
            ours = proc.stdout.split("\n")
            ref = oracle(name, tag, kind, lines)
            bad = [i for i in range(len(lines)) if ours[i].upper().split() != ref[i].upper().split()]
            total += len(bad)
            print("%s %-5s %-6s: %d differences of %d" % (tag, kind, which, len(bad), len(lines)))
            for i in bad[:4]:
                print("   text %s\n     ours %s\n     %s  %s" % (lines[i], ours[i], name, ref[i]))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
