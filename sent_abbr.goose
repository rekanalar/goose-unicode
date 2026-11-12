// The abbreviations of the sentence break. Each locale holds two tries.
// The reverse trie holds the strings in reverse order. The forward trie
// holds the strings in the normal order. The data file holds the nodes
// of the tries. The loader reads the bytes at the first use.
//
// The rule of the match follows the filtered sentence iterator of the
// ICU library. The text before a break is the region. One space at the
// end of the region is skipped. The reverse trie is walked backwards
// from the end of the region, and the longest match wins. An exact
// match holds the break. A partial match starts a walk over the
// forward trie from the start of the match. The walk ends at the
// deepest node it reaches, and that node must hold a value.
namespace unicode;

import std;

// The locales of the sentence break. The root locale holds no list.
const SENT_LOCALE_ROOT: i64 = 0;
const SENT_LOCALE_EN: i64 = 1;
const SENT_LOCALE_DE: i64 = 2;
const SENT_LOCALE_ES: i64 = 3;
const SENT_LOCALE_FR: i64 = 4;
const SENT_LOCALE_IT: i64 = 5;
const SENT_LOCALE_PT: i64 = 6;
const SENT_LOCALE_RU: i64 = 7;

// The kinds of the value of a node.
const SENT_KIND_NONE: i64 = 0;
const SENT_KIND_PARTIAL: i64 = 1;
const SENT_KIND_MATCH: i64 = 2;

// The nodes of the tries, decoded from the bytes of the data file at
// the first use. The compiler reads a string of bytes far faster than
// it reads a list of numbers, so the data file holds bytes.
var SENT_REV_DATA: i64[>..] = [];
var SENT_FWD_DATA: i64[>..] = [];
var SENT_READY: bool = false;

// Reads the bytes of the data file into the arrays of the nodes.
fn sent_abbr_load() {
    if SENT_READY { return; }
    SENT_READY = true;
    dict_decode(SENT_ABBR_REV, SENT_REV_DATA);
    dict_decode(SENT_ABBR_FWD, SENT_FWD_DATA);
}

// The kind of the value of a node.
fn sent_abbr_kind(data: const i64[:], node: i64) -> i64 {
    if (data[node] & 1) == 0 { return SENT_KIND_NONE; }
    return (data[node] >> 57) & 3;
}

// The start of the code point before the byte offset pos. -1 when there
// is none or when the bytes before pos are bad.
fn sent_abbr_prev(s: const u8[:], pos: i64) -> i64 {
    let cp, len = decode_back(s, pos);
    if cp < 0 { return -1; }
    return pos - len;
}

// True when the text before the break at the byte offset at ends with
// an abbreviation of the locale. The break is held when it does.
fn sent_abbr_holds(s: const u8[:], at: i64, locale: i64) -> bool {
    // The region ends before the break. One space at the end is skipped.
    var end = at;
    if end > 0 {
        let p = sent_abbr_prev(s, end);
        if p >= 0 {
            let cp, n = decode_at(s, p);
            if cp == 0x20 { end = p; }
        }
    }
    if end <= 0 { return false; }
    // The walk backwards over the reverse trie. The longest match wins.
    let base = (locale - 1) * 4;
    var node = SENT_ABBR_INDEX[base];
    var best_at: i64 = -1;
    var best = SENT_KIND_NONE;
    var pos = end;
    while pos > 0 {
        let p = sent_abbr_prev(s, pos);
        if p < 0 { break; }
        let cp, n = decode_at(s, p);
        let next = trie_child(SENT_REV_DATA, node, cp);
        if next < 0 { break; }
        node = next;
        pos = p;
        let kind = sent_abbr_kind(SENT_REV_DATA, node);
        if kind != SENT_KIND_NONE {
            best_at = p;
            best = kind;
        }
    }
    if best == SENT_KIND_MATCH { return true; }
    if best != SENT_KIND_PARTIAL { return false; }
    // The walk forwards over the forward trie from the start of the
    // match. The deepest node that it reaches must hold a value. A
    // character that no edge holds ends the walk without a value.
    var fnode = SENT_ABBR_INDEX[base + 2];
    var kind = SENT_KIND_NONE;
    var i = best_at;
    while i < s.len {
        let cp, n = decode_at(s, i);
        if cp < 0 { break; }
        let next = trie_child(SENT_FWD_DATA, fnode, cp);
        if next < 0 { kind = SENT_KIND_NONE; break; }
        fnode = next;
        i += n;
        kind = sent_abbr_kind(SENT_FWD_DATA, fnode);
        if ((SENT_FWD_DATA[fnode] >> 1) & 0x3FFF) == 0 { break; }
    }
    return kind == SENT_KIND_MATCH;
}

// The locale of a language tag. The language is the first subtag: two or
// three ASCII letters, then the end of the tag, a hyphen or an
// underscore. The letters match without regard to case. Any other tag
// gives SENT_LOCALE_ROOT.
fn sentence_locale_of(tag: const u8[:]) -> i64 {
    let l = lang_key(tag);
    if l == 0x656E { return SENT_LOCALE_EN; }  // en
    if l == 0x6465 { return SENT_LOCALE_DE; }  // de
    if l == 0x6573 { return SENT_LOCALE_ES; }  // es
    if l == 0x6672 { return SENT_LOCALE_FR; }  // fr
    if l == 0x6974 { return SENT_LOCALE_IT; }  // it
    if l == 0x7074 { return SENT_LOCALE_PT; }  // pt
    if l == 0x7275 { return SENT_LOCALE_RU; }  // ru
    return SENT_LOCALE_ROOT;
}
