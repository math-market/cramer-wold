#!/usr/bin/env bash
# review.sh — automatic check of a submitted proof for this board.
#
# You do not need Lean installed, and you do not need to read the proof.
# This script checks everything that can be checked mechanically and prints a
# verdict. It only reads public data, so anyone can re-run it and get the same
# answer — including the person who submitted.
#
#   Usage:  ./review.sh <pull-request-number>
#   Needs:  git, gh (GitHub CLI, logged in via `gh auth login`), python3

set -uo pipefail

REPO="math-market/cramer-wold"
THEOREM="CramerWold.cramerWold"
SPEC="CramerWold.lean"
# The criteria commit the posted task pins. It contains the *unproved*
# statement, and is used below as a control.
CRITERIA="26fa6275bf33c3fa9ce28dd600db25963f63c44c"
# The only axioms a proof may rest on. These three are the foundations Mathlib
# itself is built on; anything else is an extra assumption granted for free.
ALLOWED='[propext, Classical.choice, Quot.sound]'
# Files that define what counts as a solution. A submission may not touch them.
PROTECTED='^(\.github/|lakefile\.toml$|lean-toolchain$|lake-manifest\.json$)'

PR="${1:-}"
[ -z "$PR" ] && { echo "usage: $0 <pull-request-number>"; exit 2; }

pass=0; fail=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
no()   { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); }
info() { printf '        %s\n' "$1"; }

# The statement as it must stay: everything from the top of the file down to
# and including the `:= by` that opens the proof — imports, namespace, opens,
# variables and the theorem signature. Comments and blank lines are ignored,
# so the submitter may write whatever notes they like; the code may not move.
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

echo
echo "Reviewing $REPO PR #$PR"
echo

meta=$(gh pr view "$PR" --repo "$REPO" --json headRefOid,baseRefName,files 2>/dev/null) \
  || { echo "Could not read PR #$PR. Is 'gh' logged in?"; exit 2; }
head=$(jq -r .headRefOid <<<"$meta")
base=$(jq -r .baseRefName <<<"$meta")
files=$(jq -r '.files[].path' <<<"$meta")
info "submitted commit $head"
echo

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git clone -q "https://github.com/$REPO.git" "$tmp/r" 2>/dev/null
git -C "$tmp/r" fetch -q origin "$head" 2>/dev/null

# ---------------------------------------------------------------- 1. scope
echo "1. Did the submission change only the proof?"
touched=$(grep -E "$PROTECTED" <<<"$files" || true)
if [ -n "$touched" ]; then
  no "it modified files that define the task itself:"
  info "$(tr '\n' ' ' <<<"$touched")"
  info "That is the build configuration or the CI check — so the submission may"
  info "have altered the very test it is judged by. Stop here and escalate."
else
  ok "build configuration and CI check untouched"
fi
echo

# ------------------------------------------------------- 2. statement fixed
echo "2. Is it a proof of OUR theorem, or was the statement changed?"
git -C "$tmp/r" show "$CRITERIA:$SPEC" | spec_of > "$tmp/spec.locked" 2>/dev/null
git -C "$tmp/r" show "$head:$SPEC"     | spec_of > "$tmp/spec.head"   2>/dev/null
if ! [ -s "$tmp/spec.locked" ]; then
  no "could not read the locked statement from the criteria commit"
elif diff -q "$tmp/spec.locked" "$tmp/spec.head" >/dev/null 2>&1; then
  ok "the theorem, its hypotheses and the imports are byte-identical to the locked version"
else
  no "the statement is NOT the one that was posted. Differences:"
  diff "$tmp/spec.locked" "$tmp/spec.head" | sed 's/^/        /'
  info "This is the failure that matters most: a weakened or altered statement"
  info "passes every other check on this list. Do not accept."
fi
echo

# ------------------------------------------------ 3. no gaps, no back doors
echo "3. Does the proof contain gaps or escape hatches?"
body=$(git -C "$tmp/r" show "$head:$SPEC" | sed -n '/:= by/,$p')
bad=""
grep -qE '(^|[^[:alnum:]_])sorry([^[:alnum:]_]|$)' <<<"$body" && bad+=" sorry"
grep -qE '(^|[^[:alnum:]_])admit([^[:alnum:]_]|$)'  <<<"$body" && bad+=" admit"
grep -q  'native_decide'                            <<<"$body" && bad+=" native_decide"
grep -qE '^[[:space:]]*axiom[[:space:]]'            <<<"$(git -C "$tmp/r" show "$head:$SPEC")" && bad+=" axiom"
if [ -z "$bad" ]; then
  ok "no 'sorry', no 'admit', no new axioms, no 'native_decide'"
else
  no "found:$bad"
  info "'sorry'/'admit' leave the proof incomplete; a new 'axiom' assumes what was"
  info "to be proved; 'native_decide' trusts compiled code and is barred by this board."
fi
echo

# --------------------------------------------------------- 4. CI, on the PR
echo "4. Does it build?"
run=$(gh api "repos/$REPO/actions/runs?head_sha=$head" \
      --jq '[.workflow_runs[] | select(.name=="verify")] | first' 2>/dev/null)
concl=$(jq -r '.conclusion // "none"' <<<"$run")
runid=$(jq -r '.id // empty' <<<"$run")
if [ "$concl" = "success" ]; then
  ok "built successfully against the pinned toolchain and Mathlib (run $runid)"
else
  no "the build did not succeed: $concl (run ${runid:-unknown})"
fi
echo

# ------------------------------------------------------ 5. what it rests on
echo "5. What does the finished proof assume?"
report=""
if [ -n "$runid" ]; then
  gh run download "$runid" --repo "$REPO" -n axiom-report -D "$tmp/a" >/dev/null 2>&1 \
    && report=$(cat "$tmp/a/axiom-report.txt" 2>/dev/null)
fi
if [ -z "$report" ]; then
  no "could not retrieve the axiom report from the build"
else
  line=$(grep "depends on axioms" <<<"$report" | head -1)
  info "${line:-<no axiom line found>}"
  if grep -q "sorryAx" <<<"$report"; then
    no "the proof still has a gap in it somewhere ('sorryAx')"
    info "Note this catches gaps in anything the theorem leans on, not just this file."
  elif [ "$line" = "'$THEOREM' depends on axioms: $ALLOWED" ]; then
    ok "rests on Mathlib's three foundations and nothing else"
  else
    no "it rests on something beyond the three standard axioms — see the line above"
  fi
fi
echo

# --------------------------------- 6. the control: does the check work at all?
echo "6. Control — would any of this have caught an unproved statement?"
info "The criteria commit holds the same theorem with the proof left open."
info "The identical check runs on it, and must FAIL. If it passes on both, a"
info "green result above would mean nothing."
ctl=$(gh api "repos/$REPO/actions/runs?head_sha=$CRITERIA" \
      --jq '[.workflow_runs[] | select(.name=="verify")] | first' 2>/dev/null)
cc=$(jq -r '.conclusion // "none"' <<<"$ctl"); cid=$(jq -r '.id // empty' <<<"$ctl")
if [ "$cc" = "failure" ]; then
  ok "the check correctly rejects the unproved statement (run $cid)"
else
  no "the check did NOT reject the unproved statement (got: $cc)"
  info "Until this is explained, treat every result above as unverified."
fi
echo

# ------------------------------------------------------------------ verdict
echo "==========================================================="
if [ "$fail" -eq 0 ]; then
  printf '  \033[32mAll %d checks passed.\033[0m\n\n' "$pass"
  cat <<'EOT'
  This is a complete, gap-free proof of exactly the theorem that was posted,
  assuming nothing beyond Mathlib's own foundations.

  One judgement no script can make for you: whether the theorem statement
  *itself* faithfully says what the board claims it says. It is written to be
  readable without Lean — TASK.md gives the plain-English rendering next to
  the formal one. Read those two and satisfy yourself they agree. If they do,
  the mathematical content of this review is settled and you can file it.
EOT
else
  printf '  \033[31m%d of %d checks failed.\033[0m\n\n' "$fail" "$((pass+fail))"
  cat <<'EOT'
  Do not accept on a green build alone. A failure in step 1, 2 or 3 means the
  submission may have moved the goalposts rather than cleared them, and a
  failure in step 6 means the checks themselves are not trustworthy here.
  Quote the failing section in your review and ask for a fix.
EOT
fi
echo "==========================================================="
echo
[ "$fail" -eq 0 ]
