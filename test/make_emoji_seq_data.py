#!/usr/bin/env python3
"""Make emoji_seq_data.goose: the trie of the emoji sequences.

The script reads the two sequence files of the standard, emoji-sequences.txt
and emoji-zwj-sequences.txt of the Unicode Character Database 18.0.0. It
builds one prefix trie over the code points of every sequence. A node that
ends a sequence holds the kind of that sequence in its high bits.

The layout packs one node into one i64: bit 0 holds the terminal flag, bits
1 to 14 hold the number of children, bits 15 to 35 hold the index of the
first child, bits 36 to 56 hold the code point of the edge that enters the
node, and bits 57 to 62 hold the kind mask of the sequence that ends at the
node. The children of a node sit in one contiguous run, sorted by code
point. Node 0 is the root. The layout is the layout of the word lists of
the package, so the reader of the package reads this table with the same
code.

The script checks each sequence after the build: it walks the sequence
through the trie and fails when the walk does not end on a node of its kind.
It fails when one node ends two kinds, when a count exceeds its bit bound
and when an index exceeds its bit bound.

Usage: make_emoji_seq_data.py [dir with the two sequence files]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

# The kind of each line of the files. The value is the bit of the kind.
KINDS = {
    "Basic_Emoji": 1,
    "Emoji_Keycap_Sequence": 2,
    "RGI_Emoji_Modifier_Sequence": 4,
    "RGI_Emoji_Flag_Sequence": 8,
    "RGI_Emoji_Tag_Sequence": 16,
    "RGI_Emoji_ZWJ_Sequence": 32,
}

# The names of the two files.
FILES = ["emoji-sequences.txt", "emoji-zwj-sequences.txt"]

# The directory of the two files of the standard.
def emoji_dir():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                          "..", "..", "..", "tmp", "ucd18", "emoji"))

# The longest sequence of the standard holds this many code points.
MAX_CPS = 10


def read_sequences(path):
    """The sequences of one file, as a list of (kind, code points)."""
    out = []
    for line in open(path, encoding="utf-8"):
        line = line.split("#")[0].strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split(";")]
        if len(parts) < 2:
            u.fail("%s holds a line without a kind: %s" % (path, line))
        kind = KINDS.get(parts[1])
        if kind is None:
            u.fail("%s holds an unknown kind: %s" % (path, parts[1]))
        cps = parts[0].split()
        if len(cps) == 1 and ".." in cps[0]:
            first, last = cps[0].split("..")
            for cp in range(int(first, 16), int(last, 16) + 1):
                out.append((kind, (cp,)))
        else:
            out.append((kind, tuple(int(c, 16) for c in cps)))
    return out


def build_trie(sequences):
    """The trie of the sequences. Each node holds its children and its kind."""
    root = {}
    for kind, seq in sequences:
        node = root
        for cp in seq:
            node = node.setdefault(cp, {})
        if node.get(None) is not None:
            u.fail("the data holds the sequence %s twice, with two kinds" % (seq,))
        node[None] = kind
    return root


def layout(root):
    """Walk the trie breadth first and give every node its id.

    The children of a node are laid out in one contiguous run, so a node is
    expanded when its turn comes and its children take the next ids in one
    block. The children are sorted by code point.
    """
    nodes = []  # (cp, first_child, count, terminal, kind)
    ids = {}    # (prefix tuple) -> id; the root has the empty prefix
    queue = [()]  # prefixes to expand, the first is the root
    nodes.append((0, 1, -1, 0, 0))  # count is filled at expansion
    next_id = 1
    while queue:
        prefix = queue.pop(0)
        my_id = ids[prefix] if prefix else 0
        node = root
        for cp in prefix:
            node = node[cp]
        kids = sorted(k for k in node if k is not None)
        kind = node.get(None) or 0
        cp = prefix[-1] if prefix else 0
        first = next_id if kids else 0
        if kids:
            for k in kids:
                ids[prefix + (k,)] = next_id
                nodes.append((k, 0, -1, 0, 0))  # placeholder
                next_id += 1
                queue.append(prefix + (k,))
        nodes[my_id] = (cp, first, len(kids), 1 if kind else 0, kind)
    return nodes, ids


def encode(nodes):
    """The bytes of the nodes: eight bytes per node, low byte first.

    The bytes are a string in the data file. The compiler reads a string of
    bytes far faster than it reads a list of numbers, so the data file holds
    bytes and the package decodes them at the first use.
    """
    out = bytearray()
    if len(nodes) >= (1 << 21):
        u.fail("%d nodes exceed the 21 bit index bound" % len(nodes))
    for cp, first, count, term, kind in nodes:
        if count < 0:
            u.fail("a node was never expanded")
        if count >= (1 << 14):
            u.fail("a node holds %d children, above the 14 bit bound" % count)
        if first >= (1 << 21):
            u.fail("a node holds the index %d, above the 21 bit bound" % first)
        if cp >= (1 << 21):
            u.fail("a node holds the code point %d, above the 21 bit bound" % cp)
        val = (cp << 36) | (first << 15) | (count << 1) | term | (kind << 57)
        out += val.to_bytes(8, "little")
    return bytes(out)


def check_build(sequences, nodes):
    """Walk every sequence through the trie and check the node of its kind."""
    for kind, seq in sequences:
        node = 0
        for cp in seq:
            found = -1
            first = nodes[node][1]
            for kid in range(first, first + nodes[node][2]):
                if nodes[kid][0] == cp:
                    found = kid
                    break
            if found < 0:
                u.fail("the trie holds no edge for the sequence %s" % (seq,))
            node = found
        if nodes[node][3] != 1:
            u.fail("the sequence %s ends at no node" % (seq,))
        if nodes[node][4] != kind:
            u.fail("the sequence %s ends at a node of the kind %d"
                   % (seq, nodes[node][4]))


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else emoji_dir()
    sequences = []
    for name in FILES:
        path = os.path.join(src, name)
        if not os.path.exists(path):
            u.fail("the file %s is missing" % path)
        got = read_sequences(path)
        sequences.extend(got)
        print("%s: %d sequences" % (name, len(got)))
    counts = {}
    for kind, seq in sequences:
        counts[kind] = counts.get(kind, 0) + 1
        if len(seq) > MAX_CPS:
            u.fail("a sequence holds %d code points, above the bound"
                   % len(seq))
    for kind in sorted(counts):
        print("kind %2d: %d sequences" % (kind, counts[kind]))
    print("total: %d sequences" % len(sequences))
    root = build_trie(sequences)
    nodes, _ = layout(root)
    print("nodes: %d" % len(nodes))
    check_build(sequences, nodes)
    data = encode(nodes)
    print("bytes: %d" % len(data))
    parts = [u.bytes_array(
        "EMOJI_SEQ_NODES",
        data,
        "The nodes of the trie of the emoji sequences. Eight bytes per node,"
        " low byte first: bit 0 the flag of a sequence, bits 1 to 14 the"
        " child count, bits 15 to 35 the first child, bits 36 to 56 the edge"
        " code point, bits 57 to 62 the kind mask of the sequence that ends"
        " at the node.")]
    u.write_goose(os.path.join(u.ROOT, "emoji_seq_data.goose"),
                  "make_emoji_seq_data.py", parts)


if __name__ == "__main__":
    main()
