#!/usr/bin/env bash
# The mutation probes of the package. Each probe flips one rule of the
# package in a copy of it. The test program must fail after the flip.
# The probes prove that the test program checks the rule.
#
# A probe runs only the group of suites that covers the file it changes.
# The variable UNICODE_SUITES holds the name of the group. A probe that
# the group does not catch runs the whole test program, so a wrong group
# cannot hide a missing test.
#
# Usage: [MUTATE_ONLY=<part of a probe name>] bash test/mutate.sh [goose binary]
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
pkg="$(dirname "$here")"
goose_bin="${1:-goose}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fails=0
probes=0

# The groups of suites that cover a file. The group names the suites
# that hold the calls of the file. A probe of that file runs only them.
# A file may name more than one group. The probe stops at the first
# group that catches the change.
groups_for() {
    case "$1" in
        utf8.goose) echo "utf8" ;;
        norm.goose) echo "norm" ;;
        casing.goose) echo "case" ;;
        property.goose) echo "property norm" ;;
        grapheme.goose) echo "grapheme" ;;
        props.goose) echo "props" ;;
        case_full.goose) echo "case_full" ;;
        test/suite/props_suite.goose) echo "props" ;;
        restrict.goose) echo "restrict" ;;
        bidi.goose) echo "bidi_line bidi" ;;
        bidi_line.goose) echo "bidi_line" ;;
        lstm.goose) echo "lstm" ;;
        word.goose) echo "lstm segment dict" ;;
        linebreak.goose) echo "lstm line_dict" ;;
        *) echo "" ;;
    esac
}

# run_probe <name> <file> <old text> <new text>
run_probe() {
    local name="$1" file="$2" old="$3" new="$4"
    # MUTATE_ONLY holds a part of a probe name. Other probes do not run.
    if [ -n "${MUTATE_ONLY:-}" ] && [[ "$name" != *"$MUTATE_ONLY"* ]]; then return; fi
    local copy="$work/$name"
    local groups
    groups="$(groups_for "$file")"
    probes=$((probes + 1))
    rm -rf "$copy"
    cp -r "$pkg" "$copy"
    if ! grep -qF -- "$old" "$copy/$file"; then
        echo "FAIL: the probe $name did not find its rule"
        fails=$((fails + 1))
        return
    fi
    python3 - "$copy/$file" "$old" "$new" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8").read()
if old not in text:
    sys.exit(1)
open(path, "w", encoding="utf-8").write(text.replace(old, new, 1))
PY
    local code group
    for group in $groups; do
        (cd "$copy" && UNICODE_SUITES="$group" "$goose_bin" run test/run.goose >/dev/null 2>&1)
        code=$?
        if [ "$code" -ne 0 ]; then
            echo "ok: the probe $name made the test program fail"
            return
        fi
    done
    # No group of the file caught the change. The whole test program
    # runs, so a wrong group cannot hide a missing test.
    (cd "$copy" && "$goose_bin" run test/run.goose >/dev/null 2>&1)
    code=$?
    if [ "$code" -eq 0 ]; then
        echo "FAIL: the probe $name left the test program green"
        fails=$((fails + 1))
        return
    fi
    echo "NEEDS THE FULL SUITE $name: the groups $groups do not catch it"
    fails=$((fails + 1))
}

# The decoder. A bad byte must give the fault.
run_probe decode_surrogate utf8.goose \
    'if b0 == 0xED { hi = 0x9F; }' \
    'if b0 == 0xED { hi = 0xBF; }'

run_probe decode_overlong utf8.goose \
    'if b0 == 0xF0 { lo = 0x90; }' \
    'if b0 == 0xF0 { lo = 0x80; }'

run_probe decode_limit utf8.goose \
    'if b0 < 0xC2 || b0 > 0xF4 { return -1, 1; }' \
    'if b0 < 0xC0 || b0 > 0xF4 { return -1, 1; }'

run_probe encode_surrogate utf8.goose \
    'return cp >= 0 && cp <= 0x10FFFF && !utf16_is_surrogate(cp);' \
    'return cp >= 0 && cp <= 0x10FFFF;'

# The input bound. A long input must give the fault.
run_probe input_bound utf8.goose \
    'if s.len > MAX_INPUT { return false; }' \
    'if s.len > MAX_INPUT * 2 { return false; }'

# The normalization. The order of the combining marks must hold.
run_probe reorder norm.goose \
    'while j >= a && combining_class(v[j]) > cx {' \
    'while j >= a && combining_class(v[j]) >= cx {'

# The composition exclusion. The table holds the pairs that compose.
run_probe composition norm.goose \
    'if starter >= 0 && (last < cc || w - 1 == starter) {' \
    'if starter >= 0 && (last <= cc || w - 1 == starter) {'

# The blocked pair rule. A mark between two code points stops the pair.
run_probe blocked norm.goose \
    'if starter >= 0 && (last < cc || w - 1 == starter) {' \
    'if starter >= 0 {'

# The Hangul composition.
run_probe hangul norm.goose \
    'if a >= L_BASE && a < L_BASE + L_COUNT && b >= V_BASE && b < V_BASE + V_COUNT {' \
    'if a >= L_BASE && a < L_BASE + L_COUNT && b >= V_BASE && b < V_BASE + V_COUNT - 1 {'

# The case mapping. The table gives the result.
run_probe case_upper casing.goose \
    'let i = find_exact(UP_CP[..], cp);' \
    'let i = find_exact(UP_CP[..], cp + 1);'

run_probe case_lower casing.goose \
    'let i = find_exact(LO_CP[..], cp);' \
    'let i = find_exact(LO_CP[..], cp + 1);'

# The categories. The table gives the value.
run_probe category property.goose \
    'return CAT_VAL[last_at_or_below(CAT_START[..], cp)];' \
    'return CAT_VAL[last_at_or_below(CAT_START[..], cp) + 1];'

# The combining class.
run_probe combining_class property.goose \
    'if i >= 0 && cp <= CCC_END[i] { return CCC_VAL[i]; }' \
    'if i >= 0 && cp <= CCC_END[i] + 1 { return CCC_VAL[i]; }'

# The cluster split. The rules of the standard.
run_probe cluster_regional grapheme.goose \
    'if prev == GB_REGIONAL_INDICATOR && cur == GB_REGIONAL_INDICATOR && st.ri % 2 == 1 { return true; }' \
    'if prev == GB_REGIONAL_INDICATOR && cur == GB_REGIONAL_INDICATOR { return true; }'

run_probe cluster_extend grapheme.goose \
    'if cur == GB_EXTEND || cur == GB_ZWJ || cur == GB_SPACINGMARK { return true; }' \
    'if cur == GB_ZWJ || cur == GB_SPACINGMARK { return true; }'

run_probe cluster_control grapheme.goose \
    'if cur == GB_CR || cur == GB_LF || cur == GB_CONTROL { return false; }' \
    'if cur == GB_CR || cur == GB_LF { return false; }'

run_probe cluster_hangul grapheme.goose \
    'if prev == GB_L && (cur == GB_L || cur == GB_V || cur == GB_LV || cur == GB_LVT) { return true; }' \
    'if prev == GB_L && (cur == GB_V || cur == GB_LV || cur == GB_LVT) { return true; }'

# The script lookup. The table gives the value.
run_probe script props.goose \
    'return SCRIPT_INDEX[i];' \
    'return SCRIPT_INDEX[i + 1];'

# The script run. The next run starts after the last code point.
run_probe script_run test/suite/props_suite.goose \
    'if k + 1 < unicode::SCRIPT_START.len { last = unicode::SCRIPT_START[k + 1] - 1; }' \
    'if k + 1 < unicode::SCRIPT_START.len { last = unicode::SCRIPT_START[k + 1] - 2; }'

# The width. The table gives the value.
run_probe width props.goose \
    'let i = run_at(WIDTH_START[..], WIDTH_END[..], cp);
    if i >= 0 { return WIDTH_VAL[i]; }' \
    'let i = run_at(WIDTH_START[..], WIDTH_END[..], cp);
    if i >= 0 { return WIDTH_VAL[i] + 1; }'

# The width default. A code point outside the range is neutral.
run_probe width_default props.goose \
    'if cp < 0 || cp > 0x10FFFF { return WIDTH_NEUTRAL; }' \
    'if cp < 0 || cp > 0x10FFFF { return WIDTH_NARROW; }'

# The class. The table gives the value.
run_probe bidi_class props.goose \
    'let i = run_at(BIDI_START[..], BIDI_END[..], cp);
    if i >= 0 { return BIDI_VAL[i]; }' \
    'let i = run_at(BIDI_START[..], BIDI_END[..], cp);
    if i >= 0 { return BIDI_VAL[i] + 1; }'

# The mirror partner. The partner is the code point plus the number.
run_probe mirror props.goose \
    'let i = run_at(MIRROR_START[..], MIRROR_END[..], cp);
    if i >= 0 { return cp + MIRROR_DELTA[i]; }' \
    'let i = run_at(MIRROR_START[..], MIRROR_END[..], cp);
    if i >= 0 { return cp + MIRROR_DELTA[i] + 1; }'

# The numeric value. The table gives the denominator.
run_probe numeric props.goose \
    'let i = run_at(NUM_START[..], NUM_END[..], cp);
    if i >= 0 { return NUM_NUM[i], NUM_DEN[i]; }' \
    'let i = run_at(NUM_START[..], NUM_END[..], cp);
    if i >= 0 { return NUM_NUM[i], NUM_DEN[i] + 1; }'

# The name. The table holds the code point of each name.
run_probe name props.goose \
    'let i = find_exact(NAME_START[..], cp);' \
    'let i = find_exact(NAME_START[..], cp + 1);'

# The full mapping. The table gives the result.
run_probe full_case case_full.goose \
    'let k = find_exact(cps, cp);' \
    'let k = find_exact(cps, cp + 1);'

# The final sigma. A sigma with no cased letter after it is final.
run_probe final_sigma case_full.goose \
    'return !cased_follows(s, i + n);' \
    'return cased_follows(s, i + n);'

# The input bound of the full case calls.
run_probe full_input_bound case_full.goose \
    'if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }' \
    'if s.len > MAX_INPUT * 2 { return ERR_TOO_LONG, -1; }'

# The output bound of the full case calls. A tight bound makes the
# normal calls fault, so the test program fails.
run_probe full_output_bound case_full.goose \
    'if out.len > MAX_OUTPUT {' \
    'if out.len > 8 {'

# The restriction level. The level of a text of one script is Single
# Script.
run_probe restrict_single restrict.goose \
    'if !set_is_empty(all) { return RESTRICT_SINGLE; }' \
    'if false { return RESTRICT_SINGLE; }'

# The restriction level. The level of a text of ASCII is ASCII-Only.
run_probe restrict_ascii restrict.goose \
    'if ascii_only { return RESTRICT_ASCII; }' \
    'if false { return RESTRICT_ASCII; }'

# The restriction level. A code point outside the profile gives
# Unrestricted.
run_probe restrict_profile restrict.goose \
    'if !profile_allows(cps[k], profile) { return RESTRICT_UNRESTRICTED; }' \
    'if false { return RESTRICT_UNRESTRICTED; }'

# The restriction level. The Hntl rule of the standard adds the writing
# system Hntl to Latin.
run_probe restrict_hntl restrict.goose \
    'if set_has(s, SCRIPT_LATIN) {
        set_add(s, SCRIPT_HNTL);
    }' \
    'if false {
        set_add(s, SCRIPT_HNTL);
    }'

# The restriction level. The rule of step 7 asks for a Recommended
# script. The table holds the scripts of Table 5 of UAX #31. The probe
# takes Devanagari out of the table, so a text of Latin and Devanagari
# no longer gives the level Moderately Restrictive.
run_probe restrict_recommended restrict.goose \
    'if v == 11 { return true; }            // Devanagari' \
    'if v == 33 { return true; }            // Devanagari'

# The restriction level. The rule of step 6 asks for a writing system.
run_probe restrict_writing_system restrict.goose \
    'if set_has(no_latin, SCRIPT_KORE) || set_has(no_latin, SCRIPT_HANB)
        || set_has(no_latin, SCRIPT_JPAN) {' \
    'if false {'

# The whole script test. A code point with no row of the table has no
# confusable.
run_probe restrict_whole_script restrict.goose \
    'if i < 0 { return; }' \
    'if i < 0 { out = set_all(); return; }'

# The confusable flags. The set of every script does not meet the empty
# set of a text that mixes scripts.
run_probe restrict_kinds_all restrict.goose \
    '    if !set_is_empty(set_and(set_a, set_b)) {
        mask |= CONF_SINGLE;' \
    '    if set_is_all(set_a) || set_is_all(set_b) || !set_is_empty(set_and(set_a, set_b)) {
        mask |= CONF_SINGLE;'

# The paragraph split. A CR followed by LF is one terminator.
run_probe bidi_line_crlf bidi.goose \
    'if cps[b] == 0x0D && b + 1 < n && cps[b + 1] == 0x0A { b += 1; }' \
    'if false { b += 1; }'

# The paragraph level of a paragraph of separators follows the direction.
run_probe bidi_line_sep_para bidi.goose \
    '            if dir == BIDI_DIR_RTL { para = 1; }
            lev.clear();' \
    '            lev.clear();'

# Rule L1. The white space at the end of a line takes the paragraph level.
run_probe bidi_line_l1_trailing bidi_line.goose \
    '    if from >= 0 {' \
    '    if false {'

# Rule L1. A separator resets the white space before it.
run_probe bidi_line_l1_separator bidi_line.goose \
    'if kind == BL_SEPARATOR || kind == BL_END {' \
    'if kind == BL_END {'

# A removed code point takes the level of the code point before it, after
# rule L1.
run_probe bidi_line_removed_after_l1 bidi_line.goose \
    'else { out[k - start] = out[k - start - 1]; }' \
    'else { out[k - start] = bl_para(res[k]); }'

# A removed code point takes the level of the code point before it, before
# rule L1.
run_probe bidi_line_removed_resolve bidi_line.goose \
    'if l == BD_REMOVED { l = prev; }' \
    'if l == BD_REMOVED { l = pl; }'

# Rule L2 reverses the runs of a line.
run_probe bidi_line_l2 bidi_line.goose \
    '    bd_reverse(ord, lv[..], maxl, min_odd);' \
    '    min_odd = min_odd + 0;'

# A line that crosses a paragraph is a fault.
run_probe bidi_line_cross bidi_line.goose \
    'if bl_kind(v) == BL_END && k + 1 < limit { return ERR_BAD_ARG; }' \
    'if false { return ERR_BAD_ARG; }'

# An unknown option bit is a fault.
run_probe bidi_line_flag_mask bidi_line.goose \
    '| BIDI_REMOVE_CONTROLS)) != 0 { return ERR_BAD_ARG; }' \
    '| BIDI_REMOVE_CONTROLS | 4)) != 0 { return ERR_BAD_ARG; }'

# Rule L4 mirrors a code point in a right to left run.
run_probe bidi_line_mirror bidi_line.goose \
    'lv[ord[i] - start] % 2 == 1 { cp = mirror_of(cp); }' \
    'lv[ord[i] - start] % 2 == 0 { cp = mirror_of(cp); }'

# The removal of the controls follows the property Bidi_Control.
run_probe bidi_line_controls bidi_line.goose \
    'has_property(cp, PROP_BIDI_CONTROL) { continue; }' \
    '(cp == 0x200E || cp == 0x200D) { continue; }'

# Rule L3 keeps a mark after its base.
run_probe bidi_line_keep_base bidi_line.goose \
    'if (flags & BIDI_KEEP_BASE_COMBINING) != 0 { bl_keep_base(' \
    'if false { bl_keep_base('

# The bound of the input of the paragraph split.
run_probe bidi_line_input_bound bidi_line.goose \
    'if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }' \
    'if s.len > MAX_INPUT * 2 { return ERR_TOO_LONG, -1; }'

# A fault of the resolution clears the offsets.
run_probe bidi_line_resolve_clear bidi_line.goose \
    '        offs.clear();
        return code, off;' \
    '        return code, off;'

# The model engine. Each probe flips one rule of lstm.goose.
run_probe lstm_argmax_last lstm.goose \
    'if v[k] > v[best] { best = k; }' \
    'if v[k] >= v[best] { best = k; }'
run_probe lstm_min_span lstm.goose \
    'const LSTM_MIN_SPAN: i64 = 5;' \
    'const LSTM_MIN_SPAN: i64 = 4;'
run_probe lstm_forward_row lstm.goose \
    'sum = sum + fwd[j] * LSTM_VALS[base + ow + j * 4 + i2];' \
    'sum = sum + 0.0 * LSTM_VALS[base + ow + j * 4 + i2];'
run_probe lstm_backward_start lstm.goose \
    'if i != nc - 1 {' \
    'if i != nc - 2 {'
run_probe lstm_first_break lstm.goose \
    'if (best == 0 || best == 3) && i != 0 {' \
    'if (best == 0 || best == 3) {'
run_probe lstm_single_class lstm.goose \
    'if (best == 0 || best == 3) && i != 0 {' \
    'if (best == 0) && i != 0 {'
run_probe lstm_cluster_limit lstm.goose \
    'if units.len > LSTM_MAX_CLUSTER { return; }' \
    'if units.len > 40 { return; }'
run_probe lstm_model_input lstm.goose \
    'if engine == SEG_MODEL && n > MAX_MODEL_INPUT { return ERR_TOO_LONG; }' \
    'if engine == SEG_MODEL && n > 1000000000 { return ERR_TOO_LONG; }'

echo "$probes probes, $fails failures"
if [ "$fails" -ne 0 ]; then exit 1; fi
exit 0
