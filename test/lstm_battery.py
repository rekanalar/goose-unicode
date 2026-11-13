#!/usr/bin/env python3
"""Compare the model engine of the package with ICU 79.1, Node 22 and the
Rust crate icu_segmenter 2.4.0 on seeded Thai and Burmese texts.

Needs: Python 3, ICU 79.1 with genrb, Node 22, and the Rust oracle built
in test/oracle (cargo build --release).

Usage: lstm_battery.py <icu prefix> <icu source> [texts] [seed] [goose]
For each script and for the word and the line breaks the script prints
the count of texts where the package and ICU differ. Then it prints how
many texts the dictionary engine, Node and Rust split as ICU does with
the models. It exits nonzero when the package differs from ICU.
"""
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_lstm_cases as mk
import ucdlib as u


def lines_of(texts):
    return "\n".join(u.hexline(t) for t in texts) + "\n"


def package(texts, engine, mode, goose):
    path = os.path.join(u.ROOT, "tmp", "lstm_battery_in.txt")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(lines_of(texts))
    r = subprocess.run([goose, "run", "test/lstm_diff.goose", "--", path, engine, mode],
                       cwd=u.ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        u.fail("the package run failed: " + r.stdout[-300:] + r.stderr[-300:])
    rows = [x for x in r.stdout.splitlines() if x and x[0] in "0123456789E"]
    shift = 1 if mode == "line" else 0
    return [[(int(b) >> shift) // 3 for b in x.split()] if not x.startswith("E") else None
            for x in rows]


def inner(rows, texts):
    """The break indexes without the start and the end of the text."""
    return [sorted(set(r or []) - {0, len(t)}) for r, t in zip(rows, texts)]


def rows_to_breaks(rows):
    """The break indexes of each row, without the end of the text."""
    return [[int(x) for x in l.split()][:-1] for l in rows]


def node(texts, gran):
    return rows_to_breaks(u.oracle_node("lstmword.mjs", gran, stdin=lines_of(texts)))


def rust(texts, mode):
    exe = os.path.join(HERE, "oracle", "target", "release", "wordseg")
    r = subprocess.run([exe, mode], input=lines_of(texts), capture_output=True,
                       text=True, check=True)
    return rows_to_breaks(r.stdout.splitlines())


def main():
    prefix, src = sys.argv[1], sys.argv[2]
    count = int(sys.argv[3]) if len(sys.argv) > 3 else 1000
    seed = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    goose = sys.argv[5] if len(sys.argv) > 5 else "goose"
    exe, work, env = mk.build_oracle(prefix, src)
    rng = random.Random(seed)
    bad = 0
    for name in ("thai", "burmese"):
        texts = mk.corpus(name, count, rng)
        icu_w = [w[:-1] for w in mk.ask(exe, work, env, "word", texts)]
        icu_l = [l[:-1] for l in mk.ask(exe, work, env, "line", texts)]
        mine_w = package(texts, "model", "word", goose)
        mine_l = package(texts, "model", "line", goose)
        dw = sum(1 for a, b in zip(mine_w, icu_w) if a != b)
        dl = sum(1 for a, b in zip(inner(mine_l, texts), inner(icu_l, texts)) if a != b)
        print("%s: %d texts, word differences %d, line differences %d"
              % (name, len(texts), dw, dl))
        bad += dw + dl
        dict_w = package(texts, "dict", "word", goose)
        print("  dictionary engine equals the model of ICU in %d texts"
              % sum(1 for a, b in zip(dict_w, icu_w) if a == b))
        nd = node(texts, "word")
        print("  Node equals the model of ICU in %d texts, the dictionary of the package in %d"
              % (sum(1 for a, b in zip(nd, icu_w) if a == b),
                 sum(1 for a, b in zip(nd, dict_w) if a == b)))
        for mode in ("auto", "lstm", "dictionary"):
            rs = rust(texts, mode)
            print("  Rust %s equals the model of ICU in %d texts"
                  % (mode, sum(1 for a, b in zip(rs, icu_w) if a == b)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
