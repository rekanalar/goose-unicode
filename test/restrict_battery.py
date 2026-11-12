#!/usr/bin/env python3
"""Make the case file of the restriction levels.

The script builds the texts of the battery. It computes the level of
every text by the rules of the standard. It asks the ICU library and the
Rust crate for the level of every text.

The package follows the standard, revision 34. The two libraries follow
an older revision, so they differ on the texts of two classes. The
first class is the texts that mix Latin and Han. The second class is the
texts that hold a script of Table 7 of UAX #31.

The script prints the count of the differences per class. A difference
outside the two classes is a defect. The script writes the case file
with the levels of the standard, so the suite of the package can assert
them.

Usage: restrict_battery.py
"""
import itertools
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u
import restrict_reference as ref
import make_restrict_data as gen

# The ICU library of the oracle.
ICU_LIB = os.path.normpath(os.path.join(u.HERE, "..", "..", "..", "tmp", "icu",
                                        "icu", "usr", "local", "lib"))

# The level numbers of the Rust crate. They run from the strictest to
# the loosest.
RUST = {ref.ASCII: 0, ref.SINGLE: 1, ref.HIGHLY: 2, ref.MODERATELY: 3,
        ref.MINIMALLY: 4, ref.UNRESTRICTED: 5}

# The code points that the texts of the battery hold. Each one sits in
# one script of the two tables of UAX #31.
BY_SCRIPT = {}


def collect():
    """The code points of every script, one per script."""
    global BY_SCRIPT
    if BY_SCRIPT:
        return BY_SCRIPT
    for cp, s in ref.scripts().items():
        if s in ("Zyyy", "Zinh"):
            continue
        BY_SCRIPT.setdefault(s, cp)
    return BY_SCRIPT


def recommended_scripts():
    """The Recommended scripts of Table 5 of UAX #31. The file of the
    standard names the scripts of the table. The script reads the file
    from the scratch directory of the management repository."""
    path = os.path.normpath(os.path.join(u.HERE, "..", "..", "..", "tmp",
                                         "tr31.html"))
    if not os.path.exists(path):
        u.fail("the file %s is missing. Copy the report of UAX #31 from "
               "https://www.unicode.org/reports/tr31/ to that path"
               % path)
    text = open(path, encoding="utf-8").read()
    i = text.find('name="Table_Recommended_Scripts"')
    if i < 0:
        u.fail("the file of UAX #31 holds no Table 5")
    seg = text[i:]
    j = seg.find("Aspirational")
    if j > 0:
        seg = seg[:j]
    return set(re.findall(r"\\p\{script=([A-Za-z]+)\}", seg))


def package_recommended():
    """The scripts that the package treats as Recommended. The script
    reads the list of the source of the package."""
    source = open(os.path.join(u.ROOT, "restrict.goose"),
                  encoding="utf-8").read()
    i = source.index("fn is_recommended(")
    j = source.index("fn ", i + 10)
    body = source[i:j]
    values = set(int(x) for x in re.findall(r"v == (\d+)", body))
    names = gen.read_script_names()
    # The file of the standard maps the short name of a script to its
    # long name. The package holds the long names.
    short_of = {long: short for short, long in gen.read_short_names().items()}
    out = set()
    for v in values:
        long_name = names[v]
        if long_name not in short_of:
            u.fail("the package holds no script named %s" % long_name)
        out.add(short_of[long_name])
    return out


def check_recommended():
    """The Recommended list of the package and the list of the reference
    must give the scripts of Table 5 of UAX #31."""
    want = recommended_scripts()
    if ref.RECOMMENDED != want:
        u.fail("the reference holds %d scripts and Table 5 holds %d"
               % (len(ref.RECOMMENDED), len(want)))
    mine = package_recommended()
    if mine != want:
        u.fail("the package holds %d Recommended scripts and Table 5 "
               "holds %d" % (len(mine), len(want)))


def build_texts():
    """The texts of the battery."""
    collect()
    texts = []
    # The texts of one script, on their own and with a Latin letter.
    for s, cp in sorted(BY_SCRIPT.items()):
        texts.append([cp])
        texts.append([0x61, cp])
        texts.append([cp, 0x61])
        texts.append([0x61, cp, 0x62])
    # The texts that mix Latin and Han. The first class of divergence.
    for cp in (0x4E00, 0x5207, 0x3006, 0x3042, 0x30AB, 0xAC00, 0x3123):
        texts.append([0x61, cp])
        texts.append([cp, 0x61])
        texts.append([cp])
        texts.append([0x61, cp, 0x3042])
        texts.append([0x61, cp, 0xAC00])
        texts.append([cp, 0x3042])
        texts.append([cp, 0x3042, 0xAC00])
    # The texts of the edge cases.
    texts.extend([
        [],
        [0x61],
        [0x31],
        [0x20AC],
        [0xA9],
        [0x3006, 0x5207],
        [0x306D, 0x30AC],
        [0x0640, 0x0710],
        [0x1E900],
        [0x0661, 0x0031],
        [0x05D0, 0x0430],
        [0x0430, 0x0431, 0x0442],
        [0x0061, 0x0301, 0x0062],
        [0x2160],
        [0x00B5],
        [0x0061, 0x0000, 0x0062],
    ])
    # The texts of two scripts, over every pair of the scripts that the
    # standard names.
    shorts = sorted(BY_SCRIPT)
    for i in range(len(shorts)):
        for j in range(i + 1, len(shorts)):
            texts.append([BY_SCRIPT[shorts[i]], BY_SCRIPT[shorts[j]]])
    return texts


def profile_file():
    """The file of the ranges of the identifier profile."""
    path = os.path.normpath(os.path.join(u.HERE, "..", "..", "..", "tmp",
                                         "restrict_profile.txt"))
    if os.path.exists(path):
        return path
    lines = ["%04X..%04X" % (a, b) for a, b in gen.read_profile()]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return path


def icu_levels(texts, profile):
    """The levels of the texts from the ICU library. The flag tells the
    script to use the profile of the standard."""
    lines = [u.hexline(t) for t in texts]
    out = []
    here = os.path.join(u.HERE, "oracle")
    cmd = [os.path.join(here, "oracle")]
    if profile:
        cmd += ["icurestrictprofile", profile_file()]
    else:
        cmd += ["icurestrict"]
    r = subprocess.run(cmd,
                       input="\n".join(lines) + "\n", capture_output=True,
                       text=True,
                       env=dict(os.environ,
                                LD_LIBRARY_PATH=ICU_LIB))
    if r.returncode != 0:
        u.fail("the ICU oracle failed: " + r.stderr[:400])
    for line in r.stdout.splitlines():
        out.append(int(line, 16))
    return out


def rust_levels(texts):
    """The levels and the mixed script test of the texts from the Rust
    crate. The crate holds no Hntl, so its mixed script test differs
    from the package on the texts of the first class."""
    lines = [u.hexline(t) for t in texts]
    out = []
    mixed = []
    scripts = []
    here = os.path.join(u.HERE, "oracle")
    r = subprocess.run([os.path.join(here, "target", "release", "restrict")],
                       input="\n".join(lines) + "\n", capture_output=True,
                       text=True)
    if r.returncode != 0:
        u.fail("the Rust oracle failed: " + r.stderr[:400])
    for line in r.stdout.splitlines():
        parts = line.split()
        out.append(int(parts[0]))
        mixed.append(int(parts[1]))
        names = [x for x in parts[2].split(",") if x] if len(parts) > 2 else []
        scripts.append(",".join(sorted(names)))
    return out, mixed, scripts


def whole_script_sets():
    """The script sets of the whole script table of Unicode 8.0.0. The
    script reads the file of the standard directly, so it does not use
    the table of the package."""
    return gen.read_whole_script()


def build_pairs(texts):
    """The pairs of texts of the battery. Each pair holds two texts that
    read the same, or two texts of one script."""
    pairs = []
    # The pairs of one code point. The Latin and the Cyrillic letters.
    for cp in (0x61, 0x430, 0x3B1, 0x627, 0x915, 0x4E00, 0x3042, 0x30AB):
        pairs.append(([cp], [cp]))
    # The Latin letter and the Cyrillic a.
    pairs.append(([0x61], [0x430]))
    pairs.append(([0x430], [0x61]))
    # The two letters of one script.
    pairs.append(([0x430], [0x431]))
    pairs.append(([0x61], [0x62]))
    # The Latin word and the Cyrillic word.
    pairs.append(([0x73, 0x63, 0x6F, 0x70, 0x65], [0x441, 0x430, 0x43A, 0x43E]))
    # The Latin text and the Latin text with a Cyrillic letter.
    pairs.append(([0x61, 0x62], [0x430, 0x62]))
    # The two texts of one script that are no confusable.
    pairs.append(([0x430], [0x431]))
    pairs.append(([0x61], [0x62]))
    # The Latin text and the Han text.
    pairs.append(([0x61], [0x4E00]))
    # The Han text and the Latin text that read the same. The Hntl
    # rule of the standard makes the two sets meet, so the package
    # gives the single script flag. The ICU library gives the mixed
    # script flag and the whole script flag.
    pairs.append(([0x3007], [0x4F]))
    pairs.append(([0x4F], [0x3007]))
    pairs.append(([0x3005], [0x4F]))
    pairs.append(([0x4F], [0x3005]))
    # The texts of the script Common meet any text that holds a script.
    # They do not meet a text that mixes scripts. The ICU library gives
    # the mixed script flag for such a pair, and the package must too.
    pairs.append(([0x31], [0x6C]))             # 1 and Latin l
    pairs.append(([0x6C], [0x31]))
    pairs.append(([0x30], [0x41E]))            # 0 and Cyrillic O
    pairs.append(([0x31], [0x31]))             # Common and Common
    pairs.append(([0x31], [0x406, 0x115F]))    # 1 and a mixed text
    pairs.append(([0x406, 0x115F], [0x31]))
    pairs.append(([0x6C], [0x406, 0x115F]))    # Latin and a mixed text
    return pairs


def icu_flags(pairs):
    """The confusable flags of the pairs from the ICU library."""
    lines = []
    for a, b in pairs:
        lines.append(u.hexline(a) + "|" + u.hexline(b))
    out = []
    here = os.path.join(u.HERE, "oracle")
    cmd = [os.path.join(here, "oracle"), "icurestrictflag"]
    r = subprocess.run(cmd,
                       input="\n".join(lines) + "\n", capture_output=True,
                       text=True,
                       env=dict(os.environ,
                                LD_LIBRARY_PATH=ICU_LIB))
    if r.returncode != 0:
        u.fail("the ICU oracle failed: " + r.stderr[:400])
    for line in r.stdout.splitlines():
        out.append(int(line))
    return out


def classify(texts, mine, theirs):
    """The classes of the texts where the levels differ. The level of
    the standard and the level of the ICU library differ for two reasons.
    The Hntl rule of the standard and the rule of step 7 of the ICU
    library."""
    han = []
    limited = []
    other = []
    for i, t in enumerate(texts):
        if mine[i] == theirs[i]:
            continue
        no_hntl = ref.level_of(t, profile=False, hntl=False)
        icu_rule = ref.level_of(t, profile=False, hntl=False, icu_step7=True)
        if mine[i] != no_hntl:
            han.append(i)
        elif no_hntl != icu_rule:
            limited.append(i)
        else:
            other.append(i)
    return han, limited, other


def main():
    check_recommended()
    texts = build_texts()
    print("the texts of the battery: %d" % len(texts))
    # The profile of the standard. The ICU library holds it in the mode
    # with the profile, and the crate holds it always.
    mine = [ref.level_of(t, profile=False) for t in texts]
    icu = icu_levels(texts, False)
    rust, rust_mixed, rust_scripts = rust_levels(texts)
    if len(icu) != len(texts) or len(rust) != len(texts):
        u.fail("the oracles returned %d and %d levels for %d texts"
               % (len(icu), len(rust), len(texts)))
    han, limited, other = classify(texts, mine, icu)
    print("the differences against ICU without the profile: %d texts"
          % (len(han) + len(limited) + len(other)))
    print("  the texts of the Hntl rule: %d" % len(han))
    print("  the texts of the rule of step 7: %d" % len(limited))
    print("  the other texts: %d" % len(other))
    for i in other[:40]:
        print("  the level differs: %s mine=%08X icu=%08X"
              % (u.hexline(texts[i]), mine[i], icu[i]))
    # The same texts under the profile of the standard.
    mine_p = [ref.level_of(t, profile=True) for t in texts]
    icu_p = icu_levels(texts, True)
    han_p, limited_p, other_p = classify(texts, mine_p, icu_p)
    print("the differences against ICU with the profile: %d texts"
          % (len(han_p) + len(limited_p) + len(other_p)))
    print("  the texts of the Hntl rule: %d" % len(han_p))
    print("  the texts of the rule of step 7: %d" % len(limited_p))
    print("  the other texts: %d" % len(other_p))
    for i in other_p[:40]:
        print("  the level differs: %s mine=%08X icu=%08X"
              % (u.hexline(texts[i]), mine_p[i], icu_p[i]))
    # The Rust crate against the package. The crate holds the profile.
    rust_diff = []
    for i, t in enumerate(texts):
        if RUST[mine_p[i]] != rust[i]:
            rust_diff.append(i)
    print("the differences of the Rust crate against the package: %d texts"
          % len(rust_diff))
    for i in rust_diff[:20]:
        print("  the level differs: %s mine=%08X rust=%d"
              % (u.hexline(texts[i]), mine_p[i], rust[i]))
    # The level of the Rust crate for the texts of each class. The
    # crate holds the identifier profile always.
    for label, group in (("the Hntl rule", han), ("the rule of step 7", limited)):
        counts = {}
        for i in group:
            counts[rust[i]] = counts.get(rust[i], 0) + 1
        print("the level of the Rust crate for the texts of %s: %s"
              % (label, sorted(counts.items())))
    if other or other_p:
        u.fail("%d texts differ outside the two classes" % (len(other) + len(other_p)))
    # The class of each text. The class is 0 when the package and the
    # ICU library agree. The class is 1 for the texts of the Hntl rule.
    # The class is 2 for the texts of the rule of step 7.
    def classes(han, limited):
        out = []
        for i in range(len(texts)):
            if i in han:
                out.append(1)
            elif i in limited:
                out.append(2)
            else:
                out.append(0)
        return out
    # The mixed script test of the package against the Rust crate. The
    # crate holds no Hntl, so the two differ on the texts that mix
    # Latin and Han.
    mixed_diff = []
    mixed_mine = []
    for i, t in enumerate(texts):
        mine_mixed = 1 if ref.resolved(t) == set() else 0
        mixed_mine.append(mine_mixed)
        if mine_mixed != rust_mixed[i]:
            mixed_diff.append(i)
    print("the differences of the mixed script test against the Rust crate: "
          "%d texts" % len(mixed_diff))
    for i in mixed_diff[:20]:
        print("  the mixed script test differs: %s mine=%d rust=%d"
              % (u.hexline(texts[i]), 1 if ref.resolved(texts[i]) == set() else 0,
                 rust_mixed[i]))
    # The script values of the package, by the long name of the script.
    d = open(os.path.join(u.ROOT, "props_data.goose"), encoding="utf-8").read()
    snames_blob = re.search(r'const SCRIPT_NAMES: u8\[\] = "(.*?)";', d, re.S).group(1)
    soffs = [int(x) for x in re.search(
        r"const SCRIPT_OFF: i64\[\d+\] = \[(.*?)\];", d, re.S).group(1)
        .replace("\n", " ").split(",") if x.strip()]
    names_index = {snames_blob[soffs[i]:soffs[i + 1]]: i
                   for i in range(len(soffs) - 1)}
    # The writing systems of the standard sit above the scripts.
    writing_systems = {"Hanb": 178, "Jpan": 179, "Kore": 180, "Hntl": 181}
    # The resolved script set of the package against the Rust crate. The
    # crate holds no Hntl, so the set of the package without Hntl must
    # give the set of the crate.
    script_diff = []
    for i, t in enumerate(texts):
        theirs = sorted(x for x in rust_scripts[i].split(",") if x)
        # The crate writes a set of every script as the writing systems
        # and the script Common. The package writes it as the set of
        # every script value. The two mean the same.
        theirs_all = "Zyyy" in theirs or "Zinh" in theirs
        mine_all = ref.resolved(t) is None
        if mine_all != theirs_all:
            script_diff.append(i)
            continue
        if mine_all:
            continue
        if sorted(ref.resolved_names(t)) != theirs:
            script_diff.append(i)
    print("the differences of the resolved script set against the Rust crate: "
          "%d texts" % len(script_diff))
    for i in script_diff[:20]:
        print("  the resolved set differs: %s mine=%s rust=%s"
              % (u.hexline(texts[i]), ref.resolved_names(texts[i]),
                 rust_scripts[i]))
    if script_diff:
        u.fail("%d texts have another resolved script set" % len(script_diff))
    # The short name of every script, from the file of the standard.
    name_value = {}
    for line in u.lines_of("PropertyValueAliases.txt"):
        fields = [x.strip() for x in line.split(";")]
        if fields[0] == "sc":
            name_value[fields[1]] = fields[2]
    # The writing systems of the standard sit above the scripts of the
    # package. They have no entry in that file.
    name_value["Hanb"] = "Hanb"
    name_value["Jpan"] = "Jpan"
    name_value["Kore"] = "Kore"
    name_value["Hntl"] = "Hntl"
    # The whole script twins of every text of the battery. The script
    # reads the table of Unicode 8.0.0 itself, so the answer does not
    # come from the package.
    ws_sets = whole_script_sets()
    twins = []
    for t in texts:
        found = None
        for cp in t:
            target = ws_sets.get(cp, set())
            if not target:
                found = set()
                break
            found = set(target) if found is None else (found & target)
        if not found:
            twins.append([])
            continue
        # The script of the text drops out of the set. A text that
        # mixes scripts has no whole script confusable. A text of the
        # script Common sits in every script, so it has none either.
        scripts = ref.resolved(t)
        if scripts is None or not scripts:
            twins.append([])
            continue
        found = found - scripts
        twins.append(sorted(found))
    print("the texts of the battery with a whole script twin: %d"
          % sum(1 for x in twins if x))
    # The texts with a code point that the file of Unicode 8.0.0 does
    # not name. The package gives no twin for such a text.
    unnamed = 0
    for t in texts:
        for cp in t:
            if cp not in ws_sets:
                unnamed += 1
                break
    print("the texts with a code point that the file does not name: %d"
          % unnamed)
    # The twins as the script values of the package.
    twin_values = []
    for x in twins:
        values = []
        for n in x:
            long_name = name_value.get(n)
            if long_name is None or long_name not in names_index:
                u.fail("the package holds no script named %s" % n)
            values.append(names_index[long_name])
        # The package sorts the twins by the script value.
        twin_values.append(sorted(values))
    # The confusable flags of the pairs. The package and the ICU
    # library must agree on every pair.
    pairs = build_pairs(texts)
    flags = icu_flags(pairs)
    if len(flags) != len(pairs):
        u.fail("the ICU oracle returned %d flags for %d pairs"
               % (len(flags), len(pairs)))
    print("the pairs of the battery: %d" % len(pairs))
    # The class of each pair. The class is 0 for the pairs that agree
    # and 1 for the pairs of Latin and Han. The Hntl rule of the
    # standard makes the two sets of such a pair meet.
    pair_class = []
    for a, b in pairs:
        if flags[len(pair_class)] == 0:
            # The skeletons of the two texts differ, so the pair is no
            # confusable. The two libraries agree.
            pair_class.append(0)
            continue
        pair_mine = ref.kinds(a, b, hntl=True)
        pair_theirs = ref.kinds(a, b, hntl=False)
        if pair_mine != pair_theirs:
            pair_class.append(1)
        else:
            pair_class.append(0)
    print("  the pairs of Latin and Han: %d"
          % sum(1 for x in pair_class if x == 1))
    # The resolved set of the crate, as the script values of the
    # package. The value -1 stands for the set of every script.
    set_pool = []
    for i in range(len(texts)):
        names = [x for x in rust_scripts[i].split(",") if x]
        if "Zyyy" in names or "Zinh" in names:
            set_pool.append([-1])
            continue
        values = []
        for n in names:
            if n in writing_systems:
                values.append(writing_systems[n])
                continue
            long_name = name_value.get(n)
            if long_name is None or long_name not in names_index:
                u.fail("the package holds no script named %s" % n)
            values.append(names_index[long_name])
        # The package sorts the scripts by the script value.
        set_pool.append(sorted(values))
    # The case file of the suite.
    parts = [
        u.array("RL_TXT_OFF", list(itertools.accumulate(
            [len(t) for t in texts], initial=0)),
            "The end of each text in RL_TXT_POOL."),
        u.array("RL_TXT_POOL", [c for t in texts for c in t],
                "The code points of each text."),
        u.array("RL_LEVEL", mine,
                "The level of each text without the profile, by the rules of the standard."),
        u.array("RL_LEVEL_P", mine_p,
                "The level of each text under the profile, by the rules of the standard."),
        u.array("RL_ICU", icu,
                "The level of each text without the profile, by the ICU library 79.1."),
        u.array("RL_ICU_P", icu_p,
                "The level of each text under the profile, by the ICU library 79.1."),
        u.array("RL_CLASS", classes(set(han), set(limited)),
                "The class of each text without the profile: 0 for the texts that agree, 1 for the texts of the Hntl rule, 2 for the texts of the rule of step 7."),
        u.array("RL_CLASS_P", classes(set(han_p), set(limited_p)),
                "The class of each text under the profile: 0 for the texts that agree, 1 for the texts of the Hntl rule, 2 for the texts of the rule of step 7."),
        u.array("RL_PAIR_OFF", list(itertools.accumulate(
            [len(a) + len(b) for a, b in pairs], initial=0)),
            "The end of each pair in RL_PAIR_POOL."),
        u.array("RL_PAIR_POOL", [c for a, b in pairs for c in a + b],
                "The code points of the two texts of each pair."),
        u.array("RL_PAIR_SPLIT", [len(a) for a, b in pairs],
                "The number of code points of the first text of each pair."),
        u.array("RL_FLAGS", flags,
                "The confusable flags of each pair, by the ICU library 79.1."),
        u.array("RL_PAIR_CLASS", pair_class,
                "The class of each pair: 0 for the pairs that agree with the ICU library and 1 for the pairs of Latin and Han."),
        u.array("RL_MIXED", rust_mixed,
                "The mixed script test of each text, by the Rust crate 0.1.3: 1 for a text that mixes scripts and 0 for a text of one script."),
        u.array("RL_MIXED_MINE", mixed_mine,
                "The mixed script test of each text, by the rules of the standard: 1 for a text that mixes scripts and 0 for a text of one script."),
        u.array("RL_MIXED_CLASS", [0 if mixed_mine[i] == rust_mixed[i] else 1
                                   for i in range(len(texts))],
                "The class of each text for the mixed script test: 0 for the texts that agree with the Rust crate and 1 for the texts of the Hntl rule."),
        u.array("RL_SET_OFF", list(itertools.accumulate(
            [len(set_pool[i]) for i in range(len(texts))], initial=0)),
            "The end of each resolved set in RL_SET_POOL."),
        u.array("RL_SET_POOL", [v for i in range(len(texts))
                                for v in set_pool[i]],
                "The script values of the resolved set of each text, by the Rust crate 0.1.3. The value -1 stands for the set of every script."),
        u.array("RL_TWIN_OFF", list(itertools.accumulate(
            [len(x) for x in twin_values], initial=0)),
            "The end of each twin set in RL_TWIN_POOL."),
        u.array("RL_TWIN_POOL", [v for x in twin_values for v in x],
                "The script values of the whole script twins of each text, by the table of Unicode 8.0.0."),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "restrict_cases.goose"),
                  "restrict_battery.py", parts, "suite")


if __name__ == "__main__":
    main()
