"""The corpus and the expected answers of the paragraph and line calls.

The module builds texts, asks the three oracles and works out the answer
that the package must give. The generator of the suite data and the
battery both use it.

The oracles are ICU 79.1 (mode icubidi of the Go oracle) and the Rust
crate unicode-bidi 0.3.18 (binary bidilines). The expected answer is the
answer of the standard. It follows ICU and Rust where they agree. Where
they differ, the module names the class of the difference and takes one
side:

  crlf     ICU takes CR LF as one terminator, Rust takes it as two. The
           package follows ICU. A text with CR LF takes its answer from
           ICU.
  removed  A code point that rule X9 removes gets the level of the next
           code point in ICU and of the previous code point in Rust. The
           package follows Rust.
  empty    ICU refuses an empty line. The package gives an empty answer.
  flags    ICU removes ZWJ and ZWNJ with the flag 8 and keeps ALM. The
           package follows the property Bidi_Control. A text with one of
           the three code points gives no expected text for a flag.
  rustline The crate writes the line as it is when the levels of the
           paragraph, before rule L1, hold no odd level. The standard
           reverses such a line, and so does ICU. The package follows the
           standard, so the answer comes from ICU.

  removedstart  A removed code point at the start of a line takes the
           paragraph level in the crate and the level of the code point
           before the line in ICU. No text is expected then.
  icuflat  ICU writes a line of one direction as one run, so the flag 1
           has no meaning for it. No text is expected for that flag.
  icudrop  ICU drops a mark whose base is a removed control with the
           flags 1 and 8. The package keeps the mark. No text is expected.

A difference outside these classes raises Unexplained.
"""
import os
import random
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

FLAGS = [0, 1, 2, 3, 8, 9, 10, 11]

# The code points of the pool, by class.
L = [0x61, 0x62]
R = [0x5D0, 0x5D1]
AL = [0x627]
NUM = [0x31, 0x2B, 0x24, 0x661, 0x2C]
MARK = [0x300, 0x5B0, 0x64B]
BN = [0xAD, 0x200B]
EXPLICIT = [0x202A, 0x202B, 0x202C, 0x202D, 0x202E]
ISO = [0x2066, 0x2067, 0x2068, 0x2069]
SEP = [0x0A, 0x0D, 0x2029, 0x85, 0x1C]
SPACE = [0x20, 0x09]
BRACKET = [0x28, 0x29, 0x5B, 0x5D, 0xFD3E, 0xFD3F]
MARKS_LR = [0x200E, 0x200F]
JOIN = [0x200C, 0x200D, 0x61C]
OTHER = [0x21, 0x2D]

REMOVED = set(BN + EXPLICIT)
JOINERS = set(JOIN)
ALL = (L + R + AL + NUM + MARK + BN + EXPLICIT + ISO + SEP + SPACE + BRACKET
       + MARKS_LR + OTHER)


class Unexplained(Exception):
    pass


def classes():
    """The named classes of texts. Each gives a pool and a length range."""
    letters = L + R + AL
    return [
        ("separators", letters + SPACE + SEP * 3 + [0x0D, 0x0A], 1, 9),
        ("removed", letters + SPACE + BN + EXPLICIT + [0x61, 0x5D0], 1, 9),
        ("marks", R + L + MARK * 2 + BN + SPACE, 1, 8),
        ("brackets", letters + BRACKET * 2 + SPACE + NUM, 1, 10),
        ("trailing", letters + SPACE * 3 + ISO + SEP[:2], 1, 9),
        ("isolates", letters + ISO * 2 + SPACE + NUM, 1, 10),
        ("random", ALL, 1, 12),
    ]


def build(seed, count):
    """Texts of every class. A case is (class name, dir, start, limit,
    code points). Several lines come from each text."""
    rng = random.Random(seed)
    cls = classes()
    out = []
    while len(out) < count:
        name, pool, lo, hi = cls[len(out) % len(cls)]
        n = rng.randint(lo, hi)
        cps = [rng.choice(pool) for _ in range(n)]
        if name == "separators" and rng.random() < 0.3 and n >= 2:
            k = rng.randrange(n - 1)
            cps[k], cps[k + 1] = 0x0D, 0x0A
        d = rng.randrange(3)
        lines = [(0, n)]
        for _ in range(2):
            a = rng.randint(0, n - 1)
            b = rng.randint(a + 1, n)
            if rng.random() < 0.08:
                b = a
            lines.append((a, b))
        for a, b in lines:
            out.append((name, d, a, b, cps))
    return out


def line_of(case):
    name, d, a, b, cps = case
    return "%d %d %d | %s" % (d, a, b, " ".join("%X" % c for c in cps))


def parse(text):
    """The blocks of an oracle output. A block ends with a dot line."""
    blocks = []
    cur = {}
    for row in text:
        row = row.strip()
        if row == ".":
            blocks.append(cur)
            cur = {}
            continue
        tag, _, rest = row.partition(" ")
        if tag == "P":
            v = [int(x) for x in rest.split()]
            cur["P"] = v[1:]
        elif tag == "D":
            cur["D"] = int(rest)
        elif tag in ("L", "PL", "O"):
            cur[tag] = [int(x) for x in rest.split()]
        elif tag == "W":
            f, _, r = rest.partition(" ")
            cur.setdefault("W", {})[int(f)] = (
                None if r.startswith("E") else [int(x, 16) for x in r.split()])
        elif tag == "E":
            cur["E"] = rest
    return blocks


def run_icu(lines):
    return parse(u.oracle_go("icubidi", stdin="\n".join(lines) + "\n"))


def run_rust(lines):
    path = os.path.join(u.HERE, "oracle", "target", "release", "bidilines")
    r = subprocess.run([path], input="\n".join(lines) + "\n",
                       capture_output=True, text=True)
    if r.returncode == 0:
        return parse(r.stdout.splitlines())
    # The crate panics on some texts. Run each line alone.
    out = []
    for line in lines:
        r = subprocess.run([path], input=line + "\n", capture_output=True, text=True)
        out.append(parse(r.stdout.splitlines())[0] if r.returncode == 0 else None)
    return out


def run_package(lines, goose="goose"):
    path = os.path.join(u.ROOT, "tmp", "bidi_line_in.txt")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    r = subprocess.run([goose, "run", "test/bidi_line_diff.goose", "--", path],
                       cwd=u.ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        u.fail("the package run failed: " + r.stdout[-500:] + r.stderr[-500:])
    rows = [x for x in r.stdout.splitlines()
            if x.split(" ")[0] in ("P", "L", "O", "W", "E", "D") or x == "."]
    return parse(rows)


def has_crlf(cps):
    return any(cps[k] == 0x0D and cps[k + 1] == 0x0A for k in range(len(cps) - 1))


def crosses(paras, a, b):
    """True when a paragraph limit falls inside the line."""
    for k in range(0, len(paras), 3):
        if a < paras[k + 1] < b:
            return True
    return False


def clean(cps):
    return not (set(cps) & (REMOVED | JOINERS))


def keep_positions(a, b, cps):
    """The positions of the line that hold a code point that rule X9 does
    not remove. ICU and the crate give a removed code point a different
    level, so the levels, the order and the text of the other code points
    are the only parts that both references answer the same way."""
    return [k for k in range(a, b) if cps[k] not in REMOVED]


def expected(case, icu, rust):
    """The answer that the package must give, and the classes of the
    differences that the answer rests on."""
    name, d, a, b, cps = case
    diffs = set()
    exp = {"P": icu["P"]}
    if has_crlf(cps):
        diffs.add("crlf")
    elif rust is not None and rust.get("P") != icu["P"]:
        raise Unexplained("paragraphs differ: icu %s rust %s" % (icu["P"], rust.get("P")))
    if crosses(icu["P"], a, b):
        exp["E"] = "arg"
        return exp, diffs
    if a == b:
        diffs.add("empty")
        exp.update({"L": [], "O": [], "W": {0: []}})
        return exp, diffs
    if "L" not in icu:
        raise Unexplained("ICU gave no levels: %s" % icu)
    # ICU gives the paragraph level to every code point of a line that it
    # finds to be one direction. Its levels count only for a mixed line.
    icu_levels = icu.get("D") == 2
    removed = [k for k in range(a, b) if cps[k] in REMOVED]
    ic = [x for x in icu["O"] if cps[x] not in REMOVED]
    crate = rust is not None and "L" in rust and "O" in rust
    if "crlf" in diffs or not crate:
        # The crate and ICU split a text with CR LF into paragraphs in
        # different ways, so only ICU answers such a text.
        if removed:
            # ICU gives a removed code point the level of the next code
            # point. The standard gives it the level of the previous one.
            # The line is compared without the removed code points.
            diffs.add("removed")
        src = icu
        exp["L"] = icu["L"] if icu_levels else None
        exp["O"] = icu["O"]
    else:
        # The crate gives the levels of the standard. ICU gives the level
        # of the next code point to a removed code point.
        src = rust
        for k in range(b - a):
            if cps[a + k] in REMOVED:
                if icu_levels and icu["L"][k] != rust["L"][k]:
                    diffs.add("removed")
            elif icu_levels and icu["L"][k] != rust["L"][k]:
                raise Unexplained("levels differ at %d: icu %s rust %s"
                                  % (k, icu["L"], rust["L"]))
        ru = [x for x in rust["O"] if cps[x] not in REMOVED]
        if ic != ru:
            raise Unexplained("order differs: icu %s rust %s" % (icu["O"], rust["O"]))
        exp["L"] = rust["L"]
        exp["O"] = rust["O"]
    # The crate writes the line as it is when the levels of the paragraph
    # hold no odd level. The standard reverses such a line.
    if rust is not None and rust.get("PL") and all(x % 2 == 0 for x in rust["PL"]):
        diffs.add("rustline")
        if crate and "crlf" not in diffs:
            # The crate writes the line as it is. The standard reverses
            # it. The order of the crate is the order of the standard.
            exp["W"] = {0: [cps[i] for i in rust["O"]]}
        else:
            exp["W"] = {0: icu["W"][0]}
        if cps[a] in REMOVED:
            # A removed code point at the start of a line takes the
            # paragraph level in the crate and the level of the code point
            # before the line in ICU. The standard fixes neither. The text
            # follows the levels, so no text is expected.
            diffs.add("removedstart")
            del exp["W"][0]
    else:
        exp["W"] = {0: src["W"][0]}
    if clean(cps[a:b]):
        # ICU writes a line that it finds to be one direction as one run,
        # with no regard for the levels inside it. With the flag 1 that
        # decides where a mark goes. The package follows the levels.
        flat = icu.get("D") != 2 and len(set(exp["L"] or [])) > 1
        # ICU drops a mark whose base is a control that the flag 8
        # removes. The package keeps the mark.
        drop = any(cps[k] in (0x200E, 0x200F, 0x2066, 0x2067, 0x2068, 0x2069)
                   and k + 1 < b and cps[k + 1] in MARK
                   for k in range(a, b))
        if flat or drop:
            diffs.add("icuflat" if flat else "icudrop")
        for f in FLAGS:
            if f == 0:
                continue
            if flat and f & 1:
                continue
            if drop and f & 8 and f & 1:
                continue
            exp["W"][f] = icu["W"][f]
    else:
        diffs.add("flags")
    return exp, diffs
