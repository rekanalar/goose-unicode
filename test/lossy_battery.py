#!/usr/bin/env python3
"""Builds the cases of the lossy decode and of the byte order mark.

The expected values come from the ICU 79.1 converters. The script checks
them against Python, and against Rust for UTF-8, and prints each
difference. It writes test/suite/lossy_cases.goose.
Run: python3 test/lossy_battery.py
"""
import codecs
import itertools
import os
import random
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

SEED = 20261113
KINDS = [("UTF-8", "utf-8"), ("UTF-16LE", "utf-16-le"), ("UTF-16BE", "utf-16-be"),
         ("UTF-32LE", "utf-32-le"), ("UTF-32BE", "utf-32-be")]


def utf8_inputs(rng):
    out = []
    for b0 in range(256):
        for b1 in range(256):
            if 0xC2 <= b0 <= 0xF4 or b1 in (0x00, 0x41, 0x7F, 0x80, 0x8F, 0x90, 0x9F, 0xA0, 0xBF, 0xC0, 0xFF):
                out.append(bytes([b0, b1]))
    edge1 = [0x7F, 0x80, 0x8F, 0x90, 0x9F, 0xA0, 0xBF, 0xC0]
    edge2 = [0x41, 0x80, 0xBF, 0xC0]
    for b0 in range(0xE0, 0xF5):
        for b1 in edge1:
            for b2 in edge2:
                out.append(bytes([b0, b1, b2]))
                for b3 in edge2:
                    out.append(bytes([b0, b1, b2, b3]))
    for _ in range(3000):
        n = rng.randint(1, 12)
        pool = [0x41, 0x7F, 0x80, 0xBF, 0xC2, 0xDF, 0xE0, 0xE1, 0xED, 0xEF, 0xF0, 0xF4, 0xF5, 0xFF]
        out.append(bytes(rng.choice(pool) for _ in range(n)))
    return out


def unit_inputs(width, units, lengths, endian):
    out = []
    for n in lengths:
        for seq in itertools.product(units, repeat=n):
            out.append(b"".join(v.to_bytes(width, endian) for v in seq))
    return out


def all_cases(rng):
    cases = []
    for b in utf8_inputs(rng):
        cases.append((0, b))
    u16 = [0x41, 0x7F, 0xD7FF, 0xD800, 0xDBFF, 0xDC00, 0xDFFF, 0xE000, 0xFFFF]
    for k, endian in ((1, "little"), (2, "big")):
        base = unit_inputs(2, u16, [1, 2, 3, 4], endian)
        for b in base:
            cases.append((k, b))
        for b in base[:90]:
            cases.append((k, b + b"\x41"))
    u32 = [0x41, 0xD7FF, 0xD800, 0xDFFF, 0xE000, 0x10FFFF, 0x110000, 0xFFFFFFFF, 0x80000000]
    for k, endian in ((3, "little"), (4, "big")):
        base = unit_inputs(4, u32, [1, 2, 3, 4], endian)
        for b in base:
            cases.append((k, b))
        for b in base[:90]:
            for tail in (1, 2, 3):
                cases.append((k, b + b"\x41" * tail))
    return cases


def hexbytes(b):
    return " ".join("%02X" % x for x in b)


def icu_decode(kind, inputs):
    out = u.oracle_go("icuconv", KINDS[kind][0], stdin="\n".join(hexbytes(b) for b in inputs) + "\n")
    if len(out) != len(inputs):
        u.fail("the ICU oracle gave %d lines for %d inputs" % (len(out), len(inputs)))
    return [[int(v, 16) for v in line.split()] for line in out]


def python_decode(kind, data):
    """The code points and the count of replacements of Python."""
    count = [0]

    def handler(err):
        count[0] += 1
        return ("�", err.end)

    codecs.register_error("lossycount", handler)
    text = data.decode(KINDS[kind][1], "lossycount")
    return [ord(c) for c in text], count[0]


def rust_decode(inputs):
    binary = os.path.join(u.HERE, "oracle", "target", "release", "lossy")
    r = subprocess.run([binary], input="\n".join(hexbytes(b) for b in inputs) + "\n",
                       capture_output=True, text=True)
    if r.returncode != 0:
        u.fail("the Rust oracle failed: " + r.stderr[:300])
    return [[int(v, 16) for v in line.split()] for line in r.stdout.splitlines()]


BOM_NAMES = {"none": 0, "UTF-8": 1, "UTF-16LE": 2, "UTF-16BE": 3, "UTF-32LE": 4, "UTF-32BE": 5}


def bom_cases(rng):
    marks = [b"", b"\xEF\xBB\xBF", b"\xFF\xFE", b"\xFE\xFF", b"\xFF\xFE\x00\x00", b"\x00\x00\xFE\xFF",
             b"\xEF", b"\xEF\xBB", b"\xFF", b"\xFE", b"\xFF\xFE\x00", b"\x00\x00\xFE", b"\x00\x00", b"\x00"]
    tails = [b"", b"A", b"\x41\x00", b"\x00\x41", b"\x41\x00\x00\x00", b"\x00\x00\x00\x41", b"\x00\x00", b"\xFF\xFE"]
    out = []
    for m in marks:
        for t in tails:
            out.append(m + t)
    for _ in range(300):
        out.append(bytes(rng.choice([0x00, 0x41, 0xEF, 0xBB, 0xBF, 0xFE, 0xFF]) for _ in range(rng.randint(0, 6))))
    seen = []
    for b in out:
        if b not in seen:
            seen.append(b)
    return seen


def main():
    u.check_version()
    rng = random.Random(SEED)
    cases = all_cases(rng)
    print("lossy cases: %d" % len(cases))
    pool = bytearray()
    diffs = {k: 0 for k in range(5)}
    rust_diffs = 0
    counts = {k: 0 for k in range(5)}
    for kind in range(5):
        inputs = [b for k, b in cases if k == kind]
        icu = icu_decode(kind, inputs)
        counts[kind] = len(inputs)
        if kind == 0:
            rust = rust_decode(inputs)
            rust_diffs = sum(1 for a, b in zip(icu, rust) if a != b)
        for data, expect in zip(inputs, icu):
            py, nbad = python_decode(kind, data)
            if py != expect:
                diffs[kind] += 1
            if len(data) >= 1 << 24 or any(v > 0x10FFFF for v in expect):
                u.fail("a value does not fit in 3 bytes")
            pool.append(kind)
            pool += len(data).to_bytes(3, "little") + data
            pool += len(expect).to_bytes(3, "little")
            for v in expect:
                pool += v.to_bytes(3, "little")
            pool += nbad.to_bytes(3, "little")
    for kind in range(5):
        print("%s: %d cases, Python differs from ICU on %d" % (KINDS[kind][0], counts[kind], diffs[kind]))
    print("Rust from_utf8_lossy differs from ICU on %d of %d" % (rust_diffs, counts[0]))
    bcases = bom_cases(rng)
    names = u.oracle_go("icubom", stdin="\n".join(hexbytes(b) for b in bcases) + "\n")
    bpool = bytearray()
    for data, line in zip(bcases, names):
        name, _, length = line.partition(" ")
        bpool += len(data).to_bytes(3, "little") + data
        bpool.append(BOM_NAMES[name])
        bpool.append(int(length))
    print("BOM cases: %d" % len(bcases))
    parts = [
        u.bytes_array("LOSSY_POOL", bytes(pool),
                      "For each case: the kind (0 UTF-8, 1 and 2 UTF-16 little and big endian, 3 and 4 UTF-32), the byte count and the bytes, the count of code points and the code points, then the count of replacements. Each count and code point takes 3 bytes, low byte first."),
        "const LOSSY_CASES: i64 = %d;\n" % len(cases),
        u.bytes_array("BOM_POOL", bytes(bpool),
                      "For each case: the byte count in 3 bytes, the bytes, the kind of the mark and its length."),
        "const BOM_CASES: i64 = %d;\n" % len(bcases),
    ]
    out = os.path.join(u.HERE, "suite", "lossy_cases.goose")
    with open(out, "w", encoding="utf-8") as f:
        f.write("// Generated by test/lossy_battery.py. Do not edit by hand.\n")
        f.write("// Reference cases for the lossy decode and the byte order mark.\n")
        f.write("namespace suite;\n\n")
        f.write("\n".join(parts))
    print("wrote %s, %d bytes" % (out, len(pool) + len(bpool)))


if __name__ == "__main__":
    main()
