#!/usr/bin/env bash
# check-statement.sh — is this a proof of the theorem we actually posted?
#
# A green build and a clean axiom report only establish that the submitter
# proved *something* honestly. They say nothing about whether it is *our*
# theorem: adding a hypothesis that makes the statement trivially true passes
# every other check we run. This is the check that catches that, and it is the
# reason the others can be trusted.
#
# Compares the locked region of the statement file — everything from the top of
# the file down to and including the `:= by` that opens the proof, so imports,
# namespace, opens, variables and the theorem signature — against the criteria
# commit pinned by the posted task. Comments and blank lines are ignored; a
# submitter may annotate freely, but the code may not move.
#
#   Usage:  ./check-statement.sh [git-ref]     (default: the working tree)

set -uo pipefail

SPEC="CramerWold.lean"
CRITERIA="26fa6275bf33c3fa9ce28dd600db25963f63c44c"
REF="${1:-}"

spec_of() {
python3 -c '
import sys, re
src = sys.stdin.read()
src = re.sub(r"/-.*?-/", "", src, flags=re.S)   # block comments
src = re.sub(r"--[^\n]*", "", src)              # line comments
out = []
for line in src.split("\n"):
    line = line.rstrip()
    if not line.strip():
        continue
    out.append(line)
    if line.endswith(":= by"):
        break
print("\n".join(out))
'
}

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# The criteria commit may be absent in a shallow CI checkout; fetch on demand.
git cat-file -e "$CRITERIA^{commit}" 2>/dev/null || git fetch -q --depth=1 origin "$CRITERIA" 2>/dev/null

if ! git show "$CRITERIA:$SPEC" 2>/dev/null | spec_of > "$tmp/locked"; then
  echo "check-statement: could not read $SPEC at criteria commit $CRITERIA" >&2
  exit 2
fi
[ -s "$tmp/locked" ] || { echo "check-statement: locked statement came back empty" >&2; exit 2; }

if [ -n "$REF" ]; then
  git show "$REF:$SPEC" | spec_of > "$tmp/actual"
else
  spec_of < "$SPEC" > "$tmp/actual"
fi

if diff -q "$tmp/locked" "$tmp/actual" >/dev/null 2>&1; then
  echo "check-statement: OK — statement identical to criteria commit ${CRITERIA:0:7}"
  exit 0
fi

echo "check-statement: FAILED — the statement is not the one that was posted." >&2
echo "  (< locked at ${CRITERIA:0:7}   > as submitted)" >&2
diff "$tmp/locked" "$tmp/actual" | sed 's/^/  /' >&2
exit 1
