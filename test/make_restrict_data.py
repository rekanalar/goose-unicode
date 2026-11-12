#!/usr/bin/env python3
"""Make restrict_data.goose: the tables of the restriction levels.

The tables are the identifier profile and the whole script table.

The identifier profile is the set of the code points whose
Identifier_Status is Allowed. The file comes from the security data of
the Unicode standard, release 18.0.0. The script packs the ranges of
the Allowed code points into two sorted arrays.

The whole script table holds, for each code point, the set of scripts
that hold a character confusable with it. The file comes from the
security data of the Unicode standard, release 8.0.0. The Unicode
Consortium stopped publishing that file after that release. The script
packs the sets into a sorted array of code points and a pool of script
values.

The script checks the profile against the ICU library. The ICU library
holds the Identifier_Status property of every code point. The script
fails on the first difference.

Usage: make_restrict_data.py [security directory]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u


# The bound of the scripts of one code point. It must agree with the
# constant MAX_WHOLE_SCRIPTS of restrict.goose.
MAX_WHOLE_SCRIPTS = 17


def sec_dir():
    """The directory of the security data of the standard. The command
    line of the script names another directory. The scripts that import
    this module always use the default directory."""
    if __name__ == "__main__" and len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.normpath(os.path.join(u.HERE, "..", "..", "..", "tmp", "sec18"))


def read_profile():
    """The ranges of the code points whose Identifier_Status is Allowed."""
    path = os.path.join(sec_dir(), "IdentifierStatus.txt")
    ranges = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.split("#")[0].strip()
            if not line or ";" not in line:
                continue
            parts = [x.strip() for x in line.split(";")]
            if parts[1] != "Allowed":
                continue
            a, b = u.parse_range(parts[0])
            ranges.append((a, b))
    if len(ranges) < 1000:
        u.fail("only %d ranges of the identifier profile" % len(ranges))
    count = 0
    for a, b in ranges:
        if a > b:
            u.fail("the range %04X..%04X of the identifier profile is empty"
                   % (a, b))
        count += b - a + 1
    if count != 33792:
        u.fail("the identifier profile holds %d code points and not 33792"
               % count)
    for k in range(len(ranges) - 1):
        if ranges[k][1] >= ranges[k + 1][0]:
            u.fail("the ranges of the identifier profile overlap")
    return ranges


def read_whole_script():
    """The script sets of the whole script table."""
    path = os.path.join(sec_dir(), "confusablesWholeScript.txt")
    sets = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.split("#")[0].strip()
            if not line or ";" not in line:
                continue
            parts = [x.strip() for x in line.split(";")]
            if len(parts) < 3:
                continue
            a, b = u.parse_range(parts[0])
            for c in range(a, b + 1):
                # The row names the script of the code point and the
                # script that holds a confusable of it. The set of the
                # code point holds the target scripts.
                sets.setdefault(c, set()).add(parts[2])
    if len(sets) < 100:
        u.fail("only %d code points of the whole script table" % len(sets))
    for c in sorted(sets):
        if not sets[c]:
            u.fail("the code point %04X holds no script" % c)
        if len(sets[c]) > MAX_WHOLE_SCRIPTS:
            u.fail("the code point %04X holds %d scripts and not %d"
                   % (c, len(sets[c]), MAX_WHOLE_SCRIPTS))
    return sets


def read_script_names():
    """The script names of the package, in the order of their values."""
    text = open(os.path.join(u.ROOT, "props_data.goose"), encoding="utf-8").read()
    names = re.search(r'const SCRIPT_NAMES: u8\[\] = "(.*?)";', text, re.S).group(1)
    off = [int(x) for x in re.search(
        r"const SCRIPT_OFF: i64\[\d+\] = \[(.*?)\];", text, re.S).group(1)
        .replace("\n", " ").split(",") if x.strip()]
    return [names[off[i]:off[i + 1]] for i in range(len(off) - 1)]


def read_short_names():
    """The short name of every script, from the file of the standard."""
    short = {}
    path = os.path.join(u.ucd_dir(), "PropertyValueAliases.txt")
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.split("#")[0].strip()
            if not line:
                continue
            parts = [x.strip() for x in line.split(";")]
            if parts[0] == "sc":
                short[parts[1]] = parts[2]
    return short


def main():
    ranges = read_profile()
    sets = read_whole_script()
    names = read_script_names()
    short = read_short_names()

    # ---- the identifier profile ------------------------------------
    # The ICU library holds the Identifier_Status of every code point.
    # The script asks it for the value of every code point of a range
    # and fails on the first code point that differs.
    cps = [c for a, b in ranges for c in range(a, b + 1)]
    want = u.oracle_go("icuidstatus", stdin="\n".join(
        "%04X" % c for c in cps) + "\n")
    if len(want) != len(cps):
        u.fail("the ICU oracle returned %d values for %d code points"
               % (len(want), len(cps)))
    for line in want:
        cp, value = line.split()
        if value != "1":
            u.fail("the ICU library says %s is not allowed" % cp)

    # ---- the whole script table ------------------------------------
    # The constant of the package must agree with the data. The script
    # reads it from the source of the package.
    source = open(os.path.join(u.ROOT, "restrict.goose"),
                  encoding="utf-8").read()
    found = re.search(r"const MAX_WHOLE_SCRIPTS: i64 = (\d+);", source)
    if found is None:
        u.fail("the package holds no constant MAX_WHOLE_SCRIPTS")
    if int(found.group(1)) != MAX_WHOLE_SCRIPTS:
        u.fail("the package holds the bound %s and the data holds %d"
               % (found.group(1), MAX_WHOLE_SCRIPTS))
    # The writing systems of the standard sit above the scripts of the
    # package. A new release of the standard may add a script. The
    # values of the package must follow the table of the scripts.
    hanb = re.search(r"const SCRIPT_HANB: i64 = (\d+);", source)
    count = re.search(r"const SCRIPT_COUNT: i64 = (\d+);", source)
    if hanb is None or count is None:
        u.fail("the package holds no constant SCRIPT_HANB or SCRIPT_COUNT")
    if int(hanb.group(1)) != len(names):
        u.fail("the package holds the writing system %s and the table of "
               "the scripts holds %d scripts" % (hanb.group(1), len(names)))
    if int(count.group(1)) != len(names) + 4:
        u.fail("the package holds the count %s and the table of the scripts "
               "holds %d scripts" % (count.group(1), len(names)))
    # The pool holds the script values of each set. The sets are the
    # sets of the file, in the order of the code points.
    codes = sorted(sets)
    off = [0]
    pool = []
    for c in codes:
        values = []
        for n in sorted(sets[c]):
            long = short.get(n)
            if long not in names:
                u.fail("the package holds no script named %s" % long)
            values.append(names.index(long))
        pool += values
        off.append(len(pool))
    if len(pool) > 4096:
        u.fail("the pool of the whole script table holds %d values" % len(pool))

    data = [
        u.array("IDP_START", [a for a, _ in ranges],
                "The first code point of each range of the identifier profile."),
        u.array("IDP_END", [b for _, b in ranges],
                "The last code point of each range of the identifier profile."),
        u.array("WS_CP", codes,
                "The code point of each set of the whole script table, sorted."),
        u.array("WS_OFF", off,
                "The end of each set of the whole script table in WS_POOL."),
        u.array("WS_POOL", pool,
                "The script values of the sets of the whole script table."),
    ]
    u.write_goose(os.path.join(u.ROOT, "restrict_data.goose"),
                  "make_restrict_data.py", data)
    print("restrict_data.goose: %d ranges, %d code points, %d values"
          % (len(ranges), len(codes), len(pool)))


if __name__ == "__main__":
    main()
