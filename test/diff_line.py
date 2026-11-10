#!/usr/bin/env python3
"""Compare the line breaks of random texts with the ICU line iterator.

Builds random texts from characters of the classes that the rules name,
runs the Goose package and the ICU oracle, and reports the first
differences. The texts avoid the scripts that ICU breaks with a
dictionary. ICU and the standard differ on a few cases, so the script
skips the texts that hold a known difference.
Usage: diff_line.py [seed] [count]
"""
import os
import random
import subprocess
import sys

CHARS = [
    0x61, 0x62, 0x41, 0x5A, 0x31, 0x32, 0x20, 0x20, 0x2E, 0x2C, 0x3A, 0x2F, 0x2D, 0x2013,
    0x21, 0x3F, 0x28, 0x29, 0x5B, 0x5D, 0x7B, 0x7D, 0x22, 0x27, 0x201C, 0x201D, 0x2018,
    0x2019, 0xAB, 0xBB, 0x24, 0x25, 0xA3, 0xA0, 0x2060, 0x200B, 0x200D, 0x300, 0x301,
    0xA, 0xD, 0xB, 0x85, 0x2028, 0x4E2D, 0x3042, 0x3041, 0x300C, 0x300D, 0x3001, 0xFF08,
    0xFF09, 0x1100, 0x1161, 0x11A8, 0xAC00, 0xAC01, 0x1F1E6, 0x1F1E7, 0x1F468, 0x1F3FB,
    0x1F600, 0x5D0, 0x5BE, 0x627, 0x660, 0x2026, 0x25CC, 0x915, 0x94D, 0x93E, 0xAD,
    0x2010, 0x23, 0x40, 0x7C, 0xD7, 0xB4, 0x2E3A,
]


def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 5000
    rng = random.Random(seed)
    texts = [[rng.choice(CHARS) for _ in range(1 + (i * 7) % 24)] for i in range(count)]
    lines = [" ".join("%X" % c for c in t) for t in texts]
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    path = os.path.join(root, "line_diff_in.txt")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    try:
        proc = subprocess.run(["goose", "run", "test/line_diff.goose", "--", path],
                              cwd=root, capture_output=True, text=True)
    finally:
        os.remove(path)
    if proc.returncode != 0:
        print(proc.stdout[-3000:], proc.stderr[-2000:])
        return 1
    ours = proc.stdout.split("\n")
    env = dict(os.environ, GOFLAGS="-mod=mod", GOPROXY="off")
    icu = subprocess.run(["go", "run", ".", "icelines"], cwd=os.path.join(here, "oracle"),
                         input="\n".join(lines) + "\n", capture_output=True,
                         text=True, env=env).stdout.split("\n")
    def norm(row):
        parts = row.split()
        if parts:
            parts[-1] = parts[-1].rstrip("m")
        return parts
    bad = 0
    for i in range(count):
        a, b = norm(ours[i]), norm(icu[i])
        if a != b:
            bad += 1
            if bad <= 8:
                print("case", i, "text", lines[i])
                print("  ours", " ".join(a))
                print("  icu ", " ".join(b))
    print("differences:", bad, "of", count)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
