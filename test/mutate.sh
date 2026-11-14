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
        collate.goose) echo "collopt" ;;
        collate_opts.goose) echo "collopt" ;;
        *) echo "" ;;
    esac
}

# run_probe_pair <name> <file> <old1> <new1> <old2> <new2>
# A probe that changes two rules of one file.
run_probe_pair() {
    local name="$1" file="$2" old1="$3" new1="$4" old2="$5" new2="$6"
    if [ -n "${MUTATE_ONLY:-}" ] && [[ "$name" != *"$MUTATE_ONLY"* ]]; then return; fi
    local copy="$work/$name"
    local groups
    groups="$(groups_for "$file")"
    probes=$((probes + 1))
    rm -rf "$copy"
    cp -r "$pkg" "$copy"
    python3 - "$copy/$file" "$old1" "$new1" "$old2" "$new2" <<'RULE'
import sys
path, old1, new1, old2, new2 = sys.argv[1:6]
text = open(path, encoding="utf-8").read()
if old1 not in text or old2 not in text:
    sys.exit(1)
text = text.replace(old1, new1, 1).replace(old2, new2, 1)
open(path, "w", encoding="utf-8").write(text)
RULE
    if [ $? -ne 0 ]; then
        echo "FAIL: the probe $name did not find its rules"
        fails=$((fails + 1))
        return
    fi
    local code group
    for group in $groups; do
        (cd "$copy" && UNICODE_SUITES="$group" "$goose_bin" run test/run.goose >/dev/null 2>&1)
        code=$?
        if [ "$code" -ne 0 ]; then
            echo "ok: the probe $name made the test program fail"
            return
        fi
    done
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

# The options of the collation. Each probe flips one rule of the walk.
run_probe collopt_variable_limit collate.goose \
    'const COLL_VAR_LAST: i64 = 0x04E4;' \
    'const COLL_VAR_LAST: i64 = 0x04DF;'
run_probe collopt_variable_follow collate.goose \
    'if (p > 0x0200 && p <= COLL_VAR_LAST) || (p == 0 && st.dropped == 1) {' \
    'if (p > 0x0200 && p <= COLL_VAR_LAST) {'
run_probe collopt_numeric_zeros collate_opts.goose \
    'while k < j - 1 && coll_digit_value(cps[k]) == 0 { k += 1; }' \
    'while k < j - 1 && false { k += 1; }'
run_probe collopt_numeric_digits collate_opts.goose \
    'for m in k..j { l1.push(COLL_NUM_BASE + coll_digit_value(cps[m])); }' \
    'for m in k..j { l1.push(COLL_NUM_BASE + (9 - coll_digit_value(cps[m]))); }'
run_probe collopt_case_polarity collate.goose \
    'if st.case_first == CASE_LOWER_FIRST && upper { bit = 1; }' \
    'if st.case_first == CASE_LOWER_FIRST && !upper { bit = 1; }'
run_probe collopt_case_shift collate.goose \
    'return (bit << 5) | t;' \
    'return (bit | t);'
# The numbers sit below the digits. A shift upward gives a weight above
# 16 bits to the last code points of the range.
run_probe collopt_weight_shift collate.goose \
    'if st.numeric == 1 && p < COLL_DIGIT_BASE { return p - 16; }' \
    'if st.numeric == 1 && p >= COLL_DIGIT_BASE { return p + 16; }'
# The identical key counts the separator and the terminator.
run_probe collopt_identical_bound collate_opts.goose \
    'if out.len + cps.len + 2 > MAX_OUTPUT {' \
    'if out.len + cps.len + 1 > MAX_OUTPUT {'
run_probe collopt_strength_check collate_opts.goose \
    'if s != STRENGTH_PRIMARY && s != STRENGTH_SECONDARY && s != STRENGTH_TERTIARY' \
    'if s != STRENGTH_PRIMARY && s != STRENGTH_SECONDARY && s != STRENGTH_TERTIARY && s != 4'
run_probe collopt_compare_bound collate_opts.goose \
    'if coll_over(l1[..], l2[..], l3[..], lc[..], lq[..], o, 0)
            || coll_over(m1[..], m2[..], m3[..], mc[..], mq[..], o, 0) {' \
    'if coll_over(l1[..], l2[..], l3[..], lc[..], lq[..], o, 4 * MAX_OUTPUT)
            || coll_over(m1[..], m2[..], m3[..], mc[..], mq[..], o, 4 * MAX_OUTPUT) {'

# The bound of a numeric run. The run adds its weights to the bound
# before it writes them, and the walk checks the bound after each step.
# The probe takes both checks out, so no bound of the key holds.
run_probe_pair collopt_no_bound collate_opts.goose \
    'return n > MAX_OUTPUT;' 'return n > 4 * MAX_OUTPUT;' \
    'if n > MAX_OUTPUT { return j - i, true; }' \
    'if n > 4 * MAX_OUTPUT { return j - i, true; }'

# The bound of the key counts the levels up to the strength. The key of
# the primary strength holds the primary level alone.
run_probe collopt_strength_bound collate_opts.goose \
    'if strength >= STRENGTH_SECONDARY { n += l2 + 1; }' \
    'if strength >= STRENGTH_SECONDARY { n += l2 + 1; } n += l2;'

# The case class of an element. The nine upper case weights decide it.
# The weight 0x08 holds the upper case letters. The probe takes that bit
# out of the mask, so the letters lose their upper case class.
run_probe collopt_case_mask collate.goose \
    'const COLL_UPPER_MASK: i64 = (1 << 8) | (1 << 9) | (1 << 10) | (1 << 11)' \
    'const COLL_UPPER_MASK: i64 = (1 << 9) | (1 << 10) | (1 << 11)'

# The bound of the key. The sum of the levels of the strength and the
# separators gives the size of the key.
run_probe collopt_output_bound collate_opts.goose \
    'return n > MAX_OUTPUT;' \
    'return n > 4 * MAX_OUTPUT;'

# The case level. The weight of a lower case element is 2 and the weight
# of an upper case element is 3. The probe swaps them, so the case level
# gives the opposite sign.
run_probe collopt_case_weight collate.goose \
    'if upper { return 3; }' \
    'if upper { return 2; }'
# The case level skips an element with no secondary weight at the higher
# strengths. The probe takes that rule out, so the marks join the level.
run_probe collopt_case_skip collate.goose \
    'if s != 0 { lc.push(coll_case(st, t)); }' \
    'lc.push(coll_case(st, t));'
# The fourth level holds the primary weight of each element that the
# shifted handling drops. The probe drops that weight, so the fourth
# level gives the same sign as the tertiary level.
run_probe collopt_fourth_weight collate.goose \
    'lq.push(coll_primary(st, p));' \
    'lq.push(COLL_FOURTH_REGULAR);'
# The fourth level holds the weight of an element that is not variable.
# The probe takes that rule out, so the level holds no weight for the
# elements that the walk keeps.
run_probe collopt_fourth_regular collate.goose \
    'lq.push(COLL_FOURTH_REGULAR);' \
    'lq.push(0);'
# The case level of the options. The field outside its range gives the
# fault. The probe accepts every value, so a bad field gives a result.
run_probe collopt_case_level_check collate_opts.goose \
    'return o.case_level >= CASE_LEVEL_OFF && o.case_level <= CASE_LEVEL_ON;' \
    'return true;'
# The quaternary strength. The value 3 is the quaternary strength. The
# probe takes it out of the check, so the value gives the fault.
run_probe collopt_quaternary_check collate_opts.goose \
    '&& s != STRENGTH_QUATERNARY && s != STRENGTH_IDENTICAL {' \
    '&& s != STRENGTH_IDENTICAL {'

# A run of digits is one element of the collation, so the fourth level
# takes one weight for the run. The probe takes that weight out, so the
# fourth level holds no weight for the run.
run_probe collopt_numeric_fourth collate_opts.goose \
    'if st.strength >= STRENGTH_QUATERNARY { lq.push(COLL_FOURTH_REGULAR); }' \
    'if st.strength >= STRENGTH_QUATERNARY { lq.push(0); }'

echo "$probes probes, $fails failures"
if [ "$fails" -ne 0 ]; then exit 1; fi
exit 0
