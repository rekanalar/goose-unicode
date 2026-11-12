#!/usr/bin/env python3
"""Make the data file of the sentence abbreviations.

The script reads the sentence break exceptions of the locales of the
ICU library, release 79.1, and writes the two tries of each locale into
the package. The lists come from icu4c/source/data/brkitr of the
release. The script holds no copy of a list; the lists are inputs, and
the NOTICE note under test/ names them.

The build follows the builder of the filtered sentence iterator of ICU,
the file common/filteredbrk.cpp of the release. That builder reads:

  - An entry with a full stop that is not the last character is a
    partial entry. The prefix up to and including that full stop is a
    partial prefix.
  - The exact entries and the partial prefixes go into the reverse
    trie. That trie holds the strings in reverse order.
  - A partial entry marks every entry that shares its prefix. Those
    entries move to the forward trie. That trie holds the strings in
    the normal order.
  - A prefix that two partial entries share is added once.

Each trie holds one node per code point. The layout packs one node
into one i64: bit 0 holds the flag of a value, bits 1 to 14 hold the
number of children, bits 15 to 35 hold the index of the first child,
bits 36 to 56 hold the code point of the edge that enters the node,
and bits 57 to 58 hold the kind of the value. The kind 0 means no
value, the kind 1 a partial prefix and the kind 2 an exact entry.

Usage: make_sent_abbr_data.py <dir with the locale files>
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

LOCALES = [
    ("en", "EN", "en.txt of ICU 79.1"),
    ("de", "DE", "de.txt of ICU 79.1"),
    ("es", "ES", "es.txt of ICU 79.1"),
    ("fr", "FR", "fr.txt of ICU 79.1"),
    ("it", "IT", "it.txt of ICU 79.1"),
    ("pt", "PT", "pt.txt of ICU 79.1"),
    ("ru", "RU", "ru.txt of ICU 79.1"),
]

# The kinds of a value.
NONE = 0
PARTIAL = 1
MATCH = 2

# The flags of the builder of ICU.
SUPPRESS = 1
ADD_TO_FORWARD = 2


def read_list(path):
    """The sentence break exceptions of one locale file."""
    text = open(path, encoding="utf-8").read()
    start = text.find("SentenceBreak:array{")
    if start < 0:
        u.fail("%s holds no sentence break list" % path)
    end = text.find("\n        }", start)
    if end < 0:
        u.fail("%s holds no end of the sentence break list" % path)
    block = text[start:end]
    out = []
    for raw in re.findall(r'"((?:[^"\\]|\\.)*)"', block):
        out.append(unescape(raw))
    return out


def unescape(text):
    """The string of a resource file."""
    out = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch != "\\":
            out.append(ch)
            i += 1
            continue
        nxt = text[i + 1]
        if nxt == "u":
            out.append(chr(int(text[i + 2:i + 6], 16)))
            i += 6
            continue
        if nxt == "n":
            out.append("\n")
            i += 2
            continue
        if nxt == "t":
            out.append("\t")
            i += 2
            continue
        out.append(nxt)
        i += 2
    return "".join(out)


def split_entries(entries):
    """The entries of a locale, split into the kinds of the builder.

    The first list holds the exact entries and the partial prefixes for
    the reverse trie. The second list holds the entries for the forward
    trie.
    """
    partials = [0] * len(entries)
    for i, word in enumerate(entries):
        dot = word.find(".")
        if dot < 0 or dot + 1 == len(word):
            continue
        same_as = -1
        for j, other in enumerate(entries):
            if i == j:
                continue
            if other[:dot + 1] != word[:dot + 1]:
                continue
            if partials[j] == 0:
                partials[j] = SUPPRESS | ADD_TO_FORWARD
            elif partials[j] & SUPPRESS:
                same_as = j
        if same_as == -1 and partials[i] == 0:
            partials[i] = SUPPRESS | ADD_TO_FORWARD
    reverse = []
    forward = []
    for i, word in enumerate(entries):
        if partials[i] == 0:
            reverse.append((word[::-1], MATCH))
        else:
            forward.append((word, MATCH))
    # The partial prefixes go into the reverse trie. A prefix that two
    # partial entries share is added once.
    seen = set()
    for i, word in enumerate(entries):
        dot = word.find(".")
        if dot < 0 or dot + 1 == len(word):
            continue
        prefix = word[:dot + 1]
        if prefix in seen:
            continue
        seen.add(prefix)
        reverse.append((prefix[::-1], PARTIAL))
    return reverse, forward


def build_trie(items):
    """The trie of the strings. A node holds a kind and its children."""
    root = {}
    for text, kind in items:
        node = root
        for ch in text:
            node = node.setdefault(ch, {})
        if None in node:
            u.fail("the trie holds %s twice" % text)
        node[None] = kind
    return root


def layout(root, base):
    """Walk the trie breadth first and give every node its index.

    The children of a node sit in one contiguous run, sorted by code
    point. The index of the first child is the index in the whole data
    file, so the base of the run of the locale is added here.
    """
    nodes = []
    queue = [()]
    ids = {(): base}
    nodes.append((0, base + 1, -1, 0, NONE))
    next_id = base + 1
    while queue:
        prefix = queue.pop(0)
        my_id = ids[prefix]
        node = root
        for ch in prefix:
            node = node[ch]
        kids = sorted(k for k in node if k is not None)
        kind = node[None] if None in node else NONE
        cp = ord(prefix[-1]) if prefix else 0
        first = next_id if kids else 0
        if kids:
            for k in kids:
                ids[prefix + (k,)] = next_id
                nodes.append((ord(k), 0, -1, 0, NONE))
                next_id += 1
                queue.append(prefix + (k,))
        nodes[my_id - base] = (cp, first, len(kids), 1 if kind else 0, kind)
    return nodes


def encode(nodes):
    """The bytes of the nodes: eight bytes per node, low byte first."""
    out = bytearray()
    for cp, first, count, flag, kind in nodes:
        if count < 0:
            u.fail("a node was never expanded")
        if count >= (1 << 14):
            u.fail("a node holds %d children, above the 14 bit bound" % count)
        if first >= (1 << 21):
            u.fail("a child index is above the 21 bit bound")
        if cp >= (1 << 21):
            u.fail("a code point is above the 21 bit bound")
        val = (kind << 57) | (cp << 36) | (first << 15) | (count << 1) | flag
        out += val.to_bytes(8, "little")
    return bytes(out)


def check_layout(nodes, base):
    """Every run of children must sit inside the run of the locale."""
    end = base + len(nodes)
    for cp, first, count, flag, kind in nodes:
        if count == 0:
            continue
        if first < base + 1 or first + count > end:
            u.fail("the children of a node run from %d to %d, outside the"
                   " run of the locale" % (first, first + count))


def check_trie(root, items):
    for text, kind in items:
        node = root
        for ch in text:
            if ch not in node:
                u.fail("the walk of %s left the trie" % text)
            node = node[ch]
        if None not in node:
            u.fail("%s does not end on a node with a value" % text)
        if node[None] != kind:
            u.fail("%s does not end on a node of its kind" % text)


def main():
    if len(sys.argv) != 2:
        u.fail("usage: make_sent_abbr_data.py <dir with the locale files>")
    src = sys.argv[1]
    rev_bytes = bytearray()
    fwd_bytes = bytearray()
    index = []
    for name, tag, source in LOCALES:
        path = os.path.join(src, name + ".txt")
        entries = read_list(path)
        for word in entries:
            for ch in word:
                if ord(ch) > 0xFFFF:
                    u.fail("%s holds a character outside the basic plane" % path)
        reverse, forward = split_entries(entries)
        rev_root = build_trie(reverse)
        fwd_root = build_trie(forward)
        check_trie(rev_root, reverse)
        check_trie(fwd_root, forward)
        rev_base = len(rev_bytes) // 8
        fwd_base = len(fwd_bytes) // 8
        rev_nodes = layout(rev_root, rev_base)
        fwd_nodes = layout(fwd_root, fwd_base)
        check_layout(rev_nodes, rev_base)
        check_layout(fwd_nodes, fwd_base)
        rev_bytes += encode(rev_nodes)
        fwd_bytes += encode(fwd_nodes)
        index.extend([rev_base, len(rev_nodes), fwd_base, len(fwd_nodes)])
        print("%s: %d entries, %d reverse nodes, %d forward nodes"
              % (name, len(entries), len(rev_nodes), len(fwd_nodes)))
    parts = []
    parts.append(u.bytes_array(
        "SENT_ABBR_REV",
        bytes(rev_bytes),
        "The nodes of the reverse tries of the sentence abbreviations."
        " Eight bytes per node, low byte first: bit 0 the flag of a value,"
        " bits 1 to 14 the child count, bits 15 to 35 the first child,"
        " bits 36 to 56 the edge code point, bits 57 to 58 the kind."))
    parts.append(u.bytes_array(
        "SENT_ABBR_FWD",
        bytes(fwd_bytes),
        "The nodes of the forward tries of the sentence abbreviations."
        " The layout is the layout of the reverse tries."))
    parts.append(u.array(
        "SENT_ABBR_INDEX",
        index,
        "The first node and the count of the nodes of each locale. The"
        " reverse trie comes first, then the forward trie. The locales"
        " are en, de, es, fr, it, pt and ru."))
    u.write_goose(os.path.join(u.ROOT, "sent_abbr_data.goose"),
                  "make_sent_abbr_data.py", parts)


if __name__ == "__main__":
    main()
