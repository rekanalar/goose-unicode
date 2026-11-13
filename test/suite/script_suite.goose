// Tests for the script extensions, the block and the age.
namespace suite;

import std;
import unicode from "../..";

fn sc_check(ok: bool, name: const u8[:]) -> i64 {
    if !ok { print("FAIL: script ", name, "\n"); return 1; }
    return 0;
}

// Every code point of every run of ICU.
fn sx_runs() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    for r in 0..SX_START.len {
        for cp in SX_START[r]..SX_END[r] + 1 {
            unicode::script_extensions(out, cp);
            var same = out.len == SX_OFF[r + 1] - SX_OFF[r];
            if same {
                for k in 0..out.len { if out[k] != SX_POOL[SX_OFF[r] + k] { same = false; } }
            }
            if !same {
                bad += 1;
                if bad <= 5 { print("FAIL: extensions of ", cp, "\n"); }
            }
        }
    }
    for r in 0..SA_START.len {
        for cp in SA_START[r]..SA_END[r] + 1 {
            let major, minor = unicode::age(cp);
            if major * 100 + minor != SA_VAL[r] {
                bad += 1;
                if bad <= 5 { print("FAIL: age of ", cp, "\n"); }
            }
        }
    }
    return bad;
}

fn sx_samples() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    unicode::script_extensions(out, 0x61);
    bad += sc_check(out.len == 1 && out[0] == unicode::script(0x61), "one script");
    unicode::script_extensions(out, 0x30FC);
    bad += sc_check(out.len == 2, "prolonged sound mark");
    unicode::script_extensions(out, 0xB7);
    bad += sc_check(out.len > 5, "middle dot");
    unicode::script_extensions(out, 0x110000);
    bad += sc_check(out.len == 1 && out[0] == unicode::SCRIPT_UNKNOWN, "outside the range");
    bad += sc_check(unicode::script_value_name(unicode::script(0x61)) == "Latin", "name of a script");
    bad += sc_check(unicode::script_value_name(-1) == "Unknown" && unicode::script_value_name(100000) == "Unknown", "name of no script");
    bad += sc_check(unicode::block_name(0x41) == "Basic Latin", "basic latin");
    bad += sc_check(unicode::block_start(0x41) == 0 && unicode::block_end(0x41) == 0x7F, "basic latin range");
    bad += sc_check(unicode::block_name(0xAC00) == "Hangul Syllables", "hangul");
    bad += sc_check(unicode::block_name(0x378) == "Greek and Coptic" || unicode::block_name(0x378) == "No_Block", "unassigned");
    bad += sc_check(unicode::block_name(0x10FFFF) == "Supplementary Private Use Area-B", "last block");
    bad += sc_check(unicode::block_name(0x110000) == "No_Block" && unicode::block_start(-1) == -1, "no block");
    let a1, a2 = unicode::age(0x41);
    bad += sc_check(a1 == 1 && a2 == 1, "age of A");
    let b1, b2 = unicode::age(0x1F600);
    bad += sc_check(b1 == 6 && b2 == 1, "age of a face");
    let c1, c2 = unicode::age(0x378);
    bad += sc_check(c1 == 0 && c2 == 0, "age of an unassigned");
    let d1, d2 = unicode::age(-1);
    bad += sc_check(d1 == 0 && d2 == 0, "age outside the range");
    return bad;
}

fn run_script() -> i64 {
    var bad = 0;
    if want("script", "sx_samples") { bad += sx_samples(); }
    if want("script", "sx_runs") { bad += sx_runs(); }
    return bad;
}
