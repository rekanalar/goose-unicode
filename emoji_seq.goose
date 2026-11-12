// The emoji sequences of the standard. The standard defines six kinds of
// sequence in two data files. The data file of the package holds the
// sequences of the standard in one trie over the code points. A node that
// ends a sequence holds the kind of that sequence in its high bits.
//
// Two rules tell the calls apart. The whole text rule takes one sequence.
// The text has to be one sequence of the standard, with no byte before it
// and no byte after it. The scan rule takes the longest sequence at each
// position. The scan moves on by one code point when no sequence starts
// there.
namespace unicode;

import std;

// The kinds of the emoji sequence. The values are the bits of the mask.
const EMOJI_SEQ_BASIC: i64 = 1;
const EMOJI_SEQ_KEYCAP: i64 = 2;
const EMOJI_SEQ_MODIFIER: i64 = 4;
const EMOJI_SEQ_FLAG: i64 = 8;
const EMOJI_SEQ_TAG: i64 = 16;
const EMOJI_SEQ_ZWJ: i64 = 32;

// The mask of all six kinds. It is a query mask and no bit of its own.
const EMOJI_SEQ_RGI: i64 = 63;

// The bounds of the calls. The longest sequence of the standard holds 35
// bytes and 10 code points.
const MAX_EMOJI_SEQ: i64 = 35;
const MAX_EMOJI_SEQ_CPS: i64 = 10;

// The nodes of the trie, decoded from the bytes of the data file at the
// first use. The compiler reads a string of bytes far faster than it
// reads a list of numbers, so the data file holds bytes.
var EMOJI_SEQ_DATA: i64[>..] = [];
var EMOJI_SEQ_READY: bool = false;

// Reads the bytes of the data file into the array of the nodes.
fn emoji_seq_load() {
    if EMOJI_SEQ_READY { return; }
    EMOJI_SEQ_READY = true;
    dict_decode(EMOJI_SEQ_NODES, EMOJI_SEQ_DATA);
}

// The kind of the sequence that ends at the node. 0 when the node ends
// no sequence.
fn emoji_seq_kind(node: i64) -> i64 {
    if (EMOJI_SEQ_DATA[node] & 1) == 0 { return 0; }
    return (EMOJI_SEQ_DATA[node] >> 57) & 63;
}

// The end of the longest sequence that starts at the byte offset at, and
// the kind of that sequence. The end is -1 when no sequence starts there.
// The walk stops at 10 code points, at a bad byte and at the end of the
// text. A bad byte gives no fault.
fn emoji_seq_match(s: const u8[:], at: i64) -> i64, i64 {
    emoji_seq_load();
    var node: i64 = 0;
    var i: i64 = at;
    var depth: i64 = 0;
    var best_end: i64 = -1;
    var best_kind: i64 = 0;
    while i < s.len && depth < MAX_EMOJI_SEQ_CPS {
        let cp, n = decode_at(s, i);
        if cp < 0 { break; }
        let next = trie_child(EMOJI_SEQ_DATA, node, cp);
        if next < 0 { break; }
        node = next;
        i += n;
        depth += 1;
        let kind = emoji_seq_kind(node);
        if kind != 0 {
            best_end = i;
            best_kind = kind;
        }
    }
    return best_end, best_kind;
}

// The mask of the kind of the whole text. The text has to be one sequence
// of the standard. The result is 0 when the text is no sequence. A text
// above 35 bytes gives 0, because no sequence is longer.
fn emoji_sequence_kinds(s: const u8[:]) -> i64 {
    if s.len > MAX_EMOJI_SEQ { return 0; }
    let end, kind = emoji_seq_match(s, 0);
    if end != s.len { return 0; }
    return kind;
}

// True when the whole text holds any of the six kinds.
fn is_rgi_emoji(s: const u8[:]) -> bool {
    return emoji_sequence_kinds(s) != 0;
}

// True when the whole text holds a kind of the mask. An unknown kind
// gives false. The mask of all six kinds holds any sequence.
fn is_emoji_sequence(s: const u8[:], kind: i64) -> bool {
    if kind < 1 || kind > EMOJI_SEQ_RGI { return false; }
    return (emoji_sequence_kinds(s) & kind) != 0;
}

// The code, the offset of the bad byte and the mask of the kind of the
// whole text. The offset is 0 when the call gives no fault. The mask is
// 0 when the text is no sequence.
fn emoji_sequence_kinds_checked(s: const u8[:]) -> i64, i64, i64 {
    if s.len > MAX_INPUT { return ERR_TOO_LONG, 0, 0; }
    var i: i64 = 0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        if cp < 0 { return ERR_BAD_UTF8, i, 0; }
        i += n;
    }
    return OK, 0, emoji_sequence_kinds(s);
}

// The code and the offset of the bad byte. The buffer holds the start and
// the end of each sequence, in bytes. The count of pairs is half the
// length of the buffer. The buffer is empty after a fault. The offset is
// 0 when the call gives no fault.
//
// The scan takes the longest sequence at each position. The pairs do not
// overlap.
fn emoji_sequences(out: i64[>..]&, s: const u8[:]) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, 0; }
    var i: i64 = 0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        if cp < 0 {
            out.clear();
            return ERR_BAD_UTF8, i;
        }
        let end, _ = emoji_seq_match(s, i);
        if end > i {
            out.push(i);
            out.push(end);
            i = end;
        } else {
            i += n;
        }
    }
    return OK, 0;
}
