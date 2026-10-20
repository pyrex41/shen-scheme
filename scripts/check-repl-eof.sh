#!/bin/sh
# Fork-specific: the REPL must exit cleanly on stdin EOF, and must still
# evaluate a final line that reaches EOF without a trailing newline (the
# Shen 42.1+ reader contract).
#
# Each REPL runs in the background with its output in a temp file and is
# killed after a deadline, so a regression that loops on "error: empty
# stream" fails instead of hanging. (Piping into head is not enough: pr
# swallows write errors, so a looping REPL never dies of SIGPIPE.)
set -u
exe="$1"
deadline="${REPL_EOF_DEADLINE:-30}"
status=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

check() {
  label="$1"; input="$2"; expected="$3"
  printf "$input" > "$tmp/in"
  "$exe" < "$tmp/in" > "$tmp/out" 2>&1 &
  pid=$!
  waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$deadline" ]; do
    sleep 1; waited=$((waited + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    echo "[FAIL]  $label: REPL did not exit at EOF"; status=1
    return
  fi
  wait "$pid" 2>/dev/null
  out=$(head -c 20000 "$tmp/out")
  if printf '%s' "$out" | grep -q 'empty stream'; then
    echo "[FAIL]  $label: REPL reported an empty stream at EOF"; status=1
  elif ! printf '%s' "$out" | grep -qF "$expected"; then
    echo "[FAIL]  $label: expected '$expected' in output"; status=1
  else
    echo "[OK]    $label"
  fi
}

check "EOF without trailing newline" '(+ 1 2)' '(0-) 3'
check "EOF after trailing newline" '(+ 20 22)\n' '(0-) 42'
check "multi-line input at EOF" '(+ 1\n2)' '(0-) 3'
check "two lines, last unterminated" '(+ 1 2)\n(* 3 4)' '(1-) 12'
check "empty input" '' '(0-)'

exit $status
