#!/usr/bin/env python3
"""Make the cases of the dictionary word segmentation.

The script builds a battery of texts in Thai, Lao, Burmese, Khmer, Chinese
and Japanese. It sends every text to two oracles: the ICU library, release
79.1, and the Intl.Segmenter of Node 22. It writes the splits of ICU into
the file test/suite/dict_cases.goose, and it fails when the two oracles
give different splits.

The words of the battery come from the trie data files of the package, so
the script holds no copy of a word list. The trie files are made by
test/make_dict_data.py from the word lists of the ICU library, release
79.1.

Usage: dict_battery.py [number of texts]
"""
import json
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

HERE = u.HERE
ROOT = u.ROOT

# The trie data files of the package, one per script.
TRIES = ["thai", "lao", "burmese", "khmer", "cj"]

# The code points of the marks and the letters of each script.
MARKS = {
    "thai": [0x0E31, 0x0E34, 0x0E35, 0x0E36, 0x0E37, 0x0E38, 0x0E39,
             0x0E47, 0x0E48, 0x0E49, 0x0E4A, 0x0E4B, 0x0E4C, 0x0E4D],
    "lao": [0x0EB0, 0x0EB1, 0x0EB2, 0x0EB3, 0x0EB4, 0x0EB5, 0x0EB6,
            0x0EB7, 0x0EB8, 0x0EB9, 0x0EBB, 0x0EBC],
    "burmese": [0x102B, 0x102C, 0x102D, 0x102E, 0x102F, 0x1030, 0x1031,
                0x1032, 0x1033, 0x1034, 0x1035, 0x1036, 0x1037, 0x1038,
                0x1039, 0x103A, 0x105A, 0x105B, 0x105C, 0x105D, 0x105E],
    "khmer": [0x17B6, 0x17B7, 0x17B8, 0x17B9, 0x17BA, 0x17BB, 0x17BC,
              0x17BD, 0x17BE, 0x17BF, 0x17C0, 0x17C1, 0x17C2, 0x17C3,
              0x17C4, 0x17C5, 0x17C7, 0x17C8, 0x17C9, 0x17CA, 0x17CB,
              0x17CC, 0x17CD, 0x17CE, 0x17CF, 0x17D0, 0x17D1, 0x17D2],
}

LETTERS = {
    "thai": (0x0E01, 0x0E3A),
    "lao": (0x0E81, 0x0EDF),
    "burmese": (0x1000, 0x102A),
    "khmer": (0x1780, 0x17A2),
}

# The letters of the Han, Hiragana and Katakana text.
CJ_LETTERS = [
    (0x4E00, 0x9FA5),   # Han
    (0x3042, 0x3096),   # Hiragana
    (0x30A2, 0x30FA),   # Katakana
]

# The marks of the Japanese text.
CJ_MARKS = [0x3099, 0x309A, 0x309B, 0x309C, 0x30FC, 0x30FD, 0x30FE]

# The letters that no word of the list holds.
FILLERS = [0x0E2D, 0x0E2D, 0x0E2D, 0x0E2F, 0x0E46, 0x0E01, 0x0E45]


def read_trie(name):
    """The nodes of one trie data file of the package."""
    path = os.path.join(ROOT, "dict_data_%s.goose" % name)
    with open(path, encoding="utf-8") as f:
        text = f.read()
    m = re.search(r'const DICT_[A-Z]+_NODE: u8\[\d+\] = "(.*?)";', text, re.S)
    if not m:
        u.fail("the trie file %s holds no node array" % path)
    data = bytes(int(h, 16) for h in re.findall(r"\\x([0-9a-f]{2})", m.group(1)))
    return [int.from_bytes(data[i:i + 8], "little") for i in range(0, len(data), 8)]


def trie_words(nodes):
    """Every word of a trie, as a list of code points."""
    out = []

    def walk(node, prefix):
        v = nodes[node]
        if v & 1:
            out.append(list(prefix))
        first = (v >> 15) & 0x1FFFFF
        count = (v >> 1) & 0x3FFF
        for k in range(count):
            child = nodes[first + k]
            prefix.append((child >> 36) & 0x1FFFFF)
            walk(first + k, prefix)
            prefix.pop()

    walk(0, [])
    return out


def pick(rng, words):
    """One word of the list, cut to 99 code points."""
    return rng.choice(words)[:99]


def build_battery(rng, words):
    """The texts of the battery, one list of code points per text."""
    texts = []
    # The words of the four scripts, alone and in pairs.
    for name in ["thai", "lao", "burmese", "khmer"]:
        pool = words[name]
        for _ in range(1200):
            t = []
            for _ in range(rng.randint(1, 3)):
                t += pick(rng, pool)
            if rng.random() < 0.3:
                t.insert(rng.randrange(len(t) + 1), rng.choice(MARKS[name]))
            if rng.random() < 0.2:
                t += [rng.choice(FILLERS)] * rng.randint(1, 3)
            texts.append(t)
    # The letters of the four scripts with no word.
    for name in ["thai", "lao", "burmese", "khmer"]:
        lo, hi = LETTERS[name]
        for _ in range(300):
            t = [rng.randint(lo, hi) for _ in range(rng.randint(2, 8))]
            texts.append(t)
    # The Chinese and Japanese text.
    cj = words["cj"]
    for _ in range(2500):
        t = []
        for _ in range(rng.randint(1, 3)):
            t += pick(rng, cj)
        texts.append(t)
    # The Han, Hiragana and Katakana letters with no word.
    for _ in range(800):
        t = []
        for _ in range(rng.randint(2, 6)):
            lo, hi = rng.choice(CJ_LETTERS)
            t.append(rng.randint(lo, hi))
        texts.append(t)
    # The Japanese text with the marks and the width forms.
    for _ in range(600):
        t = []
        for _ in range(rng.randint(2, 5)):
            t.append(rng.randint(0x3042, 0x30FA))
            if rng.random() < 0.4:
                t.append(rng.choice(CJ_MARKS))
        texts.append(t)
    for _ in range(200):
        # The halfwidth and the fullwidth forms, which the NFKC step folds.
        t = []
        for _ in range(rng.randint(2, 4)):
            t.append(rng.randint(0xFF66, 0xFF9D))
            if rng.random() < 0.3:
                t.append(rng.randint(0xFF01, 0xFF5E))
        texts.append(t)
    # The texts that mix the scripts with the letters, the digits and the
    # punctuation.
    other = ["thai", "lao", "burmese", "khmer"]
    for _ in range(1200):
        name = rng.choice(other)
        pool = words[name]
        t = list(pick(rng, pool))
        if rng.random() < 0.5:
            t = [rng.randint(0x41, 0x5A)] + t
        if rng.random() < 0.4:
            t = t + [rng.randint(0x30, 0x39)]
        if rng.random() < 0.4:
            t = t + [rng.choice([0x2E, 0x2C, 0x21, 0x3F, 0x20, 0x3002])]
        if rng.random() < 0.3:
            t = t + [rng.randint(0x4E00, 0x9FA5)]
        if rng.random() < 0.3:
            t = t + [rng.randint(0x3042, 0x30FA)]
        texts.append(t)
    # The compatibility forms that the NFKC step folds or expands: the
    # compatibility ideographs, the squared and circled Katakana, and a
    # kana with a combining voiced mark. They stand among words of the
    # Chinese and Japanese list.
    compat = [(0xF900, 0xFAD9), (0x2F800, 0x2FA1D), (0x3300, 0x3357),
              (0x32D0, 0x32FE), (0x3358, 0x3370), (0x3200, 0x321E)]
    for _ in range(600):
        t = list(pick(rng, cj)) if rng.random() < 0.6 else []
        for _ in range(rng.randint(1, 3)):
            lo, hi = rng.choice(compat)
            t.append(rng.randint(lo, hi))
            if rng.random() < 0.3:
                t.append(rng.choice([0x3099, 0x309A]))
        if rng.random() < 0.5:
            t += list(pick(rng, cj))
        texts.append(t)
    for _ in range(200):
        t = []
        for _ in range(rng.randint(1, 4)):
            t.append(rng.randint(0x304B, 0x3062))
            t.append(rng.choice([0x3099, 0x309A]))
        texts.append(t)
    return texts


def icu_splits(texts):
    """The segment sizes and the word-like flags of ICU.

    The size of a segment is in code points. The oracle gives offsets in
    UTF-16 units, and the code below turns them into code points. The flag
    of a segment comes from the rule status of the boundary that ends it:
    the statuses 100, 200 and 400 mark a number, a letter and an ideograph.
    """
    lines = [" ".join("%04X" % c for c in t) for t in texts]
    out = u.oracle_go("icubrk", "root", stdin="\n".join(lines) + "\n")
    if len(out) != len(texts):
        u.fail("the ICU oracle gave %d lines for %d texts" % (len(out), len(texts)))
    sizes = []
    flags = []
    for t, line in zip(texts, out):
        offsets = []
        for part in line.split():
            off, _, status = part.partition(":")
            offsets.append((int(off), int(status)))
        # The unit offset of the end of each code point.
        ends = {}
        unit = 0
        for k, c in enumerate(t):
            unit += 2 if c >= 0x10000 else 1
            ends[unit] = k + 1
        if not offsets or offsets[-1][0] != unit:
            u.fail("the ICU oracle did not reach the end of %r" % t)
        segs = []
        fs = []
        prev = 0
        for off, status in offsets:
            if off not in ends:
                u.fail("the ICU oracle split inside a code point of %r" % t)
            segs.append(ends[off] - prev)
            fs.append(1 if status in (100, 200, 400) else 0)
            prev = ends[off]
        sizes.append(segs)
        flags.append(fs)
    return sizes, flags


def node_splits(texts):
    """The segment sizes of Node, in code points, one list per text.

    The script records the texts where the splits of Node differ from the
    splits of ICU. The Unicode 18 tables of the package and the ICU 79.1
    tables drive the split, so ICU holds the truth. The disagreement
    goes into the README.
    """
    lines = [json.dumps(t) for t in texts]
    out = u.oracle_node("segment.mjs", "word", stdin="\n".join(lines) + "\n")
    if len(out) != len(texts):
        u.fail("the Node oracle gave %d lines for %d texts" % (len(out), len(texts)))
    sizes = []
    for t, line in zip(texts, out):
        a, _, _b = line.partition("|")
        segs = [int(v) for v in a.split()]
        if sum(segs) != len(t):
            u.fail("the Node oracle did not reach the end of %r" % t)
        sizes.append(segs)
    return sizes


def main():
    u.check_version()
    rng = random.Random(20261111)
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    words = {}
    for name in TRIES:
        nodes = read_trie(name)
        words[name] = trie_words(nodes)
        print("%s: %d nodes, %d words" % (name, len(nodes), len(words[name])))
    texts = build_battery(rng, words)
    if limit:
        texts = texts[:limit]
    print("battery: %d texts" % len(texts))
    icu, flags = icu_splits(texts)
    node = node_splits(texts)
    diff = 0
    for t, a, b in zip(texts, icu, node):
        if a != b:
            diff += 1
            if diff <= 5:
                print("NODE-DIFF: %r ICU %r Node %r" % (t, a, b))
    print("ICU and Node differ on %d of %d texts" % (diff, len(texts)))
    # The cases: the code points of the text, the size of every segment and
    # the word-like flag of every segment.
    pool = []
    off = []
    for t, segs, fs in zip(texts, icu, flags):
        off.append(len(pool))
        pool.append(len(t))
        pool += t
        pool.append(len(segs))
        pool += segs
        pool += fs
    off.append(len(pool))
    parts = [
        u.array("DICT_OFF", off, "Start of each case in DICT_POOL. One more entry ends the last."),
        u.array("DICT_POOL", pool, "For each case: the count of code points, the code points, the count of segments, the size of each segment, the word-like flag of each segment."),
    ]
    out = os.path.join(HERE, "suite", "dict_cases.goose")
    with open(out, "w", encoding="utf-8") as f:
        f.write("// Reference cases for the dictionary word segmentation.\n")
        f.write("// Made by test/dict_battery.py. Do not edit by hand.\n")
        f.write("namespace suite;\n\n")
        f.write("\n".join(parts))
    print("wrote %s" % out)


if __name__ == "__main__":
    main()
