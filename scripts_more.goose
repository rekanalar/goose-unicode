// The script extensions, the block and the age of a code point. Each is a
// table searched with a binary search, as the other properties are.
namespace unicode;

import std;

// Writes the scripts of a code point into out, as SCRIPT_ constants in
// ascending order. out is cleared first. A code point that has an
// extension list gives the list. Any other code point gives its one
// script from `script`.
fn script_extensions(out: i64[>..]&, cp: i64) -> i64 {
    out.clear();
    let r = run_at(ES_START[..], ES_END[..], cp);
    if r < 0 {
        out.push(script(cp));
        return OK;
    }
    for k in ES_OFF[r]..ES_OFF[r + 1] { out.push(ES_POOL[k]); }
    return OK;
}

// The name of a script from its SCRIPT_ constant, such as Latin or Han.
// A value that is no script gives Unknown.
fn script_value_name(s: i64) -> const u8[:] {
    if s == SCRIPT_HANB { return "Hanb"; }
    if s == SCRIPT_JPAN { return "Jpan"; }
    if s == SCRIPT_KORE { return "Kore"; }
    if s == SCRIPT_HNTL { return "Hntl"; }
    if s < 0 || s + 1 >= SCRIPT_OFF.len { return SCRIPT_NAMES[0..7]; }
    return SCRIPT_NAMES[SCRIPT_OFF[s]..SCRIPT_OFF[s + 1]];
}

// The index of the block that holds a code point, or -1.
fn block_index(cp: i64) -> i64 {
    return run_at(BK_START[..], BK_END[..], cp);
}

// The name of the block, as the file of the standard spells it. A code
// point in no block gives No_Block.
fn block_name(cp: i64) -> const u8[:] {
    let b = block_index(cp);
    if b < 0 { return "No_Block"; }
    return BK_NAMES[BK_NAME_OFF[b]..BK_NAME_OFF[b + 1]];
}

// The first code point of the block, or -1 for a code point in no block.
fn block_start(cp: i64) -> i64 {
    let b = block_index(cp);
    if b < 0 { return -1; }
    return BK_START[b];
}

// The last code point of the block, or -1 for a code point in no block.
fn block_end(cp: i64) -> i64 {
    let b = block_index(cp);
    if b < 0 { return -1; }
    return BK_END[b];
}

// The major and the minor number of the Unicode release that assigned the
// code point. A code point that no release assigned gives 0 and 0.
fn age(cp: i64) -> i64, i64 {
    let r = run_at(AG_START[..], AG_END[..], cp);
    if r < 0 { return 0, 0; }
    return AG_VAL[r] / 100, AG_VAL[r] % 100;
}
