#!/usr/bin/env python3
"""Compare the title case of random texts with the Go library.

Builds random texts of letters, marks, digits and punctuation, runs the
Go package and the Go oracle, and reports the first differences.
Usage: diff_title.py [seed] [count] [title|icetitle]
"""
import os
import random
import subprocess
import sys

# Characters of the classes that decide a word: cased letters of both
# cases, a digraph, the sharp s, the sigmas, marks, digits and the
# punctuation of the word rules. The Go library approximates the word
# rules, so the characters that it joins to a word against the standard
# stay out: the cased combining mark U+0345, the connector U+005F, the
# format character U+00AD and the joiner U+200D. A text where a mid word
# mark touches a digit stays out too. The capital sigma has its own fixed
# texts, because Go gives the final sigma after an uncased letter.
CHARS = [
    0x61, 0x62, 0x7A, 0x41, 0x42, 0x5A, 0xE9, 0xC9, 0xDF, 0x1C5, 0x1C6,
    0x3C3, 0x3C2, 0x3B1, 0x391, 0x430, 0x410, 0x5D0, 0x627,
    0x300, 0x301, 0x31, 0x32, 0x20, 0x2E, 0x27,
    0x2C, 0x3A, 0x2D, 0x21, 0x22, 0x28, 0x29, 0xFB01, 0x1F80,
    0x4E2D, 0x30A2, 0x0A, 0x2019, 0x2018, 0x130, 0x131,
]


MID = {0x2E, 0x27, 0x3A, 0x2C, 0x2018, 0x2019}
DIGITS = {0x31, 0x32}
MARKS = {0x300, 0x301}
NOT_LETTERS = MID | DIGITS | MARKS | {0x20, 0x2D, 0x21, 0x22, 0x28, 0x29, 0x0A, 0x4E2D, 0x30A2}


def known_difference(t):
    """True when the text holds a pattern where Go differs from the
    standard. A mid word mark that touches a digit: Go joins the two with
    no break, and the standard breaks there. A capital sigma right after
    a digit: Go gives the final sigma, and the standard, Python and ICU
    give the plain one. A combining mark at the start of the text or after
    a character that is no letter: Go reads it as part of a word."""
    if t[0] in MARKS:
        return True
    for k in range(1, len(t)):
        if t[k] in MARKS and t[k - 1] in NOT_LETTERS and t[k - 1] not in MARKS:
            return True
    for k in range(len(t) - 1):
        if (t[k] in MID and t[k + 1] in DIGITS) or (t[k] in DIGITS and t[k + 1] in MID):
            return True
        if t[k] in DIGITS and t[k + 1] == 0x3A3:
            return True
    return False


def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 2000
    mode = sys.argv[3] if len(sys.argv) > 3 else "title"
    rng = random.Random(seed)
    texts = []
    while len(texts) < count:
        t = [rng.choice(CHARS) for _ in range(1 + (len(texts) * 7) % 30)]
        if not known_difference(t):
            texts.append(t)
    lines = [" ".join("%X" % c for c in t) for t in texts]
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    path = os.path.join(root, "title_diff_in.txt")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    try:
        proc = subprocess.run(
            ["goose", "run", "test/title_diff.goose", "--", path],
            cwd=root, capture_output=True, text=True)
    finally:
        os.remove(path)
    if proc.returncode != 0:
        print(proc.stdout[-3000:])
        print(proc.stderr[-2000:])
        return 1
    ours = proc.stdout.split("\n")
    env = dict(os.environ, GOFLAGS="-mod=mod", GOPROXY="off")
    go = subprocess.run(["go", "run", ".", mode], cwd=os.path.join(here, "oracle"),
                        input="\n".join(lines) + "\n", capture_output=True,
                        text=True, env=env).stdout.split("\n")
    bad = 0
    for i, t in enumerate(texts):
        if i >= len(ours) or i >= len(go):
            print("FAIL: short output at case", i)
            return 1
        a = ours[i].upper().split()
        b = go[i].upper().split()
        if a != b:
            bad += 1
            print("case", i, "text", lines[i])
            print("  ours", " ".join(a))
            print("  go  ", " ".join(b))
            if bad > 5:
                break
    print("differences:", bad, "of", count)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
