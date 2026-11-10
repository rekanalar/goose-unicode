#!/usr/bin/env python3
"""Compare the levels and the visual order with the Rust unicode-bidi crate.

Builds random texts from characters of every class, runs the Go package
and the Rust oracle, and reports the first differences.
"""
import os
import random
import subprocess
import sys

# One character of each class that both Unicode 16 and 17 hold.
CHARS = [
    0x61, 0x5D0, 0x627, 0x31, 0x2B, 0x24, 0x661, 0x2C, 0x300, 0xAD,
    0x09, 0x20, 0x21, 0x202A, 0x202D, 0x202B, 0x202E, 0x202C,
    0x2066, 0x2067, 0x2068, 0x2069, 0x28, 0x29, 0x5B, 0x5D,
    0x2D, 0x2013, 0x2014, 0x2018, 0x201C, 0x4E2D, 0x30A2, 0xFF10,
]


def build(seed, count):
    rng = random.Random(seed)
    out = []
    for _ in range(count):
        out.append(rng.choice(CHARS))
    return out


def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 2000
    texts = [build(seed * 100000 + k, rng_len) for k, rng_len in
             ((k, 1 + (k * 7) % 40) for k in range(count))]
    lines = [" ".join("%X" % c for c in t) for t in texts]
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    path = os.path.join(root, "bidi_diff_in.txt")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    proc = subprocess.run(
        ["goose", "run", "test/bidi_diff.goose", "--", path],
        cwd=root, capture_output=True, text=True)
    os.remove(path)
    if proc.returncode != 0:
        print(proc.stdout[-3000:])
        print(proc.stderr[-2000:])
        return 1
    ours = proc.stdout.split("\n")
    rust = subprocess.run([os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                       "oracle", "target", "release", "bidi")],
                          input="\n".join(lines) + "\n",
                          capture_output=True, text=True).stdout.split("\n")
    # The characters that rule X9 removes. The Rust crate keeps them in
    # its levels, and this package gives them the level -1.
    removed = {0xAD, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E}
    bad = 0
    for i in range(len(texts)):
        if i * 2 + 1 >= len(ours) or i * 2 + 1 >= len(rust):
            print("FAIL: short output at case", i)
            return 1
        cps = texts[i]
        o_lv = [x for k, x in enumerate(ours[i * 2].split()) if cps[k] not in removed]
        o_od = ours[i * 2 + 1].split()
        r_lv = [x for k, x in enumerate(rust[i * 2].split()) if cps[k] not in removed]
        r_od = [x for x in rust[i * 2 + 1].split()
                if cps[int(x)] not in removed]
        if o_lv != r_lv or o_od != r_od:
            bad += 1
            print("case", i, "text", " ".join("%X" % c for c in texts[i]))
            print("  levels ours", " ".join(o_lv))
            print("  levels rust", " ".join(r_lv))
            print("  order  ours", " ".join(o_od))
            print("  order  rust", " ".join(r_od))
            if bad > 5:
                break
    print("%d cases, %d differences" % (len(texts), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
