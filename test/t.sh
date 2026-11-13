#!/usr/bin/env bash
# Runs single tests of the package.
#
#   bash test/t.sh list [text]        print each test as group.test
#   bash test/t.sh run NAME [NAME..]  run the named tests
#
# A NAME is a test (rl_levels), a group.test pair (restrict.rl_levels)
# or a group (restrict). The variable GOOSE holds the compiler, and the
# default is goose. The command fails when a NAME matches no test.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$here")"
goose_bin="${GOOSE:-goose}"
cmd="${1:-}"
shift || true
case "$cmd" in
list)
    out="$(UNICODE_LIST=1 "$goose_bin" run test/run.goose 2>&1 | grep '^test ' | sed 's/^test //')"
    if [ -n "${1:-}" ]; then out="$(printf '%s\n' "$out" | grep -F -- "$1")"; fi
    printf '%s\n' "$out"
    ;;
run)
    [ "$#" -gt 0 ] || { echo "usage: t.sh run NAME [NAME..]"; exit 2; }
    names="$(IFS=,; echo "$*")"
    out="$(UNICODE_ONLY="$names" "$goose_bin" run test/run.goose 2>&1)"
    code=$?
    printf '%s\n' "$out" | grep -v -e 'warning' -e '^ *|' -e '\^~' | grep -v '^$'
    ran="$(printf '%s\n' "$out" | grep -c '^run ')"
    if [ "$ran" -eq 0 ]; then echo "FAIL: no test matches: $names"; exit 1; fi
    exit "$code"
    ;;
*)
    echo "usage: t.sh list [text] | run NAME [NAME..]"; exit 2
    ;;
esac
