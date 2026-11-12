"""Shared helpers of the table generators.

The generators read the Unicode Character Database 18.0.0 text files from
a directory. The first argument of a generator names that directory. The
default is ../../../tmp/ucd relative to this file. Each generator writes
numbers only into a Goose source file in the package root.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MAX_CP = 0x10FFFF
VERSION = "18.0.0"

CATS = ["Cn", "Lu", "Ll", "Lt", "Lm", "Lo", "Mn", "Mc", "Me", "Nd", "Nl", "No",
        "Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po", "Sm", "Sc", "Sk", "So", "Zs",
        "Zl", "Zp", "Cc", "Cf", "Cs", "Co"]

HEADER = """// Unicode {version} data for the unicode package.
// Made by test/{script}. Do not edit by hand. Make the file again with
// the script. The numbers come from the Unicode Character Database, which
// the Unicode License covers. See test/NOTICE.
namespace unicode;
"""


def ucd_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.normpath(os.path.join(HERE, "..", "..", "..", "tmp", "ucd"))


def ucd_path(name):
    return os.path.join(ucd_dir(), name)


def fail(msg):
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def lines_of(name):
    """Yield the data lines of a UCD file without comments."""
    with open(ucd_path(name), encoding="utf-8") as f:
        for line in f:
            line = line.split("#")[0].strip()
            if line:
                yield line


def parse_range(text):
    text = text.strip()
    if ".." in text:
        a, b = text.split("..")
        return int(a, 16), int(b, 16)
    v = int(text, 16)
    return v, v


def unicode_data():
    """Return a dict cp -> fields of UnicodeData.txt. Ranges expand."""
    rows = {}
    first = None
    with open(ucd_path("UnicodeData.txt"), encoding="utf-8") as f:
        for line in f:
            fields = line.rstrip("\n").split(";")
            cp = int(fields[0], 16)
            name = fields[1]
            if name.endswith(", First>"):
                first = (cp, fields)
                continue
            if name.endswith(", Last>"):
                lo, ffields = first
                for c in range(lo, cp + 1):
                    rows[c] = ffields
                first = None
                continue
            rows[cp] = fields
    return rows


def string(name, text, comment=None):
    out = []
    if comment:
        out.append("// " + comment)
    out.append('const %s: u8[] = "%s";' % (name, text))
    out.append("")
    return "\n".join(out)


def array(name, values, comment=None):
    out = []
    if comment:
        out.append("// " + comment)
    out.append("const %s: i64[%d] = [" % (name, len(values)))
    for i in range(0, len(values), 24):
        out.append("    " + ", ".join(str(v) for v in values[i:i + 24]) + ",")
    out.append("];")
    out.append("")
    return "\n".join(out)


def bytes_array(name, data, comment=None):
    """A byte string of the data, as an escaped literal.

    The compiler reads a string of bytes far faster than it reads a list
    of numbers, so the big tables of the package hold bytes.
    """
    out = []
    if comment:
        out.append("// " + comment)
    # One line: the compiler is slow on a literal that spans lines.
    body = "".join("\\x%02x" % b for b in data)
    out.append("const %s: u8[%d] = \"%s\";" % (name, len(data), body))
    out.append("")
    return "\n".join(out)


def pool_bytes(values):
    """The pool of the values: three bytes each, low byte first."""
    out = bytearray()
    for v in values:
        if v < 0 or v > 0xFFFFFF:
            fail("the value %d does not fit three bytes" % v)
        out += bytes([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF])
    return bytes(out)


def write_goose(path, script, parts, namespace="unicode"):
    header = HEADER.format(version=VERSION, script=script)
    if namespace != "unicode":
        header = header.replace("namespace unicode;", "namespace %s;" % namespace)
    with open(path, "w", encoding="utf-8") as f:
        f.write(header)
        f.write("\n")
        f.write("\n".join(parts))


def oracle_go(*args, stdin=None):
    """Run the Go oracle and return its output lines."""
    env = dict(os.environ)
    env["GOFLAGS"] = "-mod=mod"
    env["GOPROXY"] = "off"
    r = subprocess.run(["go", "run", "."] + list(args), cwd=os.path.join(HERE, "oracle"),
                       input=stdin, capture_output=True, text=True, env=env)
    if r.returncode != 0:
        fail("the Go oracle failed: " + r.stderr[:500])
    return r.stdout.splitlines()


def oracle_node(script, *args, stdin=None):
    r = subprocess.run(["node", os.path.join(HERE, "oracle", script)] + list(args),
                       input=stdin, capture_output=True, text=True)
    if r.returncode != 0:
        fail("the Node oracle failed: " + r.stderr[:500])
    return r.stdout.splitlines()


def icu_case(tag, kind, lines):
    """Run ICU over the texts and return one line per text."""
    return oracle_go("icelocale", tag, kind, stdin="\n".join(lines) + "\n")


def hexline(cps):
    """The code points as a line of hex, for the oracles."""
    return " ".join("%04X" % c for c in cps)


def icu_rows(texts, tag, kind):
    """The texts whose ICU result in the locale differs from the root, with
    the result as a list of code points."""
    lines = [hexline(t) for t in texts]
    loc = icu_case(tag, kind, lines)
    root = icu_case("und", kind, lines)
    out = []
    for t, a, b in zip(texts, loc, root):
        if a.startswith("error") or b.startswith("error"):
            fail("ICU gave an error for %s" % hexline(t))
        if a != b:
            out.append((t, [int(x, 16) for x in a.split()]))
    return out


def runs_of(values, skip=None):
    """Turn a list indexed by code point into (start, end, value) runs."""
    out = []
    start = 0
    for cp in range(1, len(values) + 1):
        if cp == len(values) or values[cp] != values[start]:
            if skip is None or values[start] != skip:
                out.append((start, cp - 1, values[start]))
            start = cp
    return out


def check_version():
    """The ICU library is the oracle that holds the release of the
    tables. The Go library, Node and Python hold older releases, so the
    generators compare with them only where the older release holds the
    code point."""
    v = oracle_go("icuver")[0].strip()
    if v != VERSION:
        fail("the ICU oracle holds Unicode %s, not %s" % (v, VERSION))


_HELD = None


def held():
    """A bytearray over all code points: 1 where the older oracles can
    judge the code point, 0 where the release of the tables assigned it.
    The Go library, Node and Python hold an older release, so they know
    nothing of the new code points. The ICU library holds the release
    of the tables and judges every code point."""
    global _HELD
    if _HELD is None:
        h = bytearray([1]) * (MAX_CP + 1)
        major = int(VERSION.split(".")[0])
        for line in oracle_go("iceage"):
            a, b, age = line.split()
            if int(age.split(".")[0]) >= major:
                for c in range(int(a, 16), int(b, 16) + 1):
                    h[c] = 0
        _HELD = h
    return _HELD


def expand(runs, default=0):
    """The list over all code points from (first, last, value) runs."""
    out = [default] * (MAX_CP + 1)
    for a, b, v in runs:
        for c in range(a, b + 1):
            out[c] = v
    return out
