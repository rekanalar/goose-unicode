// The break engine of the Han, Hiragana and Katakana text. The engine
// normalizes the run with NFKC, because the dictionary holds the text in
// the composed and width folded shapes. A dynamic program then picks the
// split of least cost: each word of the dictionary carries the frequency
// it holds in the list, a code point with no word carries the top cost,
// and a run of Katakana letters carries a length based cost. The split
// of least cost decides the boundaries.
namespace unicode;

import std;

// The cost of a split that no path reaches.
const CJ_BIG: i64 = 0xFFFFFFFF;

// The cost of one code point that no dictionary word starts.
const CJ_MAX_SNLP: i64 = 255;

// The length cost of a run of Katakana, by the length frequencies of the
// Katakana phrases in the dictionary. A run above 8 takes the top cost.
const CJ_KATA_COST: i64[9] = [8192, 984, 408, 240, 204, 252, 300, 372, 480];

const CJ_KATA_GROUP_MAX: i64 = 20;

fn cj_kata_cost(length: i64) -> i64 {
    if length > 8 { return 8192; }
    return CJ_KATA_COST[length];
}

// True for the letters that the Katakana run heuristic counts: the small
// and extended Katakana block, without the middle dot, and the halfwidth
// Katakana block.
fn cj_is_katakana(cp: i64) -> bool {
    if cp >= 0x30A1 && cp <= 0x30FE && cp != 0x30FB { return true; }
    return cp >= 0xFF66 && cp <= 0xFF9F;
}

// True when a fragment can end before this code point, the composition
// boundary of NFKC: the code point is a starter, it does not combine with
// a starter before it, and when it decomposes, its decomposition starts
// with such a starter.
fn cj_boundary_before(cp: i64) -> bool {
    if combining_class(cp) != 0 { return false; }
    let q = quick_check(FORM_NFKC, cp);
    if q == 2 { return false; }
    if q == 1 {
        var d: i64[>..] = [];
        decompose_cp(d, cp, true);
        let f = d[0];
        if combining_class(f) != 0 || quick_check(FORM_NFKC, f) == 2 { return false; }
    }
    return true;
}

// Finds the breaks of one run of Han, Hiragana and Katakana text. c holds
// the code points of the run, off the byte offset of each one and of the
// end. The walk pushes the byte offset after each word. It drops a break
// at the start and at the end of the run, because the rule stage holds
// those two.
fn dict_cj(c: const i64[:], off: const i64[:], breaks: i64[>..]&) {
    let n = c.len;
    if n <= 0 { return; }
    // True when the run is already in NFKC, so the map is one to one.
    var identity = true;
    var last_cc: i64 = 0;
    for k in 0..n {
        let cc = combining_class(c[k]);
        if quick_check(FORM_NFKC, c[k]) != 0 || (cc != 0 && last_cc > cc) {
            identity = false;
            break;
        }
        last_cc = cc;
    }
    var nrm: i64[>..] = [];
    var map: i64[>..] = [];
    if identity {
        for k in 0..n { nrm.push(c[k]); map.push(k); }
    } else {
        // Normalize one fragment at a time. A fragment is one starter
        // with the marks and the MAYBE code points that follow it. Every
        // code point of the result maps back to the start of its
        // fragment, so a boundary inside an expansion folds back to one
        // position of the input.
        var frag: i64[>..] = [];
        var work: i64[>..] = [];
        var i: i64 = 0;
        while i < n {
            let fs = i;
            frag.clear();
            var go = true;
            while go {
                frag.push(c[i]);
                i += 1;
                if i >= n {
                    go = false;
                } else if cj_boundary_before(c[i]) {
                    go = false;
                }
            }
            let rc = normalize_cps(work, frag[..], FORM_NFKC);
            if rc != OK { return; }
            for k in 0..work.len {
                nrm.push(work[k]);
                map.push(fs);
            }
        }
    }
    map.push(n);

    let numCp = nrm.len;
    // best[i] is the least cost of a split of the first i code points.
    // prev[i] is the start of the last word of that split.
    var best: i64[>..] = [];
    var prev: i64[>..] = [];
    best.push(0);
    prev.push(-1);
    for k in 1..numCp + 1 {
        best.push(CJ_BIG);
        prev.push(-1);
    }
    var m = DictMatch { count: 0, prefix: 0, len: [0; 21], cost: [0; 21] };
    var is_prev_kata = false;
    var i: i64 = 0;
    while i < numCp {
        if best[i] == CJ_BIG {
            // No split reaches this code point. The katakana run state
            // stays as it is, as in the reference engine.
            i += 1;
            continue;
        }
        dict_matches(DICT_CJ, nrm[..], i, numCp, DICT_MAX_CAND, m);
        var count = m.count;
        // A code point that starts no dictionary word is a word of one
        // code point with the top cost.
        if count == 0 || m.len[0] != 1 {
            m.len[count] = 1;
            m.cost[count] = CJ_MAX_SNLP;
            count += 1;
        }
        for j in 0..count {
            let newSnlp = best[i] + m.cost[j];
            let e = m.len[j] + i;
            if newSnlp < best[e] {
                best[e] = newSnlp;
                prev[e] = i;
            }
        }
        // A run of Katakana is a word candidate with a length cost.
        let is_kata = cj_is_katakana(nrm[i]);
        if !is_prev_kata && is_kata {
            var run: i64 = 1;
            var j = i + 1;
            while j < numCp && run < CJ_KATA_GROUP_MAX && cj_is_katakana(nrm[j]) {
                j += 1;
                run += 1;
            }
            if run < CJ_KATA_GROUP_MAX {
                let newSnlp = best[i] + cj_kata_cost(run);
                if newSnlp < best[i + run] {
                    best[i + run] = newSnlp;
                    prev[i + run] = i;
                }
            }
        }
        is_prev_kata = is_kata;
        i += 1;
    }
    // Walk the back pointers and collect the word ends, in reverse order.
    var tb: i64[>..] = [];
    if best[numCp] == CJ_BIG {
        tb.push(numCp);
    } else {
        var i = numCp;
        while i > 0 {
            tb.push(i);
            i = prev[i];
        }
    }
    // Convert to byte offsets, drop the run start, and fold the two ends
    // of a normalization expansion into one boundary.
    var prevPos: i64 = -1;
    var k = tb.len - 1;
    while k >= 0 {
        let upos = map[tb[k]];
        if upos > prevPos && upos != 0 {
            breaks.push(off[upos]);
        }
        prevPos = upos;
        k -= 1;
    }
    if breaks.len > 0 && breaks[breaks.len - 1] >= off[n] { breaks.pop(); }
}
