#!/usr/bin/env python3
"""Make enum_data.goose and test/suite/enum_cases.goose: seven enumerated properties.

The properties are Grapheme_Cluster_Break, Word_Break, Sentence_Break,
Hangul_Syllable_Type, Indic_Syllabic_Category, Indic_Positional_Category
and Vertical_Orientation. The value of a property is the position of its
value in PropertyValueAliases.txt, counted from zero for each property.

The three segmentation properties already have tables for the break
rules. Their classes have a numbering of their own, so the script writes
one small array for each that maps a class to the position in the alias
file. It matches the classes to the aliases by name. The other four
properties get a table of runs from HangulSyllableType.txt,
IndicSyllabicCategory.txt, IndicPositionalCategory.txt and
VerticalOrientation.txt of the Unicode Character Database 18.0.0.

Second source: the ICU library gives the value of every property for every
code point. The script compares the short name of the value over the whole
range and fails on the first difference. The suite file holds the runs of
ICU as positions in the alias file.
Usage: make_enum_data.py [ucd directory]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

# name, alias code, ICU property number, default short name, source file
PROPS = [
    ("grapheme_break", "GCB", 0x1012, "XX", None),
    ("word_break", "WB", 0x1014, "XX", None),
    ("sentence_break", "SB", 0x1013, "XX", None),
    ("hangul_syllable_type", "hst", 0x100B, "NA", "HangulSyllableType.txt"),
    ("indic_syllabic_category", "InSC", 0x1017, "Other", "IndicSyllabicCategory.txt"),
    ("indic_positional_category", "InPC", 0x1016, "NA", "IndicPositionalCategory.txt"),
    ("vertical_orientation", "vo", 0x1018, "R", "VerticalOrientation.txt"),
]
PREFIX = {"GCB": "GB", "WB": "WB", "SB": "SB"}
PACK_MASK = {"GCB": 15, "WB": 31, "SB": 15}


def aliases():
    """The (short, long) names of each property in the file order."""
    out = {}
    for line in u.lines_of("PropertyValueAliases.txt"):
        p = [x.strip() for x in line.split(";")]
        if len(p) >= 3 and p[0] in {x[1] for x in PROPS}:
            out.setdefault(p[0], []).append((p[1], p[2]))
    return out


def norm(text):
    return text.lower().replace("_", "")


def internal_classes(prefix):
    """The class numbers of the break tables, by name."""
    text = open(os.path.join(u.ROOT, "unicode.goose"), encoding="utf-8").read()
    out = {}
    for m in re.finditer(r"const %s_([A-Z_]+): i64 = (\d+);" % prefix, text):
        out[m.group(1)] = int(m.group(2))
    return out


def table_values(path, start, val, mask):
    """Expand a table of runs of the package into one value per code point."""
    text = open(os.path.join(u.ROOT, path), encoding="utf-8").read()

    def numbers(name):
        m = re.search(r"const %s: i64\[\d+\] = \[(.*?)\];" % name, text, re.S)
        return [int(x) for x in m.group(1).replace("\n", " ").split(",") if x.strip()]
    s, v = numbers(start), numbers(val)
    out = [0] * (u.MAX_CP + 1)
    for k, a in enumerate(s):
        b = s[k + 1] - 1 if k + 1 < len(s) else u.MAX_CP
        for c in range(a, b + 1):
            out[c] = v[k] & mask
    return out


def file_values(name, names, default):
    """The value position of every code point from a derived file."""
    index = {}
    for k, (short, long) in enumerate(names):
        index[short] = k
        index.setdefault(long, k)
    text = open(u.ucd_path(name), encoding="utf-8").read()
    m = re.search(r"# @missing: 0000\.\.10FFFF; (\S+)", text)
    if not m or index[m.group(1)] != index[default]:
        u.fail("the default of %s is not %s" % (name, default))
    val = [index[default]] * (u.MAX_CP + 1)
    for line in u.lines_of(name):
        p = [x.strip() for x in line.split(";")]
        a, b = u.parse_range(p[0])
        if p[1] not in index:
            u.fail("%s holds the value %s that the alias file lacks" % (name, p[1]))
        for c in range(a, b + 1):
            val[c] = index[p[1]]
    return val


def icu_values(prop, names):
    """The ICU value position of every code point, matched by short name."""
    index = {}
    for k, (short, long) in enumerate(names):
        index[short] = k
        index.setdefault(long, k)
    val = [None] * (u.MAX_CP + 1)
    for line in u.oracle_go("icushort", str(prop)):
        a, b, name = line.split()
        if name not in index:
            u.fail("ICU holds the value %s that the alias file lacks" % name)
        for c in range(int(a, 16), int(b, 16) + 1):
            val[c] = index[name]
    if None in val:
        u.fail("ICU gave no value for some code point")
    return val


def main():
    u.check_version()
    names = aliases()
    parts, suite = [], []
    for fname, code, prop, default, source in PROPS:
        pn = names[code]
        shorts = [s for s, _ in pn]
        long_index = {norm(l): k for k, (s, l) in enumerate(pn)}
        if default not in shorts:
            u.fail("no default value %s in %s" % (default, code))
        if source is None:
            # The classes of the break tables map to the alias positions.
            classes = internal_classes(PREFIX[code])
            classes["OTHER"] = 0
            # The classes below are the ones of the package, not of the
            # standard. The alias file of the standard holds no name for
            # them, and the standard never gives them to a code point.
            if code == "SB":
                classes.pop("BAD")
            if code == "WB":
                classes.pop("CJ")
            table = {}
            for cname, num in classes.items():
                if norm(cname) not in long_index:
                    u.fail("the class %s_%s has no alias" % (PREFIX[code], cname))
                table[num] = long_index[norm(cname)]
            top = max(table) + 1
            if sorted(table) != list(range(top)):
                u.fail("the classes of %s do not run from zero" % code)
            tfile, tstart, tval = {"GCB": ("grapheme_data.goose", "GP_START", "GP_VAL"),
                                   "WB": ("segment_data.goose", "WP_START", "WP_VAL"),
                                   "SB": ("segment_data.goose", "SP_START", "SP_VAL")}[code]
            cls = table_values(tfile, tstart, tval, PACK_MASK[code])
            mine = [table[c] for c in cls]
            parts.append(u.array("ENUM_%s_MAP" % code.upper(), [table[k] for k in range(top)],
                                 "The position in the alias file of each class of the break table: %s." % fname))
        else:
            mine = file_values(source, pn, default)
            runs = u.runs_of(mine)
            parts.append(u.array("ENUM_%s_START" % code.upper(), [r[0] for r in runs],
                                 "The first code point of each run of %s." % fname))
            parts.append(u.array("ENUM_%s_VAL" % code.upper(), [r[2] for r in runs],
                                 "The position in the alias file of the value of each run."))
        icu = icu_values(prop, pn)
        for c in range(u.MAX_CP + 1):
            if mine[c] != icu[c]:
                u.fail("%s of %04X: %s here, %s in ICU" % (fname, c, shorts[mine[c]], shorts[icu[c]]))
        text = "".join(shorts)
        off = [0]
        for s in shorts:
            off.append(off[-1] + len(s))
        parts.append(u.string("ENUM_%s_NAMES" % code.upper(), text))
        parts.append(u.array("ENUM_%s_NAME_OFF" % code.upper(), off,
                             "The start of each short name in ENUM_%s_NAMES." % code.upper()))
        parts.append(u.array("ENUM_%s_DEFAULT" % code.upper(), [shorts.index(default)],
                             "The position of the default value, that of a code point outside the range."))
        runs = u.runs_of(icu)
        flat = []
        for a, b, v in runs:
            flat.extend([a, b, v])
        suite.append(u.array("EN_%s" % code.upper(), flat,
                             "Runs of ICU for %s: first, last, position." % fname))
        print("%s: %d values, %d runs of ICU" % (fname, len(shorts), len(runs)))
    u.write_goose(os.path.join(u.ROOT, "enum_data.goose"), "make_enum_data.py", parts)
    u.write_goose(os.path.join(u.HERE, "suite", "enum_cases.goose"), "make_enum_data.py", suite,
                  namespace="suite")


if __name__ == "__main__":
    main()
