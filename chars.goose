// The numeric type, the decomposition, the joining and the paired bracket
// properties of a code point. Each property is a table of runs of equal
// values, searched with a binary search, as the other properties are.
namespace unicode;

import std;

// ---- the numeric type -------------------------------------------------
const NUMTYPE_NONE: i64 = 0;
const NUMTYPE_DECIMAL: i64 = 1;
const NUMTYPE_DIGIT: i64 = 2;
const NUMTYPE_NUMERIC: i64 = 3;

// The packed value of a code point: the type in bits 0 and 1, the decimal
// value plus one in bits 2 to 5 and the digit value plus one in bits 6 to 9.
fn numeric_packed(cp: i64) -> i64 {
    let r = run_at(NT_START[..], NT_END[..], cp);
    if r < 0 { return 0; }
    return NT_VAL[r];
}

// The numeric type of a code point, as a NUMTYPE_ constant.
fn numeric_type(cp: i64) -> i64 {
    return numeric_packed(cp) & 3;
}

fn numeric_type_name(cp: i64) -> const u8[:] {
    let t = numeric_type(cp);
    if t == NUMTYPE_DECIMAL { return "Decimal"; }
    if t == NUMTYPE_DIGIT { return "Digit"; }
    if t == NUMTYPE_NUMERIC { return "Numeric"; }
    return "None";
}

// The decimal digit value of a code point of the type decimal, else -1.
fn decimal_value(cp: i64) -> i64 {
    return ((numeric_packed(cp) >> 2) & 15) - 1;
}

// The digit value of a code point of the type decimal or digit, else -1.
fn digit_value(cp: i64) -> i64 {
    return ((numeric_packed(cp) >> 6) & 15) - 1;
}

// ---- the decomposition ------------------------------------------------
const DECOMP_NONE: i64 = 0;
const DECOMP_CANONICAL: i64 = 1;
const DECOMP_COMPAT: i64 = 2;
const DECOMP_CIRCLE: i64 = 3;
const DECOMP_FINAL: i64 = 4;
const DECOMP_FONT: i64 = 5;
const DECOMP_FRACTION: i64 = 6;
const DECOMP_INITIAL: i64 = 7;
const DECOMP_ISOLATED: i64 = 8;
const DECOMP_MEDIAL: i64 = 9;
const DECOMP_NARROW: i64 = 10;
const DECOMP_NOBREAK: i64 = 11;
const DECOMP_SMALL: i64 = 12;
const DECOMP_SQUARE: i64 = 13;
const DECOMP_SUB: i64 = 14;
const DECOMP_SUPER: i64 = 15;
const DECOMP_VERTICAL: i64 = 16;
const DECOMP_WIDE: i64 = 17;

const DECOMP_NAMES: u8[] = "NoneCanonicalCompatCircleFinalFontFractionInitialIsolatedMedialNarrowNobreakSmallSquareSubSuperVerticalWide";
const DECOMP_NAME_OFF: i64[19] = [0, 4, 13, 19, 25, 30, 34, 42, 49, 57, 63, 69, 76, 81, 87, 90, 95, 103, 107];

// The decomposition type of a code point, as a DECOMP_ constant.
fn decomposition_type(cp: i64) -> i64 {
    let r = run_at(DT_START[..], DT_END[..], cp);
    if r < 0 { return DECOMP_NONE; }
    return DT_VAL[r];
}

fn decomposition_type_name(cp: i64) -> const u8[:] {
    let t = decomposition_type(cp);
    return DECOMP_NAMES[DECOMP_NAME_OFF[t]..DECOMP_NAME_OFF[t + 1]];
}

// Writes the one level mapping of a code point into out, as code points.
// out is cleared first. A code point with no mapping, and a value outside
// the range, give an empty result. A Hangul syllable gives its jamo, the
// way Python does: two code points, or three with a final consonant.
fn decomposition(out: i64[>..]&, cp: i64) -> i64 {
    out.clear();
    if cp >= 0xAC00 && cp <= 0xD7A3 {
        let s = cp - 0xAC00;
        out.push(0x1100 + s / 588);
        out.push(0x1161 + (s % 588) / 28);
        if s % 28 != 0 { out.push(0x11A7 + s % 28); }
        return OK;
    }
    let i = find_exact(DM_CP[..], cp);
    if i < 0 { return OK; }
    for k in DM_OFF[i]..DM_OFF[i + 1] { out.push(DM_POOL[k]); }
    return OK;
}

// ---- the joining properties -------------------------------------------
const JOINING_NONE: i64 = 0;          // Non_Joining
const JOINING_CAUSING: i64 = 1;       // Join_Causing
const JOINING_DUAL: i64 = 2;          // Dual_Joining
const JOINING_LEFT: i64 = 3;          // Left_Joining
const JOINING_RIGHT: i64 = 4;         // Right_Joining
const JOINING_TRANSPARENT: i64 = 5;   // Transparent

const JOINING_NAMES: u8[] = "Non_JoiningJoin_CausingDual_JoiningLeft_JoiningRight_JoiningTransparent";
const JOINING_NAME_OFF: i64[7] = [0, 11, 23, 35, 47, 60, 71];

// The joining type of a code point, as a JOINING_ constant.
fn joining_type(cp: i64) -> i64 {
    let r = run_at(JT_START[..], JT_END[..], cp);
    if r < 0 { return JOINING_NONE; }
    return JT_VAL[r];
}

fn joining_type_name(cp: i64) -> const u8[:] {
    let t = joining_type(cp);
    return JOINING_NAMES[JOINING_NAME_OFF[t]..JOINING_NAME_OFF[t + 1]];
}

// The joining group of a code point as a number. 0 is No_Joining_Group.
// The groups follow the order of their names, so compare the name.
fn joining_group(cp: i64) -> i64 {
    let r = run_at(JG_START[..], JG_END[..], cp);
    if r < 0 { return 0; }
    return JG_VAL[r];
}

fn joining_group_name(cp: i64) -> const u8[:] {
    let g = joining_group(cp);
    return JG_NAMES[JG_NAME_OFF[g]..JG_NAME_OFF[g + 1]];
}

// ---- the paired brackets ----------------------------------------------
const BRACKET_NONE: i64 = 0;
const BRACKET_OPEN: i64 = 1;
const BRACKET_CLOSE: i64 = 2;

// The Bidi_Paired_Bracket_Type of a code point, as a BRACKET_ constant.
fn bidi_bracket_type(cp: i64) -> i64 {
    let i = find_exact(BP_CP[..], cp);
    if i < 0 { return BRACKET_NONE; }
    return BP_TYPE[i];
}

// The Bidi_Paired_Bracket of a code point: the partner of a bracket, and
// the code point itself for a code point that is no bracket.
fn bidi_paired_bracket(cp: i64) -> i64 {
    let i = find_exact(BP_CP[..], cp);
    if i < 0 { return cp; }
    return BP_PAIR[i];
}
