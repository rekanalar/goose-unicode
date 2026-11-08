#!/usr/bin/env bash
# The mutation probes of the package. Each probe flips one rule of the
# package in a copy of it. The test program must fail after the flip.
# The probes prove that the test program checks the rule.
#
# Usage: bash test/mutate.sh [goose binary]
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
pkg="$(dirname "$here")"
goose_bin="${1:-goose}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fails=0
probes=0

# run_probe <name> <file> <old text> <new text>
run_probe() {
    local name="$1" file="$2" old="$3" new="$4"
    local copy="$work/$name"
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
    local out
    out="$(cd "$copy" && "$goose_bin" run test/run.goose 2>&1)"
    local code=$?
    if [ "$code" -eq 0 ]; then
        echo "FAIL: the probe $name left the test program green"
        fails=$((fails + 1))
        return
    fi
    echo "ok: the probe $name made the test program fail"
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
    'return cp >= 0 && cp <= 0x10FFFF && !(cp >= 0xD800 && cp <= 0xDFFF);' \
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

echo "$probes probes, $fails failures"
if [ "$fails" -ne 0 ]; then exit 1; fi
exit 0
