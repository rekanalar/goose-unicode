#!/usr/bin/env python3
"""Make the case file of the emoji sequences.

The script reads the two sequence files of the standard. It builds the
texts of the battery. Every entry of the two files is a text. A copy of
each entry holds a change, so the battery holds negative texts too.

The script asks the ICU library for the kinds of every text and the Node
library for the kinds and for the scan. The kinds of the case file come
from the ICU library. The pairs of the scan come from the sequence files
of the standard. The Node library holds the data of the older release,
so it differs on the sequences that the newer release added. The script
prints the count of the differences.

Usage: emoji_seq_battery.py [dir with the two sequence files of 18.0.0]
                             [dir with the two sequence files of 17.0.0]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u
import make_emoji_seq_data as gen

# The code points that the changes of the texts use.
INSERTS = [0xFE0F, 0xFE0E, 0x200D, 0xE0061, 0x1F3FB]
FE0F = 0xFE0F
FE0E = 0xFE0E
ZWJ = 0x200D
TAG = 0xE0061
TONE = 0x1F3FB
RI_A = 0x1F1E6
RI_B = 0x1F1FF

# The texts that mix emoji and text. They hold the cases of the rules of
# the scan: a run of flags, a flag and a lone regional indicator, a lone
# copyright sign and a lone heart.
MIXED = [
    [0x61, 0x1F1EF, 0x1F1F5, 0x1F1FA, 0x1F1F8, 0x62, 0x1F600, 0x78, 0xA9, FE0F],
    [0x61, 0x1F1EF, 0x1F1F5, 0x1F1FA, 0x1F1F8, 0x62, 0x1F600, 0x78, 0xA9],
    [0x1F1EF, 0x1F1F5, 0x1F1FA],
    [0x1F1EF, 0x1F1F5, 0x1F1EF],
    [0x1F1FA, 0x1F1F8, 0x1F1EF, 0x1F1F5, 0x1F1FA, 0x1F1F8],
    [0x1F1EF, 0x1F1F5, 0x1F1FA, 0x1F1F8, 0x1F1FA],
    [0x1F1FA],
    [0x2764],
    [0x2764, FE0F],
    [0xA9],
    [0xA9, FE0F],
    [0x31, FE0F, 0x20E3],
    [0x31, 0x20E3],
    [0x1F3F4, 0xE0067, 0xE0062, 0xE007F],
    [0x1F3F4, 0xE0067, 0xE0062],
    [0x1F468, ZWJ, 0x1F469, ZWJ, 0x1F466],
    [0x1F44D, TONE],
    [0x1F44D],
    [0x1F600],
    [0x20E3],
    [FE0F],
]


def read_all(src, prefix=""):
    """The sequences of the two files of one release."""
    out = []
    for name in gen.FILES:
        path = os.path.join(src, prefix + name)
        if not os.path.exists(path):
            u.fail("the file %s is missing" % path)
        out.extend(gen.read_sequences(path))
    return out


def change(cps, kind):
    """A copy of the code points with one change."""
    out = list(cps)
    if kind == 0 and len(out) > 1:
        del out[len(out) // 2]
    elif kind == 1 and len(out) > 1:
        out[0], out[-1] = out[-1], out[0]
    elif 2 <= kind <= 6:
        out.insert(len(out) // 2, INSERTS[kind - 2])
    elif kind == 7:
        for i, cp in enumerate(out):
            if RI_A <= cp <= RI_B:
                out[i] = RI_A if cp != RI_A else RI_B
                break
        else:
            out.insert(0, RI_A)
    return out


def utf8_len(cp):
    """The number of bytes of the code point in UTF-8."""
    if cp < 0x80:
        return 1
    if cp < 0x800:
        return 2
    if cp < 0x10000:
        return 3
    return 4


def scan_pairs(cps, seqs):
    """The byte pairs of the longest sequence at each position."""
    starts = [0]
    for cp in cps:
        starts.append(starts[-1] + utf8_len(cp))
    out = []
    i = 0
    n = len(cps)
    while i < n:
        best = -1
        for j in range(i + 1, min(i + gen.MAX_CPS, n) + 1):
            if tuple(cps[i:j]) in seqs:
                best = j
        if best > 0:
            out.append(starts[i])
            out.append(starts[best])
            i = best
        else:
            i += 1
    return out


def icu_rows(texts):
    """The mask of the kinds and the flag of the RGI property of ICU."""
    lines = [u.hexline(t) for t in texts]
    out = []
    for line in u.oracle_go("icuemoji", stdin="\n".join(lines) + "\n"):
        parts = line.split()
        if len(parts) != 2:
            u.fail("the ICU oracle gave the row %s" % line)
        out.append((int(parts[0]), int(parts[1])))
    if len(out) != len(texts):
        u.fail("ICU gave %d rows for %d texts" % (len(out), len(texts)))
    return out


def node_rows(texts, mode):
    """The rows of the Node oracle. The scan mode holds the byte pairs."""
    lines = [u.hexline(t) for t in texts]
    out = []
    for line in u.oracle_node("emoji.mjs", mode, stdin="\n".join(lines) + "\n"):
        if mode == "kinds":
            parts = line.split()
            if len(parts) != 2:
                u.fail("the Node oracle gave the row %s" % line)
            out.append((int(parts[0]), int(parts[1])))
        else:
            out.append([int(x) for x in line.split()])
    if len(out) != len(texts):
        u.fail("Node gave %d rows for %d texts" % (len(out), len(texts)))
    return out


def icu_basic_code_points():
    """The code points that the ICU library accepts alone, for the basic
    kind. The dump mode of the oracle prints the runs of the kind."""
    out = set()
    for line in u.oracle_go("icuemoji", "dump", "0"):
        parts = line.split()
        if len(parts) != 3 or parts[2] != "Y":
            continue
        first, last = int(parts[0], 16), int(parts[1], 16)
        out.update(range(first, last + 1))
    return out


def main():
    here = u.HERE
    src = sys.argv[1] if len(sys.argv) > 1 else gen.emoji_dir()
    old = sys.argv[2] if len(sys.argv) > 2 else os.path.normpath(
        os.path.join(here, "..", "..", "..", "tmp", "emoji18"))
    sequences = read_all(src)
    seqs = set(seq for _, seq in sequences)
    old_sequences = set(seq for _, seq in read_all(old, "17.0.0-"))
    added = seqs - old_sequences
    print("the sequences of 18.0.0: %d" % len(sequences))
    print("the sequences that 18.0.0 added: %d" % len(added))
    # The texts of the battery. Every entry is a text. A copy of each
    # entry holds one change. The mixed texts come at the end.
    texts = [list(seq) for _, seq in sequences]
    for i, (_, seq) in enumerate(sequences):
        texts.append(change(list(seq), i % 8))
    texts.extend(MIXED)
    print("the texts of the battery: %d" % len(texts))
    # The kinds of the texts. The ICU library holds the data of 18.0.0.
    kinds = icu_rows(texts)
    node_kinds = node_rows(texts, "kinds")
    # The pairs of the scan. The sequence files of the standard hold the
    # truth. The Node library holds the data of the older release.
    pairs = [scan_pairs(t, seqs) for t in texts]
    node_pairs = node_rows(texts, "scan")
    # The differences of the Node library. They hold the sequences that
    # the newer release added.
    diff_kinds = []
    diff_pairs = []
    for i in range(len(texts)):
        if kinds[i] != node_kinds[i]:
            diff_kinds.append(i)
        if pairs[i] != node_pairs[i]:
            diff_pairs.append(i)
    print("the differences of Node against ICU: %d texts" % len(diff_kinds))
    print("the differences of Node against the files: %d texts" % len(diff_pairs))
    for i in diff_kinds:
        print("  the kinds differ: %s" % u.hexline(texts[i]))
    for i in diff_pairs:
        print("  the pairs differ: %s" % u.hexline(texts[i]))
    # Every difference has to hold a sequence that the newer release
    # added.
    for i in diff_kinds + diff_pairs:
        text = texts[i]
        holds = False
        for j in range(len(text)):
            for k in range(j + 1, min(j + gen.MAX_CPS, len(text)) + 1):
                if tuple(text[j:k]) in added:
                    holds = True
        if not holds:
            u.fail("the text %s differs and holds no new sequence"
                   % u.hexline(text))
    # The single code points of the basic kind have to be the same as the
    # code points that the ICU library accepts alone.
    basic = set(seq[0] for kind, seq in sequences
                if kind == 1 and len(seq) == 1)
    icu_basic = icu_basic_code_points()
    if basic != icu_basic:
        u.fail("the basic code points differ from ICU: %d in the data, %d in ICU"
               % (len(basic), len(icu_basic)))
    print("the basic code points: %d, the same as ICU" % len(basic))
    values = []
    for i, text in enumerate(texts):
        mask, rgi = kinds[i]
        values.append(len(text))
        values.extend(text)
        values.append(mask)
        values.append(rgi)
        values.append(len(pairs[i]) // 2)
        values.extend(pairs[i])
    parts = [u.array(
        "EMOJI_SEQ_CASES_COUNT",
        [len(texts)],
        "The number of the cases of the emoji sequences."),
        u.bytes_array(
        "EMOJI_SEQ_CASES_POOL",
        u.pool_bytes(values),
        "The cases of the emoji sequences. Each case holds the count of"
        " the code points, the code points, the mask of the kinds, the"
        " flag of the RGI property, the count of the pairs and the"
        " pairs. The values take three bytes, low byte first.")]
    u.write_goose(os.path.join(here, "suite", "emoji_seq_cases.goose"),
                  "emoji_seq_battery.py", parts, namespace="suite")
    print("the cases of the emoji sequences: %d texts" % len(texts))


if __name__ == "__main__":
    main()
