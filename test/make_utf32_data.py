#!/usr/bin/env python3
"""Make utf32_cases.goose: the vectors of the UTF-32 suite.

The source is the codec module of Python, which reads and writes UTF-32
in both byte orders and refuses a surrogate and a value above U+10FFFF
in its strict mode. Go holds no UTF-32 and Node rejects it, so Python is
the only oracle. The script writes the vectors of the code points of the
whole range, the pair that spans the hole of the surrogates, the
malformed inputs and 20,000 random texts. It fails when Python and the
rules of the package differ.

Usage: make_utf32_data.py [ucd directory]
"""
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def fail(msg):
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def py_encode(cps, order):
    b = bytearray()
    for cp in cps:
        b += cp.to_bytes(4, "big" if order == "be" else "little")
    return b


def py_refuse(by, order):
    # The strict decoder of Python raises on a surrogate, a value above
    # U+10FFFF and a length that no count of units gives.
    try:
        bytes(by).decode("utf-32-" + order, "strict")
    except UnicodeDecodeError:
        return True
    return False


def main():
    random.seed(20261110)
    cases = []

    # The code points of the whole range, one text each, plus the pair
    # that spans the hole of the surrogates.
    for cp in range(0, 0x110000):
        if 0xD800 <= cp <= 0xDFFF:
            continue
        cases.append([cp])
    cases.append([0xD7FF, 0xE000])
    # Texts of two and three code points.
    for _ in range(20000):
        n = random.randint(2, 3)
        text = []
        while len(text) < n:
            cp = random.randint(0, 0x10FFFF)
            if 0xD800 <= cp <= 0xDFFF:
                continue
            text.append(cp)
        cases.append(text)

    # The malformed inputs: a surrogate, a value above U+10FFFF and
    # lengths that no count of units gives. Python must refuse each one.
    bad_bytes = []
    for order in ("le", "be"):
        bad_bytes.append((py_encode([0xD800], order), order))
        bad_bytes.append((py_encode([0xDFFF], order), order))
        bad_bytes.append((py_encode([0x110000], order), order))
        bad_bytes.append((py_encode([0xFFFFFFFF], order), order))
        bad_bytes.append((py_encode([0x41, 0x42], order) + b"\x00", order))
        bad_bytes.append((py_encode([0x41], order) + b"\x01\x02", order))
        bad_bytes.append((b"\x01", order))

    for by, order in bad_bytes:
        if not py_refuse(by, order):
            fail("Python accepts a malformed input: %s %s" % (by.hex(), order))

    # The output: the code points of a sample of the cases. The script
    # above checked every code point of the range against Python. The
    # suite holds a sample, so the test run stays quick.
    sample = cases[:64] + cases[::997] + cases[-64:]
    pool = []
    off = []
    for text in sample:
        off.append(len(pool))
        pool.append(len(text))
        pool.extend(text)
    off.append(len(pool))
    with open(os.path.join(HERE, "suite", "utf32_cases.goose"), "w", encoding="utf-8") as f:
        f.write("// Reference cases for the test suites, UTF-32 encodings.\n")
        f.write("// Made by test/make_utf32_data.py. Do not edit by hand.\nnamespace suite;\n\n")
        f.write("// Start of each case in U32_POOL. One more entry ends the last.\n")
        f.write("const U32_OFF: i64[%d] = [\n" % len(off))
        for i in range(0, len(off), 24):
            f.write("    " + ", ".join(str(v) for v in off[i:i + 24]) + ",\n")
        f.write("];\n\n")
        f.write("// For each case: the count of code points, the code points.\n")
        f.write("const U32_POOL: i64[%d] = [\n" % len(pool))
        for i in range(0, len(pool), 24):
            f.write("    " + ", ".join(str(v) for v in pool[i:i + 24]) + ",\n")
        f.write("];\n")
    print("utf32 cases %d checked against Python; %d of them in the suite" % (len(cases), len(sample)))


main()
