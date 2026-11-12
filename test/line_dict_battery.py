#!/usr/bin/env python3
"""Make the cases of the dictionary line breaking.

The script builds a battery of texts in Thai, Lao, Burmese and Khmer with
spaces, punctuation, digits, Latin letters, hard breaks and scripts that
have no word list. It sends every text to the ICU line iterator, release
79.1, and it writes the break offsets of ICU into the file
test/suite/line_dict_cases.goose. It runs the Rust icu_segmenter line
segmenter too, in the dictionary and in the automatic form, and prints
how many texts differ from ICU.

The words come from the trie data files of the package, so the script
holds no copy of a word list.

Usage: line_dict_battery.py [number of texts]
"""
import os
import random
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u
import dict_battery as d

SEED = 20261112

# Characters that stand between two runs of letters.
SEPARATORS = [0x20, 0x20, 0x2E, 0x2C, 0x21, 0x3F, 0x2D, 0xA0, 0x200B, 0x2060,
              0x0A, 0x0D, 0x85, 0x2028, 0x3002, 0x300C, 0x300D, 0x28, 0x29]

# Letters of scripts of the class SA that have no word list.
NO_LIST = [(0x1A20, 0x1A4B), (0x1980, 0x19AB), (0x1950, 0x196D),
           (0xA984, 0xA9B2), (0xAA00, 0xAA28), (0xAA80, 0xAAAF)]

SCRIPTS = ["thai", "lao", "burmese", "khmer"]


def words_text(rng, words, name, count):
    """A run of one to count words of one script."""
    t = []
    for _ in range(rng.randint(1, count)):
        t += d.pick(rng, words[name])
    return t


def build(rng, words, total):
    texts = []
    per = total // 8
    # Words of one script, alone and in pairs, with marks and fillers.
    for name in SCRIPTS:
        for _ in range(per // 2):
            t = words_text(rng, words, name, 3)
            if rng.random() < 0.3:
                t.insert(rng.randrange(len(t) + 1), rng.choice(d.MARKS[name]))
            if rng.random() < 0.2:
                t += [rng.choice(d.FILLERS)] * rng.randint(1, 3)
            texts.append(t)
    # Letters with no word.
    for name in SCRIPTS:
        lo, hi = d.LETTERS[name]
        for _ in range(per // 8):
            texts.append([rng.randint(lo, hi) for _ in range(rng.randint(1, 8))])
    # Runs of words with a separator, a hard break or a joiner between.
    for _ in range(per * 2):
        name = rng.choice(SCRIPTS)
        t = words_text(rng, words, name, 2)
        for _ in range(rng.randint(1, 3)):
            t.append(rng.choice(SEPARATORS))
            t += words_text(rng, words, rng.choice(SCRIPTS), 2)
        texts.append(t)
    # Words next to Latin letters, digits and punctuation.
    for _ in range(per):
        t = words_text(rng, words, rng.choice(SCRIPTS), 2)
        if rng.random() < 0.5:
            t = [rng.randint(0x41, 0x5A)] + t
        if rng.random() < 0.5:
            t = t + [rng.randint(0x30, 0x39)]
        if rng.random() < 0.4:
            t = t + [rng.choice(SEPARATORS)]
        if rng.random() < 0.4:
            t = t + words_text(rng, words, rng.choice(SCRIPTS), 2)
        texts.append(t)
    # Scripts of the class SA with no list, next to a script with a list.
    for _ in range(per):
        lo, hi = rng.choice(NO_LIST)
        other = [rng.randint(lo, hi) for _ in range(rng.randint(1, 4))]
        t = words_text(rng, words, rng.choice(SCRIPTS), 2)
        r = rng.random()
        if r < 0.33:
            t = other + t
        elif r < 0.66:
            t = t + other
        else:
            k = rng.randrange(len(t) + 1)
            t = t[:k] + other + t[k:]
        texts.append(t)
    # Han, Hiragana and Katakana next to the words: the rules decide.
    for _ in range(per // 2):
        t = words_text(rng, words, rng.choice(SCRIPTS), 2)
        han = [rng.randint(0x4E00, 0x9FA5) for _ in range(rng.randint(1, 3))]
        t = t + han if rng.random() < 0.5 else han + t
        texts.append(t)
    return texts


def icu_breaks(texts):
    """The breaks of ICU for each text: a list of (offset, hard) pairs.

    The oracle gives offsets in UTF-16 units. The code below turns them
    into code point offsets. The status 100 marks a hard break.
    """
    lines = [" ".join("%X" % c for c in t) for t in texts]
    out = u.oracle_go("iculinebrk", "root", stdin="\n".join(lines) + "\n")
    if len(out) != len(texts):
        u.fail("the ICU oracle gave %d lines for %d texts" % (len(out), len(texts)))
    result = []
    for t, line in zip(texts, out):
        ends = {}
        unit = 0
        for k, c in enumerate(t):
            unit += 2 if c >= 0x10000 else 1
            ends[unit] = k + 1
        brk = []
        for part in line.split():
            off, _, status = part.partition(":")
            if int(off) not in ends:
                u.fail("the ICU oracle split inside a code point of %r" % t)
            brk.append((ends[int(off)], 1 if int(status) >= 100 else 0))
        if not brk or brk[-1][0] != len(t):
            u.fail("the ICU oracle did not reach the end of %r" % t)
        result.append(brk)
    return result


def rust_breaks(texts, mode):
    """The code point offsets of the Rust line segmenter, one list per text."""
    binary = os.path.join(u.HERE, "oracle", "target", "release", "lineseg")
    lines = [" ".join("%X" % c for c in t) for t in texts]
    r = subprocess.run([binary, mode], input="\n".join(lines) + "\n",
                       capture_output=True, text=True)
    if r.returncode != 0:
        u.fail("the Rust oracle failed: " + r.stderr[:300])
    return [[int(v) for v in row.split()] for row in r.stdout.splitlines()]


def main():
    u.check_version()
    rng = random.Random(SEED)
    total = int(sys.argv[1]) if len(sys.argv) > 1 else 12000
    words = {}
    for name in SCRIPTS:
        words[name] = d.trie_words(d.read_trie(name))
        print("%s: %d words" % (name, len(words[name])))
    texts = build(rng, words, total)
    print("battery: %d texts" % len(texts))
    icu = icu_breaks(texts)
    for mode in ["dictionary", "auto"]:
        rust = rust_breaks(texts, mode)
        diff = sum(1 for b, r in zip(icu, rust) if [o for o, _ in b] != r)
        print("Rust %s differs from ICU on %d of %d texts" % (mode, diff, len(texts)))
    soft = sum(1 for b in icu for _, h in b[:-1] if not h)
    hard = sum(1 for b in icu for _, h in b[:-1] if h)
    print("ICU breaks inside the texts: %d soft, %d hard" % (soft, hard))
    # One byte string of 3 bytes for each value. The values are code
    # points, counts, offsets and flags, and none exceeds 0x10FFFF.
    values = []
    for t, b in zip(texts, icu):
        values.append(len(t))
        values += t
        values.append(len(b))
        for off, hard in b:
            values.append(off)
            values.append(hard)
    data = bytearray()
    for v in values:
        if v > 0x10FFFF:
            u.fail("a value does not fit in 3 bytes")
        data += v.to_bytes(3, "little")
    parts = [
        u.bytes_array("LINE_DICT_POOL", bytes(data),
                      "For each case, as 3 bytes for each value, low byte first: the count of code points, the code points, the count of breaks, then the offset in code points and the hard flag of each break."),
        "const LINE_DICT_CASES: i64 = %d;\n" % len(texts),
    ]
    out = os.path.join(u.HERE, "suite", "line_dict_cases.goose")
    with open(out, "w", encoding="utf-8") as f:
        f.write("// Reference cases for the dictionary line breaking.\n")
        f.write("// Made by test/line_dict_battery.py. Do not edit by hand.\n")
        f.write("namespace suite;\n\n")
        f.write("\n".join(parts))
    print("wrote %s" % out)


if __name__ == "__main__":
    main()
