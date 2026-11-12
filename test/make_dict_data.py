#!/usr/bin/env python3
"""Make the trie data files of the dictionary word segmentation.

The script reads the five word lists of the ICU library, release 79.1,
and writes one trie data file per script into the package. The lists
come from icu4c/source/data/brkitr/dictionaries of the release. The
script holds no copy of a list; the lists are inputs, and the NOTICE
note under test/ names them.

Each list becomes a prefix trie over code points. The layout packs one
node into one i64: bit 0 holds the terminal flag, bits 1 to 14 hold the
number of children, bits 15 to 35 hold the index of the first child,
and bits 36 to 56 hold the code point of the edge that enters the
node. The children of a node sit in one contiguous run, sorted by code
point. Node 0 is the root.

The script checks each trie after the build: it walks every word of
the list through the trie and fails when a walk does not end on a
terminal node, and it fails when a count or an index exceeds the bit
bound of its field.

Usage: make_dict_data.py <dir with the five list files>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

LISTS = [
    ("thaidict", False, "dict_data_thai.goose", "thaidict.txt of ICU 79.1"),
    ("laodict", False, "dict_data_lao.goose", "laodict.txt of ICU 79.1"),
    ("burmesedict", False, "dict_data_burmese.goose", "burmesedict.txt of ICU 79.1"),
    ("khmerdict", False, "dict_data_khmer.goose", "khmerdict.txt of ICU 79.1"),
    ("cjdict", True, "dict_data_cj.goose", "cjdict.txt of ICU 79.1"),
]


def read_list(path, weighted):
    words = {}
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line:
            continue
        if weighted:
            word, freq = line.split("\t")
            f = int(freq)
            if word in words and words[word] != f:
                u.fail("%s holds two frequencies for %s" % (path, word))
            words[word] = f
        else:
            words[line] = None
    return words


def build_trie(words, weighted):
    root = {}
    for word, freq in words.items():
        node = root
        for ch in word:
            node = node.setdefault(ch, {})
        if None in node:
            u.fail("the list holds the word %s twice" % word)
        node[None] = freq if weighted else True
    return root


def layout(root, weighted):
    """Walk the trie breadth first and give every node its id.

    The children of a node are laid out in one contiguous run, so a
    node is expanded when its turn comes and its children take the
    next ids in one block.
    """
    nodes = []  # (cp, first_child, count, terminal, freq)
    ids = {}    # (prefix tuple) -> id; the root has the empty prefix
    queue = [()]  # prefixes to expand, the first is the root
    # The root is node 0. Its children start at node 1.
    nodes.append((0, 1, -1, 0, 0))  # count is filled at expansion
    next_id = 1
    while queue:
        prefix = queue.pop(0)
        my_id = ids[prefix] if prefix else 0
        node = root
        for ch in prefix:
            node = node[ch]
        kids = sorted(k for k in node if k is not None)
        terminal = 1 if None in node else 0
        freq = node[None] if None in node and weighted else 0
        cp = ord(prefix[-1]) if prefix else 0
        first = next_id if kids else 0
        if kids:
            for k in kids:
                ids[prefix + (k,)] = next_id
                nodes.append((ord(k), 0, -1, 0, 0))  # placeholder
                next_id += 1
                queue.append(prefix + (k,))
        nodes[my_id] = (cp, first, len(kids), terminal, freq)
    return nodes


def encode(nodes):
    """The bytes of the nodes: eight bytes per node, low byte first.

    The bytes are a string in the data file. The compiler reads a string
    of bytes far faster than it reads a list of numbers, so the data
    files hold bytes and the package decodes them at the first use.
    """
    out = bytearray()
    max_id = len(nodes) - 1
    if max_id >= (1 << 21):
        u.fail("%d nodes exceed the 21 bit index bound" % (max_id + 1))
    for cp, first, count, term, freq in nodes:
        if count < 0:
            u.fail("a node was never expanded")
        if count >= (1 << 14):
            u.fail("a node holds %d children, above the 14 bit bound" % count)
        val = (cp << 36) | (first << 15) | (count << 1) | term
        out += val.to_bytes(8, "little")
    return bytes(out)


def check_trie(root, words):
    for word in words:
        node = root
        for ch in word:
            if ch not in node:
                u.fail("the walk of %s left the trie" % word)
            node = node[ch]
        if None not in node:
            u.fail("%s does not end on a terminal node" % word)


def main():
    u.check_version()
    if len(sys.argv) != 2:
        u.fail("usage: make_dict_data.py <dir with the five list files>")
    src = sys.argv[1]
    for name, weighted, out_name, source in LISTS:
        words = read_list(os.path.join(src, name + ".txt"), weighted)
        root = build_trie(words, weighted)
        check_trie(root, words)
        nodes = layout(root, weighted)
        vals = encode(nodes)
        parts = []
        comment = ("Trie nodes of %s. Eight bytes per node, low byte first:"
                   " bit 0 the word end, bits 1 to 14 the child count, bits 15"
                   " to 35 the first child, bits 36 to 56 the edge code point."
                   % source)
        parts.append(u.bytes_array("DICT_" + name.upper() + "_NODE", vals, comment))
        if weighted:
            costs = bytearray()
            for _, _, _, _, freq in nodes:
                costs += bytes([freq & 0xFF])
            parts.append(u.bytes_array("DICT_CJ_COST", bytes(costs),
                                 "Cost of the word that ends at each node, 0 when none."))
        print("%s: %d words, %d nodes" % (name, len(words), len(nodes)))
        u.write_goose(os.path.join(u.ROOT, out_name), "make_dict_data.py", parts)


if __name__ == "__main__":
    main()
