// The rules of the bidirectional algorithm (UAX #9) that act on one
// isolating run sequence: the weak types (W1 to W7), the paired brackets
// (N0), the neutral types (N1, N2) and the implicit levels (I1, I2).
// The pass in bidi.goose finds the sequences and calls bd_run on each.
namespace unicode;

import std;

// The rules W1 to W7, N0 to N2 and I1, I2 on one isolating run sequence.
// sq holds the positions of the sequence, and t holds the class of each.
fn bd_run(t: i64[>..]&, pairat: i64[>..]&, bs_id: i64[>..]&, bs_pos: i64[>..]&,
          sq: const i64[:], cls: const i64[:], brk: const i64[:],
          lev: i64[>..]&, sl: i64, sos: i64, eos: i64) {
    let len = sq.len;
    // W1: a mark takes the class of the code point before it.
    var prev = sos;
    for i in 0..len {
        if t[i] == BIDI_NSM { t[i] = prev; }
        let oc = cls[sq[i]];
        if bd_is_isolate_init(oc) || oc == BIDI_PDI {
            prev = BIDI_ON;
        } else {
            prev = t[i];
        }
    }
    // W2: a European number after an Arabic letter is an Arabic number.
    var last = sos;
    for i in 0..len {
        let c = t[i];
        if c == BIDI_L || c == BIDI_R || c == BIDI_AL {
            last = c;
        } else if c == BIDI_EN && last == BIDI_AL {
            t[i] = BIDI_AN;
        }
    }
    // W3: an Arabic letter is a right to left letter.
    for i in 0..len {
        if t[i] == BIDI_AL { t[i] = BIDI_R; }
    }
    // W4: one separator between two numbers of one kind joins them.
    if len >= 3 {
        for i in 1..(len - 1) {
            let c = t[i];
            if c == BIDI_ES && t[i - 1] == BIDI_EN && t[i + 1] == BIDI_EN {
                t[i] = BIDI_EN;
            } else if c == BIDI_CS {
                let a = t[i - 1];
                if (a == BIDI_EN || a == BIDI_AN) && t[i + 1] == a {
                    t[i] = a;
                }
            }
        }
    }
    // W5: a run of terminators next to a European number joins it.
    var i5 = 0;
    while i5 < len {
        if t[i5] == BIDI_ET {
            var e = i5;
            while e < len && t[e] == BIDI_ET { e += 1; }
            if (i5 > 0 && t[i5 - 1] == BIDI_EN) || (e < len && t[e] == BIDI_EN) {
                for q in i5..e { t[q] = BIDI_EN; }
            }
            i5 = e;
        } else {
            i5 += 1;
        }
    }
    // W6: the separators and terminators that stay are neutral.
    for i in 0..len {
        let c = t[i];
        if c == BIDI_ES || c == BIDI_ET || c == BIDI_CS { t[i] = BIDI_ON; }
    }
    // W7: a European number after a left to right letter is one.
    last = sos;
    for i in 0..len {
        let c = t[i];
        if c == BIDI_L || c == BIDI_R {
            last = c;
        } else if c == BIDI_EN && last == BIDI_L {
            t[i] = BIDI_L;
        }
    }

    let ed = bd_level_dir(sl);

    // N0: the paired brackets. The pairs come from one pass with a stack
    // of at most 63 open brackets. pairat holds the close of each open.
    bd_fill(pairat, len, -1);
    bd_fill(bs_id, BD_BRACKET_SIZE, 0);
    bd_fill(bs_pos, BD_BRACKET_SIZE, 0);
    var sp = 0;
    for i in 0..len {
        let b = brk[sq[i]];
        if b == 0 || t[i] != BIDI_ON { continue; }
        if (b & 1) == 1 {
            if sp == BD_BRACKET_STACK { break; }
            bs_id[sp] = b >> 1;
            bs_pos[sp] = i;
            sp += 1;
        } else {
            let id = b >> 1;
            var k = sp;
            while k > 0 {
                k -= 1;
                if bs_id[k] == id {
                    pairat[bs_pos[k]] = i;
                    sp = k;
                    break;
                }
            }
        }
    }
    for i in 0..len {
        let ci = pairat[i];
        if ci < 0 { continue; }
        var found_e = false;
        var found_o = false;
        var q = i + 1;
        while q < ci {
            let d = bd_strong_dir(t[q]);
            if d == ed {
                found_e = true;
                break;
            }
            if d >= 0 { found_o = true; }
            q += 1;
        }
        var nd = -1;
        if found_e {
            nd = ed;
        } else if found_o {
            var ctx = sos;
            var b = i;
            while b > 0 {
                b -= 1;
                let d = bd_strong_dir(t[b]);
                if d >= 0 {
                    ctx = d;
                    break;
                }
            }
            if ctx != ed { nd = ctx; } else { nd = ed; }
        }
        if nd >= 0 {
            t[i] = nd;
            t[ci] = nd;
            // A mark after a bracket takes the type of the bracket.
            bd_mark_after(t, cls, sq, i, len, nd);
            bd_mark_after(t, cls, sq, ci, len, nd);
        }
    }

    // N1 and N2: a run of neutrals takes the direction of both ends when
    // they agree, and the direction of the level when they do not.
    var i1 = 0;
    while i1 < len {
        if bd_strong_dir(t[i1]) < 0 {
            var e = i1;
            while e < len && bd_strong_dir(t[e]) < 0 { e += 1; }
            var left = sos;
            if i1 > 0 { left = bd_strong_dir(t[i1 - 1]); }
            var right = eos;
            if e < len { right = bd_strong_dir(t[e]); }
            var nd = ed;
            if left == right { nd = left; }
            for q in i1..e { t[q] = nd; }
            i1 = e;
        } else {
            i1 += 1;
        }
    }

    // I1 and I2: the implicit levels.
    for i in 0..len {
        let c = t[i];
        var l = sl;
        if sl % 2 == 0 {
            if c == BIDI_R {
                l = sl + 1;
            } else if c == BIDI_AN || c == BIDI_EN {
                l = sl + 2;
            }
        } else if c == BIDI_L || c == BIDI_EN || c == BIDI_AN {
            l = sl + 1;
        }
        lev[sq[i]] = l;
    }
}
