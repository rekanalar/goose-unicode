// The dictionary break engines of the word segmentation. A rule segment
// that holds a letter of Thai, Lao, Burmese, Khmer, Han, Hiragana or
// Katakana goes to the engine of that script. The engine puts a boundary
// at the end of each word of the dictionary. Thai, Lao, Burmese and Khmer
// share one greedy walk with a look ahead of three words. The walk of the
// Han, Hiragana and Katakana text picks the split of least cost.
namespace unicode;

import std;

// The bounds of the plain walk, with the names of the reference
// library. The root combine threshold keeps a short word from joining
// the word before it, and the prefix combine threshold keeps a word
// that shares a long prefix with a word from joining it.
const PLAIN_MIN_WORD_SPAN: i64 = 4;
const THAI_MIN_WORD_SPAN: i64 = 5;
const PLAIN_ROOT_COMBINE_THRESHOLD: i64 = 3;
const PLAIN_PREFIX_COMBINE_THRESHOLD: i64 = 3;

// One candidate list of the plain walk: the words that start at one index.
struct PossibleWord {
    offset: i64,   // the index of the candidates, -1 when the list is empty
    mark: i64,     // the candidate that the walk prefers
    current: i64,  // the candidate under test
    m: DictMatch,
}

// The trie of the script of a code point that starts a plain run, or -1.
fn dict_plain_of(cp: i64) -> i64 {
    if line_break_class(cp) != LB_SA { return -1; }
    let sc = script(cp);
    if sc == SCRIPT_THAI { return DICT_THAI; }
    if sc == SCRIPT_LAO { return DICT_LAO; }
    if sc == SCRIPT_MYANMAR { return DICT_BURMESE; }
    if sc == SCRIPT_KHMER { return DICT_KHMER; }
    return -1;
}

// True when the code point has the script of Han, Hiragana or Katakana.
fn dict_cj_own(cp: i64) -> bool {
    let sc = script(cp);
    return sc == SCRIPT_HAN || sc == SCRIPT_HIRAGANA || sc == SCRIPT_KATAKANA;
}

// True when the code point belongs to the Han, Hiragana or Katakana set of
// the engine: the three scripts and four marks of the Katakana text.
fn dict_cj_set(cp: i64) -> bool {
    if dict_cj_own(cp) { return true; }
    return cp == 0x30FC || cp == 0xFF70 || cp == 0xFF9E || cp == 0xFF9F;
}

// The end word set of a plain engine: the letters that can end a word.
fn dict_end_ok(t: i64, cp: i64) -> bool {
    if t == DICT_THAI { return cp != 0x0E31 && !(cp >= 0x0E40 && cp <= 0x0E44); }
    if t == DICT_LAO { return !(cp >= 0x0EC0 && cp <= 0x0EC4); }
    if t == DICT_KHMER { return cp != 0x17D2; }
    return true;
}

// The begin word set of a plain engine: the letters that can start a word.
fn dict_begin_ok(t: i64, cp: i64) -> bool {
    if t == DICT_THAI { return (cp >= 0x0E01 && cp <= 0x0E2E) || (cp >= 0x0E40 && cp <= 0x0E44); }
    if t == DICT_LAO {
        return (cp >= 0x0E81 && cp <= 0x0EAE) || (cp >= 0x0EDC && cp <= 0x0EDD)
            || (cp >= 0x0EC0 && cp <= 0x0EC4);
    }
    if t == DICT_BURMESE { return cp >= 0x1000 && cp <= 0x102A; }
    return cp >= 0x1780 && cp <= 0x17B3;
}

// True when the code point is a mark of the set of the plain trie t.
fn dict_mark_ok(t: i64, cp: i64) -> bool {
    let c = category(cp);
    return c >= CAT_MN && c <= CAT_ME;
}

// Fills the candidates of the list w at index at.
fn pw_candidates(w: PossibleWord&, t: i64, c: const i64[:], at: i64, re: i64) -> i64 {
    if at != w.offset {
        w.offset = at;
        dict_matches(t, c, at, re, 0, w.m);
    }
    w.current = w.m.count - 1;
    w.mark = w.current;
    return w.m.count;
}

fn pw_new() -> PossibleWord {
    return PossibleWord { offset: -1, mark: 0, current: 0,
        m: DictMatch { count: 0, prefix: 0, len: [0; 21], cost: [0; 21] } };
}

// Finds the breaks of one run of a plain script. c holds the code points
// of the run, off the byte offset of each one and of the end. The walk
// pushes the byte offset after each word. It drops a break at the end of
// the run.
fn dict_plain(t: i64, c: const i64[:], off: const i64[:], breaks: i64[>..]&) {
    let re = c.len;
    // The shortest run that can hold two words. The reference library
    // names this the minimum word span: four code points for the Lao,
    // Khmer and Burmese engines and five for the Thai engine.
    var need: i64 = PLAIN_MIN_WORD_SPAN;
    if t == DICT_THAI { need = THAI_MIN_WORD_SPAN; }
    if re < need { return; }
    var words: PossibleWord[3] = [pw_new(), pw_new(), pw_new()];
    var wf: i64 = 0;
    var pos: i64 = 0;
    while pos < re {
        let current = pos;
        var cu_len: i64 = 0;
        let slot = wf % 3;
        let c0 = pw_candidates(words[slot], t, c, pos, re);
        if c0 > 0 { pos = current + words[slot].m.len[c0 - 1]; }
        if c0 == 1 {
            cu_len = words[slot].m.len[words[slot].mark];
            pos = words[slot].offset + cu_len;
            wf += 1;
        } else if c0 > 1 {
            var best = false;
            if pos >= re { best = true; }
            var more = true;
            while !best && more {
                let s1 = (wf + 1) % 3;
                let start1 = pos;
                let c1 = pw_candidates(words[s1], t, c, start1, re);
                if c1 > 0 { pos = start1 + words[s1].m.len[c1 - 1]; }
                if c1 > 0 {
                    words[slot].mark = words[slot].current;
                    if pos >= re {
                        best = true;
                    } else {
                        var inner = true;
                        while inner {
                            let s2 = (wf + 2) % 3;
                            let start2 = pos;
                            let c2 = pw_candidates(words[s2], t, c, start2, re);
                            if c2 > 0 { pos = start2 + words[s2].m.len[c2 - 1]; }
                            if c2 != 0 {
                                words[slot].mark = words[slot].current;
                                best = true;
                                inner = false;
                            } else if words[s1].current > 0 {
                                words[s1].current -= 1;
                                pos = words[s1].offset + words[s1].m.len[words[s1].current];
                            } else {
                                inner = false;
                            }
                        }
                    }
                }
                if !best {
                    if words[slot].current > 0 {
                        words[slot].current -= 1;
                        pos = words[slot].offset + words[slot].m.len[words[slot].current];
                    } else {
                        more = false;
                    }
                }
            }
            cu_len = words[slot].m.len[words[slot].mark];
            pos = words[slot].offset + cu_len;
            wf += 1;
        }
        // Look at the next word. A short word and a remainder that is no
        // word join, or the walk scans to the next plausible boundary.
        if pos < re && cu_len < PLAIN_ROOT_COMBINE_THRESHOLD {
            let sl = wf % 3;
            let st = pos;
            let cc = pw_candidates(words[sl], t, c, st, re);
            if cc > 0 { pos = st + words[sl].m.len[cc - 1]; }
            if cc <= 0 && (cu_len == 0 || words[sl].m.prefix < PLAIN_PREFIX_COMBINE_THRESHOLD) {
                var remaining = re - (current + cu_len);
                var chars: i64 = 0;
                var go = true;
                while go {
                    let pc = c[pos];
                    pos += 1;
                    chars += 1;
                    remaining -= 1;
                    if remaining <= 0 {
                        go = false;
                    } else if dict_end_ok(t, pc) && dict_begin_ok(t, c[pos]) {
                        let s1 = (wf + 1) % 3;
                        let st1 = pos;
                        let n1 = pw_candidates(words[s1], t, c, st1, re);
                        pos = current + cu_len + chars;
                        if n1 > 0 { go = false; }
                    }
                }
                if cu_len <= 0 { wf += 1; }
                cu_len += chars;
            } else {
                pos = current + cu_len;
            }
        }
        // Never stop before a mark.
        while pos < re && dict_mark_ok(t, c[pos]) {
            pos += 1;
            cu_len += 1;
        }
        // Thai only: the elision sign and the repeat sign join the word
        // when no dictionary word follows.
        if t == DICT_THAI && pos < re && cu_len > 0 {
            let sl = wf % 3;
            let st = pos;
            let sc = pw_candidates(words[sl], t, c, st, re);
            let uc = c[pos];
            if sc <= 0 && (uc == 0x0E2F || uc == 0x0E46) {
                var u2 = uc;
                if u2 == 0x0E2F {
                    let prev = c[pos - 1];
                    if prev != 0x0E2F && prev != 0x0E46 {
                        pos += 1;
                        cu_len += 1;
                        u2 = 0;
                        if pos < c.len { u2 = c[pos]; }
                    }
                }
                if u2 == 0x0E46 {
                    if c[pos - 1] != 0x0E46 {
                        pos += 1;
                        cu_len += 1;
                    }
                }
            }
            pos = current + cu_len;
        }
        if cu_len > 0 { breaks.push(off[current + cu_len]); }
    }
    // No break at the end of the run.
    if breaks.len > 0 && breaks[breaks.len - 1] >= off[re] {
        breaks.pop();
    }
}
