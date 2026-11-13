#!/usr/bin/env python3
"""Make utf16_cases.goose: the vectors of the UTF-16 suite.

The sources are three libraries: the Go library unicode/utf16, the Node
library TextDecoder in the fatal mode and the Rust standard library
String::from_utf16. The script writes the vectors of the code points of
the whole range, the pair that spans the hole of the surrogates, the
malformed inputs and 20,000 random texts. It fails when the three
libraries disagree.

The Go library writes U+FFFD for a lone surrogate. The Node library in
the fatal mode and the Rust library refuse it. The script checks the
valid texts against the Go library and the malformed inputs against the
Node library and the Rust library.

Usage: make_utf16_data.py [ucd directory]
"""
import json
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ORACLE = os.path.join(HERE, "oracle")
RS = os.path.join(HERE, "oracle", "utf16.rs")
RS_BIN = os.path.join(ROOT, "tmp", "utf16rs")
GO_BIN = os.path.join(ROOT, "tmp", "utf16go")


def fail(msg):
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def go_build():
    env = dict(os.environ)
    env["GOFLAGS"] = "-mod=mod"
    env["GOPROXY"] = "off"
    os.makedirs(os.path.dirname(GO_BIN), exist_ok=True)
    r = subprocess.run(["go", "build", "-o", GO_BIN, "."], cwd=ORACLE,
                       capture_output=True, text=True, env=env)
    if r.returncode != 0:
        fail("the Go oracle did not build: " + r.stderr[:500])


def go_utf16(mode, lines):
    r = subprocess.run([GO_BIN, mode], cwd=ORACLE, input="\n".join(lines) + "\n",
                       capture_output=True, text=True)
    if r.returncode != 0:
        fail("the Go oracle failed: " + r.stderr[:500])
    return r.stdout.splitlines()


def node_utf16(mode, lines):
    r = subprocess.run(["node", os.path.join(ORACLE, "utf16.mjs"), mode],
                       input="\n".join(lines) + "\n", capture_output=True, text=True)
    if r.returncode != 0:
        fail("the Node oracle failed: " + r.stderr[:500])
    return r.stdout.splitlines()


def rust_utf16(mode, lines):
    # The binary is built every run, so it never lags behind the source.
    os.makedirs(os.path.dirname(RS_BIN), exist_ok=True)
    r = subprocess.run(["rustc", "-O", RS, "-o", RS_BIN], capture_output=True, text=True)
    if r.returncode != 0:
        fail("the Rust oracle did not build: " + r.stderr[:500])
    r = subprocess.run([RS_BIN, mode], input="\n".join(lines) + "\n", capture_output=True, text=True)
    if r.returncode != 0:
        fail("the Rust oracle failed: " + r.stderr[:500])
    return r.stdout.splitlines()


def main():
    random.seed(20261110)
    go_build()
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

    # The malformed inputs: a lone surrogate and an odd count of bytes.
    # The malformed inputs hold a lone surrogate. The units are the
    # surrogates themselves, so the Go library writes U+FFFD for them and
    # the Node library and the Rust library refuse them.
    bad = []
    bad.append([0xD800])
    bad.append([0xDC00])
    bad.append([0xDFFF])
    bad.append([0xD800, 0x0041])
    bad.append([0x0041, 0xDC00])
    bad.append([0xD800, 0xD800])
    bad.append([0xDBFF, 0x0041])

    bodies = [" ".join("%04X" % cp for cp in text) for text in cases]
    for order in ("le", "be"):
        lines = [body + "|" + order for body in bodies]
        go = go_utf16("utf16", lines)
        node = node_utf16("encode", lines)
        rs = rust_utf16("encode", lines)
        if not (len(go) == len(node) == len(rs) == len(cases)):
            fail("the oracles give different line counts")
        for text, g, n, r in zip(cases, go, node, rs):
            if g != n or g != r:
                fail("the libraries disagree on %r: Go %r, Node %r, Rust %r" % (text, g, n, r))
        # The malformed inputs: the Node library and the Rust library must refuse.
        bad_lines = []
        for text in bad:
            by = []
            for u in text:
                by += ([u >> 8, u & 0xFF] if order == "be" else [u & 0xFF, u >> 8])
            bad_lines.append(" ".join("%02X" % b for b in by) + "|" + order)
        # An odd count of bytes.
        bad_lines.append("41|" + order)
        node = node_utf16("decode", bad_lines)
        rs = rust_utf16("decode", bad_lines)
        if node != rs:
            fail("the Node library and the Rust library disagree on the malformed inputs")
        for line in node:
            if line != "bad":
                fail("the libraries accept a malformed input: " + line)

    # The output: the code points of a sample of the cases. The script
    # above checked every code point of the range against the three
    # libraries. The suite holds a sample, so the test run stays quick.
    sample = cases[:64] + cases[::997] + cases[-64:]
    pool = []
    off = []
    for text in sample:
        off.append(len(pool))
        pool.append(len(text))
        pool.extend(text)
    off.append(len(pool))
    with open(os.path.join(HERE, "suite", "utf16_cases.goose"), "w", encoding="utf-8") as f:
        f.write("// Generated by test/make_utf16_data.py. Do not edit by hand.\n")
        f.write("// Reference cases for the test suites, UTF-16 encodings.\n")
        f.write("namespace suite;\n\n")
        f.write("// Start of each case in U16_POOL. One more entry ends the last.\n")
        f.write("const U16_OFF: i64[%d] = [\n" % len(off))
        for i in range(0, len(off), 24):
            f.write("    " + ", ".join(str(v) for v in off[i:i + 24]) + ",\n")
        f.write("];\n\n")
        f.write("// For each case: the count of code points, the code points.\n")
        f.write("const U16_POOL: i64[%d] = [\n" % len(pool))
        for i in range(0, len(pool), 24):
            f.write("    " + ", ".join(str(v) for v in pool[i:i + 24]) + ",\n")
        f.write("];\n")
    print("utf16 cases %d checked against Go, Node and Rust; %d of them in the suite" % (len(cases), len(sample)))


main()
