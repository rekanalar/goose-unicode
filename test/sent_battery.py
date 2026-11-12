#!/usr/bin/env python3
"""Make the case files of the sentence abbreviations and the line styles.

The script asks the ICU library for the breaks of the texts it builds.
The oracle of the package calls the library. The sentence texts come
from the abbreviations of the seven locales. The line texts hold the
class CJ and the six iteration marks in many positions.

The two case files hold the code points of each text and the breaks
that the library gives. The suite of the package replays them.

Usage: sent_battery.py [dir with the locale files]
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u
import make_sent_abbr_data as abbr

# The tag of each locale and its number. The number is the value of the
# constant of the locale in the package.
LOCALES = [
    ("en", 1),
    ("de", 2),
    ("es", 3),
    ("fr", 4),
    ("it", 5),
    ("pt", 6),
    ("ru", 7),
]

# The number of each locale.
NUM = {tag: num for tag, num in LOCALES}

# The code points of the line texts. They hold the class CJ, the six
# marks, the classes that bind to them and the plain letters.
LINE_CHARS = [0x20, 0x21, 0x22, 0x23, 0x24, 0x28, 0x29, 0x2B, 0x2E, 0x2F,
              0x30, 0x41, 0x5B, 0x5D, 0x2010, 0x2011, 0x00A0, 0x30FC, 0x3005,
              0x303B, 0x309D, 0x309E, 0x30FD, 0x30FE, 0x4E2D, 0x3042]


def utf16_offsets(cps):
    """The offset of every code point in UTF-16 units, and the length."""
    out = []
    at = 0
    for cp in cps:
        out.append(at)
        at += 2 if cp > 0xFFFF else 1
    out.append(at)
    return out


def to_code_points(cps, offsets):
    """The UTF-16 offsets of ICU as the offsets of the code points."""
    starts = utf16_offsets(cps)
    table = {start: i for i, start in enumerate(starts)}
    out = []
    for off in offsets:
        if off not in table:
            u.fail("ICU gave the offset %d, which no code point has" % off)
        out.append(table[off])
    return out


def sentence_starts(texts, locale):
    """The starts of the sentences of every text, for one locale."""
    out = []
    for cps, row in zip(texts, icu_sentences(texts, locale)):
        got = to_code_points(cps, row)
        # The last break of ICU is the end of the text. The starts of the
        # sentences do not hold it.
        if got and got[-1] == len(cps):
            got = got[:-1]
        out.append([0] + got)
    return out


def icu_sentences(texts, locale):
    """The breaks of the filtered sentence iterator of ICU."""
    lines = [u.hexline(t) for t in texts]
    out = []
    for line in u.oracle_go("icusent", locale, stdin="\n".join(lines) + "\n"):
        if line.startswith("error"):
            u.fail("ICU gave an error for the sentence iterator")
        out.append([int(x) for x in line.split()])
    if len(out) != len(texts):
        u.fail("ICU gave %d rows for %d texts" % (len(out), len(texts)))
    return out


def icu_lines(texts, style):
    """The break opportunities of the ICU line iterator."""
    lines = [u.hexline(t) for t in texts]
    out = []
    for line in u.oracle_go("iculinebrk", "root@lb=" + style, stdin="\n".join(lines) + "\n"):
        if line.startswith("error"):
            u.fail("ICU gave an error for the line iterator")
        row = []
        for part in line.split():
            row.append(int(part.split(":")[0]))
        out.append(row)
    if len(out) != len(texts):
        u.fail("ICU gave %d rows for %d texts" % (len(out), len(texts)))
    return out


def pool_bytes(values):
    """The pool of the values: three bytes each, low byte first."""
    out = bytearray()
    for v in values:
        if v < 0 or v > 0xFFFFFF:
            u.fail("the value %d does not fit three bytes" % v)
        out += bytes([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF])
    return bytes(out)


def sentence_texts(src):
    """The texts of the sentences: the abbreviations of every locale."""
    out = []
    for name, _ in LOCALES:
        entries = abbr.read_list(os.path.join(src, name + ".txt"))
        for word in entries:
            cps = [ord(c) for c in word]
            out.append((name, cps + [ord(" ")] + [ord(c) for c in "Smith went home."]))
            out.append((name, [ord(c) for c in "The "] + cps + [ord(c) for c in " is here."]))
            out.append((name, cps))
    # The texts of the scenarios of the spec.
    for text in ["Mr. Smith went home. Dr. Jones stayed.",
                 "Prof. A. B. C. Smith et al. wrote it.",
                 "Ph.D. and M.Sc. degrees. No. 5 and Vol. 2.",
                 "Vol. 2. No. 5 and Mr. Smith went home.",
                 "A text with no abbreviation at all. It has two sentences."]:
        out.append(("en", [ord(c) for c in text]))
    return out


def line_texts():
    """The texts of the lines: the marks and the class CJ in many places."""
    out = []
    for a in LINE_CHARS:
        for b in LINE_CHARS:
            out.append([a, b])
            out.append([a, b, a, b, 0x41])
    rng = random.Random(20261113)
    for _ in range(1200):
        n = rng.randint(3, 14)
        out.append([rng.choice(LINE_CHARS) for _ in range(n)])
    return out


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.normpath(
        os.path.join(u.HERE, "..", "..", "..", "tmp", "icu-release-79.1", "icu4c",
                     "source", "data", "brkitr"))
    # The sentences.
    cases = sentence_texts(src)
    by_locale = {}
    for name, cps in cases:
        by_locale.setdefault(name, []).append(cps)
    starts = {}
    for name, _ in LOCALES:
        texts = by_locale.get(name, [])
        if not texts:
            continue
        starts[name] = sentence_starts(texts, name + "@ss=standard")
    # The root locale gives the breaks of the plain call. The cases of
    # the root locale hold the texts of the English locale.
    root_texts = by_locale.get("en", [])
    root_starts = sentence_starts(root_texts, "root")
    cases = cases + [("root", cps) for cps in root_texts]
    values = []
    pos = {}
    for name, cps in cases:
        if name == "root":
            row = root_starts[pos.get("root", 0)]
            pos["root"] = pos.get("root", 0) + 1
        else:
            if name not in starts:
                u.fail("no breaks for the text of %s" % name)
            row = starts[name][pos.get(name, 0)]
            pos[name] = pos.get(name, 0) + 1
        locale = NUM.get(name, 0)
        values.append(locale)
        values.append(len(cps))
        values.extend(cps)
        values.append(len(row))
        values.extend(row)
    parts = [u.array(
        "SENT_CASES_COUNT",
        [len(cases)],
        "The number of the cases of the sentence abbreviations."),
        u.bytes_array(
        "SENT_CASES_POOL",
        pool_bytes(values),
        "The cases of the sentence abbreviations. Each case holds the"
        " locale, the count of the code points, the code points, the"
        " count of the starts and the starts. The values take three"
        " bytes, low byte first.")]
    u.write_goose(os.path.join(u.HERE, "suite", "sent_abbr_cases.goose"),
                  "sent_battery.py", parts, namespace="suite")
    print("the sentence cases: %d texts" % len(cases))
    # The lines.
    texts = line_texts()
    styles = []
    for style in ["strict", "normal", "loose"]:
        styles.append(icu_lines(texts, style))
    values = []
    for i, cps in enumerate(texts):
        values.append(len(cps))
        values.extend(cps)
        for rows in styles:
            row = to_code_points(cps, rows[i])
            values.append(len(row))
            values.extend(row)
    parts = [u.array(
        "LINE_STYLE_CASES_COUNT",
        [len(texts)],
        "The number of the cases of the line styles."),
        u.bytes_array(
        "LINE_STYLE_CASES_POOL",
        pool_bytes(values),
        "The cases of the line styles. Each case holds the count of the"
        " code points, the code points, and then the breaks of the"
        " strict, the normal and the loose style. Each list holds the"
        " count and the offsets. The values take three bytes, low byte"
        " first.")]
    u.write_goose(os.path.join(u.HERE, "suite", "line_style_cases.goose"),
                  "sent_battery.py", parts, namespace="suite")
    print("the line cases: %d texts" % len(texts))


if __name__ == "__main__":
    main()
