#!/usr/bin/env python3
"""The restriction level of the standard, as a reference.

The rules are the ones of section 5.2 of UTS #39, revision 34. The
script reads the Script_Extensions and the Scripts of the Unicode
Character Database 18.0.0. It computes the augmented script set of a
code point, the resolved script set of a text, and the level of a text.

The package follows these rules. The battery compares the levels of the
package with the levels of this script and with the levels of the ICU
library and of the Rust crate.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u
import make_restrict_data as gen

ASCII = 0x10000000
SINGLE = 0x20000000
HIGHLY = 0x30000000
MODERATELY = 0x40000000
MINIMALLY = 0x50000000
UNRESTRICTED = 0x60000000

# The Recommended scripts of Table 5 of UAX #31.
RECOMMENDED = {"Zyyy", "Zinh", "Arab", "Armn", "Beng", "Cyrl", "Deva",
               "Ethi", "Geor", "Grek", "Gujr", "Guru", "Hang", "Hani",
               "Hebr", "Hira", "Kana", "Knda", "Khmr", "Laoo", "Latn",
               "Mlym", "Mymr", "Orya", "Sinh", "Taml", "Telu", "Thaa",
               "Thai", "Tibt"}

_EXT = None
_SCRIPT = None
_ALLOWED = None


def load():
    """The tables of the standard."""
    global _EXT, _SCRIPT, _ALLOWED
    if _EXT is not None:
        return
    ext = {}
    script = {}
    for line in u.lines_of("ScriptExtensions.txt"):
        parts = [x.strip() for x in line.split(";")]
        a, b = u.parse_range(parts[0])
        names = parts[1].split()
        for c in range(a, b + 1):
            ext[c] = names
    for line in u.lines_of("Scripts.txt"):
        parts = [x.strip() for x in line.split(";")]
        a, b = u.parse_range(parts[0])
        for c in range(a, b + 1):
            script[c] = parts[1]
    # The short name of every script. The file of the standard names
    # the scripts in two ways. The Script_Extensions file uses the short
    # names and the Scripts file uses the long names.
    short_of = {}
    for line in u.lines_of("PropertyValueAliases.txt"):
        parts = [x.strip() for x in line.split(";")]
        if parts[0] == "sc":
            short_of[parts[2]] = parts[1]
    for c in list(script):
        script[c] = short_of.get(script[c], script[c])
    _EXT = ext
    _SCRIPT = script
    # The set of the code points of the identifier profile.
    profile = set()
    for a, b in gen.read_profile():
        profile.update(range(a, b + 1))
    _ALLOWED = profile


def scripts():
    """The short name of the script of every code point."""
    load()
    return _SCRIPT


def augmented(cp, hntl=True):
    """The augmented script set of a code point. None for the set of all
    script values. The flag turns the Hntl rule off. The rule of the
    revision 34 of the standard adds Hntl to Latin and to Han."""
    load()
    names = _EXT.get(cp)
    if names is None:
        names = [_SCRIPT.get(cp, "Zyyy")]
    s = set(names)
    if "Zyyy" in s or "Zinh" in s:
        return None
    if "Hani" in s:
        s |= {"Hanb", "Jpan", "Kore"}
        if hntl:
            s.add("Hntl")
    if "Hira" in s:
        s.add("Jpan")
    if "Kana" in s:
        s.add("Jpan")
    if "Hang" in s:
        s.add("Kore")
    if "Bopo" in s:
        s.add("Hanb")
    if "Latn" in s and hntl:
        s.add("Hntl")
    return s


def resolved(cps, hntl=True):
    """The resolved script set of the text. None for the set of all
    script values."""
    cur = None
    for cp in cps:
        a = augmented(cp, hntl)
        if a is None:
            continue
        cur = set(a) if cur is None else (cur & a)
    return cur


def resolved_names(cps):
    """The names of the scripts of the resolved set, without the writing
    system Hntl. The Rust crate holds no Hntl, so this set must give the
    set of the crate."""
    r = resolved(cps)
    if r is None:
        return []
    return sorted(n for n in r if n != "Hntl")


def kinds(a, b, hntl=True):
    """The confusable flags of a pair of texts. The flags are 1 for a
    single script, 2 for a mixed script and 4 for a whole script. The
    caller must check that the skeletons of the two texts are equal.
    The flag of the Hntl rule turns the rule off."""
    set_a = resolved(a, hntl)
    set_b = resolved(b, hntl)
    # The set of every script (None) meets any set that holds a script.
    # It does not meet the empty set of a text that mixes scripts.
    if set_a is None and set_b is None:
        return 1
    if set_a is None:
        set_a = set_b
    elif set_b is None:
        set_b = set_a
    if set_a & set_b:
        return 1
    mask = 2
    if set_a and set_b:
        mask |= 4
    return mask


def level_of(cps, profile=True, hntl=True, icu_step7=False):
    """The level of the text.

    The profile of the identifier profile of the standard is used when
    the flag is true. The Hntl rule of revision 34 is used when the flag
    is true. The flag of the ICU library turns the rule of step 7 off.
    The ICU library asks for a set of no script, no Greek and no
    Cherokee."""
    load()
    if profile:
        for cp in cps:
            if cp not in _ALLOWED:
                return UNRESTRICTED
    if all(cp <= 0x7F for cp in cps):
        return ASCII
    r = resolved(cps, hntl)
    if r is None or r:
        return SINGLE
    # Step 5: the entries that hold Latin drop out.
    no_latin = None
    for cp in cps:
        a = augmented(cp, hntl)
        if a is None:
            continue
        if "Latn" in a:
            continue
        no_latin = set(a) if no_latin is None else (no_latin & a)
    if no_latin is None:
        return MINIMALLY
    # Step 6: a writing system covers the set.
    if no_latin & {"Kore", "Hanb", "Jpan"}:
        return HIGHLY
    # Step 7: a Recommended script that is not Cyrillic or Greek.
    if icu_step7:
        if no_latin and not (no_latin & {"Cyrl", "Grek", "Cher"}):
            return MODERATELY
    else:
        if no_latin & (RECOMMENDED - {"Cyrl", "Grek"}):
            return MODERATELY
    return MINIMALLY


if __name__ == "__main__":
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        cps = [int(x, 16) for x in line.split()]
        print("%08X" % level_of(cps))
